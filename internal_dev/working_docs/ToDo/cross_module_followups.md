# Cross-Module Followups
Unresolved addon-wide checks discovered while closing module review findings. Add an item here when a resolved finding's cause or fix pattern can recur outside its module; remove items once verified or promoted to a durable rule in `project.md`.


## Open Items
### OBJ12-01 — Objective Tracker secret-Aura taint
- **Evidence:** WoW 12.1 combat layout reached `Blizzard_MawBuffs.ShouldShowMawBuffs()` through the Scenario Objective Tracker and failed at `GetAuraDataByIndex()` because execution was tainted by LsTweeks. The captured stack contains no Aura Frames code.
- **Risk boundary:** Objectives currently writes Blizzard Objective Tracker state through position, background opacity/layout, collapse, and direct `Update()` paths. Its custom background also stores `_lstweeks_*` overlay fields directly on Blizzard `NineSlice`. Blizzard now reads secret Aura data inside that system, so out-of-combat writes can remain unsafe when Blizzard later updates it in combat.
- **Next isolation:** Disable only the Objectives module, reload, and repeat combat entry. If the error stops, audit capabilities in this order: direct `tracker:Update()` calls; Blizzard background/Edit Mode writes; tracker position writes; collapse writes; hooks that correct Blizzard `NineSlice` anchors. Owned overlays and read-only status should be evaluated separately from Blizzard-frame mutations.
- **Do not conflate:** The managed Debuff combat-alpha transition is working and does not appear in this error stack. Keep its fix intact while isolating Objective Tracker ownership.
- **Disable correction:** Module disable now hides only owned overlay/border frames and no longer forces opacity to 100 or calls `ObjectiveTrackerFrame:Update()`. Reload after disabling to obtain a clean Blizzard-owned lifecycle; the remaining capability audit must move addon metadata off Blizzard frames before re-enabling Objectives for combat testing.
