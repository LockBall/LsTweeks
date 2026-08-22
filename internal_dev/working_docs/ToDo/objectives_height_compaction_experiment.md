# Objectives Height Compaction Experiment

## Goal
Determine whether Auto-Collapse can safely reclaim the vertical space reserved by a hidden Objective Tracker section without calling Blizzard collapse methods, entering the shared container update graph, or tainting later secret-sensitive layout work.

Current safe behavior hides each selected module's `ContentsFrame` and uses an addon-owned expand button. This preserves taint safety and manual-open state, but Blizzard still reserves the module's recorded content height.


## Safety Boundary
- Never call section or container `SetCollapsed`, `ToggleCollapsed`, `MarkDirty`, or `Update` from addon code.
- Never write custom fields onto Blizzard frames or their Lua tables.
- Apply experimental geometry only out of combat unless a later test explicitly proves a hardware-click restore is safe.
- Keep experiment state file-local and reload-scoped; do not add SavedVariables or release-facing settings.
- Keep the current visibility-only path as the control and immediate fallback.
- Treat headless tests as state-machine coverage only. In-game taint evidence is required before enabling compaction by default.


## Primary Hypothesis
`ObjectiveTrackerModuleMixin:SetHeightModifier(key, height)` may allow a hidden module to retain its header while reducing its frame height enough for the next anchored module to move upward.

Expected compact height:

```text
headerHeight + bottomSpacing
```

Candidate modifier:

```text
target compact height - (contentsHeight + bottomSpacing)
```

The principal risk is that `SetHeightModifier` stores addon-provided state in Blizzard's `heightModifiers` table. Blizzard later iterates that table from `UpdateHeight`; the value, table, resulting geometry, or downstream control flow may become tainted.

### Blocking Finding
In-game evidence shows that Achievements can remain completely absent after Quests contents are hidden, then appear only after the user expands and collapses Quests through Blizzard's button. This confirms the container still budgets the full Quests `contentsHeight`; the following module can remain truncated before it ever receives a visible header.

`SetHeightModifier` changes the module frame's physical height, but `ObjectiveTrackerContainerMixin:Update()` budgets available space with `module:GetContentsHeight()`, which returns Blizzard's `contentsHeight` when the module is displayable. A height modifier therefore may move an already-laid-out sibling but cannot reliably make a truncated following module displayable. Do not implement the primary hypothesis as the next step unless a separate safe mechanism first corrects container height budgeting.


## Lower-Priority Alternatives
Evaluate these only if the height-modifier experiment is rejected:
- Direct `SetHeight`: more intrusive, can be overwritten by Blizzard updates, and may taint geometry consumed elsewhere.
- Reanchoring sibling modules: highest ownership/conflict risk and likely to fight the container layout; do not prototype without a new review.
- Addon-owned visual duplication: avoids Blizzard geometry but does not actually reclaim tracker layout space.


## Phase 1: Baseline
- [x] **a** Start from the current visibility-only implementation with compaction disabled
- [x] **b** Run `/console taintLog 0` without closing WoW
- [x] **c** (Agent) Clear `_retail_/Logs/taint.log` from the addon root with `Clear-Content -LiteralPath '..\..\..\Logs\taint.log' -ErrorAction SilentlyContinue`; no archive is required for this disposable baseline. No matching file existed anywhere under the WoW installation.
- [x] **d** Run `/console scriptErrors 1`
- [x] **e** Run `/console taintLog 2`
- [x] **f** Run `/reload`
- [x] **g** Paste the multiline `/lst status objectives` chat output into `objectives_height_compaction_1g_status.txt`
- [x] **h** Confirm each available auto-hidden section shows the safe plus button and expands with one click
  - [x] Turn on Campaign Auto-Collapse
  - [x] Turn on Quests Auto-Collapse
  - [x] Turn on Achievements Auto-Collapse
- [x] **i** After manually opening a section, trigger an Objectives refresh by tracking or untracking a quest and confirm the section stays open
- [x] **j** Confirm manually collapsing an opened section rearms Auto-Collapse


## Phase 2: Reload-Scoped Prototype
- [x] **a** (Agent) Trace how Blizzard calculates each section's layout height and identify a safe way for an auto-hidden section to contribute only its header height; no safe mechanism was found
- [x] **b** (Agent) Reject the mechanism if it requires overriding `GetContentsHeight`, writing `contentsHeight`, or calling the shared container update; all identified candidates require one of these paths
- [ ] **c** (Agent) Add a temporary `/lst` experiment toggle
- [ ] **d** (Agent) Default the experiment toggle off
- [ ] **e** (Agent) Reset the experiment toggle on reload
- [ ] **f** (Agent) Implement one centralized compaction apply path
- [ ] **g** (Agent) Implement one centralized compaction clear path
- [ ] **h** (Agent) Define one file-local modifier key
- [ ] **i** (Agent) Keep all experiment tracker state file-local
- [ ] **j** (Agent) Require numeric `contentsHeight`, `headerHeight`, and `bottomSpacing` before compaction
- [ ] **k** (Agent) Compute the compact target when Auto-Collapse hides a section
- [ ] **l** (Agent) Apply the computed modifier when Auto-Collapse hides a section
- [ ] **m** (Agent) Clear the modifier when the addon-owned expand button opens a section
- [ ] **n** (Agent) Clear the modifier when the section's Auto-Collapse setting is disabled
- [ ] **o** (Agent) Clear every applied modifier when Objectives is disabled
- [ ] **p** (Agent) Skip geometry mutation during combat
- [ ] **q** (Agent) Queue one existing Objectives combat replay for skipped geometry mutation
- [ ] **r** (Agent) Confirm the prototype does not hook container `Update` or tracker `OnUpdate`
- [ ] **s** (Agent) Add a status field for experiment enabled state
- [ ] **t** (Agent) Add a status field for modifier applied state
- [ ] **u** (Agent) Add status fields for source height and compact target height
- [ ] **v** (Agent) Add a status field for the last compaction reason

Stop gate: steps c through v remain paused because a and b found no candidate that can change Blizzard's container budget within the experiment's safety boundary


## Phase 3: Native securecall Comparison
- [x] **a** (Agent) Add a reload-scoped `/lst obnative` experiment command
- [x] **b** (Agent) Limit the experiment to `QuestObjectiveTracker`
- [x] **c** (Agent) Defer each requested action until the next frame
- [x] **d** (Agent) Invoke the native `SetCollapsed()` method through `securecall()` without copying addon code
- [x] **e** (Agent) Refuse the experiment during combat
- [x] **f** (Agent) Keep the experiment separate from normal Auto-Collapse and refuse it while LsTweeks Quests Auto-Collapse is enabled
- [x] **g** Disable Quest Log Collapse
- [x] **h** Disable CollapseQuestLog
- [x] **i** Turn off LsTweeks Quests Auto-Collapse
- [x] **j** (Agent) Clear `_retail_/Logs/taint.log`
- [x] **k** Run `/reload`
- [x] **l** Run `/lst obnative collapse`
- [x] **m** Confirm Quests enters Blizzard's real collapsed state
- [x] **n** Confirm the Achievements section appears without another manual collapse
- [x] **o** Save `/lst status objectives` output to `objectives_native_securecall_3o_status.txt`
- [x] **p** Open the world map and hover quest or world-quest rewards
- [x] **q** Save `Logs/taint.log` for agent analysis
- [x] **r** Run `/lst obnative expand` after the evidence is saved

This phase is an explicit diagnostic exception to Phase 2's safety boundary. It must not be promoted into normal Auto-Collapse unless the resulting taint evidence disproves the known failure mode

Phases 1 through 3 preserve the investigation history. Their height-modifier and visibility-overlay tasks are superseded by the successful native-collapse experiment and Phase 5 production candidate


## Phase 4: Delayed Scenario Taint Test
- [x] **a** (Agent) Clear `_retail_/Logs/taint.log`
- [x] **b** Run `/lst obnative collapse`
- [x] **c** Confirm the collapse reports `result=applied`
- [x] **d** Leave Quests collapsed while Scenario criteria update during normal play
- [x] **e** Complete a Scenario boss or stage when available
- [x] **f** Report any Lua, secret-value, or blocked-action error immediately; none appeared during the Void Incursion boss defeat
- [x] **g** (Agent) Inspect the live `taint.log` after the Scenario updates
- [x] **h** Run `/lst obnative expand` after the evidence is captured


## Phase 5: Production Candidate
- [x] **a** (Agent) Back up the visibility-only implementation as `backups/ob_auto_collapse_visibility_2026-08-22.lua`
- [x] **b** (Agent) Route normal Campaign, Quests, and Achievements Auto-Collapse through deferred native `securecall`
- [x] **c** (Agent) Remove the overlay-button workaround from the active implementation
- [x] **d** (Agent) Preserve manual-open overrides and manual-collapse rearming
- [x] **e** (Agent) Preserve combat deferral
- [x] **f** (Agent) Expand native sections when their setting or the Objectives module is disabled
- [x] **g** (Agent) Add per-section native result status
- [x] **h** (Agent) Pass focused Auto-Collapse and smoke tests
- [ ] **i** Run `/reload`
- [ ] **j** Enable Campaign, Quests, and Achievements Auto-Collapse
- [ ] **k** Confirm all available sections use Blizzard's native collapsed state and no layout gap remains
- [ ] **l** Confirm a manually expanded section stays open through an Objectives refresh
- [ ] **m** Confirm manually collapsing the section rearms Auto-Collapse
- [ ] **n** Complete another Void Incursion boss or Scenario update with Auto-Collapse active
- [ ] **o** (Agent) Inspect `taint.log` and decide whether to retain or restore the candidate


## Phase 6: Update Resilience
Blizzard can rebuild tracker contents after quest, campaign, achievement, or scenario updates. Confirm its native collapsed state remains authoritative without addon-owned geometry.

- [ ] **a** Trigger a tracker update while all configured sections are collapsed
- [ ] **b** Confirm collapsed sections retain header-only layout height
- [ ] **c** Confirm later sections remain visible without gaps, clipping, or overlap
- [ ] **d** Manually expand one section
- [ ] **e** Trigger another tracker update
- [ ] **f** Confirm the manually expanded section stays open
- [ ] **g** Manually collapse that section
- [ ] **h** Trigger another tracker update
- [ ] **i** Confirm native collapsed layout remains stable
- [ ] **j** (Agent) Inspect status and taint evidence after the sequence


## Diagnostics
Capture before and after each candidate mutation:
- Tracker name and current collapsed/visible state.
- `contentsHeight`, `headerHeight`, `bottomSpacing`, and `GetHeight()`.
- Applied modifier and computed compact target.
- Combat state and apply reason.
- Security state for relevant Blizzard-owned fields where `issecurevariable` can inspect them safely.
- `/lst status objectives`.
- New Lua errors and the relevant `Logs/taint.log` excerpt.

Do not store full logs in durable module memory. Archive raw evidence under the existing error-batch workflow and summarize only confirmed conclusions here and in `proj_mem/modules/objectives.md`.


## In-Game Test Matrix
Run each case first with compaction off, then with it on.

### Basic Layout
- [ ] Reload with Campaign, Quests, and Achievements enabled for Auto-Collapse.
- [ ] Confirm hidden headers stack without blank vertical gaps.
- [ ] Expand each section individually and confirm exact height restoration.
- [ ] Collapse each expanded section and confirm compaction is rearmed.
- [ ] Repeat expansion/collapse in different section orders.
- [ ] Disable and re-enable each setting.
- [ ] Disable and re-enable the Objectives module.

### Tracker Updates
- [ ] Track and untrack ordinary quests.
- [ ] Advance quest objectives and complete/turn in a quest.
- [ ] Track and untrack achievements.
- [ ] Trigger Campaign objective changes.
- [ ] Test empty sections and sections that acquire their first entry after login.
- [ ] Test sections whose content height grows and shrinks while manually open.

### Combat And Protected-State Boundaries
- [ ] Enter combat while sections are auto-hidden.
- [ ] Try Blizzard's native section button during combat.
- [ ] Change settings during combat and verify deferred application after regeneration.
- [ ] Enter and leave combat with a manual-open override active.
- [ ] Confirm no `ADDON_ACTION_BLOCKED` or protected-frame mutation errors.

### Known High-Risk Surfaces
- [ ] Open the world map and hover quest or world-quest rewards with embedded tooltip content.
- [ ] Run Scenario content that updates criteria repeatedly.
- [ ] Run a Void Incursion through boss death and the subsequent `SCENARIO_CRITERIA_UPDATE` path.
- [ ] Exercise Maw Buffs or another secret-sensitive Scenario display when available.
- [ ] Allow several tracker updates after the last addon interaction to catch delayed dirty passes.

### Compatibility
- [ ] Test with no other tracker addon enabled.
- [ ] Test with the user's normal addon set.
- [ ] Verify Edit Mode and Objective Tracker background behavior.
- [ ] Verify section-count title updates and hover behavior.


## Headless Regression Coverage
- [x] Native apply never collapses the parent tracker or calls the shared container update directly.
- [x] Native section changes are deferred and refused during combat.
- [x] Manual expansion remains open across later apply passes.
- [x] Manual collapse rearms Auto-Collapse.
- [x] Disabling a setting expands its section with combat deferral.
- [x] Disabling the Objectives module expands sections owned by Auto-Collapse.
- [x] Repeated apply operations skip redundant native state writes.


## Acceptance Gates
All gates must pass before compaction can become default behavior:
- [ ] Hidden sections reclaim vertical space without clipping, overlap, or anchor drift.
- [ ] Manual expansion restores the exact Blizzard layout and remains open.
- [ ] Manual collapse rearms Auto-Collapse without an immediate reopen or rehide race.
- [ ] Blizzard content updates do not invalidate the compact height.
- [ ] No addon-driven collapse, dirty mark, or container update enters the call graph.
- [ ] No new taint attribution, secret-value error, protected-action failure, or tooltip geometry error appears across the full matrix.
- [ ] Disable and reload paths restore Blizzard-owned geometry cleanly.
- [ ] Headless suites, changed-file LuaLS/Ketho, and routine fast checks pass.


## Immediate Rejection Conditions
Reject the candidate and return to visibility-only behavior if any occurs:
- `heightModifiers`, related frame geometry, or downstream execution becomes addon-tainted.
- Scenario/Maw Buffs secret-value errors return.
- World-map or embedded-item tooltip geometry errors appear.
- Blizzard updates repeatedly overwrite or accumulate the modifier.
- A secure/protected mutation is required to keep layout synchronized.
- The prototype must reanchor Blizzard modules or call the shared container update.
- Another addon can no longer control or restore the tracker normally.


## Evidence Log
Add dated entries while testing; keep each entry concise and link archived raw evidence when present.

### 2026-08-22 — Phase 1g status capture
- Raw evidence: [`objectives_height_compaction_1g_status.txt`](objectives_height_compaction_1g_status.txt).
- All three Auto-Collapse settings were disabled, providing the requested unmodified baseline.
- `QuestObjectiveTracker` was shown and displayable with approximately `489.67` height and `489.67` contents height; `has_skipped_blocks=true` shows that it exhausted the remaining tracker budget.
- `AchievementObjectiveTracker` was not shown or displayable, had `contents_height=0`, and remained in state `1` despite `collapsed=false`.
- This supports the observed failure mode: Quests consumes the available container budget before Achievements is laid out. It does not by itself test the visibility-only Auto-Collapse state.

### 2026-08-22 — Phase 2a source and addon survey
- The synced Retail 12.1.0 FrameXML container calls each module's `Update(availableHeight)` and then subtracts `module:GetContentsHeight()` before laying out the next module
- `GetContentsHeight()` returns `contentsHeight` only when the module is displayable; `SetHeightModifier()` changes the physical frame height but does not change this budget value
- Native `SetCollapsed()` obtains header-only budgeting by changing collapse state, marking the module dirty, and re-entering the shared container update, which is the known taint path
- Overriding `GetContentsHeight`, writing `contentsHeight` or module state, and invoking the shared container update were rejected by the experiment's safety boundary
- Surveyed current objective-tracker addons use native collapse, hide or reparent the whole tracker, or replace/rebuild the tracker; none exposed a separate safe per-section budget mechanism
- QuestLogCollapse 1.5.6 calls the native section `SetCollapsed()` method inside `securecall`; this does not bypass the shared Blizzard layout call graph and is not evidence that the path is safe for LsTweeks
- Result: no viable compaction prototype was identified, so Phase 2 implementation remains paused

### 2026-08-22 — Installed similarly named addons
- `CollapseQuestLog` 03.00 is unrelated to Objective Tracker section compaction; it adds collapse and expand controls to the Quest Log and other list-based UI panels and uses the Quest Log header APIs
- `QuestLogCollapse` is the relevant Objective Tracker addon; its installed TOC and Lua identify version 1.5.6, while its bundled `CHANGES.txt` contains the 1.5.7 tag dated 2026-08-18
- The installed `QuestLogCollapse` directly invokes each selected tracker module's native `SetCollapsed()` method from a deferred `OnUpdate` callback wrapped in `securecall`
- It explicitly skips Scenario and UI Widget trackers through a taint blacklist, and its configuration warns that Quests, Bonus Objectives, World Quests, Monthly Activities, and Adventure Map operations may taint related UI paths
- No code from either addon will be copied; their behavior and API choices are evidence only

### 2026-08-22 — Native securecall initial result
- `/lst obnative collapse` reported that the request was queued and then applied
- Quests entered Blizzard's real collapsed state
- Campaign and Achievements remained visible and expanded normally; Achievements appeared without another manual collapse
- This confirms the native call releases the container budget; taint safety remains unproven until the status and log checks are complete
- The saved status reports `native_experiment_requests=1`, `native_experiment_result=applied`, and `native_experiment_quest_collapsed=true`
- Blizzard reports Quests shown, displayable, collapsed, and budgeted at `25` pixels instead of the earlier approximately `489.67` pixels
- Achievements is now shown and fully displayable with approximately `384` pixels of contents height and no skipped blocks
- The LsTweeks Objectives module was disabled during this capture, further isolating the manual experiment from normal module application
- The first world-map tooltip pass produced no visible error and no Objective Tracker, Scenario, Maw Buffs, secret-value, or blocked-action entry attributed to LsTweeks in `taint.log`
- The log's only LsTweeks entry was Blizzard reading the addon's normal `SLASH_LSTWEEKS1` registration; the remaining log noise was attributed to other addons
- This is a clean initial result, not proof against the previously observed delayed Scenario update failure
- `/lst obnative expand` also reported `result=applied`, and Quests returned to its normal expanded layout
- The expand call added no relevant entry to `taint.log`

### 2026-08-22 — Delayed Scenario taint result
- Quests remained natively collapsed through a Void Incursion boss defeat and its Scenario criteria updates
- No visible Lua, secret-value, or blocked-action error appeared
- The resulting `taint.log` contained no Objective Tracker, Scenario tracker, `ShouldShowMawBuffs`, secret-value, or blocked-action record
- The sole LsTweeks log line was Blizzard reading the normal `SLASH_LSTWEEKS1` registration
- This directly passes the previously failing delayed event once; repetition and broader tracker-update testing are still required before promoting the technique
- The final native expand also reported `result=applied` and restored the normal Quests layout

### Pending
- Baseline client: Retail 12.1.0.69404, Interface 120100, synced FrameXML commit `81d15e42f16f3473131880500e7a8c8eb88fa5e6`.
- Reproduced limitation: Achievements header can remain truncated until a real Blizzard collapse of Quests releases the container's budgeted height.
- Rejected as a standalone candidate: `SetHeightModifier`; it changes physical frame height but not the `GetContentsHeight()` value used for container budgeting.
- Current decision: do not implement height compaction until a taint-safe container-budget mechanism is identified. Visibility-only Auto-Collapse is safe from the known dirty-graph taint but is not functionally equivalent to collapse.


## Closeout
If accepted:
- Remove the reload-scoped experiment toggle and diagnostic-only code.
- Keep the smallest useful status fields.
- Promote the confirmed contract and taint evidence to `proj_mem/modules/objectives.md`.
- Update README wording if the visible layout changes.
- Archive or remove this ToDo after durable documentation is complete.

If rejected:
- Remove all experimental geometry code and hooks.
- Record the rejected mechanism, exact failure, and archived evidence in Objectives memory.
- Retain the visibility-only path and its manual-open state machine.
