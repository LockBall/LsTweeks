# Player Frame OOC Fade

Date: 2026-05-31
Version: 0.10.0

## Summary

Player Frame fading is split across:

- `modules/player_frame/pf_main.lua`: settings, GUI, defaults, event routing, portrait combat text hiding.
- `modules/player_frame/pf_fade.lua`: OOC fade runtime state, combat transitions, timers, health curve gate.

The health API probe used during development is archived at `internal_docs/tests/player_frame_health_probe.lua` and is not loaded by the addon.

## Final Behavior

- PlayerFrame always remains clickable.
- Combat immediately restores full visibility.
- OOC fade uses `fade_delay`, then fades toward `fade_alpha` over `fade_length`.
- Low health keeps PlayerFrame fully visible while OOC.
- Above `health_visible_threshold`, visibility eases toward the current fade alpha instead of snapping.
- `health_visible_threshold = 0` disables the health gate.

## Defaults

- `fade_alpha = 0.5`
- `fade_delay = 2.0`
- `fade_length = 5.0`
- `health_visible_threshold = 80`

## Key Lessons

- Retail 12.x health APIs can return Secret Values from tainted addon paths.
- Do not compare, stringify, or do arithmetic on current health or `UnitHealthPercent()` curve results.
- The viable health-gate pattern is pass-through only: build a `C_CurveUtil` curve, call `UnitHealthPercent("player", true, curve)`, and pass the returned alpha directly to `PlayerFrame:SetAlpha()`.
- Blizzard PlayerFrame health bar internals and hidden status bars were not reliable for addon health gating.
- Do not use `UnitAffectingCombat("player")` for this fade gate; it can remain sticky after regen. Use `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, with `InCombatLockdown()` as fallback.
- Do not use `CreateAnimationGroup()` / `AnimationGroup:Play()` on `PlayerFrame`; it tainted Blizzard unit-frame heal prediction during testing.
- Health events should not interrupt an active fade. One post-fade health event per combat/OOC cycle may intentionally start a fresh visible-to-faded transition to soften threshold release.
