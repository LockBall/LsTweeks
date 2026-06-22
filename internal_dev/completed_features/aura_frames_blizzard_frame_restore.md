# Aura Frames Blizzard Frame Restore

Completed: 2026-06-21


## Summary

Aura Frames' **Enable Blizz Frame** toggles for Blizzard `BuffFrame` and `DebuffFrame` stopped restoring the default frames after they had been hidden. The failure matched the old implementation in `modules/aura_frames/af_core.lua`: hiding called `Hide()`, `UnregisterAllEvents()`, and cleared `OnShow`; restore registered only `UNIT_AURA` and `PLAYER_ENTERING_WORLD`.

Retail 12.0.7 source review showed that both frames inherit event ownership through `AuraFrameEventListenerMixin`, including `UNIT_AURA`, `GROUP_ROSTER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_ENTERING_WORLD`, and `PLAYER_IN_COMBAT_CHANGED`. `BuffFrameMixin` also registers `WEAPON_ENCHANT_CHANGED` and `WEAPON_SLOT_CHANGED`. The old restore list was incomplete and brittle.

The fix preserves Blizzard ownership. LsTweeks now tracks forced-hidden state in an addon-owned weak table keyed by Blizzard frame, installs one `OnShow` hook per frame, calls `Hide()` only while forced hidden, and restores by clearing the forced-hidden flag and calling `Show()` only for frames LsTweeks hid.


## Source References

- [Gethe/wow-ui-source `12.0.7`, `Blizzard_BuffFrame.toc`](https://github.com/Gethe/wow-ui-source/blob/12.0.7/Interface/AddOns/Blizzard_BuffFrame/Blizzard_BuffFrame.toc)

- [Gethe/wow-ui-source `12.0.7`, `BuffFrameTemplates.xml`](https://github.com/Gethe/wow-ui-source/blob/12.0.7/Interface/AddOns/Blizzard_BuffFrame/BuffFrameTemplates.xml)

- [Gethe/wow-ui-source `12.0.7`, `BuffFrame.xml`](https://github.com/Gethe/wow-ui-source/blob/12.0.7/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.xml)

- [Gethe/wow-ui-source `12.0.7`, `BuffFrame.lua`](https://github.com/Gethe/wow-ui-source/blob/12.0.7/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua)

- [Gethe/wow-ui-source `12.0.7`, `EditModeSystemTemplates.xml`](https://github.com/Gethe/wow-ui-source/blob/12.0.7/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.xml)


## Validation

- Shell: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1` passed Lua syntax and whitespace checks on 2026-06-21.

- In-game: user completed Retail in-game testing on 2026-06-21 and reported the Blizzard buff/debuff frame toggles look good after the implementation.


## Durable Rule

Do not call `UnregisterAllEvents()`, register guessed restore events, or replace scripts on Blizzard `BuffFrame` / `DebuffFrame`. Hide through addon-owned forced-hidden state plus a one-time `OnShow` hook, and restore by clearing that state and showing only frames LsTweeks forced hidden.
