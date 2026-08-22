# Cross-Module Followups
Unresolved addon-wide checks discovered while closing module review findings. Add an item here when a resolved finding's cause or fix pattern can recur outside its module; remove items once verified or promoted to a durable rule in `project.md`.


## Open Items
### OBJ12-01 — Objective Tracker secret-Aura taint
- **Evidence:** WoW 12.1 combat layout reached `Blizzard_MawBuffs.ShouldShowMawBuffs()` through the Scenario Objective Tracker and failed at `GetAuraDataByIndex()` because execution was tainted by LsTweeks. The captured stack contains no Aura Frames code.
- **Recurrence:** Recurred twice with the identical Blizzard-only stack: 2026-08-15 (before any fix) and 2026-08-17 after a Void Incursion boss died, following a fix that removed only parent-level `ObjectiveTrackerFrame:SetCollapsed()` and kept section-level `SetCollapsed()` on Campaign/Quests/Achievements as believed-safe. Root cause confirmed by source read: any `SetCollapsed()`/`MarkDirty()` call on any tracker (parent or section) taints the single shared `ObjectiveTrackerFrame` container's next `Update()` pass, which walks every Blizzard module including Scenario, whose `LayoutContents()` unconditionally calls `ShouldShowMawBuffs()`. Section-level calls only defer the taint to a later dirty pass instead of triggering it synchronously, so it surfaced far more rarely and looked fixed.
- **Current candidate (2026-08-22, pending repeated in-game validation):** the visibility-only fix avoided taint but failed layout budgeting. An isolated deferred `securecall(tracker.SetCollapsed, tracker, collapsed)` experiment released the correct space and passed world-map tooltip plus Void Incursion boss/Scenario updates without relevant taint evidence. Normal Campaign, Quests, and Achievements Auto-Collapse now uses that candidate; the prior visibility implementation is backed up under `internal_dev/working_docs/ToDo/backups/`.
- **Risk boundary:** never collapse the parent `ObjectiveTrackerFrame`, never override `GetContentsHeight`, write `contentsHeight`, or call the shared container update directly. Section `SetCollapsed` is permitted only through the centralized deferred `securecall` helper while this candidate is validated; any recurrence immediately rejects it and restores the backup.
- **Do not conflate:** The managed Debuff combat-alpha transition is working and does not appear in this error stack. Keep its fix intact while isolating Objective Tracker ownership.


### CHAT-01 — Formatted chat export module
- **Goal:** Build an LsTweeks chat copy/export module with a distinct user-facing name instead of depending on the current third-party chat copy/paste addon.
- **UX:** Preserve intentional line breaks, offer readable formatting controls, and expose selected output through an addon-owned text box for manual Ctrl+C.
- **Safety boundary:** Never call restricted `CopyToClipboard` from addon code; Retail blocks it as a Blizzard-UI-only action.
- **Current decision:** Deferred. Continue using the existing chat copy/paste addon and tolerate its formatting limitations until this module is intentionally designed and authorized.
