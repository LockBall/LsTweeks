# Sound Levels Notes

Durable module-specific notes for `modules/sound_levels/`.

## Saved Variables

- `sound_levels.targets.<target>.preset`: file-level string `"0"` through `"19"`; UI maps this to `100%` through `5%`, with slider `0%` setting `sound_off`.
- `sound_levels.targets.<target>.use_original`, `.sound_off`, `.play_on_adjust`.
- `sound_levels.fishing_focus.enabled`: toggles the Fishing Focus channel profile.
- `sound_levels.fishing_focus.master`, `sfx`, `music`, `ambience`, `dialog`: 0-100 channel volumes applied only while channeling Fishing. Missing/reset values initialize from the user's current Sound_*Volume CVars; SFX starts 25 percentage points above normal Effects volume, clamped to 100.
- `sound_levels.last_tab_index` and `sound_levels.last_sound_key`: restore Sound Levels UI tab/selection.

## Ownership

- Sound target metadata and replacement assets live in `modules/sound_levels/sl_defaults.lua`.
- Fishing Focus behavior lives in `modules/sound_levels/sl_fishing.lua`; keep Fishing channel CVar profile logic out of generic replacement-sound runtime.
- The `achievmentsound1` / `AchievmentSound1` spelling is inherited from Blizzard's original asset naming and matches the on-disk replacement folder. Do not "fix" it unless all paths, files, and docs are intentionally migrated together.
- Sound reference/log files under `modules/sound_levels/sounds/` are public-facing and included in release zips.

## Runtime Rules

- WoW does not expose true per-sound volume control or custom channels. This module mutes known original FileDataIDs and optionally plays addon-owned replacement files.
- File-backed targets use 20 files where `_0.ogg` is loudest and `_19.ogg` is quietest. UI presents this as `0-100%` in 5% steps.
- `use_original` plays the original FileDataIDs or SoundKit fallback; the replacement slider stays saved but dimmed until moved, which clears Original.
- Each target declares a playback `channel`; default to `"Master"` if absent. Achievement and Ready Check use `"SFX"`.
- In-game testing confirmed `PlaySound(soundKitID, "SFX")` works on the current client despite Ketho typing `C_Sound.PlaySound` with numeric `UISoundSubType`.
- Sound APIs are resolved to local upvalues at file load in `sl_core.lua`; call those locals instead of re-checking `C_Sound` at call sites.
- Preview cleanup must cancel pending timers and stop active sound handles. Reset/logout should use the combined cleanup path.
- Settings Module Enabler disables runtime side effects through `M.is_runtime_enabled()` / `M.stop_runtime()`: stop previews, restore Fishing Focus, unmute originals, clear event cache, and unregister sound events.

## Event Cache And Performance

- Runtime playback is cache-driven: `M._event_cache[event]` holds only actionable `path` or `soundkit_id` plus `channel`.
- Off and Original targets do not create event-cache slots.
- `handle_event` must not read DB/defaults or resolve presets/paths.
- `sync_registered_events()` diffs registrations against the actionable cache.
- Mute/unmute work stays outside hot events and runs only on settings changes, load, reset, enable/disable, and logout.
- Do not add polling, always-running `OnUpdate`, DB reads, or preset/path lookup to the event hot path.

## Fishing Focus

- Fishing Bobber bite timing is not exposed through tested Lua hooks/APIs. Do not re-add Bobber replacement controls without a new confirmed trigger.
- Fishing Focus caches Sound_* CVars on Fishing channel start (`131476`), applies configured Master/SFX/Music/Ambience/Dialog values, and restores cached values on channel stop/reset/logout.
- Fishing Focus registers `UNIT_SPELLCAST_CHANNEL_START/STOP` only when enabled, via `RegisterUnitEvent(..., "player")`, and keeps the Fishing spell ID guard.
- Disabled sync should not create the event frame or initialize Fishing Focus DB values.
- Preview buttons play FishingBobber SoundKit `3355` on SFX. **Normal Volumes** preview must not write CVars; **Fishing Volumes** preview temporarily applies and then restores the Fishing profile.

## LuaLS/Ketho Notes

- `MinimalSliderWithSteppersTemplate` mixin calls in `sl_gui.lua` may produce type warnings.
- Ketho annotates `C_Sound.PlaySound` with numeric `UISoundSubType`; current in-game behavior accepts `"SFX"`.

Treat these as annotation limitations unless behavior regresses.

## Validation

- Customized Sound Levels sliders work in-game.
- Ready Check and LFG proposal replacement behavior was revalidated after the client update.
- Current Retail references still map Ready Check SoundKit `8960` to FileDataID `567478`; Achievement test SoundKit `12891` still maps to FileDataID `569143`.
