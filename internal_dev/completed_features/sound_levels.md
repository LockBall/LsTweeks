# Sound Levels Notes

Durable module-specific notes for `modules/sound_levels/`.


## Saved Variables

- `sound_levels.targets.<target>.preset` stores file-level strings `"0"` through `"19"`; the UI maps these to `100%` through `5%`, with slider `0%` setting `sound_off`.

- `sound_levels.targets.<target>.use_original`

- `sound_levels.targets.<target>.sound_off`

- `sound_levels.targets.<target>.play_on_adjust`

- `sound_levels.fishing_focus.enabled` toggles the Fishing Focus channel profile.

- `sound_levels.fishing_focus.master`, `sfx`, `music`, `ambience`, and `dialog` store 0-100 channel volumes applied only while the player is channeling Fishing. Missing/reset channel values initialize from the user's current normal Sound_*Volume CVars, not hardcoded defaults.

- Fishing Focus Effects (`sfx`) initializes 25 percentage points above the user's normal Effects volume, clamped to 100; other Fishing Focus channels initialize from current normal channel values.

- `sound_levels.last_tab_index` and `sound_levels.last_sound_key` restore the Sound Levels UI tab and selected sound when reopening after reload.


## Ownership

- Sound target metadata lives in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_TARGETS`.

- Replacement audio file sets are configured only in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_ASSETS`; targets reference them with `replacement_asset`.

- The `achievmentsound1` / `AchievmentSound1` spelling is inherited from Blizzard's original asset naming and matches the on-disk replacement folder. Do not "fix" it unless all paths, files, and docs are intentionally migrated together.

- Fishing Focus behavior lives in `modules/sound_levels/sl_fishing.lua`; keep fishing-channel CVar profile logic out of the generic replacement sound runtime.


## Runtime Notes

- WoW does not expose true per-sound volume control or custom channels. This module uses preset replacement behavior: mute known original FileDataIDs with `MuteSoundFile` / `C_Sound.MuteSoundFile`, then optionally play addon-owned replacement files with `PlaySoundFile` / `C_Sound.PlaySoundFile`.

- File-backed targets use `M.REPLACEMENT_FILE_MIN_LEVEL` through `M.REPLACEMENT_FILE_MAX_LEVEL`, currently 20 files where `_0.ogg` is loudest and `_19.ogg` is quietest. The UI presents this as `0-100%` in 5% steps; slider `0%` is off.

- The removed Fishing Bobber replacement experiment was the only multi-file target. Current replacement targets use one `replacement_asset` each.

- Original playback is controlled by `use_original` for targets with original FileDataIDs or a SoundKit fallback; when selected, the replacement slider remains at its saved position but is dimmed/inactive until the user moves it, which clears Original.

- Sound reference/log files under `modules/sound_levels/sounds/` are public-facing and included in release zips.

- Each sound target declares a `channel` field such as `"SFX"` or `"Master"` used for all playback calls; defaults to `"Master"` if absent. Achievement and Ready Check both use `"SFX"`.

- In-game testing confirmed `PlaySound(soundKitID, "SFX")` succeeds on the current client despite Ketho annotating `C_Sound.PlaySound` with numeric `UISoundSubType`.

- `get_db()` and per-target defaults are guarded once per session; reset clears both guards.

- Preview cleanup must cancel pending timers as well as stop active sound handles; reset/logout should use the combined preview cleanup path.

- WoW sound APIs are resolved to upvalue locals at file load in `sl_core.lua` (`_PlaySoundFile`, `_PlaySound`, `_StopSound`, `_MuteSoundFile`, `_UnmuteSoundFile`). Call them directly; do not re-check `C_Sound` at call sites.

- The Settings Module Enabler locks the Sound Levels settings page and gates runtime. `sl_main.lua` registers the category with `module_key`, so the sidebar button remains visible but greyed out/locked while disabled; `M.is_runtime_enabled()` gates runtime side effects and `M.stop_runtime()` stops previews, restores Fishing Focus, unmutes original files, clears event cache, and unregisters sound events.


## Event Cache And Performance

- Runtime event playback is intentionally cheap: `M._event_cache` is a flat pre-baked table keyed by event name. Each slot holds only actionable replacement playback data (`path` or `soundkit_id`, plus `channel`).

- Off and Original targets do not create event-cache slots.

- `handle_event` must not touch DB/defaults and should fall back to the cached SoundKit when replacement file playback fails.

- `sync_registered_events()` diffs registrations against the actionable cache.

- Mute/unmute work should stay outside hot events; it currently runs only on settings changes, load, reset, enable/disable, and logout.

- Fishing Focus only registers unit spellcast events when enabled.

- Do not add polling, an always-running `OnUpdate`, DB reads, or preset/path lookup to the Sound Levels event hot path.

- Further micro-optimizations such as caching `target.channel or "Master"` more deeply or replacing the small event slot arrays are not worth the clarity cost with the current two-target shape.


## Fishing Focus Runtime Notes

- Fishing Bobber bite timing is not exposed through tested Lua hooks/APIs (sound hooks, soft-interact/world-loot/object state, tooltip APIs, vignettes, channel updates, or gamepad vibration hooks). Do not re-add Bobber replacement controls without a new confirmed runtime trigger.

- Fishing Focus is an opt-in second channel-volume profile. It caches current Sound_* CVars on Fishing channel start (`131476`), applies configured Master/SFX/Music/Ambience/Dialog values, and restores cached values on channel stop/reset/logout.

- Fishing Focus channel events use `RegisterUnitEvent(..., "player")`; keep the Fishing spell ID guard (`131476`) and do not add a redundant unit guard.

- Fishing Focus disabled sync should not create its event frame or initialize channel values; only the enabled path should normalize the Fishing Focus DB and register channel events.

- Fishing Focus preview buttons play FishingBobber SoundKit `3355` on the Effects/SFX channel. **Normal Volumes** preview must not write Sound_* CVars; **Fishing Volumes** preview temporarily applies the Fishing Focus channel profile, plays the bobber sound, then restores cached channel CVars.


## LuaLS/Ketho Findings

- `modules/sound_levels/sl_gui.lua` can report type warnings around `MinimalSliderWithSteppersTemplate` frames passed to mixin-style methods such as `Init`, `RegisterCallback`, and `SetValue`.

- Ketho currently annotates `C_Sound.PlaySound` with a numeric `UISoundSubType`, so `PlaySound(soundKitID, "SFX")` reports a parameter type warning. In-game testing confirmed this call works on the current client.

Treat these as Ketho/LuaLS annotation limitations unless in-game behavior regresses.


## Runtime Status

- Customized Sound Levels sliders have been tested in-game and work as intended.

- Ready Check and LFG proposal replacement behavior was revalidated in-game after the client update and works as expected.

- Current Retail references still map Ready Check SoundKit `8960` to FileDataID `567478`; Achievement test SoundKit `12891` still maps to FileDataID `569143`.
