# Cross-Module Followups
Unresolved addon-wide checks discovered while closing module review findings. Add an item here when a resolved finding's cause or fix pattern can recur outside its module; remove items once verified or promoted to a durable rule in `project.md`.


## Open Items
### OBJ12-01 — Objective Tracker secret-Aura taint
- **Evidence:** WoW 12.1 combat layout reached `Blizzard_MawBuffs.ShouldShowMawBuffs()` through the Scenario Objective Tracker and failed at `GetAuraDataByIndex()` because execution was tainted by LsTweeks. The captured stack contains no Aura Frames code.
- **Risk boundary:** Objectives still uses supported-looking Blizzard Objective Tracker position, opacity/layout, and collapse paths. Blizzard now reads secret Aura data inside that system, so expand this audit only when live evidence identifies another unsafe write.
- **Next isolation:** Disable only the Objectives module, reload, and repeat combat entry. If the error stops, audit capabilities in this order: direct `tracker:Update()` calls; Blizzard background/Edit Mode writes; tracker position writes; collapse writes; hooks that correct Blizzard `NineSlice` anchors. Owned overlays and read-only status should be evaluated separately from Blizzard-frame mutations.
- **Do not conflate:** The managed Debuff combat-alpha transition is working and does not appear in this error stack. Keep its fix intact while isolating Objective Tracker ownership.
- **Corrections awaiting reload validation:** Overlay state moved from Blizzard `NineSlice` fields into an addon-owned weak table. Module disable and background toggles no longer call `ObjectiveTrackerFrame:Update()`; disable also does not force opacity to 100. Current live evidence reports no repeat error since the prior reload, so preserve the remaining working capabilities until another error provides a narrower target.
