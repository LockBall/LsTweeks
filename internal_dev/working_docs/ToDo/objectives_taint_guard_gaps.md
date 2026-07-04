# Objectives Taint Guard Gaps
Audit pass found protected ObjectiveTrackerFrame mutations reachable from settings/GUI callbacks without `InCombatLockdown()` guards, inconsistent with the guarded drag-handler path in the same module.


## Table of Contents
- [Findings](#findings)
- [Assessment](#assessment)
- [Reference Pattern](#reference-pattern)


## Findings
- `ob_position.lua:125-165` `set_objective_center_position`/`apply_objective_position`/`restore_objective_position` call `tracker:ClearAllPoints()`/`tracker:SetPoint()` directly with no `InCombatLockdown()` check
- Reachable unguarded via `set_objective_position()` (line 312, position slider callback) and `reset_objective_position()` (line 319, reset button `on_click` at line 402)
- Contrast: `ob_position.lua:240` drag `OnDragStart` correctly guards with `if not is_objective_move_mode_enabled() or InCombatLockdown() then return end`
- `ob_background.lua:882` `M.restore_background` and `ob_background.lua:961` `set_customize_background` call `tracker:Update()` directly with no combat guard
- `restore_background` reachable via module-disable path (`ob_main.lua` `M.set_module_enabled(false)`); `set_customize_background` is the checkbox `OnClick`/`OnValueChanged` at line 1044
- Risk: moving the position slider, clicking reset-position, or toggling the background checkbox mid-combat directly mutates the protected `ObjectiveTrackerFrame`, matching this project's known taint-risk pattern (see `feedback_wow_taint.md`)
- Not yet re-checked: remaining `get_objective_tracker()` call sites in both files for the same omission (18 total call sites found during audit, only 2 confirmed unguarded)


## Assessment
- Confirmed actionable on 2026-07-03: protected Objective Tracker position/background mutations were reachable from settings callbacks during combat.
- Fixed by deferring Objectives protected frame work through `M.defer_objectives_combat_update()` and replaying the current saved state on `PLAYER_REGEN_ENABLED`.
- Covered paths include position apply/restore, move-mode tracker changes, background color/opacity writes, background anchor correction, border sync, and direct tracker `Update()` calls.
- Remaining expected behavior: changing these settings during combat saves the DB/control value immediately, but the visible tracker update waits until combat ends.


## Reference Pattern
`af_logic_native_visibility.lua` (aura_frames) already does this correctly: gates all `Show()`/`UpdateSystemSettingValue` calls behind `InCombatLockdown()` and avoids `Hide()` on live secure frames. Use as the template when adding guards here.
