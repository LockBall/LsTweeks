# Sound Levels Review

## Open Follow-Ups

1. [ ] Consider a small opt-in shared helper for repeated Fishing tab
channel-column stride math.

## Notes

- Do not force Sound Levels into `CreateSettingsGrid()`. The Sounds tab is a
list/detail selector, General uses riveted help plus reset, and Fishing uses
custom channel-column panels.

- Keep the known Ketho `C_Sound.PlaySound(soundKitID, "SFX")` warnings as
documentation-only unless in-game behavior changes.
