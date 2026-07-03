# Audio Volumes Modularity Review
## Scope
- Reviewed `modules/sound_levels/sl_defaults.lua`, `sl_functions.lua`, `sl_runtime_logic.lua`, `sl_situations.lua`, `sl_gui.lua`, `sl_main_control.lua`, `core/minimap_button.lua`, module memory, and README Audio Volumes wording.
- Fast validation passed on 2026-07-01: Lua syntax, region markers, and whitespace diff checks.
- Overall shape is sound: replacement-sound hot paths are cache-driven in `sl_runtime_logic.lua`/`sl_functions.lua`, temporary situation CVar runtime is centralized in `sl_situations.lua`, and public README behavior matches the current Fishing/Combat/Quick Picks model.


## Findings
1. [x] Medium: Preview CVar restore can race active situation transitions. `sl_situations.lua` uses one preview restore cache/timer for Fishing Bobber and situation previews (`restore_bobber_preview_profile()` at lines 420-435; preview cache/timer setup at lines 458-468 and 490-507). Runtime situation transitions such as Combat start (`apply_combat_volumes()` at lines 640-651) did not cancel that pending preview restore. Fixed by resolving pending situation preview restore at the start of `apply_active_sound_channel_profile()`, before active Fishing, Combat, or Quick Pick CVars are written.

2. [x] Medium/Low: Programmatic temporary-situation GUI sync can invoke slider callbacks. `M.sync_temporary_profile_controls()` directly called `slider.slider:SetValue(...)` for Fishing, Combat, Quiet Custom, and custom Quick Pick sliders at `sl_gui.lua` lines 338-363. `addon.CreateSliderWithBox()` writes DB and schedules callbacks from `OnValueChanged` unless callback suppression is active. Fixed by adding shared `GetValue()`, `SetValue()`, `SetValueSilently()`, and `HookValueChanged()` support to `CreateSliderWithBox()` and using the factory API for Audio Volumes temporary situation/current-volume display refresh paths. Follow-up audit found no intentional direct settings-slider value access; remaining direct reads/writes and `HookScript("OnValueChanged", ...)` handlers were migrated to the factory API.

3. [x] Low: `sl_fishing.lua` had outgrown its file name and single-file responsibility. It owned Fishing Focus, Combat Volumes, Quick Pick DB, custom Quick Pick CRUD, minimap menu helpers, preview playback, temporary CVar runtime, and situation event routing. Fixed by renaming the file to `sl_situations.lua`, making the current source boundary Fishing Focus, Combat Volumes, Quick Picks, custom Quick Pick CRUD, copy-current helpers, minimap-menu entry helpers, situation previews, and situation-specific temporary CVar/event handling. `sl_runtime_logic.lua` remains the module-level runtime spine for replacement playback, mutes, previews, event cache, and lifecycle cleanup. If `sl_situations.lua` later becomes too large, revisit a second split with a more specific name than generic runtime.

4. [x] Low: Disabled minimap Quick Picks menu still asked the module for entries before showing the disabled menu. `core/minimap_button.lua` computed `entries` even when `module_enabled` was false; `M.get_quick_pick_menu_entries()` initializes Quiet Custom/custom situation DB through `sl_situations.lua`. This did not enable runtime events, but it weakened the documented "disabled sync should not initialize situation DB values" rule. Fixed by making `show_menu()` lazily request entries only after the enabled branch is confirmed, so the disabled menu shows without touching Audio Volumes situation DB helpers.


## Clean Areas
- Replacement sound event handling stays hot-path friendly: `handle_event()` only reads `_event_cache`, and `rebuild_event_cache()` does DB/default work outside the event handler.
- Module enable/disable behavior is consistently routed through `M.is_runtime_enabled()` and `M.stop_runtime()` for mutes, previews, event cache, and temporary situation restoration.
- The public behavior documented in `README.md` lines 125-139 matches current settings tabs and runtime priority: Fishing and Combat are triggered situations, Quick Picks are manual, and Combat overrides Fishing.
- Follow-up shared GUI cleanup extended the same factory-surface approach to `CreateCheckbox()`, so Audio Volumes and other modules can store checkbox containers and use `SetCheckedSilently()` for reset/sync paths.
- Quick Picks are now integrated into the Situations tab as a Quick Picks group beneath triggered Fishing/Combat situations, matching the shared situation ownership in `sl_situations.lua`.


## Suggested Cleanup Order
1. [x] Fix the preview restore/runtime transition race first because it can leave real CVars inconsistent with active situation state.

2. [x] Suppress programmatic slider callbacks next; it is small and reduces incidental runtime writes from GUI refresh paths.

3. [x] After those behavioral cleanups, move `sl_fishing.lua` to `sl_situations.lua` around situation ownership: Fishing/Combat/Quick Pick data, menu-facing helpers, copy-current helpers, situation previews, and situation-specific temporary CVar/event handling. Keep `sl_runtime_logic.lua` as the single module-level runtime spine.
