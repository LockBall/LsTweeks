# Player Frame Memory
## Table of Contents
- [Settings And Defaults](#settings-and-defaults)
- [Runtime Notes](#runtime-notes)


## Settings And Defaults
Important `player_frame` keys:
- `hide_portrait_combat_text`: hides Player Frame portrait combat text.
- `fade_out_of_combat`: enables Out Of Combat (OOC) Player Frame fading.
- `fade_alpha`: target OOC alpha, default `0.5`.
- `fade_delay`: seconds to stay fully visible after combat, default `2.0`.
- `fade_length`: seconds to fade from full alpha to `fade_alpha`, default `5.0`.
- `health_visible_threshold`: health curve release point for OOC fade, default `80`. Below this point the pass-through curve keeps PlayerFrame fully visible; above it the curve eases toward the normal time-fade alpha instead of snapping.
- `health_release_speed`: 0-100 health curve tuning for how quickly visibility drops above `health_visible_threshold`, default `75`.
- `pf_defaults.lua` owns fade numeric min/max/step metadata in `M.FADE_SETTING_RANGES`; runtime clamps and GUI sliders read from that table.


## Runtime Notes
- `modules/player_frame/pf_defaults.lua` owns Player Frame defaults. `modules/player_frame/pf_gui.lua` owns the settings panel. `modules/player_frame/pf_main.lua` owns portrait combat text hiding, controller hooks, and event routing. `modules/player_frame/pf_fade.lua` owns OOC fade runtime state, combat transitions, fade timers, and the health curve gate. The old health API probe is archived at `tests_tools/player_frame_health_probe.lua` and is not loaded by the addon.
- `pf_main.lua` registers the Player Frame settings category with `module_key`, so the Settings Module Enabler leaves its sidebar button visible but greyed out/locked when disabled. Runtime side effects route through `M.update_player_frame()` / `M.set_module_enabled()` and stop at the module gate.
- Player Frame settings layout uses the shared `addon.CreateSettingsGrid()` helper from `functions/layout_grid.lua`; keep checkbox rows, fade slider columns, and per-row heights parameterized there instead of chaining row frames by hand. The OOC Fade checkbox and fade sliders share one taller grid row.
- PlayerFrame remains clickable while faded.
- Player Frame fade combat/health events are registered only while `fade_out_of_combat` is enabled. When enabling fade, refresh combat state from `InCombatLockdown()` because the module may not have been receiving regen events while disabled.
- Player Frame fade should not install its `PlayerFrame:HookScript("OnShow", ...)` hook until `fade_out_of_combat` is enabled.
- OOC fade is delay plus fade length. Combat always cancels pending fade work and restores `PlayerFrame` alpha to `1`.
- Queued OOC fade apply work must recheck the Player Frame module-enabled gate before starting a fade; `C_Timer.After(0)` cannot be cancelled after module disable.
- Combat state for Player Frame fade is owned by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` with `InCombatLockdown()` fallback. Do not use `UnitAffectingCombat("player")`; it can remain sticky after regen and block post-combat refade.
- On `PLAYER_REGEN_ENABLED`, schedule the delay and set visible alpha, but do not immediately call the combat-gated full update while the delay is active; transient combat state can cancel the new delay timer.
- Do not use `CreateAnimationGroup()` / `AnimationGroup:Play()` on `PlayerFrame`; it tainted Blizzard unit-frame heal prediction on reload. Use the module-owned `OnUpdate` fade path instead.
- Retail 12.x health APIs can return Secret Values from tainted addon paths. Player Frame health fade is strictly OOC: combat cancels fade and sets plain alpha `1`.
- In-game testing showed `UnitHealth`, `UnitHealthPercent`, `CurveConstants.ScaleTo100`, custom `UnitHealthPercent` curves, and PlayerFrame health bars all return secret current-health values OOC. The usable pattern is pass-through only: compute a normal time-based base alpha, build a `C_CurveUtil` curve where low health maps to `1` and health above the threshold eases toward the base alpha, then pass `UnitHealthPercent("player", true, curve)` directly to `PlayerFrame:SetAlpha()`.
- Health-gate API fallback is intentionally fail-visible: latest Retail is the supported target and `UnitHealthPercent` / `C_CurveUtil` are expected to exist; if the gate cannot be evaluated, keep `PlayerFrame` visible rather than applying an unsafe faded alpha.
- The health curve cache signature must include current base alpha, `health_visible_threshold`, and `health_release_speed`. Base alpha changes during the fade animation, so caching only by DB settings gives stale curve geometry.
- Do not use Lua comparisons/arithmetic/string conversion on current health or curve output. Health events should not stop or restart an active fade; after the base fade is already at target, health events only refresh the gated target alpha.
- Do not use Blizzard PlayerFrame health bar internals or hidden status bars for the health gate.
- Threshold slider changes must route through `M.fade.on_threshold_changed(db)` so the curve cache clears and already-faded alpha is reapplied without waiting for the next health event.
