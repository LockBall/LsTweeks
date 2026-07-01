# GUI Factory Followups
## Scope
- Track module-by-module cleanup work after shared control factories gain container-level APIs.
- These are follow-up refactors, not current behavior blockers.

## Current State
- `addon.CreateSliderWithBox()` now exposes a container-level API: `GetValue()`, `SetValue(value)`, `SetValueSilently(value)`, and `HookValueChanged(fn[, opts])`.
- Slider callers in modules have already been moved away from direct `.slider:SetValue()`, `.slider:GetValue()`, and `.slider:HookScript("OnValueChanged")` use where they are using the shared factory.
- `addon.CreateCheckbox()` now exposes a container-level API while preserving its existing return shape: `container, checkbox, label`.
- Checkbox container API: `GetChecked()`, `SetChecked(value)`, `SetCheckedSilently(value)`, `SetEnabled(value)`, `Enable()`, `Disable()`, and `HookCheckedChanged(fn[, opts])`.
- Several stored/sync paths already use checkbox containers and `SetCheckedSilently()`: Settings, Player Frame, Objectives Background/Auto-Collapse/Section Count, Sound Levels, Skyriding Vigor, and parts of Aura Frames.
- Raw checkbox and label returns are still valid when code needs direct template/layout/tooltip handling. Routine state storage in module control tables should prefer the container.
- This note exists because the checkbox cleanup is broader and noisier than the Sound Levels review. Finish it module by module instead of mixing every raw checkbox call into one large diff.

## Why This Matters
- Programmatic GUI sync should not accidentally fire user callbacks.
- Factory users should not need to know which raw child frame owns state, callback wiring, or enabled state.
- Consistent container APIs make reset, profile reload, and dependency toggles easier to audit.

## Fresh Session Search Commands
- Raw checkbox state search:
  `rg -n "CreateCheckbox\\(|SetChecked\\(|GetChecked\\(|SetCheckedSilently|HookCheckedChanged|:Enable\\(\\)|:Disable\\(\\)" modules functions`

- Stored control search:
  `rg -n "M\\.controls|controls\\[|CreateCheckbox\\(" modules`

- Slider regression search:
  `rg -n -F ".slider:SetValue(" modules functions core`

- Slider getter regression search:
  `rg -n -F ".slider:GetValue(" modules functions core`

- Hooking regression search:
  `rg -n "HookValueChanged|HookScript" modules functions core`

## Likely Remaining Checkbox Areas
- `modules/aura_frames/af_gui_frame_builders.lua` still has the highest chance of intentional and accidental raw checkbox usage because it creates many local checkboxes inside builder helpers. Recheck areas around source controls, timer swipe dependency handling, hide/move dependencies, and Blizzard aura toggles.
- `modules/aura_frames/af_gui_tree.lua` has a Show Grid checkbox. Verify whether it is only local layout behavior or should be stored/synced through the container.
- `modules/skyriding_vigor/sv_gui.lua` has generic enable/disable helpers that intentionally support mixed controls, not just checkbox containers. Do not blindly remove raw `Enable()`/`Disable()` support there.
- `functions/module_reset.lua` still receives the raw preserve checkbox from `CreateCheckbox()`, but current state reading should go through the preserve container. This is acceptable unless a later pass finds direct state sync on the raw checkbox.
- Any `CreateCheckbox()` destructuring into `container, checkbox, label` can be fine. The review target is routine state calls and stored control references, not every local raw variable.

## Completion Criteria
- Module control tables store checkbox containers for routine checkbox controls.
- Reset/profile/reload/sync paths use `SetCheckedSilently()` for programmatic state updates.
- User-driven state changes still go through the callback passed to `CreateCheckbox()` or `HookCheckedChanged()`.
- Remaining raw `SetChecked()`, `GetChecked()`, `Enable()`, and `Disable()` calls are either non-checkbox controls, local template-specific behavior, or explicitly justified by surrounding code.
- Run fast validation after each module pass:
  `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`

## Checklist
1. [ ] Checkbox factory migration: modules should store the `CreateCheckbox()` container for routine control state and use `GetChecked()`, `SetChecked()`, `SetCheckedSilently()`, `SetEnabled()`, `Enable()`, `Disable()`, and `HookCheckedChanged()` instead of raw `CheckButton` methods. Keep raw checkbox/label returns only for specialized layout, tooltip, or template behavior.

2. [ ] Finish the checkbox migration module by module to keep diffs reviewable. Likely remaining areas include Aura Frames source/frame builder helpers, Objectives Auto-Collapse/Section Count, and any module-local controls that still store raw checkboxes in `M.controls`.

3. [ ] After each module pass, run fast validation and search that module for raw checkbox state calls such as `SetChecked`, `GetChecked`, `Enable`, and `Disable` to confirm only intentional non-factory uses remain.
