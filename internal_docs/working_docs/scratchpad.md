# Scratchpad

## Player Frame Fade Current State

Date: 2026-05-31

- Live files:
  - `modules/player_frame/pf_main.lua`: settings, GUI, defaults, event routing, portrait combat text hiding.
  - `modules/player_frame/pf_fade.lua`: OOC fade state, combat transitions, timers, health curve gate.
- Archived diagnostic:
  - `internal_docs/tests/player_frame_health_probe.lua` is not loaded by the addon. It can be copied back into the TOC temporarily if Retail health secret-value behavior needs to be investigated again.
- Current defaults:
  - `fade_alpha = 0.5`
  - `fade_delay = 2.0`
  - `fade_length = 5.0`
  - `health_visible_threshold = 80`
  - `health_release_speed = 50`
- PlayerFrame must always remain clickable. Do not add click-through behavior.
- Fade is OOC-only. Combat enters full visibility immediately; post-combat fade starts after the configured delay.
- Health gating uses pass-through only: build a `C_CurveUtil` curve, call `UnitHealthPercent("player", true, curve)`, and pass the returned alpha directly to `PlayerFrame:SetAlpha()`.
- Do not compare, stringify, do arithmetic on, or branch on current-health values or curve output; Retail 12.x may return Secret Values from tainted addon paths.
- Low health maps to full visibility. Above the configured threshold, `health_release_speed` tunes the eased release toward the current fade base alpha. Default `50` is the current balanced curve; lower is softer, higher is faster.
- Health events are debounced and must not interrupt or restart an active fade. After the base fade has reached its target, health events only refresh the gated target alpha and must not force a full-visible restart.
- Combat state for this module is owned by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, with `InCombatLockdown()` as fallback. Do not use `UnitAffectingCombat("player")` for the fade gate.
- Do not use `CreateAnimationGroup()` / `AnimationGroup:Play()` on `PlayerFrame`; it tainted Blizzard unit-frame heal prediction during prior testing.
