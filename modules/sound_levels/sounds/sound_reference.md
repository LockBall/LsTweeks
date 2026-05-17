# Sound Reference

This file tracks the original sounds we target and the module-owned replacement files we use for each sound level.

Replacement file sets:
- Achievement test: `achievmentsound1_0.ogg` through `achievmentsound1_19.ogg`
- Ready Check: `levelup2_0.ogg` through `levelup2_19.ogg`
- `Original` is a separate checkbox and uses the unmodified WoW sound.
- The UI shows replacement volume as `0-100%`.
- `0%` is off and plays no replacement.
- Nonzero replacement levels map in 5% steps from `_19.ogg` through `_0.ogg`.
- `100%` maps to `_0.ogg`, the loudest replacement.

Original uses the unmodified WoW sound instead of a replacement file. Selecting Original leaves the replacement slider at its current position but dims it until the slider is moved.

## Achievement Test Sound

- Module name: `test_sound`
- UI label: `Achievement`
- Replacement folder: `modules/sound_levels/sounds/achievmentsound1`
- FileDataID: `569143`
- Purpose: quick local test entry for slider and preview behavior
- Note: the folder and filename prefix intentionally use the shipped `achievmentsound1` spelling.

## Ready Check

- UI label: `Ready Check`
- Purpose: Blizzard party/raid ready check and dungeon/LFG proposal ready sound
- SoundKit key: `READY_CHECK`
- File path/name: `sound/interface/levelup2.ogg`
- FileDataID: `567478`
- SoundKitID: `8960`
- Trigger events:
  - `READY_CHECK` - party/raid ready check started by a party or raid leader.
  - `LFG_PROPOSAL_SHOW` - dungeon/LFG proposal popup appears.
- Link: https://www.wowhead.com/tbc/sound=8960/readycheck

Related events that are not replacement triggers:
- `READY_CHECK_CONFIRM` - a player confirms ready or not ready.
- `READY_CHECK_FINISHED` - the ready check completes.
- `LFG_READY_CHECK_PLAYER_IS_READY` - an LFG ready-check player is ready.

- Warcraft Wiki PlaySound reference: https://warcraft.wiki.gg/wiki/API_PlaySound


## Replacement Path

Replacement file sets are configured in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_ASSETS`.

Each sound target references a file set with `replacement_asset`. To add another file-backed sound, add the folder and filename prefix to `M.SOUND_ASSETS`, then add a target in `M.SOUND_TARGETS` that points at that asset key.

The addon mutes known original Blizzard FileDataIDs when present, then plays the selected replacement file from the configured target folder.
