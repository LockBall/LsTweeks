# Skyriding Vigor Memory
## Table of Contents
- [Settings And Defaults](#settings-and-defaults)
- [Position And GUI](#position-and-gui)
- [Assets And Credits](#assets-and-credits)
- [Runtime Visibility And Fade](#runtime-visibility-and-fade)
- [Charge State](#charge-state)
- [Styles And Rendering](#styles-and-rendering)
- [Fill Test And Progress](#fill-test-and-progress)
- [Module Gating And Race Profile](#module-gating-and-race-profile)


## Settings And Defaults
Important `skyriding_vigor` keys:
- `enabled`: toggles the restored vigor display.
- `fade_when_full`: lowers alpha when vigor is full and move mode is off.
- `fade_alpha`: alpha used by `fade_when_full`.
- `fade_length`: seconds to fade from full alpha to `fade_alpha`, default `3.0`.
- `progress_update_hz`: Fill FPS slider value for the active filling-node progress driver. Defaults from `addon.UPDATE_INTERVALS.skyriding_vigor_progress` in `core/init.lua`, currently `20`.
- `race_profile_enabled`: global Skyriding Vigor flag that enables the alternate race profile and race-detection events. When false, race item checks and race profile event registration stay disabled.
- `race_profile`: nested full Skyriding Vigor configuration used while the race profile is active. It stores the same user-facing presentation/runtime settings as the normal root profile, including `enabled`, position, style, scale, colors, fade, spark, and decor settings. It must not own `race_profile_enabled` or another nested `race_profile` table.
- `show_spark`: optional Blizzard spark atlas overlay on the actively filling vigor node. Defaults off.
- `spark_color` and `spark_size`: global spark tint/alpha and thickness multiplier for the optional spark overlay. The UI labels `spark_size` as Spark Thickness. It defaults to `5.00`; range is `0.50-15.00` in `0.5` steps.
- `move_mode`: shows the frame and enables left-drag positioning.
- `snap_to_grid`: snaps drag-saved position offsets to a 20px grid.
- `style`: atlas style key for the vigor nodes. Defaults to `default`; the settings dropdown also exposes `storm_race`, which uses Blizzard `dragonriding_sgvigor_*` atlases where available.
- `style_layouts.<style>.scale`: per-node-style scale override used by the Scale slider. Legacy `scale` remains as the first active style seed/compatibility value.
- `style_layouts.<style>.node_color`: per-node-style frame color override used by the Node Color dropdown. Storm Race currently supports Blizzard frame atlas colors `bronze`, `dark`, `gold`, and `silver`; fill remains shared/tinted separately.
- The Node Color dropdown intentionally omits a selectable `default` option. When the selected node style is `default`, the dropdown is disabled and may display the first visible option, `Bronze (Default)`, while `sv_styles.lua` still resolves the actual `default` atlas key.
- `style_layouts.<style>.fill_color`: per-node-style fill tint color used by the Fill Color picker.
- `style_layouts.<style>.fill_add_alpha`: per-node-style alpha for the additive duplicate fill layer used by the Fill Brightness slider. Default is `0.5`; range is `0.00-1.00`.
- `sv_defaults.lua` intentionally seeds `style_layouts` sparsely. Treat missing per-style fields as normal; use `sv_styles.lua` layout helpers/normalization and do not assume fully populated style tables in future saved-variable migrations.
- `decor_style`: separate atlas style key for the end decorations. Defaults to `default`; `disabled` keeps the default decor footprint but sets the decor frame alpha to 0 so node positions stay stationary when toggling end-decor visibility; `storm_race` uses `dragonriding_sgvigor_decor_bronze`.
- `decor_layouts.<decor_style>.decor_color`: per-end-decoration-style atlas color override used by the Decor Color dropdown. Storm Race currently supports Blizzard decor atlas colors `bronze`, `dark`, `gold`, and `silver`.
- The Decor Color dropdown intentionally omits a selectable `default` option. When the selected end decor style is `default`, the dropdown is disabled and may display `Bronze (Default)`, while `sv_styles.lua` still resolves the actual `default` atlas key.
- `decor_layouts.<decor_style>.decor_node_gap_x`, `.offset_y`, and `.scale`: per-end-decoration-style X/Y/scale UI overrides. Missing values initialize from `DECOR_STYLES`.
- `spacing` and `scale`: presentation settings. Slider ranges/steps live in `sv_styles.lua`; DB defaults stay in `sv_defaults.lua`. Scale range is `0.40-2.00` at `0.05` steps and displays two decimals.
- `M.SETTING_RANGES` is a hard module invariant owned by `sv_styles.lua`. `sv_gui.lua` and `sv_main.lua` may fail fast if a required range is missing because runtime normalization and GUI slider construction both depend on those ranges.
- `spacing` is a 0-25px user-facing range at 0.5 steps. Runtime layout applies it directly between visible `FRAME_LAYOUT` frame edges. `FRAME_LAYOUT.visible_edge_inset_x` compensates for transparent atlas padding; node dimensions come only from `dragonriding_vigor_frame` atlas metadata.
- Slider reset buttons must write the DB and run their callback even when the slider already shows the default. Layout-affecting sliders such as `spacing` and `scale` must call `M.refresh_layout()` so the signature cache invalidates even when values appear unchanged.


## Position And GUI
- `position`: UIParent-center-relative saved position; Reset Position restores true screen center (`x = 0`, `y = 0`).
- Skyriding Vigor uses General, Vigor Bar, and Profiles tabs. General owns the root-DB ARM reset with checked-by-default **Keep Profiles**; Profiles use the shared profile manager and save both normal and race configuration.
- The active settings file is `modules/skyriding_vigor/sv_gui.lua`, which owns control construction and control synchronization. Add a one-off `sv_gui_sync.lua` split only if a broader cross-module GUI-sync file pattern is introduced.
- `M.BuildVigorTab()` coordinates local Vigor Bar builders (`build_top_row`, `build_position_row`, `build_decor_row`, `build_fade_row`, `build_race_profile_panel`, and `build_spark_row`) while `ROWS` / `CONTROL_GRID` remain local static placement data. Do not expose local GUI constants through `M` solely to share implementation details.
- Settings controls that must disable during real active flight are registered in
  `sv_gui.lua` through the module-local `register_flight_locked_control()` helper.
  Use that registry for new Skyriding setting controls instead of extending a
  manual list. Controls with narrower enabled rules can pass a predicate so those
  rules compose with the flight lock.
- Skyriding's Move Mode cell is a three-control stack: Move Mode, Snap to Grid, and Reset Position. The first control is grid-placed and the secondary controls use `grid:stack_below()` so the row/column cell owns the repeated vertical-stack math.
- `sv_gui.lua` dropdown `get_value` closures that depend on the active profile must read `M.get_db()` at call time, not capture the `db` local from `BuildSettings()`. Race Profile Test can switch the active DB after the settings page is built.
- X/Y position sliders intentionally use `HookScript("OnValueChanged", ...)` and `M.set_position_axis()` instead of the generic `set_setting_from_slider()` wrapper. The slider binding and position setter both write DB state, but this is harmless and keeps position behavior centralized.
- `sync_slider_controls()` intentionally uses both the module-level `_syncing_slider_controls` guard and per-control `_suppress_callback` flags. The module guard prevents Skyriding's local setting writes during programmatic sync, while `CreateSliderWithBox()` consumes `_suppress_callback` before debouncing the supplied callback. Decor sliders use the generic slider callback path and need `_suppress_callback`; X/Y position sliders use `_syncing_position_controls` because they attach direct `OnValueChanged` hooks.
- Programmatic slider and position synchronization must clear their module guard even when a control setter errors, then rethrow the error. A stuck guard silently mutes later user callbacks.


## Assets And Credits
- The module uses only Blizzard atlas assets (`dragonriding_vigor_*`) and does not copy DragonRider textures or implementation.
- Credit DragonRider in public docs for the restored vigor-display concept.


## Runtime Visibility And Fade
- Visibility comes from readable vigor charges plus move mode, active gliding from `C_PlayerInfo.GetGlidingInfo()`, or mounted/flying state gated by `GetGlidingInfo()`'s `can_glide` result. Do not show only because `IsFlying()` or `IsMounted()` + `IsAdvancedFlyableArea()` is true; that also matches normal non-skyriding mounts in advanced-flyable zones. Grounded skyriding-mounted visibility is allowed when `can_glide` is true; `fade_when_full` handles idle/full states.
- Ridealong passengers can inherit enough skyriding state to look eligible for the bar. Normal runtime visibility must suppress the bar when `UnitInVehicle("player")` is true and `UnitInVehicleControlSeat("player")` is false. Keep move mode/fill test usable for configuration.
- `fade_when_full` is keyed to visually full charges while not in move mode. Active gliding or `IsFlying()` gated by `can_glide` restores full alpha even when charges are full; plain ground movement and normal flying mounts must not.
- `modules/skyriding_vigor/sv_fade.lua` owns Skyriding Vigor alpha transitions and the full-charge fade decision. `sv_main.lua` should call `M.restore_frame_alpha()` / `M.apply_full_charge_fade()` instead of owning frame fade scripts directly.
- Fade animation runs on a dedicated child driver frame so Move Mode drag tracking remains the sole `OnUpdate` owner on the main vigor frame.
- Fade settings do not apply while the race profile is active. The settings UI disables Fade When Full, Fade Alpha, and Fade Length during real race detection or Race Profile Test mode through `M.sync_fade_controls_enabled()`.
- `M.sync_settings_controls_enabled()` owns the broad settings lock during real active flight. It disables settings controls and then calls `M.sync_fade_controls_enabled()` so the flight lock composes with the narrower race-profile fade lock. Fill Test remains editable while it is the active simulated state, but starting real flight stops Fill Test and re-locks settings.


## Charge State
- `modules/skyriding_vigor/sv_state.lua` owns charge and flight-state detection. Vigor charges prefer mounted/alternate unit power (`Enum.PowerType.AlternateMount`, then `Alternate`) and fall back to `C_Spell.GetSpellCharges()` for spell IDs `372610` (Skyward Ascent) and `372608` (Surge Forward). The spell-charge fallback must not drive visual node count because action spell charges can report `maxCharges = 1`; always keep the six-node bar shape in that path. Guard secret values with `issecretvalue`. `get_charge_info()` always returns four values: current, maximum, cooldown start, and cooldown duration; unavailable values are explicit `nil`s.
- `SPELL_UPDATE_CHARGES` and `SPELL_UPDATE_COOLDOWN` share `addon.UPDATE_INTERVALS.skyriding_vigor_event_bucket` (`0.1` seconds) before calling `M.refresh()`. Keep mount, glide, race, and settings changes immediate.


## Styles And Rendering
- Vigor node and end-decoration dimensions come from the selected style's Blizzard atlas metadata. Do not use live texture `GetWidth()`/`GetHeight()` reads for layout.
- Required default vigor atlas metadata is a hard dependency. `get_atlas_size()` must fail clearly when it is unavailable; do not guess fallback dimensions that could silently misrender the bar after a Blizzard asset change.
- Skyriding Vigor node and end-decoration style selection is manual, DB-backed, and validated in `sv_styles.lua`. Missing or unknown style keys fall back to `default`.
- Skyriding Vigor Scale and Node Color are style-specific. `M.set_db_value("scale", value)` and `M.set_db_value("node_color", value)` route to the active `style_layouts` entry, and style switching resyncs those controls. Active style scale/node-color/fill-color and decor position helpers live in `sv_styles.lua` with the style definitions.
- Skyriding Vigor Fill Color is style-specific and tints the active fill/full-fill status bar texture via `SetVertexColor`. Non-white fill colors automatically desaturate the fill texture first and show an additive duplicate fill layer to make custom colors read brighter. The Fill Brightness slider controls that duplicate layer's alpha per style. A separate RGB brightness multiplier was tested and discarded because RGB multiplication plus channel clamping shifted selected hues unpredictably. The default node style intentionally uses `dragonriding_vigor_fillfull` for both partial and full fill states; StatusBar clipping handles progress, and the plain `dragonriding_vigor_fill` atlas does not reliably show native color after reload/reset with the default white tint. Default-style fill reset/default is the WoW vigor cyan tint (`r=0.00, g=0.80, b=1.00, a=1`), with a narrow migration from the old exact white default and the temporary `0.20/0.82/1.00` default. Storm Race fill default remains white because its atlas carries the visible color.
- When reusing `UIWidgetFillUpFrameTemplate` outside Blizzard's widget manager, force-clear/reanchor the inherited `BG`, `Bar`, and `Frame` regions and hide unused spark/flash/flipbook regions. Do not keep template-provided anchors; they can leave node art detached from the custom slot layout.
- Vigor fill dimensions are driven by the local `FILL_LAYOUT` table in `sv_bar.lua`. Node backgrounds use per-style `background_scale_*` and `background_offset_*` fields in `BAR_STYLES` in `sv_styles.lua`.
- `sv_bar.lua` uses `M.get_render_context(db)` as the pass-local render context for style-dependent slot rendering. It carries the active DB, `style_key`, `style`, `frame_atlas`, and `spark_atlas`, and is passed through `M.refresh()` slot updates to avoid repeated style/atlas resolution without persistent cache invalidation state. `M.set_slot_state()` stamps each slot with the resolved render values, and `M.update_filling_slot_progress()` reuses those slot-local values so active progress ticks do not rebuild style/atlas context.
- Vigor spark rendering is optional and uses per-style `spark` atlas fields in `BAR_STYLES`. It is drawn only on the currently filling node and is controlled by `skyriding_vigor.show_spark`, `spark_color`, and `spark_size`. Runtime draws the spark above the fill layer but below the frame cover, with a slot-local clipped spark frame sized to the fill box plus per-style `spark_clip_inset_x/y` so texture overflow is hidden without rescaling the spark. `spark_size` remains a thickness multiplier; add broad height clamps that ignore atlas dimensions and fill-edge math only for a new concrete visual issue.
- For visual tuning, `BAR_STYLES.<style>.background_above_frame = true` draws that style's background above the node frame so background size/offset are easier to inspect. Keep it `false` for normal presentation.
- Skyriding Vigor end-decoration placement uses per-style defaults in `DECOR_STYLES` in `sv_styles.lua` (`decor_node_gap_x`, `offset_y`, `scale`, `scale_x`, `scale_y`, `decor_color`), with saved user X/Y/scale/color overrides under `db.decor_layouts`. X/Y no longer use shared `WING_LAYOUT` fallback values.
- End Decor `disabled` is intentionally implemented as a decor style that preserves the default decor footprint and hides via alpha. Replace it with a separate visibility flag only for a concrete layout mismatch.
- Skyriding Vigor reset hooks must resync controls/runtime from the DB only. Do not write defaults in `on_reset_complete()`: `CreateModuleReset()` wipes only the calling module's DB and invokes only that module's `after_reset` hook.
- Skyriding Vigor General reset is blocked during active flight and clears Fill Test, Race Profile Test, and race-active session flags before synchronizing the reset DB and runtime.
- `M.apply_layout()` intentionally returns early only when both conditions hold: `not M._layout_dirty and M._layout_signature`. If the signature is nil, layout must rebuild.


## Fill Test And Progress
- Fill Test uses simulated charge data through the normal `M.refresh()` path and the active-only progress driver. Current cadence is `2.0` seconds per node so spark color/size/placement are visible during inspection. Starting real active flight stops Fill Test before normal flight rendering continues, so Fill Test never masks real in-flight state. Reintroduce a separate fill-test render path only when the behavior intentionally diverges from runtime display.
- Move mode intentionally injects fake charge data for a static preview. `needs_progress_updates` must explicitly exclude move mode, otherwise the fake nonzero duration can start the progress driver.
- The Skyriding Talents button must guard `InCombatLockdown()` before opening `GenericTraitFrame`; in combat, print the addon-owned yellow message instead of allowing Blizzard's generic blocked-action warning.
- Avoid always-running `OnUpdate`; `sv_main.lua` uses an active-only progress driver while a node is visibly filling and stops it when hidden, disabled, full, or in move mode. The driver is capped by the DB-backed `progress_update_hz` Fill FPS slider and calls `M.update_filling_slot_progress()` so progress animation does not redo stable layout, reset slot visuals, or normalize DB on each update. The default cap comes from `addon.UPDATE_INTERVALS.skyriding_vigor_progress`, currently 20Hz.


## Module Gating And Race Profile
- Runtime module gating is centralized in `sv_main.lua` through `M.is_runtime_enabled()` and `M.stop_runtime()`. When the Settings Module Enabler disables Skyriding Vigor, `sv_main.lua` must stop progress updates, hide any existing frame, disable frame mouse input, clear fill/race test state, and unregister runtime events. If the active profile's `enabled` is false, refresh hides the bar without unregistering race-detection events when `race_profile_enabled` still needs them.
- Race profile activation uses Bronze Timepiece itemID `191140`: `C_Item.GetItemCount(191140) > 0` means an active Skyriding race was detected. In-game probing showed cached item info can exist outside a race, but item count changes from `0` before a race to `1` after accepting a race quest such as Dornogal Drift.
- Race detection registers `BAG_UPDATE_DELAYED`, `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`, `QUEST_REMOVED`, and `QUEST_TURNED_IN` only while `race_profile_enabled` is true.
- The root `skyriding_vigor` DB table remains the normal profile and owns global race controls such as `race_profile_enabled`; the nested `skyriding_vigor.race_profile` table is the alternate full profile.
- Race Profile Test forces the nested race profile active without requiring a race, so existing settings controls edit `race_profile`.
- Existing settings controls route through the active profile returned by `M.get_db()`. Use `M.get_root_db()` only for root/global controls such as `race_profile_enabled` and module reset.
- Module reset targets the root Skyriding Vigor DB so it resets both the normal profile and nested race profile.
