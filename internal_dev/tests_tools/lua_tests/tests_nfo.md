# Headless Lua Test Guide
Out-of-game tests that run addon Lua under desktop Lua 5.1 against a stubbed WoW API, so runtime logic (state machines, timers, defaults, events) is verified without launching the client. This is the owner doc for everything in `internal_dev/tests_tools/lua_tests/`.


## Table of Contents
- [Why This Exists](#why-this-exists)
- [What Is Testable Here](#what-is-testable-here)
- [What Is Not Testable Here](#what-is-not-testable-here)
- [Running](#running)
- [Folder Layout](#folder-layout)
- [The Stub: wow_stub.lua](#the-stub-wow_stublua)
- [The Harness: harness.lua](#the-harness-harnesslua)
- [Writing A Test](#writing-a-test)
- [Simulating Game State](#simulating-game-state)
- [Extending The Stub](#extending-the-stub)
- [Design Decisions And Pitfalls](#design-decisions-and-pitfalls)


## Why This Exists
- In-game testing is the slowest loop in this project: reload UI, walk slider/toggle combinations, reproduce combat timing by hand.
- WoW addons are plain Lua 5.1, so anything that is not a real client feature (rendering, taint, secure frames) can execute under a desktop interpreter against fakes.
- The static tier (LuaLS/Ketho, `check_fast.ps1`) catches syntax and API-signature mistakes but never executes logic. This tier executes it: timers fire, events dispatch, state machines transition.
- Result: the tedious mechanical part of testing (every setting combination through a state machine, exact event orderings that took in-game sessions to reproduce) becomes a sub-second command; the in-game pass shrinks to a final visual/taint smoke check.


## What Is Testable Here
- State machines and timing logic: fade sequences, delay/debounce behavior, ticker lifecycles, combat-interrupt handling.
- Anything driven by `C_Timer`: the stub clock is manual, so a 30-second scenario runs instantly and deterministically.
- Event-driven flows: `ADDON_LOADED` boot, `PLAYER_REGEN_DISABLED/ENABLED`, `UNIT_HEALTH`, module enable/disable reactions.
- DB handling: defaults merging, clamping, migrations, profile logic, saved-variable shapes.
- Pure computation: aura sorting/filtering, timing-bucket assignment, layout math given fixed fake sizes.
- Call-level frame assertions: every stub frame records its method calls, so a test can assert "SetAlpha was called with 0.5" or read back `frame:GetAlpha()`.
- Full-addon load: the smoke suite loads all TOC files (vendored Libs included) in real load order and boots, catching load-time errors, nil-global calls, and file-order dependencies.


## What Is Not Testable Here
- Taint, secure frames, and combat lockdown semantics: no mock reproduces Blizzard taint propagation. The taint rules stay an in-game concern.
- Actual rendering and anchoring visuals: a test can assert SetPoint arguments, not that the layout looks right.
- Real client event timing/order and template-defined child widgets (`$parent...` children from XML templates do not exist).
- Anything the stub fakes with a plausible value (atlas metadata, screen size, class colors) is only as accurate as the fake; do not treat stub output as evidence about real client behavior.


## Running
- All suites: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1`
- One suite by substring: append the filter, e.g. `run_tests.ps1 pf_fade`.
- Requires a Lua 5.1 interpreter; the runner checks `C:\Program Files (x86)\Lua\5.1\lua.exe` first, then PATH (`lua5.1`, `lua51`, `lua`, `luajit`).
- Each `tests/test_*.lua` file runs in its own Lua process so addon global state never leaks between suites. Exit code 0 = all passed, 1 = at least one suite failed, 2 = runner setup problem.


## Folder Layout
- `wow_stub.lua`: the fake WoW client API. Loading it (via `require`) installs frames, timers, events, and globals into the process environment.
- `harness.lua`: addon loader plus test toolkit; every test file starts by requiring this.
- `run_tests.ps1`: process-per-suite runner with substring filtering.
- `tests/test_smoke_load_all.lua`: loads every TOC file, boots, exercises module toggles, `/lst status`, and 30s of simulated time.
- `tests/test_pf_fade.lua`: Player Frame fade state machine scenarios (delay/fade/faded, combat interrupts, health gate, slider retargeting, timer-leak check).
- `tests/test_table_utils.lua`: shared table/default utilities.


## The Stub: wow_stub.lua
The stub is organized in regions; `local stub = require("wow_stub")` returns the controller table (also reachable as `harness.stub`).

Clock and C_Timer:
- `stub.now` is the fake time; `GetTime()` returns it.
- `C_Timer.After/NewTimer/NewTicker` schedule onto a queue; nothing fires until `stub.Advance(dt)` runs. Advance fires due timers in chronological order, honoring timers scheduled by fired callbacks within the same advance, and reschedules tickers.
- `stub.ActiveTimerCount()` supports leak assertions: capture a baseline, run a scenario, assert the count returns to baseline.

Frames:
- `CreateFrame(kind, name, parent, template)` returns a table with a shared method set: geometry, points, visibility (Show/Hide fire OnShow/OnHide on transitions), alpha, scripts (`SetScript`, `HookScript` chains like the client), event registration, child/region creation, and widget-specific methods for FontString, Texture, Slider/StatusBar, EditBox, Button/CheckButton, Cooldown, and GameTooltip.
- Every method call is recorded: `frame:GetCalls("SetAlpha")` returns all argument lists, `frame:GetLastCall("SetPoint")` the most recent.
- Named frames self-register as globals, matching the client.
- `stub.FireEvent(event, ...)` dispatches to every frame registered for that event with an OnEvent script.
- Pre-built Blizzard tree: `UIParent`, `PlayerFrame` (with `PlayerFrameContent.PlayerFrameContentMain.HitIndicator`), `Minimap`, `GameTooltip`, `ObjectiveTrackerFrame` (with `NineSlice`, `Header.Text`, `Header.MinimizeButton`). Extend this list when a module walks deeper.

Game state knobs (set directly, then fire the matching event or call the entry point):
- `stub.in_combat`: read by `InCombatLockdown()` / `UnitAffectingCombat()`.
- `stub.player_health_percent` (0–1): read by `UnitHealthPercent` / `UnitHealth`.
- `stub.auras[unit] = { buffs = {...}, debuffs = {...} }`: backs all `C_UnitAuras` getters, including a working `GetAuraDuration` handle (remaining time computed against `stub.now`).
- `stub.cvars`: backed by `Get/SetCVar`.
- `stub.missing_globals`: name→count of every unknown global read; `stub.strict_missing = true` turns those reads into errors for tight suites.
- `C_CurveUtil.CreateCurve()` returns a real linear-interpolating curve, so curve-gated math (pf_fade health gate) computes genuine values, not placeholders.


## The Harness: harness.lua
- `h.load_file(rel_path)`: loads one addon file with the WoW vararg convention `(addonName, addonTable)`; all files share `h.addon`.
- `h.load_addon(filter)`: loads TOC files in real load order. `Libs/`, `core/`, and `functions/` always load (modules depend on them); `filter` limits the rest by substring, e.g. `h.load_addon("modules/player_frame")`. No filter loads everything.
- `h.boot(saved_variables)`: sets `Ls_Tweeks_DB` then fires `ADDON_LOADED` and `PLAYER_ENTERING_WORLD`, simulating a fresh login.
- Gameplay helpers: `h.enter_combat()` / `h.leave_combat()` (flip `stub.in_combat` and fire the regen events), `h.set_health(pct)` (0–1, fires `UNIT_HEALTH`), `h.advance(dt)`, `h.fire_event(event, ...)`.
- Test registry: `h.test(name, fn)` registers; `h.run(suite_name)` executes all, prints PASS/FAIL per test, and exits nonzero on any failure.
- Asserts: `h.eq(actual, expected, label)`, `h.near(actual, expected, tolerance, label)` for float/alpha comparisons, `h.ok(value, label)`, `h.is_nil(value, label)`. Failure messages include expected vs got.


## Writing A Test
1. Create `tests/test_<area>.lua` with the standard header (2-sentence file comment, then the `package.path` line copied from an existing test, then `local h = require("harness")`).
2. Load code: `h.load_addon("modules/<name>")` for one module slice, `h.load_file(...)` for a single shared file, or `h.load_addon()` for everything.
3. Arrange state: set `Ls_Tweeks_DB` directly (or pass saved variables to `h.boot` when the test needs the real boot path), set stub knobs like `stub.in_combat` or `stub.player_health_percent`.
4. Act: call module entry points directly (e.g. `h.addon.player_frame.fade.on_leave_combat(db)`) or drive through events with `h.fire_event`, then `h.advance(seconds)` to let timers run.
5. Assert: state getters the module exposes (`get_runtime_status()`), frame getters (`PlayerFrame:GetAlpha()`), or recorded calls (`frame:GetLastCall("SetPoint")`).
6. Finish with `h.run("<suite name>")`. Reset shared runtime between tests inside a suite (the pf_fade suite's `reset_runtime()` pattern) — tests in one file share one Lua process.
7. Run just your suite while iterating: `run_tests.ps1 <substring>`.


## Simulating Game State
- Combat cycle: `h.enter_combat()` ... `h.leave_combat()`; or set `stub.in_combat` without firing events to model "combat began but the event has not been processed yet" race windows.
- Time: `h.advance(2.5)` fires everything due in that window instantly; a follow-up `h.advance(...)` continues the timeline. Never sleep.
- Health: `h.set_health(0.30)` for event-driven paths, or set `stub.player_health_percent` and call the module's health handler directly.
- Auras: populate `stub.auras.player = { buffs = { { auraInstanceID = 1, name = "X", spellId = 123, duration = 10, expirationTime = stub.now + 10, applications = 2, icon = 134400 } }, debuffs = {} }` using C_UnitAuras aura-data field names, then fire `UNIT_AURA`.
- Login/reload: `h.boot({ open_on_reload = true })` exercises the real `ADDON_LOADED` path including DB initialization and module flags.


## Extending The Stub
- The smoke suite prints "globals the stub returned nil for" — that list is the live gap report. Extend only when a gap changes behavior under test; a nil global that the addon already guards against is faithful to a missing in-game API.
- New global function or C_* namespace: add it to the matching stub region with the smallest plausible behavior, returning realistic types (check `api_lookup.ps1 <ApiName>` for real signatures before inventing return values).
- New frame method that must return a real value: add it to `frame_methods` explicitly. Unknown verb-prefixed methods already no-op safely, but their nil return breaks arithmetic/indexing on the result.
- New Blizzard sub-frame the addon walks (`Frame.Child.GrandChild`): build it in the "common globals" region next to the existing PlayerFrame/ObjectiveTrackerFrame trees.
- Keep fakes deterministic: no randomness, no wall-clock reads; everything derives from `stub.now` and explicit knobs.


## Design Decisions And Pitfalls
- Verb-prefix method rule: unknown frame keys become recorded no-op methods only when they start with a method verb (Set/Get/Is/Has/Register/Create/...). All other unknown keys read as nil, exactly like an unset field in game. This matters: a naive catch-all fallback turned data-field reads like `frame.NineSlice` or `button.minimapPos` into functions and broke guard clauses. If a legitimate method falls outside the prefix list, add the prefix or define the method explicitly.
- Internal stub state lives in `__`-prefixed keys (`__alpha`, `__points`, `__calls`); the method fallback ignores them. Never name addon-visible fields with a `__` prefix in tests.
- Process-per-suite is the isolation model: within one file, module-local state (upvalues like the fade state machine's `state`) persists across `h.test` blocks. Either order tests to tolerate that or reset explicitly at the top of each test.
- Vendored `Libs/` load for real (they are plain Lua); their in-game behavior is not under test and should not be asserted on.
- `h.near` over `h.eq` for alpha/positions: fade math accumulates float error across ticks; the pf_fade suite uses tolerance 0.011 for one-tick slack.
- A green run here does not replace the final in-game pass — it replaces the mechanical portion of it. Taint, visuals, and real event order still get verified in the client.
