# Audio Volumes Memory
Audio Volumes completed notes live in `completed_features/sound_levels.md`. Check that file for saved-variable shape, ownership, Fishing Focus behavior, runtime notes, Ketho findings, and performance guidance.

- Audio Volumes registers its settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Sound mutes, replacement playback, previews, event registration, and temporary volume profile runtime route through `M.is_runtime_enabled()` and `M.stop_runtime()`.
- Audio Volumes settings are not a normal full-panel `CreateSettingsGrid()` consumer. The Specifics tab remains a custom list/detail selector and General is riveted help plus reset. Situations tab channel columns use `CreateSettingsGrid()` for Normal/Fishing/Combat volume slider placement inside custom settings-group panels.
- Situations tab Normal Volumes sliders edit the user's normal Sound_* CVars. If a temporary profile is active, they update the cached normal values that will be restored when the temporary profile ends instead of overwriting Fishing or Combat Volumes.
- Combat Volumes uses `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`. Entering combat exits the Fishing profile, so combat end restores to normal volumes rather than returning to Fishing Volumes.


## Ketho / LuaLS
- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.
- 2026-06-20 LuaLS/Ketho diagnostics with explicit `Annotations/Core` and `Annotations/FrameXML` libraries reported only three Audio Volumes warnings. All were the known Ketho `C_Sound.PlaySound(soundKitID, channel)` string-channel `param-type-mismatch` warnings; no code change needed because in-game testing confirmed `"SFX"` works on this client.
