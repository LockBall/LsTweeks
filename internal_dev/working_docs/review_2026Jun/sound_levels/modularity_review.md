# Audio Volumes Modularity Review
## Scope
- Reviewed `modules/sound_levels/sl_defaults.lua`, `sl_functions.lua`, `sl_core.lua`, `sl_fishing.lua`, `sl_gui.lua`, `sl_main.lua`, `core/minimap_button.lua`, module memory, and README Audio Volumes wording.
- Fast validation passed on 2026-07-01: Lua syntax, region markers, and whitespace diff checks.
- Overall shape is sound: replacement-sound hot paths are cache-driven in `sl_core.lua`/`sl_functions.lua`, profile CVar runtime is centralized in `sl_fishing.lua`, and public README behavior matches the current Fishing/Combat/Quick Picks model.


## Findings
1. [x] Medium: Preview CVar restore can race active profile transitions. `sl_fishing.lua` uses one preview restore cache/timer for Fishing Bobber and situation previews (`restore_bobber_preview_profile()` at lines 420-435; preview cache/timer setup at lines 458-468 and 490-507). Runtime profile transitions such as Combat start (`apply_combat_volumes()` at lines 640-651) did not cancel that pending preview restore. Fixed by resolving pending profile preview restore at the start of `apply_active_sound_channel_profile()`, before active Fishing, Combat, or Quick Pick CVars are written.

2. [x] Medium/Low: Programmatic temporary-profile GUI sync can invoke slider callbacks. `M.sync_temporary_profile_controls()` directly called `slider.slider:SetValue(...)` for Fishing, Combat, Quiet Custom, and custom Quick Pick sliders at `sl_gui.lua` lines 338-363. `addon.CreateSliderWithBox()` writes DB and schedules callbacks from `OnValueChanged` unless callback suppression is active. Fixed by adding shared `GetValue()`, `SetValue()`, `SetValueSilently()`, and `HookValueChanged()` support to `CreateSliderWithBox()` and using the factory API for Audio Volumes temporary profile/current-volume display refresh paths. Follow-up audit found no intentional direct settings-slider value access; remaining direct reads/writes and `HookScript("OnValueChanged", ...)` handlers were migrated to the factory API.

3. [ ] Low: `sl_fishing.lua` has outgrown its file name and single-file responsibility. It now owns Fishing Focus, Combat Volumes, Quick Pick DB, custom Quick Pick CRUD, minimap menu helpers, preview playback, temporary profile CVar runtime, and profile event routing (`sl_fishing.lua` lines 91-776). The code is still regioned and understandable, but future work will be easier if the "temporary channel profiles" concept becomes the source boundary rather than Fishing. Recommended split when the next profile feature lands: keep shared channel/profile DB helpers in one file, runtime CVar apply/restore and event routing in another, and Quick Pick/custom CRUD plus menu-facing helpers in a third.

4. [ ] Low: Disabled minimap Quick Picks menu still asks the module for entries before showing the disabled menu. `core/minimap_button.lua` computes `entries` at lines 97-102 even when `module_enabled` is false; `M.get_quick_pick_menu_entries()` initializes Quiet Custom/custom situation DB through `sl_fishing.lua` lines 325-353. This does not enable runtime events, but it weakens the documented "disabled sync should not initialize profile DB values" rule. Recommended fix: only call `get_quick_pick_menu_entries()` after confirming Audio Volumes is enabled, or let `show_menu()` lazily request entries only in the enabled branch.


## Clean Areas
- Replacement sound event handling stays hot-path friendly: `handle_event()` only reads `_event_cache`, and `rebuild_event_cache()` does DB/default work outside the event handler.
- Module enable/disable behavior is consistently routed through `M.is_runtime_enabled()` and `M.stop_runtime()` for mutes, previews, event cache, and temporary profile restoration.
- The public behavior documented in `README.md` lines 125-139 matches current settings tabs and runtime priority: Fishing and Combat are triggered situations, Quick Picks are manual, and Combat overrides Fishing.
- Follow-up shared GUI cleanup extended the same factory-surface approach to `CreateCheckbox()`, so Audio Volumes and other modules can store checkbox containers and use `SetCheckedSilently()` for reset/sync paths.


## Suggested Cleanup Order
1. [x] Fix the preview restore/runtime transition race first because it can leave real CVars inconsistent with active profile state.

2. [x] Suppress programmatic slider callbacks next; it is small and reduces incidental runtime writes from GUI refresh paths.

3. [ ] After those behavioral cleanups, consider renaming/splitting `sl_fishing.lua` around temporary profile ownership if more Quick Pick or triggered profile work is planned.
