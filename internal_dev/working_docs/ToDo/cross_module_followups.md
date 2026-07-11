# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [x] 1. Secret-value guard completeness and placement — audited Aura Frames, Skyriding Vigor, and Player Frame. Existing guards are boundary-local and retain safe values; intentional display-only pass-throughs do not inspect or cache secret values. Audio Volumes and Objectives have no comparable restricted API surface.
- [x] 2. Control-gate composition — audited direct control enable paths. Fixed Skyriding Vigor style synchronization so registered Node Color and Decor Color eligibility always composes with the current flight lock; remaining direct paths have only local eligibility or are covered by the disabled-module overlay.
- [x] 3. Independent `OnUpdate` ownership — audited every direct assignment. Aura Frames owns OOC fade on addon-created aura frames, Objectives extends the Blizzard tracker through `HookScript`, and Skyriding Vigor separates progress, fade, and drag onto dedicated owners. No conflicting lifecycle remains.
- [x] 4. Programmatic control-sync guards — hardened shared checkbox and slider silent setters, Audio Volumes sound-slider synchronization, and Aura Frames rename escape cleanup. Every suppression path now clears before rethrowing a setter error or completing the canceled edit.
- [x] 5. Saved color normalization — Aura Frames now normalizes all preset/custom persisted color tables at startup and profile load; Skyriding fill colors and Objectives backgrounds clamp at their owning boundaries. Existing Audio Volumes and Player Frame color use is static or does not persist user RGBA data.
- [x] 6. One-shot event release — released the core `ADDON_LOADED` listener after LsTweeks initialization. All other initialization-only listeners already release; Objectives intentionally retains its listener for `Blizzard_ObjectiveTracker` later-load handling.
- [x] 7. Unit-scoped event registration — audited all `UNIT_*` listeners. Aura Frames, Audio Volumes, Player Frame, and Skyriding Vigor already use `RegisterUnitEvent(..., "player")` for player-only work; no broad listener remains.
- [ ] 8. Hot-path cache candidates — inspect repeated DB/style/config/atlas/API resolution inside event buckets, tickers, `OnUpdate`, and render/layout loops. Propose a cache only when the owner, invalidation triggers, stale-state fallback, and regression proof are explicit; profile first when the loop cost is uncertain.
- [ ] 9. Early work filtering — review event handlers, delayed callbacks, tickers, and render/update entry points for cheap disqualifying state. Filter unit, module-enabled, combat, visibility, unchanged-state, and feature-enabled conditions before table scans, DB/config resolution, scheduling, or frame writes; use registration-time filters where WoW supports them.
