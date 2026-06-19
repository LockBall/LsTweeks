# Sound Levels Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

- [x] 1. Priority: High | Impact: High | Change Risk: Low - Revalidated original FileDataIDs and in-game Ready Check/LFG proposal behavior after the client update. Behavior is as expected.

- [ ] 2. Priority: Medium | Impact: Medium | Change Risk: Medium - Fishing Focus restore paths look present on disable, preview stop, channel stop, reset, and logout. Test interrupted casts, logout/reload while active, and disabling the module while Fishing Focus is active.

- [ ] 3. Priority: Low | Impact: Low | Change Risk: Low - The asset key/path spelling `achievmentsound1` is a known spelling issue inherited from the original Blizzard asset files and matches the on-disk folder; avoid "fixing" spelling unless all paths/files/docs are migrated together.

## Item 1 Complete - 2026-06-19

In-game tests confirmed Ready Check and LFG proposal replacement behavior is as expected. Current Retail references still map Ready Check SoundKit `8960` to FileDataID `567478`; Achievement test SoundKit `12891` still maps to FileDataID `569143`.

The old TBC Ready Check reference link in `modules/sound_levels/sounds/sound_reference.md` was updated to the current Retail link.
