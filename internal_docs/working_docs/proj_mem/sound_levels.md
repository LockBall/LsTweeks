# Sound Levels Memory

Sound Levels module-specific notes live in `internal_docs/completed_features/sound_levels.md`. Check that file for saved-variable shape, ownership, Fishing Focus behavior, runtime notes, Ketho findings, and performance guidance.


## Ketho / LuaLS

- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.

- 2026-06-20 LuaLS/Ketho diagnostics with explicit `Annotations/Core` and `Annotations/FrameXML` libraries reported only three Sound Levels warnings. All were the known Ketho `C_Sound.PlaySound(soundKitID, channel)` string-channel `param-type-mismatch` warnings; no code change needed because in-game testing confirmed `"SFX"` works on this client.
