# Audio Volumes Memory
## Table of Contents
- [Saved Variables](#saved-variables)
- [Ownership](#ownership)
- [Runtime Rules](#runtime-rules)
- [Event Cache And Performance](#event-cache-and-performance)
- [Situations And Quick Picks](#situations-and-quick-picks)
- [GUI](#gui)
- [Ketho / LuaLS](#ketho--luals)


## Saved Variables
- `audio_volumes.targets.<target>.preset`: file-level string `"0"` through `"19"`; UI maps this to `100%` through `5%`, with slider `0%` setting `sound_off`.
- `audio_volumes.targets.<target>.use_original`, `.sound_off`, `.play_on_adjust`.
- `audio_volumes.fishing_focus.enabled`: toggles the Fishing Focus channel profile.
- `audio_volumes.fishing_focus.master`, `sfx`, `music`, `ambience`, `dialog`: `0-100` channel volumes applied only while channeling Fishing. Missing/reset values initialize from the user's current `Sound_*Volume` CVars; SFX starts 25 percentage points above normal Effects volume, clamped to 100.
- `audio_volumes.combat_volumes.enabled`: toggles the Combat Volumes channel profile.
- `audio_volumes.combat_volumes.master`, `sfx`, `music`, `ambience`, `dialog`: `0-100` channel volumes applied while the player is in combat. Missing/reset values initialize from the user's current `Sound_*Volume` CVars.
- `audio_volumes.custom_situations.<id>.name`, `.enabled`, `.master`, `.sfx`, `.music`, `.ambience`, `.dialog`: storage for user-created custom Quick Picks. Only one Quick Pick is enabled at a time, and triggered Fishing/Combat situations temporarily take priority.
- `audio_volumes.last_situation_key`, `last_quick_pick_key`, `next_custom_situation_id`, `last_tab_index`, and `last_sound_key`: UI/session restoration and custom ID state. The unified Situations tab uses `last_situation_key` for both triggered situations and Quick Picks; `last_quick_pick_key` retains minimap Quick Pick state.


## Ownership
- Sound target metadata and replacement assets live in `modules/audio_volumes/av_defaults.lua`.
- Fishing Focus, Combat Volumes, Quick Picks, and temporary channel CVar situation behavior live in `modules/audio_volumes/av_logic_situations.lua`; keep temporary CVar situation logic out of generic replacement-sound runtime.
- `av_logic_situations.lua` owns Fishing/Combat/Quick Pick data, CRUD, copy-current helpers, minimap/menu-facing helpers, situation previews, and situation-specific temporary CVar/event handling. Keep `av_logic_main.lua` as the module-level runtime spine for replacement playback, mutes, previews, event cache, and lifecycle cleanup; do not add a generic second runtime file unless the situation file later needs a more specific split.
- `av_logic_main.lua` is the Audio Volumes main logic file, not a passive utility/core-definition file.
- `av_main.lua` is the Audio Volumes entrypoint/controller file: reset hooks, module enable/disable, status registration, addon-load startup, logout cleanup, and settings category registration.
- GUI file naming uses `av_gui.lua` for shared GUI layout/tab host and `av_gui_<tab>.lua` for tab builders. Keep GUI-only helper controls in GUI files; move only broad non-GUI module helpers into `av_functions.lua`.
- Sound APIs are resolved to local upvalues at file load in `av_logic_main.lua`; call those locals instead of re-checking `C_Sound` at call sites.
- The `achievmentsound1` / `AchievmentSound1` spelling is inherited from Blizzard's original asset naming and matches the on-disk replacement folder. Change it only when all paths, files, and docs are intentionally migrated together.
- Sound reference/log files under `modules/audio_volumes/sounds/` are public-facing and included in release zips.
- Audio Volumes registers its settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Sound mutes, replacement playback, previews, event registration, and temporary situation runtime route through `M.is_runtime_enabled()` and `M.stop_runtime()`.


## Runtime Rules
- WoW does not expose true per-sound volume control or custom channels. This module mutes known original FileDataIDs and optionally plays addon-owned replacement files.
- File-backed targets use 20 files where `_0.ogg` is loudest and `_19.ogg` is quietest. UI presents this as `0-100%` in 5% steps.
- `use_original` plays the original FileDataIDs or SoundKit fallback. The replacement slider stays saved but dimmed until moved, which clears Original.
- Each target declares a playback `channel`; default to `"Master"` if absent. Achievement and Ready Check use `"SFX"`.
- In-game testing confirmed `PlaySound(soundKitID, "SFX")` works on the current client despite Ketho typing `C_Sound.PlaySound` with numeric `UISoundSubType`.
- Preview cleanup must cancel pending timers and stop active sound handles. Reset/logout should use the combined cleanup path.
- Settings Module Enabler disables runtime side effects through `M.is_runtime_enabled()` / `M.stop_runtime()`: stop previews, restore temporary situations, unmute originals, clear event cache, and unregister sound events.


## Event Cache And Performance
- Runtime playback is cache-driven: `M._event_cache[event]` holds only actionable `path` or `soundkit_id` plus `channel`.
- Replacement-preset slider changes refresh only the event cache and registrations; use the full audio apply only when Off or Original state changes because those transitions alter file mutes.
- Off and Original targets do not create event-cache slots.
- `handle_event` must not read DB/defaults or resolve presets/paths.
- `sync_registered_events()` diffs registrations against the actionable cache.
- Mute/unmute work stays outside hot events and runs only on settings changes, load, reset, enable/disable, and logout.
- Do not add polling, always-running `OnUpdate`, DB reads, or preset/path lookup to the event hot path.


## Situations And Quick Picks
- Fishing Bobber bite timing is not exposed through tested Lua hooks/APIs. Do not re-add Bobber replacement controls without a new confirmed trigger.
- Fishing Focus caches `Sound_*` CVars on Fishing channel start (`131476`), applies configured Master/SFX/Music/Ambience/Dialog values, and restores cached values on channel stop/reset/logout.
- Fishing Focus registers `UNIT_SPELLCAST_CHANNEL_START/STOP` only when enabled, via `RegisterUnitEvent(..., "player")`, and keeps the Fishing spell ID guard.
- Enabling Fishing Focus while Fishing is already channeling checks `UnitChannelInfo("player")` for spell `131476` and applies the profile immediately; do not rely only on the next channel-start event.
- Combat Volumes registers `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` only when enabled. Entering combat exits the Fishing situation, so combat end restores normal volumes instead of returning to Fishing Volumes.
- Quick Picks are manual situation toggles. Fishing/Combat triggered situations temporarily override the enabled Quick Pick, and the enabled Quick Pick resumes afterward.
- Deleting an enabled custom Quick Pick restores Normal Volumes in the data layer, clears its invalid saved selection, and asks the built Situations UI to remove its control references. The GUI only chooses the next visible panel.
- The addon minimap icon right-click menu lists **Normal Volumes** followed by Quick Picks. Selecting Normal clears the manual override; Fishing and Combat still take priority. It uses Blizzard's current `MenuUtil.CreateContextMenu` API only; do not add legacy `EasyMenu` or `UIDropDownMenu_*` fallbacks.
- The minimap Quick Picks disabled branch must not call `M.get_quick_pick_menu_entries()` or other situation DB initializers. Keep menu entry lookup lazy and only request entries after confirming Audio Volumes is enabled.
- Disabled sync should not create situation event frames or initialize situation DB values.
- Normal Volumes sliders edit the user's normal `Sound_*` CVars. If a temporary situation is active, they update the cached normal values restored afterward instead of overwriting the active temporary situation.
- Normal Volume reads use the cached profile for Fishing, Combat, and active manual Quick Picks, so slider display and Use Normal copy/seed helpers always use normal values rather than temporary CVar overrides.
- During a situation preview, Normal Volume edits update the preview restore cache so the delayed restore applies the new normal value rather than overwriting the edit.
- Preview buttons play FishingBobber SoundKit `3355` on SFX. Normal Volumes preview must not write CVars; situation previews temporarily apply and then restore their CVar values.
- Active situation application cancels/restores any pending situation preview before writing runtime CVars, so a delayed preview restore cannot overwrite a newly active Fishing, Combat, or Quick Pick situation.
- Temporary situation GUI refresh uses the shared slider `SetValueSilently()` helper so programmatic display sync does not schedule situation resync callbacks.
- Situation test sounds may be SoundKit-backed (`soundkit`, played with `PlaySound`) or FileDataID-backed (`file_id`, played with `PlaySoundFile`). Bloodlust `568812` was verified in-game as a FileDataID: `/run PlaySoundFile(568812)` worked while `PlaySound(568812)` did not.


## GUI
- Audio Volumes settings are not a normal full-panel `CreateSettingsGrid()` consumer. The Specifics tab remains a custom list/detail selector and General is riveted help plus reset. Situations tab uses a left tree/list plus settings-group panels; Normal Volumes is always visible and only the selected situation row is shown below it.
- Specifics panel callbacks must resolve `M.get_target_db(target_key)` at interaction time. ARM reset replaces nested target tables while settings panels remain built, so callbacks must not retain a captured target DB table.
- ARM reset rebuilds the existing Situations tab before synchronizing controls. Its sliders and callbacks intentionally capture profile tables, so rebuilding ensures they bind to the reset tables and removes panels for reset-deleted Quick Picks.
- `av_gui.lua` owns shared GUI strings/layout, `M.ApplyGUIBoxBackdrop()`, Specifics sound-target slider panel construction, and `M.BuildSettings()`. Do not move these to `av_functions.lua` unless they become non-GUI module helpers.
- `av_gui_general.lua`, `av_gui_specifics.lua`, and `av_gui_situations.lua` own their tab builders.
- `av_profiles.lua` owns the Audio Volumes snapshot schema and applies through `on_reset_complete`; shared storage/UI behavior lives in `../functions/profiles.md`. Snapshots include sound targets and situations but exclude UI selection/session state; ARM reset keeps profiles by default.
- Situations tab always shows Normal Volumes plus exactly one selected situation panel. The left list has a Triggered group for Fishing/Combat and a Quick Picks group for Quiet Custom plus user-created custom entries backed by `audio_volumes.custom_situations`.
- The Situations left list uses `addon.CreateGroupColumn()` from `functions/group_column.lua` for shared section outlines and selected-group gold borders. Triggered is the fixed primary group, equivalent to Aura Frames' Buffs section. Quick Picks is the custom-style group. Both groups use the same Aura-style group title/outline presentation.
- Custom Quick Picks are not triggered Situations because there is no user-facing way to define a trigger. `create_custom_situation()` seeds `last_situation_key` so newly created Quick Picks open in the unified Situations tab immediately.


## Ketho / LuaLS
- `MinimalSliderWithSteppersTemplate` mixin calls in `av_gui.lua` may produce type warnings. Audio Volumes tab UI is split across `av_gui_general.lua`, `av_gui_specifics.lua`, and `av_gui_situations.lua`; shared tab host/layout and Specifics slider-panel helpers remain in `av_gui.lua`.
- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.
- Ketho may report `C_Sound.PlaySound(soundKitID, channel)` string-channel `param-type-mismatch` warnings. Treat these as annotation limitations unless behavior regresses because in-game testing confirmed `"SFX"` works on this client. Known Audio Volumes call sites use inline `---@diagnostic disable-next-line: param-type-mismatch` comments only on verified `PlaySound` string-channel calls.
