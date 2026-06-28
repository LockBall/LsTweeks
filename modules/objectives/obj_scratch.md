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
