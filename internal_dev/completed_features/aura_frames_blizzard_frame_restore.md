# Aura Frames Blizzard Frame Restore

Completed: 2026-06-21

## Summary

Aura Frames' **Enable Blizz Frame** toggles stopped restoring Blizzard `BuffFrame` / `DebuffFrame` after hiding them. The old code called `Hide()`, `UnregisterAllEvents()`, and cleared `OnShow`, then tried to restore with a guessed event list.

Retail 12.0.7 source showed those frames own more event/script state than LsTweeks should recreate. The fix now tracks addon-owned forced-hidden state in a weak table, installs one `OnShow` hook per frame, and restores only by clearing that flag and showing frames LsTweeks hid.

## Durable Rule

Do not call `UnregisterAllEvents()`, register guessed restore events, or replace scripts on Blizzard `BuffFrame` / `DebuffFrame`. Hide through addon-owned forced-hidden state plus a one-time `OnShow` hook.

## Evidence

- Source reviewed: Gethe/wow-ui-source 12.0.7 `Blizzard_BuffFrame` and `Blizzard_EditMode` files.
- Validation: `check_fast.ps1` passed on 2026-06-21.
- In-game: user verified Blizzard buff/debuff frame toggles restored correctly on 2026-06-21.
