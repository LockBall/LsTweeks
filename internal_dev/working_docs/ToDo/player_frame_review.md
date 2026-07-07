# Player Frame Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/player_frame/`. Full reads: `pf_defaults.lua`, `pf_gui.lua`, `pf_main.lua`, `pf_fade.lua`. Supporting cross-check reads: `functions/slider_with_box.lua`, `functions/checkbox.lua`, `functions/module_reset.lua`, `functions/table_utils.lua`, `functions/ui_helpers.lua` (control panel and tooltip sections), `core/init.lua`, `LsTweeks.toc`. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Potential Bugs To Verify](#potential-bugs-to-verify)
- [Latent Traps](#latent-traps)
- [Optimization Candidates](#optimization-candidates)
- [Minor Cleanups](#minor-cleanups)
- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Potential Bugs To Verify
1. [x] Pending `queue_apply` survives module disable and can re-fade a disabled module. `queue_apply()` (`pf_fade.lua:202-209`) schedules an uncancellable `C_Timer.After(0)`; `F.stop_transition()` (`pf_fade.lua:211-216`) cancels the delay/ticker/health timers but cannot cancel it, and `on_delay_expired()` (`pf_fade.lua:192-200`) rechecks only `playerInCombat` and `db.fade_out_of_combat`, never the module-enabled gate. If `stop_runtime()` (`pf_main.lua:137-146`) runs in the same frame a queued apply is pending (threshold change or PlayerFrame OnShow immediately before a Settings-tab module disable), `begin_fade` runs next frame and PlayerFrame ends up stuck at `fade_alpha` with all events unregistered until combat or reload. One-frame window, but code-provable; fix by rechecking `addon.is_module_enabled(M.MODULE_KEY)` in `on_delay_expired` or bumping a generation token in `stop_transition`. Resolved 2026-07-05: `on_delay_expired()` now rechecks the module-enabled gate before beginning the fade, so uncancellable zero-delay work restores visible alpha and exits after disable.

2. [x] Fade Alpha changes during an active fade land on the old target. `F.apply()` early-returns while `STATE_FADING` (`pf_fade.lua:289`) and the running ticker captured `target` once in `begin_fade()` (`pf_fade.lua:158`, used at 181), so a mid-fade slider change completes to the stale alpha. It self-corrects only via `on_health_update` in `STATE_FADED` (`pf_fade.lua:254-256`) or the next combat cycle; at full health OOC, `UNIT_HEALTH` may never fire, so the stale alpha can persist indefinitely. The `STATE_DELAY` early-return is documented deliberate in module memory; the FADING stale-target side effect is not. In-game check: start a 10s fade, drag Fade Alpha mid-fade at full health, watch the final alpha. Resolved 2026-07-05: slider changes now notify the fade runtime; active fades are stopped and requeued from the current base alpha so the new slider target is used.

3. [x] Fade slider tooltips may never display. `pf_gui.lua:178` attaches `addon.AttachTooltip` to the slider container, a plain Frame from `addon.CreateControlPanel()` (`ui_helpers.lua:27-32`) that never enables mouse, and the mouse-enabled children (slider, edit box, buttons) cover most of its area. The factory's own tooltip route (`slider_with_box.lua:196-199`) calls `title:EnableMouse(true)` precisely for this. Verify in-game whether OnEnter fires on the container; if not, pass `opts.tooltip` to `CreateSliderWithBox` instead. (Checkbox-label tooltips at `pf_gui.lua:143,158` follow the codebase-wide pattern also used in objectives, so they are not flagged.) Resolved 2026-07-05: Player Frame fade sliders now pass `opts.tooltip` into `CreateSliderWithBox`, using the factory-owned mouse-enabled title tooltip path.

4. [x] `M.on_reset_complete()` (`pf_main.lua:186-196`) is unreachable: Player Frame builds no `CreateModuleReset` panel and a repo-wide grep finds no caller, unlike skyriding (`sv_gui.lua:1048`), audio volumes (`av_gui_general.lua:16`), and aura frames (`af_gui_frame_builders.lua:610`), which all wire `after_reset = M.on_reset_complete`. Either the module reset panel is missing from `pf_gui.lua` or the hook plus `M.sync_options_controls()` (`pf_gui.lua:187-202`) is dead code. Resolved 2026-07-05: Player Frame intentionally has no module reset panel, so the unreachable reset hook and reset-only control sync were removed.


## Latent Traps
1. [x] `F.on_threshold_changed()` clobbers `STATE_COMBAT`. `pf_fade.lua:294-303` sets `state = STATE_IDLE` whenever `state ~= STATE_DELAY`, including in combat. Correctness currently depends on both callers (`pf_main.lua:120-123` and `pf_main.lua:129-132`) immediately calling `M.update_player_frame()`, whose `apply()` restores `STATE_COMBAT`. Any future caller of `on_threshold_changed` alone leaves the state machine claiming idle while in combat. Resolved 2026-07-05: setting-change handlers now refresh `InCombatLockdown()` and restore `STATE_COMBAT` directly before any idle/requeue path, so they no longer depend on a follow-up full update.

2. [x] Health gate fails fully visible when curve APIs are missing. `get_health_gated_alpha()` returns `1` when `UnitHealthPercent` is nil (`pf_fade.lua:87`) or the curve cannot be created (`pf_fade.lua:90`), so with the default `health_visible_threshold = 80` the entire OOC fade silently stops fading on any client where these APIs are unavailable, instead of falling back to the plain time-based `base_alpha`. Accepted deliberate 2026-07-07: latest Retail is the supported API target and the health curve APIs are expected to exist; fail-visible is a defensive fallback if the health gate cannot be evaluated. Local tests should keep normal health-gate coverage by stubbing those APIs, not by changing runtime behavior for unsupported missing APIs.

3. [x] Fade clamp ranges are owned twice. `pf_fade.lua:60-64` hardcodes the runtime ranges (delay 0-5, length 0-10, alpha 0.1-1.0, threshold 0-100, speed 0-100) and `pf_gui.lua:58-109` owns the same numbers as `FADE_SLIDER_DEFS` min/max, which `sync_options_controls` also feeds back into `M.get_clamped_fade_value`. A future GUI range change silently disagrees with the runtime clamp; violates the constants-owned-in-one-place rule. Hoist the ranges next to `M.FADE_DEFAULTS` in `pf_defaults.lua`. Resolved 2026-07-07: numeric fade min/max/step metadata now lives in `M.FADE_SETTING_RANGES` in `pf_defaults.lua`; GUI controls and runtime clamps both read that table, with a headless clamp-boundary regression test.

4. [x] Strict-boolean event gate vs truthy checks elsewhere. `sync_fade_events()` uses `db.fade_out_of_combat == true` (`pf_main.lua:82`) while pf_fade gates on truthiness (`pf_fade.lua:193,233,251,264,307`). A truthy non-boolean value (old DB shape, manual SavedVariables edit) would leave the fade logic active with no events registered. Align on truthy. Resolved 2026-07-07: `sync_fade_events()` now uses the same truthy gate as the fade runtime, with a headless regression covering `fade_out_of_combat = 1`.

5. [x] Fade duration drifts under low framerate. `begin_fade`'s ticker accumulates the nominal `FADE_TICK_INTERVAL` per fire (`pf_fade.lua:179`) instead of measuring real elapsed time, so dropped ticker fires stretch the fade beyond `fade_length`. Cosmetic only; use a `GetTime()` start timestamp if it ever matters. Resolved 2026-07-07: `begin_fade()` now caches `GetTime` as a file-local upvalue and computes ticker progress from real elapsed time since fade start.


## Optimization Candidates
1. [headless-testable: reach STATE_FADED, call `update_player_frame`, assert `get_runtime_status().fade_ticker` stays false after the fix] Redundant full re-fade ticker when already at target. Every `M.update_player_frame()` while `STATE_FADED` — each PlayerFrame OnShow via the hook at `pf_fade.lua:273-278`, plus every settings change — runs `apply -> queue_apply -> begin_fade` with `start_alpha == target`, spinning a 0.1s ticker for up to `fade_length` seconds doing no-op `SetAlpha` plus `UnitHealthPercent` pcalls each tick. Early-exit `begin_fade` when `math_abs(target - start_alpha) <= ALPHA_EPSILON`: apply once, set `STATE_FADED`, skip the ticker.

2. [headless-testable: fire `UNIT_HEALTH` in each fade state, assert `queued_health_timer` only appears in STATE_FADED after the fix] Health-event timer churn with nothing to do. `sync_fade_events` registers `UNIT_HEALTH`/`UNIT_MAXHEALTH` whenever fade is on (`pf_main.lua:88-89`), and `queue_health_update` cancels and allocates a fresh `C_Timer.NewTimer` per event (`pf_fade.lua:309-313`) even though `on_health_update` only acts in `STATE_FADED` (`pf_fade.lua:252-256`) and the gate no-ops entirely at `threshold <= 0` (`pf_fade.lua:86`). Early-exit `queue_health_update` unless `state == STATE_FADED` (a fade completing inside the 0.1s debounce is covered by the next health event), and optionally skip registering health events when the threshold is 0.

3. [headless-testable: assert health events unregistered after `PLAYER_REGEN_DISABLED` if implemented] In-combat `UNIT_HEALTH` fan-out is pure overhead. Player `UNIT_HEALTH` fires constantly in combat; each event walks loader OnEvent -> `handle_runtime_event` -> `queue_health_update` -> db fetch before the `playerInCombat` early-exit (`pf_fade.lua:306-307`). Cheap, but unregistering the two health events on `PLAYER_REGEN_DISABLED` and re-registering on `PLAYER_REGEN_ENABLED` would make combat cost exactly zero. Only worth it if profiling ever points here.


## Minor Cleanups
1. `addon.module_defaults.pf` (`pf_defaults.lua:35-36`) is written and never read; only `.st`, `.sv`, and `.audio_volumes` are consumed anywhere. Drop it or add its consumer; the registry key abbreviations are also inconsistent across modules (`pf`/`ob`/`sv`/`st` vs full `audio_volumes`).

2. Dead load-order fallbacks duplicate owned constants: `M.MODULE_KEY or "player_frame"` (`pf_main.lua:13`), `M.CATEGORY_NAME or "Player Frame"` (`pf_main.lua:246`), `M.defaults or {}` / `M.FADE_DEFAULTS or {}` (`pf_main.lua:17-18`), and `M.FADE_DEFAULTS or {}` (`pf_fade.lua:49`). The `.toc` order (defaults -> gui -> main -> fade, `LsTweeks.toc:43-46`) guarantees the owners loaded first, so every fallback literal is an unreachable duplicate of a one-owner constant.

3. `ALPHA_EPSILON` reused as a time epsilon: `pf_fade.lua:162` (fade length seconds) and `pf_fade.lua:239` (fade delay seconds) compare durations against an alpha constant. Name a separate `TIME_EPSILON` or compare against 0.

4. `UI_CONFIG.slider_width = 130` (`pf_gui.lua:21`) and the bare `95` in the fade row height (`pf_gui.lua:125`) duplicate the slider factory's hardcoded container footprint (`slider_with_box.lua:20`); expose the factory's size instead of re-owning it in the panel.

5. Inconsistent `M.fade` guards in pf_main: `stop_runtime`/`start_runtime` guard with `if M.fade and ...` (`pf_main.lua:140,152`) while `set_player_frame_setting`, `on_fade_slider_changed`, and `handle_runtime_event` call `M.fade` unguarded (`pf_main.lua:121,130,164-168`). Load order makes all the guards dead; pick one style.

6. `stop_runtime` always calls `set_portrait_combat_text_hidden(false)` (`pf_main.lua:139`), doing the hit-indicator lookup plus a `SetAlpha(1)` on the Blizzard frame even when the feature was never on; guard on `hidePortraitText` for a free no-op.


## Reviewed And Confirmed Deliberate
Checked against `proj_mem/modules/player_frame.md` and code comments; do not re-flag without new evidence.
- Module-owned ticker fade instead of `CreateAnimationGroup()` on PlayerFrame: AnimationGroup tainted Blizzard heal prediction on reload, per module memory.

- HitIndicator suppressed via `SetAlpha(0)` plus an OnShow hook (`pf_main.lua:70-77,100-112`), never `Hide()`: taint-safe alpha suppression on a Blizzard frame.

- Secret-value handling: health flows only through the pass-through `UnitHealthPercent("player", true, curve)` into `SetAlpha`, both pcall-wrapped (`pf_fade.lua:114,123`), with no Lua comparison/arithmetic on the value; combat always cancels fade and sets plain alpha 1. Matches the in-game secret-value testing documented in memory.

- Health curve cache signature includes current base alpha, threshold, and release speed (`pf_fade.lua:96-111`): base alpha changes during the fade, so DB-only caching gives stale geometry per memory. `health_release_speed` changes intentionally skip `on_threshold_changed`; the signature self-invalidates and the follow-up `update_player_frame` reapplies.

- Health events never stop or restart an active fade; in `STATE_FADED` they only refresh the gated target alpha (`pf_fade.lua:250-257`), per memory.

- `on_leave_combat` schedules the delay and sets alpha 1 without calling the combat-gated full update (`pf_fade.lua:227-248`), and `F.apply` early-returns during `STATE_DELAY` (`pf_fade.lua:289`): transient combat state could cancel the new delay timer, per memory.

- PlayerFrame OnShow hook installed lazily only once fade is enabled (`pf_fade.lua:273-278`), per memory.

- Fade combat/health events registered only while `fade_out_of_combat` is on, and enabling fade refreshes combat state from `InCombatLockdown()` in `F.apply` (`pf_fade.lua:262`), per memory.

- Combat state owned by `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` with `InCombatLockdown()` fallback; `UnitAffectingCombat` deliberately avoided as sticky, per memory.

- PlayerFrame stays clickable while faded: alpha only, no mouse changes, per memory.

- 0.1s fade tick sourced from `addon.UPDATE_INTERVALS.player_frame_fade_tick` (`core/init.lua:46`); the `fifth_sec looks jittery` comment records why it is not coarser.
