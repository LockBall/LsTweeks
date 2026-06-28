# Objectives Verification Scratchpad
Active checklist for final Section Count and Objectives module verification.


## 1. In-Game Behavior
- [ ] **a** Toggle the Objectives module off and confirm there is no Section Count flicker, no hover count display, and no Section Count events left registered.
- [ ] **b** Toggle only Quest count off and confirm the Quests title restores once, then stays Blizzard-owned even while hovered.
- [ ] **c** Toggle only Achievement count off and confirm the Achievements title restores once, then stays Blizzard-owned even while hovered.
- [ ] **d** Reload with each useful Section Count and On Hover checkbox combination enabled and disabled.
- [ ] **e** Confirm Auto-Collapse still works independently of Section Count.
- [ ] **f** Confirm Quest and Achievement counts stay visible when enabled and On Hover is off.
- [ ] **g** Confirm Quest and Achievement counts appear only while hovering their section title bars and restore on leave when On Hover is on.
- [ ] **h** Collapse All Objectives and confirm the background stays header-sized instead of expanding to stale visible sections. If it expands, capture `/lst status` `background_anchor`.
- [ ] **i** Trigger a world-event/scenario-style objective while All Objectives is collapsed and confirm priority content force-expands All Objectives after the collapse grace window. Capture `/lst status` `background_force_expand` and `background_force_expand_grace`.
- [ ] **j** Expand All Objectives and confirm Blizzard-owned background sizing follows visible sections and popup/world-event objectives. Capture `/lst status` `background_anchor`; expected expanded value is `blizzard`.
- [ ] **k** When the expanded background reserves empty world-event space, capture `/lst status` `background_module_<n>_*` fields to identify which Blizzard module is displayable and claiming content height.
- [ ] **l** While All Objectives is collapsed, confirm ordinary section background anchors do not reopen All Objectives; `/lst status` should show `background_blocked_anchor=<anchor>` if one was corrected.
- [ ] **m** While All Objectives is collapsed, confirm a Blizzard priority/world-event background anchor force-expands All Objectives after the grace window; `/lst status` should show `background_force_expand=background:<priority module>`.


## 2. Count Correctness
- [ ] **a** Test quest count near the quest cap and confirm it never exceeds `C_QuestLog.GetMaxNumQuestsCanAccept()`.
- [ ] **b** Check campaign quests, world quests, bonus objectives, hidden/internal entries, and tasks do not inflate the quest count.
- [ ] **c** Confirm achievement count matches tracked achievements and the tracked achievement cap.


## 3. Runtime And Packaging
- [ ] **a** Confirm Section Count registers quest events only while Quest count is enabled.
- [ ] **b** Confirm Section Count registers achievement events only while Achievement count is enabled.
- [ ] **c** Check `/lst status` for expected event, hover-mode, hover, and title state.
- [ ] **d** Run package validation before calling the feature done because new Objective Lua files were added to the TOC.
- [ ] **e** Confirm Objective file load order remains `ob_defaults.lua`, feature files, then `ob_main.lua`.


## 4. Final Cleanup
- [ ] **a** Remove or archive this scratchpad before release unless intentionally keeping it out of packaging.
- [ ] **b** Run `check_fast.ps1`.
- [ ] **c** Run `check_fast.ps1 -Package`.
- [ ] **d** Run `git diff --check`.
