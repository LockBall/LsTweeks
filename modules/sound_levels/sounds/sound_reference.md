# Sound Reference

This file tracks the original sounds we target and the module-owned replacement files we use for each sound level.

Replacement files:
- `file_name_shush.ogg`
- `file_name_shusher.ogg`
- `file_name_shushest.ogg`

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

Replacement files live in:

`Interface\AddOns\LsTweeks\modules\sound_levels\sounds\`

The addon mutes known original Blizzard FileDataIDs, then plays the selected replacement file from this folder.
