# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [ ] 1. Secret-value guard completeness — review WoW API values that flow into addon comparisons, arithmetic, string construction, or table keys. Guard every potentially secret value before use, not only adjacent fields from the same API result.
- [ ] 2. Independent `OnUpdate` ownership — review frames whose `OnUpdate` scripts can be assigned by separate subsystems. Keep each owner on a dedicated driver frame or route them through an intentional multiplexer so one lifecycle cannot silently clear another callback.
- [ ] 3. Programmatic control-sync guards — review `_syncing` / callback-suppression guards around UI setters. They must clear on every exit path, including setter errors, so a failed synchronization cannot mute later user input.
- [ ] 4. Saved color normalization — review persisted module and profile color tables. Clamp readable RGBA components to 0–1 during normalization so manually edited, legacy, or corrupted saved values cannot reach texture or frame color APIs unchanged.
- [ ] 5. One-shot event release — review `ADDON_LOADED` and similar initialization-only event listeners. Unregister them after the module handles its own initialization unless a documented later-load dependency requires them.
- [ ] 6. Control-gate composition — review direct `SetEnabled` / `Enable` / `Disable` paths for module controls. Each path must compose broader module, combat, or flight locks with its local eligibility rule rather than relying on a later refresh to correct state.
- [ ] 7. Unit-scoped event registration — review player-only `UNIT_*` listeners. Use `RegisterUnitEvent(event, "player")` where the API supports it so party, raid, pet, and unrelated unit events do not trigger module work.
