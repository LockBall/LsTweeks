# LsTweeks Project Memory

Shared memory for coding agents. Keep this file concise and durable: architecture, ownership, defaults, workflow rules, and hard-won debugging notes only. Module-specific memory lives next to this file in `internal_dev/working_docs/proj_mem/`.


## Table of Contents
- [Project Operations](#project-operations)

  - [Workflow](#workflow)

  - [Ketho / LuaLS](#ketho--luals)

  - [Packaging / Release](#packaging--release)

- [Project Overview](#project-overview)

  - [AddOn Summary](#addon-summary)

  - [File Map](#file-map)

- [Shared Architecture](#shared-architecture)

  - [Core Architecture Rules](#core-architecture-rules)

  - [GUI/Layout Rules](#guilayout-rules)

  - [Key WoW APIs And Lessons](#key-wow-apis-and-lessons)

- [Agent Start](agent_start.md)

- [Code Map](code_map.md)

- [Module Memory](#module-memory)

  - [Player Frame](player_frame.md)

  - [Sound Levels](sound_levels.md)

  - [Skyriding Vigor](skyriding_vigor.md)

  - [Aura Frames](aura_frames.md)


## Project Operations


### Workflow
- Treat this file and the module files under `internal_dev/working_docs/proj_mem/` as the project source of truth before non-trivial edits.

- Update this file or the relevant module file when architecture, defaults, APIs, or debugging lessons change.

- Read `agent_start.md` first when starting a new coding-agent session; it routes to this file, the public README, and relevant module memory without duplicating their contents.

- Internal docs live under `internal_dev/`. Active working docs live under `internal_dev/working_docs/`: project/module memory files under `proj_mem/`, `ToDo.md`, `scratchpad.md`, and focused review notes under `review_2026Jun/`. Completed-feature notes live under `internal_dev/completed_features/` and are reviewed on demand. Root markdown is public-facing release documentation.

- Tool recovery and diagnostics notes live in `internal_dev/tests_tools/tools_notes.md`; check them first if Codex shell execution, Windows sandbox setup, Ketho/LuaLS checks, or the local `.venv` breaks.

- Lua syntax check: `& 'C:\Program Files (x86)\Lua\5.1\luac.exe' -p <files>`.

- Fast local validation: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`. Add `-Package` to also build and verify the release zip.


### Ketho / LuaLS
- Use VS Code WoW API (`ketho.wow-api`) with LuaLS (`sumneko.lua`) for Blizzard API reviews. Enable `wowAPI.luals.frameXML` for FrameXML/CDM/widget work.

- Treat LuaLS diagnostics as review prompts, not automatic change requests.

- Shell LuaLS checks can run with `--check`, but need explicit Ketho `Annotations/Core` and `Annotations/FrameXML` library paths plus workspace-local `--logpath`/`--metapath`; keep Lua check output under `internal_dev/tests_tools/lua_checks/`.

- Preferred shell helper: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1`.

- Direct annotation root: `%USERPROFILE%\.vscode\extensions\ketho.wow-api-<version>\Annotations\`.

- For APIs, grep annotations by name and cross-check call sites before changing code.


### Packaging / Release
- Release package command: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1`. It writes `dist/<toc-name>-<version>.zip` and runs `internal_dev/tests_tools/packaging/verify-package.ps1`.

- Packaging docs and policy live in `internal_dev/tests_tools/packaging/package_me.md` and `internal_dev/tests_tools/packaging/package-policy.json`.

- Packaging is data-driven. Update `internal_dev/tests_tools/packaging/package-policy.json` before changing public include/exclude behavior; verifier invariants still protect required/forbidden paths.

- README image assets and Sound Levels reference/log files are public-facing and included.


## Project Overview


### AddOn Summary
**L's Tweeks** is a modular WoW 12.0.5+ UI addon by LockBall. Keep the intentional **Tweeks** spelling.

- Slash command: `/lst` (`SLASH_LSTWEEKS1`)

- SavedVariables: `Ls_Tweeks_DB`

- Version edit point: `LsTweeks.toc` only; verify interface number in-game with `/dump (select(4, GetBuildInfo()))`


### File Map
```
README.md               public release/readme documentation
sources.md              source ledger for APIs, release references, tools, and embedded libraries
LsTweeks.toc            addon metadata, interface number, version, and load order

core/                   addon bootstrap, DB init, slash command, shared timing/theme, settings shell
functions/              shared UI factories and helpers: reset, sliders, dropdowns, color picker, riveted panels
modules/                feature modules; deeper ownership notes live in the module memory files below
  player_frame/         Player Frame settings, portrait combat text, and OOC fade
  sound_levels/         preset sound replacement controls and Fishing Focus
  skyriding_vigor/      restored vigor display, style/layout state, charge detection, fade, and GUI
  settings/             general addon settings
  aura_frames/          aura scanning/rendering, CDM integration, frame settings, profiles, and GUI

libs/                   embedded libraries, documented in sources.md
media/                  public addon/readme assets
internal_dev/          internal docs excluded from release zips
  tests_tools/          probes, test helpers, diagnostics helpers, packaging helpers, logs, and tool notes
  working_docs/         active project docs, scratch notes, review notes, and proj_mem/
  completed_features/   completed-feature notes reviewed on demand
dist/                   generated package output, ignored
```

Every Lua file starts with a short responsibility header before `local addon_name, addon = ...`. Use `code_map.md` for compact file ownership and common commands; keep detailed per-file ownership notes in the relevant module memory file instead of expanding this map.

Lua section headers use VS Code foldable region markers with visual dividers: `--#region SECTION NAME =====` and `--#endregion SECTION NAME =====`. Use uppercase section names and keep region markers paired. Put the explanatory section comment directly under `--#region` with no blank line, put no blank line before `--#endregion`, and leave two blank lines before the next `--#region`.


## Shared Architecture


### Core Architecture Rules
- Module pattern: `local addon_name, addon = ...`; share state through `addon` and `addon.aura_frames` (`M`).

- Sidebar categories use `addon.register_category(name, builder, { order = n })`; equal order values preserve registration order. Default order is 100.

- Feature modules are listed in `addon.FEATURE_MODULES` (`core/init.lua`) and can be disabled with `Ls_Tweeks_DB.modules.<module_key> = false`. Categories for feature modules pass `opts.module_key`; `core/main_frame.lua` keeps disabled module pages visible and selectable in the sidebar, greys them out, and overlays the selected page so options can be inspected but not changed.

- Runtime modules that have side effects implement `M.set_module_enabled(enabled)` so Settings tab toggles can stop/restart owned runtime state without changing each module's own feature-level settings.

- Current module toggles are soft-disable gates after addon files have loaded; they stop owned runtime work but do not unload code or free all memory. If disabled behavior is reworked, start with diagnostics such as a `/lst status` report, then consider lazy construction or LoadOnDemand-style boundaries for modules where the resource savings are worth the complexity.

- Stateful modules implement `on_reset_complete()` and resync controls/runtime after reset. Module reset panels use `CreateModuleReset()` and pass `opts.after_reset = M.on_reset_complete` so only that module is synchronized.

- Apply defaults with `addon.apply_defaults(defaults, db)`; guard DB tables with `or {}`.

- Shared timing values live in `addon.UPDATE_INTERVALS`; do not hardcode repeated refresh/debounce delays.

- Behavior-specific runtime timing aliases live in `addon.UPDATE_INTERVALS` immediately after the generic buckets. Use aliases such as `aura_visible_icon_tick`, `aura_event_bucket`, `aura_hover_check`, `player_frame_fade_tick`, and `skyriding_vigor_progress` as profiling/test adjustment points instead of changing generic buckets directly.

- Cache hot globals at file top (`local floor = math.floor`, `local GetTime = GetTime`, etc.).

- Never call protected Blizzard frame methods such as `UpdateAuras` or `UpdateLayout` from addon context. Restore events/Show and let Blizzard handlers run.

- Defer layout/geometry changes in combat. `update_auras()` skips scale, anchors, size, layout setup, and height changes during combat or while `frame._is_user_positioning`.


### GUI/Layout Rules
Violations here can create invisible or unstable controls.

- Widget internals anchor only to their own container.

- One `SetPoint` per anchor direction per frame; duplicate TOPLEFT/TOPRIGHT constraints can produce undefined layout.

- Do not use `frame:GetWidth()` at build time; it can be 0 before render.

- Factory functions should not place controls externally when the caller owns placement.

- `CreateSliderWithBox` already debounces callbacks at `addon.UPDATE_INTERVALS.tenth_sec`.


### Key WoW APIs And Lessons
- Aura APIs: `C_UnitAuras.GetBuffDataByIndex`, `GetDebuffDataByIndex`, `GetAuraDuration`, `GetUnitAuraInstanceIDs`, `DoesAuraHaveExpirationTime`, `GetAuraApplicationDisplayCount`.

- Tooltip APIs: prefer `GameTooltip:SetUnitAuraByAuraInstanceID("player", auraInstanceID)`, fall back to `GameTooltip:SetSpellByID`.

- CDM APIs/hooks: `CooldownViewerItemDataMixin`, `hooksecurefunc`, `Settings.OpenToCategory("Cooldown Viewer")`.

- Combat/taint: `InCombatLockdown()` guards protected paths. If Blizzard's blocked-action dialog appears, treat it as taint first.

- Sound APIs: `PlaySoundFile(fileDataID_or_path, channel?)` returns `(willPlay, soundHandle)`. `C_Sound.PlaySound(soundKitID, uiSoundSubType?)` returns `(success, soundHandle)`, though in-game testing confirmed `PlaySound(soundKitID, "SFX")` works on this client. `MuteSoundFile` / `UnmuteSoundFile` accept `number|string`; Ketho lists them as globals, not `C_Sound` members. Resolve sound API upvalues at file load.

- Lua operator precedence trap: `and` binds tighter than `or`, so `a and b ~= nil or false` parses as `(a and (b ~= nil)) or false`. The trailing `or false` is always a no-op when the left side already evaluates to a boolean. Write `a and b ~= nil` directly.


## Module Memory

Module-specific memory files are linked in the table of contents above.
