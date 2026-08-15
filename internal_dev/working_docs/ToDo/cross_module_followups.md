# Cross-Module Followups
Unresolved addon-wide checks discovered while closing module review findings. Add an item here when a resolved finding's cause or fix pattern can recur outside its module; remove items once verified or promoted to a durable rule in `project.md`.


## Open Items
### OBJ12-01 — Objective Tracker secret-Aura taint
- **Evidence:** WoW 12.1 combat layout reached `Blizzard_MawBuffs.ShouldShowMawBuffs()` through the Scenario Objective Tracker and failed at `GetAuraDataByIndex()` because execution was tainted by LsTweeks. The captured stack contains no Aura Frames code.
- **Recurrence:** The identical Blizzard-only stack recurred immediately after a Void Incursion boss died on 2026-08-15, after the overlay-state and priority-layout corrections. This rules out those corrections as a complete fix.
- **Risk boundary:** Objectives still uses supported-looking Blizzard Objective Tracker position, opacity/layout, and collapse paths. Blizzard now reads secret Aura data inside that system, so expand this audit only when live evidence identifies another unsafe write.
- **Next isolation:** Reload with the lazy Move Mode correction and repeat the boss/combat-exit case. If the error recurs, disable only the Objectives module, reload, and repeat; then audit remaining capabilities in this order: Blizzard background/Edit Mode writes; collapse writes; secure hooks that observe tracker and `NineSlice` changes. Owned overlays and read-only status should be evaluated separately from Blizzard-frame mutations.
- **Do not conflate:** The managed Debuff combat-alpha transition is working and does not appear in this error stack. Keep its fix intact while isolating Objective Tracker ownership.
- **Corrections awaiting reload validation:** Overlay state lives in an addon-owned weak table. Module disable and background toggles do not call `ObjectiveTrackerFrame:Update()`; disable does not force opacity to 100. Disabled Move Mode no longer installs `OnDragStart`/`OnUpdate`/`OnDragStop`, changes movability, registers drag input, or changes mouse state merely because the Objectives module is enabled.
