# Native Aura Tooltip Audit Follow-ups

Temporary findings from the 2026-08-14 unstaged-change audit. Resolve these separately from the disabled Aura Frames settings error.


## Resolved
- Default-state intent: keep the native experiment default-off until the fresh-reload controlled validation required by `functions/tooltip.md` clears the incident-history risk.
- Toggle-off ownership: `SetNativeAuraTooltipTestEnabled(false)` hides only a matching tooltip and clears `native_aura_tooltip_owner` unconditionally.
- Regression coverage: shared and Aura Frames suites verify matching-tooltip hide behavior and reject stale tracked-owner behavior.


## Pending
- Error inbox cleanup: archive and clear `ToDo/new_issue.txt` after the active disabled-module incident is resolved.


## Validation Already Completed
- 2026-08-15 fixes: `tooltip`, `af_ranges`, and `af_managed` passed (59 tests) after the stale-owner and combat-tooltip regressions failed before their code changes.
- Impact-selected headless suites passed: `af_color_sync`, `af_ranges`, `smoke_load_all`, and `tooltip` (64 tests total).
- Fast syntax, region, memory-section, whitespace, and line-ending checks passed.
- Changed-file LuaLS/Ketho validation reported no diagnostics.
- Extended in-game testing remains necessary to assess Blizzard tooltip taint propagation.
