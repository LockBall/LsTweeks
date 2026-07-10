# Module-Wide Review Follow-Ups 2026-07-08
Patterns found while working through `objectives_review.md` that may apply to other modules. These are not claims that other modules are broken; each item is a targeted audit prompt.


## Action Items
- [x] 1. Audit direct protected tracker mutations for combat deferral.
   - Source pattern: Objectives Auto-Collapse had direct tracker collapse/expand mutations that needed the module combat deferral path.
   - Check calls such as `SetCollapsed`, `ForceExpand`, tracker `Update`, and other state-changing Blizzard tracker methods. Confirm either the mutation is safe in combat or it is queued through an explicit regen path.

- [x] 2. Audit protected frame positioning and layout mutations for combat deferral.
   - Source pattern: Objectives background and position behavior defer tracker anchor correction and move-mode changes through the module combat path.
   - Check `SetPoint`, `ClearAllPoints`, drag/move-mode changes, frame sizing, and layout refreshes only where the target frame can be protected.

- [x] 3. Audit deferred combat callbacks for a second combat check.
   - Source pattern: Objectives queued collapse work rechecks combat when the timer fires before mutating the tracker.
   - Check callbacks queued before combat that can run after combat begins. Re-defer instead of mutating UI while combat remains active.

- [x] 4. Audit module disable/restore paths for complete handback to Blizzard or user state.
   - Source pattern: Objectives background opacity initially restored live manager opacity without writing through the primary Edit Mode path.
   - Check modules that change Blizzard/user settings or owned frame state while enabled. Disable should restore through the same owner/API path that applied the change, with fallback paths clearly separated.

- [x] 5. Audit primary-API success paths for duplicate fallback writes.
   - Source pattern: Objectives removed `ObjectiveTrackerManager:SetOpacity()` after successful Edit Mode writes.
   - Check integrations that try a primary Blizzard API and then a fallback. Fallback should run only when the primary path is unavailable or fails.

- [x] 6. Audit defaults and template tables for accidental aliasing.
   - Source pattern: Objectives copied `DEFAULT_BACKGROUND_COLOR` from defaults by reference before replacing it with a file-scope value copy.
   - Check local default/template tables that point at `M.defaults` or profile data. Mutable defaults should be copied before use unless sharing is intentional and documented.
   - Completed: reviewed Objectives, Aura Frames, Audio Volumes, Player Frame, Skyriding Vigor, Settings, shared UI helpers, and profile/reset code. Nested defaults are copied by `apply_defaults()`/`deep_copy_into()`; mutable Audio GUI defaults are fresh local tables; Aura custom entries copy nested template values; and Skyriding style-color defaults return value copies.

- [x] 7. Audit helper return-value contracts.
   - Source pattern: `get_count_settings()` returned fewer values on its disabled path than on its enabled path.
   - Check helpers with multiple returns, especially settings readers and status helpers. Disabled/nil/error paths should return the same arity and explicit false/nil semantics expected by callers.
   - Completed: reviewed multi-value helpers across Objectives, Aura Frames, Audio Volumes, Player Frame, Skyriding Vigor, and shared UI helpers. Skyriding charge detection now returns four explicit `nil` values when unavailable; the decor axis mapper now returns two explicit `nil` values for an invalid axis.

- [x] 8. Audit shared picker/session callbacks for stale cross-session state.
   - Source pattern: Objectives color reset state could leak into a later color-picker session until the shared picker exposed an open callback.
   - Check modules using shared popups or preview controls for session-scoped flags that need reset on open, accept, cancel, or reset.
   - Completed: reviewed shared color picker, dropdown, module-reset, sliders, Aura Frames dialogs/previews, Audio Volumes previews, and Skyriding test state. Fixed the shared color picker so its live callbacks clear on cancel or popup hide; its session identity prevents a closing older popup from clearing a newer session.

- [x] 9. Audit redundant work on already-satisfied state.
   - Source pattern: Objectives removed relayout calls, repeated anchoring, repeated show/hide, duplicate setup calls, and unchanged overlay writes.
   - Check event handlers, sync functions, and slider/picker previews for signature/state checks before frame writes, relayout calls, allocation-heavy work, or timer scheduling.
   - Completed: reviewed Objectives, Aura Frames, Audio Volumes, Player Frame, Skyriding Vigor, and shared controls. Existing state/signature guards cover repeated frame writes, preview timers, fades, and layout. Aura Frames now clears its custom and sorted scan caches only once while a unified scan is pending.

- [ ] 10. Audit high-frequency event debounce buckets.
   - Source pattern: Objectives moved quest/achievement event bursts from next-frame sync to a fifth-second bucket while keeping manual/UI paths immediate.
   - Check event-heavy modules for appropriate update rates by source: user-driven UI preview, periodic combat/runtime state, and bursty Blizzard events should not all default to the same cadence.

- [ ] 11. Audit scratch allocations inside hot sync or hook paths.
   - Source pattern: Objectives removed a per-call scratch table from a `SetPoint` hook path and skipped diagnostic string work before unchanged syncs.
   - Check hooks, OnUpdate/ticker callbacks, scan loops, and event burst handlers for avoidable temporary tables or strings.

- [ ] 12. Audit duplicate ownership of setup/layout constants and helper APIs.
    - Source pattern: Objectives centralized duplicated tracker lookup and settings-page layout constants.
    - Check modules split across multiple files for repeated local helpers, repeated settings layout constants, or duplicated registration setup. Prefer one local owner and module-scoped accessors when the value is shared.

- [ ] 13. Audit falsy-value handling in diagnostics and API probes.
    - Source pattern: Objectives status diagnostics used `method and method(region) or nil`, which swallowed explicit `false`.
    - Check status/debug code for Lua `and/or` fallback patterns where `false`, `0`, or an intentional `nil` true branch matters.


## Review Notes
- Do these one item at a time across all modules, with focused diffs and tests.
- Prefer headless tests for pure state/contract regressions.
- Use in-game checks when the result depends on Blizzard frame layering, protected UI behavior, or settings-page visual layout.
