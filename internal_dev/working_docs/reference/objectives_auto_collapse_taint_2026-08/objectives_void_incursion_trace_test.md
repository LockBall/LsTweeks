# Objectives Native Collapse Isolation Test
Archive marker: `[~]` means the step was superseded when the implementation was replaced


## Table of Contents
- [1 Purpose](#1-purpose)
- [2 Completed Auto-Collapse-On Result](#2-completed-auto-collapse-on-result)
- [3 Completed Auto-Collapse-Off Control](#3-completed-auto-collapse-off-control)
- [4 Next Single-Section Boundary Test](#4-next-single-section-boundary-test)
- [5 Agent Review](#5-agent-review)
- [6 Return To Safe Control State](#6-return-to-safe-control-state)
- [7 Evidence Files](#7-evidence-files)


## 1 Purpose
Determine whether the LsTweeks taint on Objective Tracker section collapse and height fields originates from Auto-Collapse or another Objectives feature

The completed sequence compares Auto-Collapse-on, Auto-Collapse-off, and the immediate Quests-only `securecall` boundary


## 2 Completed Auto-Collapse-On Result
- [x] **a** Complete a Void Incursion with all three Auto-Collapse settings enabled and no visible error
- [x] **b** Save the resulting trace
- [x] **c** (Agent) Confirm 54 Scenario snapshots attribute Campaign, Quests, and Achievements `isCollapsed` and `contentsHeight` to LsTweeks while parent and Scenario fields remain secure
- [x] **d** (Agent) Adjust collection so duplicate bursts coalesce and critical startup and `securecall` records print last for copy safety


## 3 Completed Auto-Collapse-Off Control
- [x] **a** Run `/reload` to load the adjusted collector
- [x] **b** Open LsTweeks Objectives settings
- [x] **c** Turn off the 3 Auto-Collapse settings: Campaign, Quests, Achievements
- [x] **d** Run `/lst obtrace clear`
- [x] **e** Run `/reload`
- [x] **f** Run `/lst obtrace mark`
- [x] **g** Complete the Void Incursion with no visible error
- [x] **h** Save the resulting trace
- [x] **i** (Agent) Confirm no `auto/securecall` occurred after the clean reload
- [x] **j** (Agent) Confirm all 75 represented Scenario events kept every inspected section, parent, and Scenario field secure


## 4 Next Single-Section Boundary Test
This test does not require another Incursion

- [x] **a** Open LsTweeks Objectives settings
- [x] **b** Turn on Quests Auto-Collapse
- [x] **c** Confirm Campaign Auto-Collapse remains off
- [x] **d** Confirm Achievements Auto-Collapse remains off
- [x] **e** Run `/lst obtrace clear`
- [x] **f** Run `/reload`
- [x] **g** Wait until the Objective Tracker finishes loading
- [x] **h** Run `/lst obtrace`
- [x] **i** Replace the contents of `objectives_native_securecall_3o_status.txt` with the complete trace output
- [x] **j** Tell the agent the boundary trace was saved
- [x] **k** Do not begin another Incursion until the agent reviews the boundary trace


## 5 Agent Review
- [x] **a** (Agent) Compare the Quests `SetCollapsed`, `isCollapsed`, `dirty`, and `contentsHeight` security labels immediately before and after `securecall`
- [x] **b** (Agent) Decide whether the native `securecall` candidate is conclusively rejected
- [x] **c** (Agent) Choose the visibility-only rollback from the boundary evidence

Result: immediately before `securecall`, all four inspected fields were secure; immediately afterward, Quests `isCollapsed` was `tainted:LsTweeks`. Earlier Scenario evidence showed the later `contentsHeight` propagation. The candidate is rejected


## 6 Return To Safe Control State
- [~] **a** Superseded — Turn off Quests Auto-Collapse
- [~] **b** Superseded — Run `/reload`
- [~] **c** Superseded — Do not enable any Auto-Collapse setting until the implementation is replaced

The implementation was replaced with visibility-only Auto-Collapse, so these temporary native-candidate controls no longer apply


## 7 Evidence Files
- Lua error: `internal_dev/working_docs/ToDo/new_issue.txt`
- Objectives trace: `objectives_native_securecall_3o_status.txt`
- Investigation history: `objectives_height_compaction_experiment.md`
