# Objectives Verification Scratchpad
Active checklist for final Section Count and Objectives module verification.


## 1. In-Game Behavior
- [ ] **a** Toggle the Objectives module off and confirm there is no Section Count flicker, no hover count display, and no Section Count events left registered.
- [ ] **b** Toggle only Quest count off and confirm the Quests title restores once, then stays Blizzard-owned even while hovered.
- [ ] **c** Reload with each useful Quest Section Count and On Hover checkbox combination enabled and disabled.
- [ ] **d** Confirm Auto-Collapse still works independently of Section Count.
- [ ] **e** Confirm Quest count stays visible when enabled and On Hover is off.
- [ ] **f** Confirm Quest count appears only while hovering the Quests section title bar and restores on leave when On Hover is on.
- [ ] **g** Change the Background color picker and confirm the All Objectives background tint/alpha updates immediately.
- [ ] **h** Reset the Background color picker and confirm Blizzard's normal background color is restored.
- [ ] **i** Toggle the Objectives module off and confirm the background color restores to Blizzard's normal color.
- [ ] **j** After choosing a non-default Background color, capture `/lst status objectives` `bg_color_state` and `bg_region_<n>_*` fields so the real NineSlice pieces can be identified before RGB tint work continues.
- [ ] **k** Collapse All Objectives and confirm the background stays header-sized instead of expanding to stale visible sections. If it expands, capture `/lst status objectives` `bg_anchor`.
- [ ] **l** Trigger a world-event/scenario-style objective while All Objectives is collapsed and confirm priority content force-expands All Objectives after the collapse grace window. Capture `/lst status objectives` `bg_force_expand` and `bg_force_expand_grace`.
- [ ] **m** Expand All Objectives and confirm Blizzard-owned background sizing follows visible sections and popup/world-event objectives. Capture `/lst status objectives` `bg_anchor`; expected expanded value is `blizzard`.
- [ ] **n** When the expanded background reserves empty world-event space, capture `/lst status objectives` `bg_module_<n>_*` fields to identify which Blizzard module is displayable and claiming content height.
- [ ] **o** While All Objectives is collapsed, confirm ordinary section background anchors do not reopen All Objectives; `/lst status objectives` should show `bg_blocked_anchor=<anchor>` if one was corrected.
- [ ] **p** While All Objectives is collapsed, confirm a Blizzard priority/world-event background anchor force-expands All Objectives after the grace window; `/lst status objectives` should show `bg_force_expand=background:<priority module>`.


## 2. Count Correctness
- [ ] **a** Test quest count near the quest cap and confirm it never exceeds `C_QuestLog.GetMaxNumQuestsCanAccept()`.
- [ ] **b** Check campaign quests, world quests, bonus objectives, hidden/internal entries, and tasks do not inflate the quest count.


## 3. Runtime And Packaging
- [ ] **a** Confirm Section Count registers quest events only while Quest count is enabled.
- [ ] **b** Check `/lst status objectives` for expected quest event, hover-mode, hover, and title state.
- [x] **c** Run package validation before calling the feature done because new Objective Lua files were added to the TOC.
- [x] **d** Confirm Objective file load order remains `ob_defaults.lua`, feature files including `ob_position.lua` and `ob_background.lua`, then `ob_main.lua`.


## 4. Final Cleanup
- [ ] **a** Remove or archive this scratchpad before release unless intentionally keeping it out of packaging.
- [x] **b** Run `check_fast.ps1`.
- [x] **c** Run `check_fast.ps1 -Package`.
- [x] **d** Run `git diff --check`.
