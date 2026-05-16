# Sound Reference

This file tracks the original sounds we target and the module-owned replacement files we use for each sound level.

Ready Check replacement files:
- `levelup2_0.ogg` through `levelup2_19.ogg`
- `Original` is a separate checkbox and uses the unmodified WoW sound.
- The UI shows replacement volume as `0-100%`.
- `0%` is off and plays no replacement.
- Nonzero replacement levels map in 5% steps to `levelup2_19.ogg` through `levelup2_0.ogg`.
- `100%` maps to `levelup2_0.ogg`, the loudest replacement.

Original uses the unmodified WoW sound instead of a replacement file. Selecting Original leaves the replacement slider at its current position but dims it until the slider is moved.

## Test Sound

- Module name: `test_sound`
- UI label: `Test Sound`
- Original source: built-in WoW SoundKit
- SoundKit key: `IG_CHARACTER_INFO_TAB`
- Purpose: quick local test entry for slider and preview behavior


## Ready Check
- UI label: `Ready Check`    Blizzard dungeon / LFG proposal ready sound
- SoundKit key: `READY_CHECK`
- file path/name: `sound/interface/levelup2.ogg`
- FileDataID: `567478`
- SoundKitID: `8960`
- Trigger events:
    - `READY_CHECK` - party/raid ready check started by a party or raid leader.
    - `LFG_PROPOSAL_SHOW` - dungeon / LFG proposal popup appears.
- Link: https://www.wowhead.com/tbc/sound=8960/readycheck

Related events that are not replacement triggers:
- `READY_CHECK_CONFIRM` - a player confirms ready or not ready.
- `READY_CHECK_FINISHED` - the ready check completes.
- `LFG_READY_CHECK_PLAYER_IS_READY` - an LFG ready-check player is ready.


- Warcraft Wiki PlaySound reference: https://warcraft.wiki.gg/wiki/API_PlaySound


## Replacement Path

Replacement file paths are configured in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_ASSET_PATHS`.

The addon mutes known original Blizzard FileDataIDs, then plays the selected replacement file from this folder.
