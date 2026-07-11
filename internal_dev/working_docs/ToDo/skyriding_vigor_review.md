# Skyriding Vigor Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/skyriding_vigor/`. Full reads: `sv_main.lua`, `sv_bar.lua`, `sv_styles.lua`, `sv_gui.lua`, `sv_state.lua`, `sv_fade.lua`, `sv_defaults.lua`. Supporting reads: `proj_mem/modules/skyriding_vigor.md`, `functions/module_reset.lua`, `functions/table_utils.lua`, `core/init.lua` (UPDATE_INTERVALS/module registry region), `LsTweeks.toc` load order. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Latent Traps](#latent-traps)
- [Optimization Candidates](#optimization-candidates)
- [Minor Cleanups](#minor-cleanups)
- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Latent Traps


## Optimization Candidates
6. The full frame tree (main frame, visual frame, 6 slots x ~5 subframes/textures, decor) is built during the `ADDON_LOADED` refresh (`sv_main.lua:442,787`, `sv_bar.lua:692-751`) even for characters that never mount. Deferring `ensure_frame()` until the first `should_show`/move-mode/fill-test need saves login work; medium effort because `apply_layout()` currently assumes the frame exists (`sv_bar.lua:780`).


## Minor Cleanups


## Reviewed And Confirmed Deliberate
Checked against `proj_mem/modules/skyriding_vigor.md` and code comments; do not re-flag without new evidence.
- Spell-charge fallback forces the six-node bar shape regardless of reported `maxCharges` (`sv_state.lua:87-97`); documented in Charge State because action spells can report `maxCharges = 1`.
- Move mode injects fake charge data for a static preview and `needs_progress_updates` explicitly excludes move mode (`sv_main.lua:481-483,509-511`); documented in Fill Test And Progress.
- Fill Test shares the normal `M.refresh()` render path and is force-stopped when real active flight starts (`sv_main.lua:461-467`); documented single-runtime-path decision.
- `M.apply_layout()` early-returns only when both `not M._layout_dirty` and `M._layout_signature` hold (`sv_bar.lua:774-777`); documented invariant in Styles And Rendering.
- End Decor `disabled` keeps the default decor footprint and hides via alpha 0 (`sv_bar.lua:857-858`, `sv_styles.lua:95-104`) so node positions stay stationary; documented.
- Default style uses `dragonriding_vigor_fillfull` for both fill states, and `normalize_db()` migrates old white/temporary fill-color defaults to the vigor cyan (`sv_main.lua:100-106`, `sv_styles.lua:34,66-67`); documented with atlas-tint history.
- Node Color / Decor Color dropdowns omit a selectable `default`, disable on the default style, and may display `Bronze (Default)` (`sv_gui.lua:412-432`, `sv_styles.lua:52,314-327`); documented.
- Fade controls lock while the race profile is active, composed under the broad flight lock (`sv_gui.lua:273-297,310-323`, predicates at 868-907); documented in Runtime Visibility And Fade.
- Visibility requires `GetGlidingInfo()` gliding or `can_glide`-gated flying/mounted state, never `IsFlying`/`IsMounted` + `IsAdvancedFlyableArea` alone, and ridealong passengers are suppressed while keeping move mode/fill test usable (`sv_main.lua:485-494`, `sv_state.lua:106-125`); documented.
- X/Y position sliders use direct `HookValueChanged` into `M.set_position_axis()` with the `_syncing_position_controls` guard instead of the generic slider wrapper (`sv_gui.lua:669-671,687-689`, `sv_main.lua:736-756`); documented dual-write as harmless.
- Dropdown `get_value` closures read `M.get_db()` at call time so Race Profile Test can swap the active DB after build (`sv_gui.lua:515-518,767-770,787-789`); documented.
- Skyriding Talents button guards `InCombatLockdown()` and prints the addon-owned yellow message (`sv_gui.lua:202-226`); documented.
- `M.SETTING_RANGES` is a fail-fast hard invariant (`sv_gui.lua:124-130`, `sv_main.lua:80-85` unconditional indexing); documented; toc order loads `sv_styles.lua` before both consumers.
- Module reset targets the root DB so both profiles reset, `before_reset` blocks flight, and `on_reset_complete()` clears test/race session state before resynchronizing from the reset DB (`sv_gui.lua:1037-1049`, `sv_main.lua:631-648`); documented.
- Race detection uses Bronze Timepiece item count and registers the five race events only while `race_profile_enabled` (`sv_main.lua:22,36-42,146-147,217-244,263-267`); refresh hides the bar without unregistering race events when only the active profile is disabled; documented.
- `M.get_db()` routes settings through the active profile; `M.get_root_db()` is reserved for root/global controls (`sv_main.lua:153-196`); documented ownership split.
- Progress driver is active-only, capped by the DB-backed Fill FPS setting, and routes ticks through `M.update_filling_slot_progress()` so stable layout is not redone per tick (`sv_main.lua:341-409`, `sv_bar.lua:429-475`); documented; stop paths cover hidden, disabled, full, move mode, and completion.
- Sparse `style_layouts` seeding with lazy create-time normalization in `get_style_layout_table()`/`get_decor_layout_table()` (`sv_styles.lua:344-364,625-649`, `sv_defaults.lua:32-41`); documented as intended saved-variable shape.
