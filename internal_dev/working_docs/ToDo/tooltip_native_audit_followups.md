# Native Aura Tooltip Audit Follow-ups

Temporary findings from the 2026-08-14 unstaged-change audit. Resolve these separately from the disabled Aura Frames settings error.


## Findings
- Default-state intent: `functions/tooltip.lua` initializes `native_aura_tooltip_test_enabled` to `false`, so every reload disables the native experiment. Decide whether prolonged in-game testing now warrants default-on behavior.
- Toggle-off ownership: `SetNativeAuraTooltipTestEnabled(false)` clears `native_aura_tooltip_owner` only while global `GameTooltip` is still owned by that Aura frame. Clear the internal owner unconditionally after optionally hiding the matching tooltip.
- Regression assertion: the experimental Aura hover test disables the experiment and then asserts that `GameTooltip` remains owned by the icon. Replace this with assertions that toggle-off hides the matching tooltip and leaves no stale tracked owner behavior.
- Error inbox cleanup: archive and clear `ToDo/new_issue.txt` after the active disabled-module incident is resolved.


## Validation Already Completed
- Impact-selected headless suites passed: `af_color_sync`, `af_ranges`, `smoke_load_all`, and `tooltip` (64 tests total).
- Fast syntax, region, memory-section, whitespace, and line-ending checks passed.
- Changed-file LuaLS/Ketho validation reported no diagnostics.
- Extended in-game testing remains necessary to assess Blizzard tooltip taint propagation.
