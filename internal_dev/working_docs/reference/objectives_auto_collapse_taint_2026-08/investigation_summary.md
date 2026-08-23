# Objectives Auto-Collapse Taint Investigation
## Table of Contents
- [Scope](#scope)
- [Evidence](#evidence)
- [Result](#result)
- [Fallbacks](#fallbacks)
- [Reusable Test Pattern](#reusable-test-pattern)


## Scope
This folder preserves the August 2026 investigation into compact per-section Auto-Collapse for Blizzard's Retail Objective Tracker. The target was Campaign, Quests, and Achievements without contaminating the shared Scenario and Maw Buffs layout path.


## Evidence
- `objectives_height_compaction_experiment.md`: full hypothesis ledger, addon survey, incremental experiments, live observations, and rejected alternatives
- `objectives_void_incursion_trace_test.md`: controlled Auto-Collapse-on, Auto-Collapse-off, and Quests-only boundary sequence
- `objectives_native_securecall_3o_status.txt`: saved immediate boundary trace
- `ob_auto_collapse_visibility_2026-08-22.lua.txt`: exact pre-conversion visibility-only fallback
- `ob_auto_collapse_securecall_rejected.lua.txt`: exact rejected production candidate before rollback
- `ob_trace_diagnostic.lua.txt`: archived persistent in-game collector
- `test_ob_trace_diagnostic.lua.txt`: archived collector coverage
- `test_ob_auto_collapse_securecall_rejected.lua.txt`: archived rejected-path coverage
- `objectives_visibility_oneshot_security.txt`: destination for the post-rollback no-reload field-security snapshot
- `../../../ToDo/error_batches/2026-08-17_185132_void-incursion-maw-buffs-secret-aura-taint/`: preserved recurrence error export
- `../../../ToDo/new_issue.txt`: most recent user-saved issue buffer at closeout; this shared buffer may later be reused and is not canonical evidence
- The live collector, slash command, Scenario-only event subscriptions, and collector-only headless suite were removed after archival


## Result
- Direct section `SetCollapsed()` reached Blizzard's shared dirty/layout path and later produced secret-Aura taint
- Next-frame and combat deferral did not change that security boundary
- Direct-function `securecall(tracker.SetCollapsed, tracker, collapsed)` produced correct native layout but changed Quests `isCollapsed` from secure to `tainted:LsTweeks` immediately
- A matching no-`securecall` control kept every inspected section, parent, and Scenario field secure across 75 represented Scenario events
- Later shared layout propagated the tainted section state into `contentsHeight`; one recurrence stopped Objective Tracker progress until `/reload`
- The installed QuestLogCollapse addon reduces exposure with disabled defaults, blacklists, and timing gates but does not provide a distinct safe collapse primitive
- A 2026-08-23 no-reload snapshot after normal gameplay with the visibility-only fallback reported secure `isCollapsed` and `contentsHeight` fields for Campaign, Quests, Achievements, the parent Objective Tracker, and Scenario


## Fallbacks
- Strongest safety fallback: remove programmatic section collapse and leave collapse state entirely Blizzard/user-owned
- Tested non-native fallback: restore the design preserved in `ob_auto_collapse_visibility_2026-08-22.lua.txt`; it avoids the rejected `SetCollapsed` path but does not release Blizzard's layout budget, can leave empty section space, and can delay later sections such as Achievements
- Neither fallback supplies compact automatic native collapse; that feature remains unresolved


## Reusable Test Pattern
1. Capture field security immediately before and after one reversible mutation
2. Compare the enabled run with a clean reload control that leaves adjacent module behavior enabled
3. Exercise the delayed high-risk consumer rather than accepting visual success
4. Preserve both clean and failing runs; intermittent clean cycles do not disprove delayed contamination
5. Reject only the exact API, caller, timing, argument, and target combination demonstrated by the evidence
