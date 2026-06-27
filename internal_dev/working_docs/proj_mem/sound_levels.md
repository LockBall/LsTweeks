# Sound Levels Memory

Sound Levels module-specific notes live in `internal_dev/completed_features/sound_levels.md`. Check that file for saved-variable shape, ownership, Fishing Focus behavior, runtime notes, Ketho findings, and performance guidance.

- Sound Levels registers its settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Sound mutes, replacement playback, previews, event registration, and Fishing Focus runtime route through `M.is_runtime_enabled()` and `M.stop_runtime()`.

- Sound Levels settings are not currently a normal `CreateSettingsGrid()` consumer. The Sounds tab is a list/detail selector, General is riveted help plus reset, and Fishing uses custom channel-column panels. Do not force the whole module into the row/column settings grid. The Fishing tab's channel-column layout is currently working well; do not extract a helper unless future layout changes make the math repeat or spread.


## Ketho / LuaLS

- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.

- 2026-06-20 LuaLS/Ketho diagnostics with explicit `Annotations/Core` and `Annotations/FrameXML` libraries reported only three Sound Levels warnings. All were the known Ketho `C_Sound.PlaySound(soundKitID, channel)` string-channel `param-type-mismatch` warnings; no code change needed because in-game testing confirmed `"SFX"` works on this client.

