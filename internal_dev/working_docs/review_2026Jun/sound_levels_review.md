# Sound Levels Review

## Dormant Follow-Up

- Consider a small opt-in shared helper for repeated Fishing tab channel-column
  stride math only if the Fishing tab layout gets touched again.


## Notes

- Do not force Sound Levels into `CreateSettingsGrid()`. The Sounds tab is a
  list/detail selector, General uses riveted help plus reset, and Fishing uses
  custom channel-column panels.

- Keep the known Ketho `C_Sound.PlaySound(soundKitID, "SFX")` warnings as
  documentation-only unless in-game behavior changes.
