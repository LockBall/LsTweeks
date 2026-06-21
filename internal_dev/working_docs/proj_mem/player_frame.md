# Player Frame Memory

Important `player_frame` keys:
- `hide_portrait_combat_text`: hides Player Frame portrait combat text.

- `fade_out_of_combat`: enables Out Of Combat (OOC) Player Frame fading.

- `fade_alpha`: target OOC alpha, default `0.5`.

- `fade_delay`: seconds to stay fully visible after combat, default `2.0`.

- `fade_length`: seconds to fade from full alpha to `fade_alpha`, default `5.0`.

- `health_visible_threshold`: health curve release point for OOC fade, default `80`. Below this point the pass-through curve keeps PlayerFrame fully visible; above it the curve eases toward the normal time-fade alpha instead of snapping.

- `health_release_speed`: 0-100 health curve tuning for how quickly visibility drops above `health_visible_threshold`, default `75`.


## Runtime Notes
- `modules/player_frame/pf_main.lua` owns Player Frame settings, GUI, portrait combat text hiding, and event routing. `modules/player_frame/pf_fade.lua` owns OOC fade runtime state, combat transitions, fade timers, and the health curve gate. The old health API probe is archived at `internal_dev/tests_tools/player_frame_health_probe.lua` and is not loaded by the addon.

- `pf_main.lua` registers the Player Frame settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Runtime side effects route through `M.update_player_frame()` / `M.set_module_enabled()` and stop at the module gate.

- Player Frame fade combat/health events are registered only while `fade_out_of_combat` is enabled. When enabling fade, refresh combat state from `InCombatLockdown()` because the module may not have been receiving regen events while disabled.

- Player Frame fade should not install its `PlayerFrame:HookScript("OnShow", ...)` hook until `fade_out_of_combat` is enabled.

- OOC fade is delay plus fade length. Combat always cancels pending fade work and restores `PlayerFrame` alpha to `1`.

- Combat state for Player Frame fade is owned by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` with `InCombatLockdown()` fallback. Do not use `UnitAffectingCombat("player")`; it can remain sticky after regen and block post-combat refade.

- On `PLAYER_REGEN_ENABLED`, schedule the delay and set visible alpha, but do not immediately call the combat-gated full update while the delay is active; transient combat state can cancel the new delay timer.

- Do not use `CreateAnimationGroup()` / `AnimationGroup:Play()` on `PlayerFrame`; it tainted Blizzard unit-frame heal prediction on reload. Use the module-owned `OnUpdate` fade path instead.

- Retail 12.x health APIs can return Secret Values from tainted addon paths. Player Frame health fade is strictly OOC: combat cancels fade and sets plain alpha `1`.

- In-game testing showed `UnitHealth`, `UnitHealthPercent`, `CurveConstants.ScaleTo100`, custom `UnitHealthPercent` curves, and PlayerFrame health bars all return secret current-health values OOC. The usable pattern is pass-through only: compute a normal time-based base alpha, build a `C_CurveUtil` curve where low health maps to `1` and health above the threshold eases toward the base alpha, then pass `UnitHealthPercent("player", true, curve)` directly to `PlayerFrame:SetAlpha()`.

- The health curve cache signature must include current base alpha, `health_visible_threshold`, and `health_release_speed`. Base alpha changes during the fade animation, so caching only by DB settings gives stale curve geometry.

- Do not use Lua comparisons/arithmetic/string conversion on current health or curve output. Health events should not stop or restart an active fade; after the base fade is already at target, health events only refresh the gated target alpha.

- Threshold slider changes must route through `M.fade.on_threshold_changed(db)` so the curve cache clears and already-faded alpha is reapplied without waiting for the next health event.

