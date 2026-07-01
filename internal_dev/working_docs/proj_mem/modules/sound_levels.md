# Audio Volumes Memory
## Table of Contents
- [Saved Variables](#saved-variables)
- [Ownership](#ownership)
- [Runtime Rules](#runtime-rules)
- [Event Cache And Performance](#event-cache-and-performance)
- [Fishing Focus And Profiles](#fishing-focus-and-profiles)
- [GUI](#gui)
- [Ketho / LuaLS](#ketho--luals)


## Saved Variables
- `sound_levels.targets.<target>.preset`: file-level string `"0"` through `"19"`; UI maps this to `100%` through `5%`, with slider `0%` setting `sound_off`.
- `sound_levels.targets.<target>.use_original`, `.sound_off`, `.play_on_adjust`.
- `sound_levels.fishing_focus.enabled`: toggles the Fishing Focus channel profile.
- `sound_levels.fishing_focus.master`, `sfx`, `music`, `ambience`, `dialog`: `0-100` channel volumes applied only while channeling Fishing. Missing/reset values initialize from the user's current `Sound_*Volume` CVars; SFX starts 25 percentage points above normal Effects volume, clamped to 100.
- `sound_levels.combat_volumes.enabled`: toggles the Combat Volumes channel profile.
- `sound_levels.combat_volumes.master`, `sfx`, `music`, `ambience`, `dialog`: `0-100` channel volumes applied while the player is in combat. Missing/reset values initialize from the user's current `Sound_*Volume` CVars.
- `sound_levels.custom_situations.<id>.name`, `.enabled`, `.master`, `.sfx`, `.music`, `.ambience`, `.dialog`: legacy storage key for user-created custom Quick Picks. Only one Quick Pick is enabled at a time, and triggered Fishing/Combat profiles temporarily take priority.
- `sound_levels.last_situation_key`, `last_quick_pick_key`, `next_custom_situation_id`, `last_tab_index`, and `last_sound_key`: UI/session restoration and custom ID state.


## Ownership
- Sound target metadata and replacement assets live in `modules/sound_levels/sl_defaults.lua`.
- Fishing Focus, Combat Volumes, Quick Picks, and temporary channel CVar profile behavior live in `modules/sound_levels/sl_fishing.lua`; keep temporary profile logic out of generic replacement-sound runtime.
- Sound APIs are resolved to local upvalues at file load in `sl_core.lua`; call those locals instead of re-checking `C_Sound` at call sites.
- The `achievmentsound1` / `AchievmentSound1` spelling is inherited from Blizzard's original asset naming and matches the on-disk replacement folder. Change it only when all paths, files, and docs are intentionally migrated together.
- Sound reference/log files under `modules/sound_levels/sounds/` are public-facing and included in release zips.
- Audio Volumes registers its settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Sound mutes, replacement playback, previews, event registration, and temporary volume profile runtime route through `M.is_runtime_enabled()` and `M.stop_runtime()`.


## Runtime Rules
- WoW does not expose true per-sound volume control or custom channels. This module mutes known original FileDataIDs and optionally plays addon-owned replacement files.
- File-backed targets use 20 files where `_0.ogg` is loudest and `_19.ogg` is quietest. UI presents this as `0-100%` in 5% steps.
- `use_original` plays the original FileDataIDs or SoundKit fallback. The replacement slider stays saved but dimmed until moved, which clears Original.
- Each target declares a playback `channel`; default to `"Master"` if absent. Achievement and Ready Check use `"SFX"`.
- In-game testing confirmed `PlaySound(soundKitID, "SFX")` works on the current client despite Ketho typing `C_Sound.PlaySound` with numeric `UISoundSubType`.
- Preview cleanup must cancel pending timers and stop active sound handles. Reset/logout should use the combined cleanup path.
- Settings Module Enabler disables runtime side effects through `M.is_runtime_enabled()` / `M.stop_runtime()`: stop previews, restore temporary profiles, unmute originals, clear event cache, and unregister sound events.


## Event Cache And Performance
- Runtime playback is cache-driven: `M._event_cache[event]` holds only actionable `path` or `soundkit_id` plus `channel`.
- Off and Original targets do not create event-cache slots.
- `handle_event` must not read DB/defaults or resolve presets/paths.
- `sync_registered_events()` diffs registrations against the actionable cache.
- Mute/unmute work stays outside hot events and runs only on settings changes, load, reset, enable/disable, and logout.
- Do not add polling, always-running `OnUpdate`, DB reads, or preset/path lookup to the event hot path.


## Fishing Focus And Profiles
- Fishing Bobber bite timing is not exposed through tested Lua hooks/APIs. Do not re-add Bobber replacement controls without a new confirmed trigger.
- Fishing Focus caches `Sound_*` CVars on Fishing channel start (`131476`), applies configured Master/SFX/Music/Ambience/Dialog values, and restores cached values on channel stop/reset/logout.
- Fishing Focus registers `UNIT_SPELLCAST_CHANNEL_START/STOP` only when enabled, via `RegisterUnitEvent(..., "player")`, and keeps the Fishing spell ID guard.
- Combat Volumes registers `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` only when enabled. Entering combat exits the Fishing profile, so combat end restores normal volumes instead of returning to Fishing Volumes.
- Quick Picks are manual profile toggles. Fishing/Combat triggered profiles temporarily override the enabled Quick Pick, and the enabled Quick Pick resumes afterward.
- The addon minimap icon right-click menu lists Quick Picks and toggles the selected Quick Pick through the same manual profile path as the Quick Picks tab. It uses Blizzard's current `MenuUtil.CreateContextMenu` API only; do not add legacy `EasyMenu` or `UIDropDownMenu_*` fallbacks.
- Disabled sync should not create profile event frames or initialize profile DB values.
- Normal Volumes sliders edit the user's normal `Sound_*` CVars. If a temporary profile is active, they update the cached normal values restored afterward instead of overwriting the active temporary profile.
- Preview buttons play FishingBobber SoundKit `3355` on SFX. Normal Volumes preview must not write CVars; profile previews temporarily apply and then restore their profiles.
- Active profile application cancels/restores any pending profile preview before writing runtime CVars, so a delayed preview restore cannot overwrite a newly active Fishing, Combat, or Quick Pick profile.
- Temporary profile GUI refresh uses the shared slider `SetValueSilently()` helper so programmatic display sync does not schedule profile resync callbacks.
- Situation test sounds may be SoundKit-backed (`soundkit`, played with `PlaySound`) or FileDataID-backed (`file_id`, played with `PlaySoundFile`). Bloodlust `568812` was verified in-game as a FileDataID: `/run PlaySoundFile(568812)` worked while `PlaySound(568812)` did not.


## GUI
- Audio Volumes settings are not a normal full-panel `CreateSettingsGrid()` consumer. The Specifics tab remains a custom list/detail selector and General is riveted help plus reset. Situations tab uses a left situation list plus settings-group panels; Normal Volumes is always visible and only the selected situation row is shown below it.
- Situations tab always shows Normal Volumes plus exactly one selected triggered situation panel. Fishing and Combat are built-in non-custom entries.
- Quick Picks tab uses the same Normal Volumes plus selected profile layout, but excludes Fishing/Combat and contains Quiet Custom plus user-created custom entries backed by `sound_levels.custom_situations`.
- Custom Quick Picks are not triggered Situations because there is no user-facing way to define a trigger. The similarly named `create_custom_situation()` helper currently seeds `last_situation_key`, but the Quick Picks tab immediately saves the new key to `last_quick_pick_key`.


## Ketho / LuaLS
- `MinimalSliderWithSteppersTemplate` mixin calls in `sl_gui.lua` may produce type warnings.
- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.
- Ketho may report `C_Sound.PlaySound(soundKitID, channel)` string-channel `param-type-mismatch` warnings. Treat these as annotation limitations unless behavior regresses because in-game testing confirmed `"SFX"` works on this client.
