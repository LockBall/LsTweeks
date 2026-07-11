# Skyriding Vigor Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/skyriding_vigor/`. Full reads: `sv_main.lua`, `sv_bar.lua`, `sv_styles.lua`, `sv_gui.lua`, `sv_state.lua`, `sv_fade.lua`, `sv_defaults.lua`. Supporting reads: `proj_mem/modules/skyriding_vigor.md`, `functions/module_reset.lua`, `functions/table_utils.lua`, `core/init.lua` (UPDATE_INTERVALS/module registry region), `LsTweeks.toc` load order. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Potential Bugs To Verify](#potential-bugs-to-verify)
- [Latent Traps](#latent-traps)
- [Optimization Candidates](#optimization-candidates)
- [Minor Cleanups](#minor-cleanups)
- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Potential Bugs To Verify
1. Half-up rounding in `normalize_power_value()` (`sv_state.lua:47-54`) displays a node as full at >=50% partial power when the display-mod or max_power>slot_count normalization path is active, and could briefly show one more charge than the player can spend. Only reachable if the live power values are scaled; defer unless a real scaled power source is observed.


## Latent Traps
2. `M.frame` has two competing `OnUpdate` owners: the fade animation (`sv_fade.lua:61`) and the drag tracker (`sv_bar.lua:722`), and `OnDragStop` clears the script unconditionally (`sv_bar.lua:732-733`). Today safe only because fades run exclusively outside move mode and drags exclusively inside it; if that invariant ever loosens, a drag-stop orphans `_sv_fade_state` and the signature check (`sv_fade.lua:44`) then swallows the next identical fade request forever. `set_move_mode()` also stamps `frame._sv_alpha = 1` without clearing `_sv_fade_state` (`sv_bar.lua:899-903`), relying on `apply_full_charge_fade()` cancelling later in the same synchronous refresh. Consider moving the fade OnUpdate to a dedicated child frame or asserting the invariant in a comment.
3. `get_atlas_size()` raises a hard `error()` in the render path when atlas metadata is missing (`sv_bar.lua:108-116`). Non-default styles are validated by `atlas_exists()` with fallback to default (`sv_styles.lua:254-257,295-303`), but the default style's own `dragonriding_vigor_*` atlases are assumed present — a Blizzard rename breaks every refresh instead of degrading. Fail-fast may be intended (matches the SETTING_RANGES invariant); if so, document it in module memory.
4. `sync_slider_controls()` sets `M._syncing_slider_controls = true` and clears it at the end with no pcall (`sv_gui.lua:344-367`); one error inside a control sync leaves the flag stuck and every Skyriding slider callback permanently muted (`sv_gui.lua:132-137`). Same shape for `M._syncing_position_controls` (`sv_gui.lua:330-341`), though those blocks are smaller.


## Optimization Candidates
1. Race-profile events always trigger a full `M.refresh()`. `update_race_active_state()` computes and returns a changed flag (`sv_main.lua:143-151`) that the event handler ignores (`sv_main.lua:791-796`), so every `QUEST_LOG_UPDATE` and `BAG_UPDATE_DELAYED` — both very chatty — runs the full refresh (frame ensure, layout check, gliding/charge reads, GUI enable sync) while `race_profile_enabled` is on. Early-return on race-only events when the flag reports no change.
2. `M.sync_settings_controls_enabled()` runs on every refresh (`sv_main.lua:468-470`), calling `SetEnabled` on every registered control plus the fade trio (`sv_gui.lua:273-297,310-323`) even when the settings panel is hidden — on every `SPELL_UPDATE_COOLDOWN` in combat. Cache the last flight-lock state and resync only when it flips (per-control predicates already get resynced by their own setters).
3. `M.refresh()` reads charge info before the visibility gates (`sv_main.lua:472` vs gates at 487-494). When not fill-testing, not in move mode, not gliding, and `can_glide` is false, `should_show` cannot be true regardless of charges — reordering the gate check ahead of `M.get_charge_info()` skips two `UnitPowerMax`/`UnitPower` reads and up to two `C_Spell.GetSpellCharges` calls per event while dismounted.
4. `UNIT_ENTERED_VEHICLE`/`UNIT_EXITED_VEHICLE` are registered with plain `RegisterEvent` (`sv_main.lua:32-33,231-235`), so vehicle transitions of every visible unit (raids, quest NPCs) trigger a full refresh. Register them via `RegisterUnitEvent(event, "player")` instead; requires a small branch in `sync_runtime_events()`.
5. `M.get_render_context()` allocates a new table and re-resolves the frame atlas per refresh (`sv_bar.lua:264-274`); `get_frame_atlas()` runs `get_style_layout_table(create)` plus `get_valid_node_color_key()` → `atlas_exists()` → `C_Texture.GetAtlasInfo` every time (`sv_styles.lua:440-446,259-273`). The atlas result only changes when style/node-color settings change; cache the resolved frame/spark atlas pair and invalidate from the existing setter paths, and reuse a scratch context table.
6. The full frame tree (main frame, visual frame, 6 slots x ~5 subframes/textures, decor) is built during the `ADDON_LOADED` refresh (`sv_main.lua:442,787`, `sv_bar.lua:692-751`) even for characters that never mount. Deferring `ensure_frame()` until the first `should_show`/move-mode/fill-test need saves login work; medium effort because `apply_layout()` currently assumes the frame exists (`sv_bar.lua:780`).


## Minor Cleanups
1. `loader` keeps `ADDON_LOADED` registered forever (`sv_main.lua:776-789`); every later-loading addon calls the handler just to hit the name check. Unregister it inside the own-addon branch.
2. `M.set_wing_layout()` (`sv_bar.lua:757-767`) has no callers anywhere in the repo — dev tuning hook; delete it or tag it as intentionally dev-only, since WING_LAYOUT scale fallbacks are otherwise reachable only through `DECOR_STYLES` gaps.
3. `update_slot_spark()` calls `slot.spark:Hide()` and rewrites `_spark_shown` unconditionally on the no-spark path (`sv_bar.lua:372-377`), which runs for all six slots on every refresh (including the unchanged-state early return at `sv_bar.lua:619-625`). Guard on `slot._spark_shown`.
4. `set_slot_spark_clip_bounds()` calls `get_fill_size(style)` before its own nil-style resolution block (`sv_bar.lua:344-353`), and every caller already passes a style, so the resolution block is dead — reorder or remove it.
5. `normalize_db()` coerces `spark_color` components to numbers but never range-clamps them to 0-1 (`sv_main.lua:90-93`); `clamp_number` without a range only applies the fallback (`functions/table_utils.lua:41-47`).
6. Per-refresh throwaway allocations in GUI sync: `#(controls or {})` builds an empty table when unbuilt (`sv_gui.lua:313`) and `sync_fade_controls_enabled()` allocates the fade-control list every call (`sv_gui.lua:279-283`).
7. Unused checkbox locals in the builders: `enabled_cb` (`sv_gui.lua:489`), `move_cb` (`sv_gui.lua:625`), `snap_cb` (`sv_gui.lua:631`), `spark_cb` (`sv_gui.lua:990`).


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
