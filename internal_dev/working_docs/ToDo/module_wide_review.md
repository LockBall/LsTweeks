# Module-Wide Review Follow-Ups 2026-07-08
Patterns found while working through `objectives_review.md` that may apply to other modules. These are not claims that other modules are broken; each item is a targeted audit prompt.


## Action Items
1. Audit protected or Blizzard-owned UI mutations for combat deferral.
   - Source pattern: Objectives Auto-Collapse had direct tracker collapse/expand mutations that needed the module combat deferral path.
   - Check modules that call Blizzard frame mutation APIs, move frames, update tracker/UI state, or restore Blizzard-owned settings. Confirm either the mutation is safe in combat or it is queued through an explicit regen path.

2. Audit module disable/restore paths for complete handback to Blizzard or user state.
   - Source pattern: Objectives background opacity initially restored live manager opacity without writing through the primary Edit Mode path.
   - Check modules that change Blizzard/user settings or owned frame state while enabled. Disable should restore through the same owner/API path that applied the change, with fallback paths clearly separated.

3. Audit shared picker/session callbacks for stale cross-session state.
   - Source pattern: Objectives color reset state could leak into a later color-picker session until the shared picker exposed an open callback.
   - Check modules using shared popups or preview controls for session-scoped flags that need reset on open, accept, cancel, or reset.

4. Audit helper return-value contracts.
   - Source pattern: `get_count_settings()` returned fewer values on its disabled path than on its enabled path.
   - Check helpers with multiple returns, especially settings readers and status helpers. Disabled/nil/error paths should return the same arity and explicit false/nil semantics expected by callers.

5. Audit defaults and template tables for accidental aliasing.
   - Source pattern: Objectives copied `DEFAULT_BACKGROUND_COLOR` from defaults by reference before replacing it with a file-scope value copy.
   - Check local default/template tables that point at `M.defaults` or profile data. Mutable defaults should be copied before use unless sharing is intentional and documented.

6. Audit falsy-value handling in diagnostics and API probes.
   - Source pattern: Objectives status diagnostics used `method and method(region) or nil`, which swallowed explicit `false`.
   - Check status/debug code for Lua `and/or` fallback patterns where `false`, `0`, or an intentional `nil` true branch matters.

7. Audit redundant work on already-satisfied state.
   - Source pattern: Objectives removed relayout calls, repeated anchoring, repeated show/hide, duplicate setup calls, and unchanged overlay writes.
   - Check event handlers, sync functions, and slider/picker previews for signature/state checks before frame writes, relayout calls, allocation-heavy work, or timer scheduling.

8. Audit high-frequency event debounce buckets.
   - Source pattern: Objectives moved quest/achievement event bursts from next-frame sync to a fifth-second bucket while keeping manual/UI paths immediate.
   - Check event-heavy modules for appropriate update rates by source: user-driven UI preview, periodic combat/runtime state, and bursty Blizzard events should not all default to the same cadence.

9. Audit scratch allocations inside hot sync or hook paths.
   - Source pattern: Objectives removed a per-call scratch table from a `SetPoint` hook path and skipped diagnostic string work before unchanged syncs.
   - Check hooks, OnUpdate/ticker callbacks, scan loops, and event burst handlers for avoidable temporary tables or strings.

10. Audit duplicate ownership of setup/layout constants and helper APIs.
    - Source pattern: Objectives centralized duplicated tracker lookup and settings-page layout constants.
    - Check modules split across multiple files for repeated local helpers, repeated settings layout constants, or duplicated registration setup. Prefer one local owner and module-scoped accessors when the value is shared.

11. Audit primary-API success paths for duplicate fallback writes.
    - Source pattern: Objectives removed `ObjectiveTrackerManager:SetOpacity()` after successful Edit Mode writes.
    - Check integrations that try a primary Blizzard API and then a fallback. Fallback should run only when the primary path is unavailable or fails.


## Review Notes
- Do these one item at a time across all modules, with focused diffs and tests.
- Prefer headless tests for pure state/contract regressions.
- Use in-game checks when the result depends on Blizzard frame layering, protected UI behavior, or settings-page visual layout.
