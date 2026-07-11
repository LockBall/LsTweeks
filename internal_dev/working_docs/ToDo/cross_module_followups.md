# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [x] 1. Secret-value guard completeness and placement — audited Aura Frames, Skyriding Vigor, and Player Frame. Existing guards are boundary-local and retain safe values; intentional display-only pass-throughs do not inspect or cache secret values. Audio Volumes and Objectives have no comparable restricted API surface.
- [x] 2. Control-gate composition — audited direct control enable paths. Fixed Skyriding Vigor style synchronization so registered Node Color and Decor Color eligibility always composes with the current flight lock; remaining direct paths have only local eligibility or are covered by the disabled-module overlay.
- [ ] 3. Independent `OnUpdate` ownership — review frames whose `OnUpdate` scripts can be assigned by separate subsystems. Keep each owner on a dedicated driver frame or route them through an intentional multiplexer so one lifecycle cannot silently clear another callback.
- [ ] 4. Programmatic control-sync guards — review `_syncing` / callback-suppression guards around UI setters. They must clear on every exit path, including setter errors, so a failed synchronization cannot mute later user input.
- [ ] 5. Saved color normalization — review persisted module and profile color tables. Clamp readable RGBA components to 0–1 during normalization so manually edited, legacy, or corrupted saved values cannot reach texture or frame color APIs unchanged.
- [ ] 6. One-shot event release — review `ADDON_LOADED` and similar initialization-only event listeners. Unregister them after the module handles its own initialization unless a documented later-load dependency requires them.
- [ ] 7. Unit-scoped event registration — review player-only `UNIT_*` listeners. Use `RegisterUnitEvent(event, "player")` where the API supports it so party, raid, pet, and unrelated unit events do not trigger module work.
- [ ] 8. Hot-path cache candidates — inspect repeated DB/style/config/atlas/API resolution inside event buckets, tickers, `OnUpdate`, and render/layout loops. Propose a cache only when the owner, invalidation triggers, stale-state fallback, and regression proof are explicit; profile first when the loop cost is uncertain.
