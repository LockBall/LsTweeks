# Player Frame OOC Fade

Completed: 2026-05-31

## Summary

Player Frame fade behavior is split between:

- `modules/player_frame/pf_main.lua`: settings, GUI, defaults, event routing, portrait combat text hiding.
- `modules/player_frame/pf_fade.lua`: OOC fade state, combat transitions, timers, and health curve gate.

Archived development probe: `internal_dev/tests_tools/player_frame_health_probe.lua`.

## Final Behavior

- PlayerFrame remains clickable.
- Combat immediately restores full visibility.
- Out of combat, fade waits `fade_delay`, then fades toward `fade_alpha` over `fade_length`.
- Low health keeps PlayerFrame fully visible; `health_visible_threshold = 0` disables this gate.
- Above the threshold, visibility eases toward the current fade alpha instead of snapping.

Defaults: `fade_alpha=0.5`, `fade_delay=2.0`, `fade_length=5.0`, `health_visible_threshold=80`, `health_release_speed=75`.

## Durable Rules

- Retail 12.x health APIs can return Secret Values from tainted addon paths. Do not compare, stringify, or do arithmetic on current health or `UnitHealthPercent()` curve results.
- The viable health-gate pattern is pass-through only: build a `C_CurveUtil` curve, call `UnitHealthPercent("player", true, curve)`, and pass the returned alpha directly to `PlayerFrame:SetAlpha()`.
- `health_release_speed` adjusts only curve weights above the threshold; it must not inspect health in addon Lua.
- Do not use Blizzard PlayerFrame health bar internals, hidden status bars, or `CreateAnimationGroup()` on `PlayerFrame`.
- Use regen events plus `InCombatLockdown()` fallback; `UnitAffectingCombat("player")` can remain sticky.
- Health events should not restart an active fade. After the base fade reaches target alpha, health events only refresh the gated alpha.
