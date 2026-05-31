# Scratchpad

## Restart Handoff: Player Frame Health Fade

Date: 2026-05-31

### User Constraints

- The health-based player frame fade decision is intended to be out-of-combat only.
- This should already be consistent with the rest of `modules/player_frame.lua`; re-check the existing code after restart.
- Do not add click-through behavior.
- The default Blizzard `PlayerFrame` should always remain clickable.
- Before editing, read `internal_docs/working_docs/proj_mem.md`.

### API / Research Notes

- Older addons commonly used:
  - `UnitHealth("player") / UnitHealthMax("player")`
  - `PlayerFrame:SetAlpha(...)`
  - Sometimes `EnableMouse(false)` when hidden
- That old health arithmetic approach is risky in Retail 12.x because Patch 12.0 introduced secret values.
- Warcraft Wiki notes combat API functions may return secret values, including `UnitHealth(unit)`.
- Tainted addon code generally cannot compare or do arithmetic on secret values.
- `Region:SetAlpha(alpha)` is documented as accepting secret arguments when tainted and adding the `Alpha` secret aspect.
- `C_CurveUtil.CreateCurve()` and `UnitHealthPercent(unit, usePredicted, curve)` were tested as a possible modern path for mapping health percent to display alpha without addon Lua inspecting the value.
- Current implementation direction: direct `UnitHealthPercent("player", true)`, hidden `StatusBar`, and default PlayerFrame healthbar read approaches failed in-game. The only working health gate so far is the curve path: pass a `C_CurveUtil` step curve to `UnitHealthPercent("player", true, curve)` and apply the result directly to `PlayerFrame:SetAlpha()`. Health events must not restart an active fade loop.
- Do not probe Blizzard health bar internals for the health gate.
- Unknown health must keep `PlayerFrame` visible.
- Since the user clarified this is OOC-only, avoid all in-combat health threshold checks and only evaluate/update health fade while not in combat.
- Do not use `PlayerFrame:Hide()`, `Show()`, `EnableMouse()`, or secure state changes for this behavior.

### Likely Implementation Direction

1. Read `internal_docs/working_docs/proj_mem.md` first.
2. Read `modules/player_frame.lua`.
3. Confirm existing fade conditions and combat guards.
4. Keep `PlayerFrame` mouse interaction untouched.
5. Only apply health-based fade state outside combat.
6. On entering combat, cancel pending fade work and restore `PlayerFrame` alpha to `1`, matching project memory.
7. On leaving combat, wait for the existing OOC delay/fade flow and recompute health state.
8. Prefer a helper that bails early when `InCombatLockdown()` is true.

### Current Curve Gate Logic

```lua
local function GetHealthGatedAlpha(target_alpha)
    if InCombatLockdown() then return 1 end

    healthAlphaCurve:SetType(Enum.LuaCurveType.Step)
    healthAlphaCurve:ClearPoints()
    healthAlphaCurve:AddPoint(0, 1)
    healthAlphaCurve:AddPoint(threshold / 100, target_alpha)
    healthAlphaCurve:AddPoint(1, target_alpha)

    local ok, alpha = pcall(UnitHealthPercent, "player", true, healthAlphaCurve)
    if ok and type(alpha) == "number" then return alpha end
    return 1
end
```

### Sources Checked

- Warcraft Wiki: Secret Values
- Warcraft Wiki: `Region:SetAlpha`
- Warcraft Wiki: `C_CurveUtil.CreateCurve`
- Warcraft Wiki: `ColorCurveObject` / `UnitHealthPercent`
- CurseForge: Player Frame Smart Hide, old pattern
- CurseForge: Fader, general conditional alpha addon

### Open Caution

- Need verify whether repo targets only Retail 12.x or supports older versions; if older support matters, guard `UnitHealthPercent` / `C_CurveUtil`.
- Need inspect existing settings/options naming before adding any new saved variable.

### 2026-05-31 Follow-up

- Rejected approach: long `HEALTH_SETTLE_DELAY` that stopped active fade, restored visible alpha, and waited for regen to settle before fading. This changed behavior too much.
- Current attempted fix: health events are only coalesced for a short update delay. They do not stop active fades. If the base fade has already reached the OOC target, exactly one health event per combat/OOC cycle can force a fresh fade from visible alpha. Important bug fixed: do not reset the one-shot flag inside the forced fade start path, or every later regen tick can pulse the frame back to full visibility.
- Post-combat delay fix: `PLAYER_REGEN_ENABLED` should not immediately call the normal combat-gated update after scheduling fade delay, because transient combat state can hit the combat block and cancel the just-created timer. Set visible alpha and let the timer call `M.update_player_frame()` after delay; only call immediately when delay is zero.
- Follow-up: post-combat refade still failed, likely because `UnitAffectingCombat("player")` remained true after `PLAYER_REGEN_ENABLED`. Player Frame fade now tracks combat from regen events and uses `InCombatLockdown()` only as a fallback. Do not reintroduce `UnitAffectingCombat` into this fade gate.
- Architecture split: `modules/player_frame/player_frame.lua` now owns settings/GUI/portrait text/event routing; `modules/player_frame/pf_fade.lua` owns the difficult OOC fade runtime and health curve gate; `modules/player_frame/pf_health_probe.lua` owns the temporary Run Health Probe diagnostic button. Keep future fade experiments in `pf_fade.lua` and health API probes in `pf_health_probe.lua`.
