# Sound Reference

This file tracks the original sounds we target and the module-owned replacement files we use for each sound level.

## Replacement Path

Replacement file sets are configured in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_ASSETS`.

Each sound target references a file set with `replacement_asset`. To add another file-backed sound, add the folder and filename prefix to `M.SOUND_ASSETS`, then add a target in `M.SOUND_TARGETS` that points at that asset key.

The addon mutes known original Blizzard FileDataIDs when present, then plays the selected replacement file from the configured target folder.


- The `Original` setting is a separate checkbox and uses the unmodified WoW sound.
- The UI shows replacement volume as `0-100%`.
- `0%` is off and plays no replacement.
- Nonzero replacement levels map in 5% steps from `_19.ogg` through `_0.ogg`. 
- filenames are `file_name_0.ogg` through `file_name_19.ogg` Where 0 is the 0 dB, loudest file.
- `100%` maps to `_0.ogg`, the loudest replacement.

Original uses the unmodified WoW sound instead of a replacement file. Selecting Original leaves the replacement slider at its current position but dims it until the slider is moved.

## Sounds, Available
- the file path / name is where, in the extracted from CASC *sound* folder, the file is located'

### Achievement - achievmentsound1
- UI label:     `Achievement`
- FileDataID:   `569143`
- SoundKit Key: `UI_Alert_AchievementGained`
- SoundKitID:   `12891`
- File Path :   `/spells/achievmentsound1.ogg`
- Source Audio: mono
- Final Audio: declipped, stereo, 8 ms leading pad on right channel
- Link: https://www.wowhead.com/sound=12891/ui-alert-achievementgained

- Note: serves as a demo sound to learn the interface and hear stereo difference


### Ready Check - levelup2
- UI Label:     `Ready Check`
- FileDataID:   `567478`
- SoundKit Key: `READY_CHECK`
- SoundKitID:   `8960`
- File Path:    `/interface/levelup2.ogg`
- Source Audio: stereo
- Final Audio: declipped, 8 ms leading pad on right channel
- Link: https://www.wowhead.com/tbc/sound=8960/readycheck
- Purpose: Blizzard party/raid ready check and dungeon/LFG proposal ready sound
- Trigger events:
  - `READY_CHECK` - party/raid ready check started by a party or raid leader.
  - `LFG_PROPOSAL_SHOW` - dungeon/LFG proposal popup appears.
Related events that are not replacement triggers:
- `READY_CHECK_CONFIRM` - a player confirms ready or not ready.
- `READY_CHECK_FINISHED` - the ready check completes.
- `LFG_READY_CHECK_PLAYER_IS_READY` - an LFG ready-check player is ready.

- Warcraft Wiki PlaySound reference: https://warcraft.wiki.gg/wiki/API_PlaySound

---

## Sounds , Future

### LevelUp
- UI Label:     `Level Up`
- FileDataID:   `569593`
- SoundKit Key: `LEVELUPSOUND`, `LEVELUP`, `LevelUp`
- SoundKitID:   `124`, `888`, `195838`, 
- File Path:    `/spells/levelup.ogg`, `/interface/levelup.ogg`
- Source Audio:
- Final Audio:     
- Link(s):
  https://www.wowhead.com/sound=124/LEVELUPSOUND
  https://www.wowhead.com/sound=888/LEVELUP
  https://www.wowhead.com/sound=195838/LevelUp
- Note: these LevelUp name variants are aliases with no difference when they resolve to the same FileDataID.

### Fishing Hooked
- UI Label:   `Fishing Bobber`
- FileDataID: 
- Source Audio: 
- Final Audio: 
- Link: https://www.wowhead.com/sound=3355/fishing-hooked
- File Path: /spells/fishingbobber_ver2_1, 2, 3 .ogg
- consists of 3 different audio files so we need a method to play them cyclically
- files are mono and exhibit no clipping so de-clipping unecessary
