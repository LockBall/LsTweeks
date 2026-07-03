# GUI Factory Followups
## Scope
- Track module-by-module cleanup work after shared control factories gain container-level APIs.
- These are follow-up refactors, not current behavior blockers.

## Current State
- `addon.CreateSliderWithBox()` now exposes a container-level API: `GetValue()`, `SetValue(value)`, `SetValueSilently(value)`, and `HookValueChanged(fn[, opts])`.
- Slider callers in modules have already been moved away from direct `.slider:SetValue()`, `.slider:GetValue()`, and `.slider:HookScript("OnValueChanged")` use where they are using the shared factory.
- `addon.CreateCheckbox()` now exposes a container-level API while preserving its existing return shape: `container, checkbox, label`.
- Checkbox container API: `GetChecked()`, `SetChecked(value)`, `SetCheckedSilently(value)`, `SetEnabled(value)`, `Enable()`, `Disable()`, and `HookCheckedChanged(fn[, opts])`.
- Several stored/sync paths already use checkbox containers and `SetCheckedSilently()`: Settings, Player Frame, Objectives Background/Auto-Collapse/Section Count, Audio Volumes, Skyriding Vigor, and parts of Aura Frames.
- Aura Frames tree Show Grid sync now stores the `CreateCheckbox()` container in `M.controls.show_grid_checkbox`.
- Raw checkbox and label returns are still valid when code needs direct template/layout/tooltip handling. Routine state storage in module control tables should prefer the container.
- This note exists because the checkbox cleanup is broader and noisier than the Audio Volumes review. Finish it module by module instead of mixing every raw checkbox call into one large diff.

## Why This Matters
- Programmatic GUI sync should not accidentally fire user callbacks.
- Factory users should not need to know which raw child frame owns state, callback wiring, or enabled state.
- Consistent container APIs make reset, profile reload, and dependency toggles easier to audit.

## Action Items
1. [x] Review Aura Frames frame builders.
- Target: `modules/aura_frames/af_gui_frame_builders.lua`.
- Focus: source controls, timer swipe dependency handling, hide/move dependencies, Blizzard aura toggles, and any checkbox stored in `M.controls`.
- Action: store `CreateCheckbox()` containers for routine state/sync paths; keep raw checkbox/label returns only for layout, tooltip, or template-specific handling.
- Result: no stored raw CheckButtons found; removed unused raw checkbox locals for Blizzard frame toggles, section outlines, and timer swipe refresh gating. Remaining raw returns are local layout/callback values or container-return helpers.

2. [x] Audit module control-table storage.
- Target: repo-wide storage search, not a deep manual review of every module.
- Search: `rg -n "M\\.controls|controls\\[|CreateCheckbox\\(" modules`.
- Action: inspect only hits where a `CreateCheckbox()` result is stored and later synced/reset/profile-reloaded. Skip local-only checkboxes and modules that already store containers.
- Result: no stored raw CheckButtons found. Settings, Player Frame, Objectives, Audio Volumes, Skyriding Vigor, and Aura Frames store the container return for routine checkbox controls; repo-wide direct assignment search only matched container-named variables.

3. Confirm intentional mixed-control enable/disable helpers.
- Target: `modules/skyriding_vigor/sv_gui.lua`.
- Focus: generic helpers that call `Enable()` / `Disable()` on mixed control types.
- Action: do a targeted check only if item 2 finds suspicious Skyriding Vigor storage. Leave generic helpers alone unless a call site is specifically a stored raw checkbox that should be a container.
- Done check: any remaining raw-looking `Enable()` / `Disable()` use is intentional mixed-control behavior, not checkbox sync leakage.

4. Check module reset preserve handling.
- Target: `functions/module_reset.lua`.
- Focus: preserve checkbox state reads and any future sync path.
- Action: keep raw preserve checkbox use only for direct template/layout needs; state reads should go through the preserve container.
- Done check: preserve state is read through `preserve_container:GetChecked()` and no routine sync depends on the raw checkbox.

5. Run the verification pass after each module cleanup.
- Searches:
  `rg -n "CreateCheckbox\\(|SetChecked\\(|GetChecked\\(|SetCheckedSilently|HookCheckedChanged|:Enable\\(\\)|:Disable\\(\\)" <module-or-file>`
  `rg -n "M\\.controls|controls\\[|CreateCheckbox\\(" modules`
  `rg -n -F ".slider:SetValue(" modules functions core`
  `rg -n -F ".slider:GetValue(" modules functions core`
- Validation:
  `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`
- Done check: fast validation passes and remaining raw checkbox state calls are non-checkbox controls, local template-specific behavior, or explicitly justified by surrounding code.
