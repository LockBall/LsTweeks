# Objectives Height Compaction Experiment
Archive marker: `[~]` means the step was superseded when the native `securecall` candidate was rejected

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
- [x] **c** (Agent) Cancel the height-modifier prototype before implementation because it cannot change Blizzard's authoritative container budget within the safety boundary

The canceled implementation checklist was condensed rather than left as false pending work; no modifier code, toggle, geometry hook, or modifier status state was created


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
- [x] **a** (Agent) Back up the visibility-only implementation as `ob_auto_collapse_visibility_2026-08-22.lua.txt`
- [x] **b** (Agent) Route normal Campaign, Quests, and Achievements Auto-Collapse through deferred native `securecall`
- [x] **c** (Agent) Remove the overlay-button workaround from the active implementation
- [x] **d** (Agent) Preserve manual-open overrides and manual-collapse rearming
- [x] **e** (Agent) Preserve combat deferral
- [x] **f** (Agent) Expand a section when its setting is disabled and expand only addon-owned collapses when Objectives is disabled
- [x] **g** (Agent) Add per-section native result status
- [x] **h** (Agent) Pass focused Auto-Collapse and smoke tests
- [x] **i** Run `/reload`
- [x] **j** Enable Campaign, Quests, and Achievements Auto-Collapse
- [x] **k** Confirm all available sections use Blizzard's native collapsed state and no layout gap remains
- [x] **l** Confirm a manually expanded section stays open through an Objectives refresh
- [x] **m** Confirm manually collapsing the section rearms Auto-Collapse
- [x] **n** Complete another Void Incursion boss or Scenario update with Auto-Collapse active
- [x] **o** (Agent) Inspect `taint.log` and retain the candidate; no relevant taint or visible error appeared


## Phase 6: Update Resilience
Blizzard can rebuild tracker contents after quest, campaign, achievement, or scenario updates. Confirm its native collapsed state remains authoritative without addon-owned geometry.

- [x] **a** Trigger a tracker update while all configured sections are collapsed
- [x] **b** Confirm collapsed sections retain header-only layout height
- [x] **c** Confirm later sections remain visible without gaps, clipping, or overlap
- [x] **d** Manually expand one section
- [x] **e** Trigger another tracker update
- [x] **f** Confirm the manually expanded section stays open
- [x] **g** Manually collapse that section
- [x] **h** Trigger another tracker update
- [x] **i** Confirm native collapsed layout remains stable
- [x] **j** (Agent) Inspect status and taint evidence after the sequence; all configured sections were natively collapsed at 25px with no queued/deferred collapse work, later sections remained displayable, ownership matched manual interaction, and the only taint entry was normal slash registration


## Phase 7: Reload-Surviving Failure Trace
- [x] **a** (Agent) Record the 2026-08-23 recurrence and objective-progress stall as a failed acceptance gate
- [x] **b** (Agent) Add a bounded 200-entry trace outside profile data so evidence survives `/reload`
- [x] **c** (Agent) Record Auto-Collapse queue, combat deferral, manual interaction, and pre/post-`securecall` field security
- [x] **d** (Agent) Record existing background callback activity and Scenario event security snapshots without adding Blizzard-frame hooks
- [x] **e** (Agent) Add `/lst obtrace`, `/lst obtrace clear`, and `/lst obtrace mark`
- [x] **f** (Agent) Pass the focused trace, Auto-Collapse, background, and smoke tests
- [x] **g** Follow the targeted procedure in `objectives_void_incursion_trace_test.md`


## Diagnostics
Capture before and after each candidate mutation:
- Tracker name and current collapsed/visible state.
- `contentsHeight`, `headerHeight`, `bottomSpacing`, and `GetHeight()`.
- Native result and addon-owned collapse state.
- Combat state and apply reason.
- Security state for relevant Blizzard-owned fields where `issecurevariable` can inspect them safely.
- `/lst status objectives`.
- New Lua errors and the relevant `Logs/taint.log` excerpt.

Do not store full logs in durable module memory. Archive raw evidence under the existing error-batch workflow and summarize only confirmed conclusions here and in `proj_mem/modules/objectives.md`.


## In-Game Acceptance

### Confirmed Evidence
- [x] Reload with Campaign, Quests, and Achievements enabled for Auto-Collapse
- [x] Confirm native collapsed headers stack without blank vertical gaps
- [x] Expand Campaign, Quests, and Achievements individually and confirm exact height restoration
- [x] Collapse Campaign, Quests, and Achievements individually and confirm Auto-Collapse is rearmed
- [x] Enter combat while sections are auto-collapsed
- [x] Run Scenario content that updates criteria repeatedly
- [x] Run two Void Incursions through boss death and the subsequent `SCENARIO_CRITERIA_UPDATE` path
- [x] Allow several tracker updates after the last addon interaction to catch delayed dirty passes
- [x] Test with the user's normal addon set except the two intentionally disabled competing tracker addons

### Reduced Remaining Matrix
These cases exercise distinct remaining risks; reordered clicks and further variations of already-proven native behavior were pruned

Paused after the 2026-08-23 taint recurrence until Phase 7 identifies the responsible Objectives path

#### 1 Module Ownership Lifecycle
- [~] **a** Superseded — Manually collapse Quests while Campaign and Achievements remain addon-owned
- [~] **b** Superseded — Disable the Objectives module
- [~] **c** Superseded — Confirm Campaign and Achievements expand while Quests stays collapsed
- [~] **d** Superseded — Re-enable the Objectives module
- [~] **e** Superseded — Confirm the configured sections collapse again

#### 2 Achievement Update While Manually Open
- [~] **a** Superseded — Manually expand Achievements
- [~] **b** Superseded — Track or untrack an achievement
- [~] **c** Superseded — Confirm Achievements remains open and the layout stays correct

#### 3 Native Section Control During Combat
- [~] **a** Superseded — Enter combat
- [~] **b** Superseded — Use a native section button
- [~] **c** Superseded — Leave combat
- [~] **d** Superseded — Trigger a tracker refresh
- [~] **e** Superseded — Confirm the manual choice persists with no blocked-action error

#### 4 Auto-Collapse Setting Change During Combat
- [~] **a** Superseded — Enter combat
- [~] **b** Superseded — Change one Auto-Collapse setting
- [~] **c** Superseded — Leave combat
- [~] **d** Superseded — Confirm the setting applies with no protected-action error

#### 5 World-Map Embedded Tooltip
- [~] **a** Superseded — Open the world map
- [~] **b** Superseded — Hover a quest or world-quest reward with embedded tooltip content
- [~] **c** Superseded — Confirm no tooltip geometry or secret-value error

#### 6 Edit Mode Compatibility
- [x] **a** Open and close Edit Mode
- [x] **b** Confirm the Objective Tracker background and native collapsed sections remain stable

#### 7 Final Evidence Inspection
- [x] **a** (Agent) Inspect final status and taint evidence; reject native collapse from the completed boundary and control evidence

### Pruned As Redundant
- Different expansion and collapse orders use the same per-section native path already proven individually
- Repeating every setting toggle out of combat duplicates the shared data-driven path and headless coverage
- Ordinary quest changes, quest completion, Scenario criteria changes, delayed tracker updates, and section growth all exercised Blizzard-driven refreshes
- Empty-section and Campaign-only variations no longer target an independent addon layout mechanism because Blizzard owns the collapsed geometry
- The two Void Incursion boss cycles exercised the exact secret-sensitive Scenario and Maw Buffs failure path that motivated this work
- Section-count title hover does not exercise the collapse boundary


## Headless Regression Coverage
- [x] Native apply never collapses the parent tracker or calls the shared container update directly.
- [x] Native section changes are deferred and refused during combat.
- [x] Manual expansion remains open across later apply passes.
- [x] Manual collapse rearms Auto-Collapse.
- [x] Disabling a setting expands its section with combat deferral.
- [x] Disabling the Objectives module expands sections owned by Auto-Collapse.
- [x] Disabling the Objectives module preserves sections already collapsed by Blizzard or the user.
- [x] Repeated apply operations skip redundant native state writes.


## Acceptance Gates
All gates must pass before native Auto-Collapse is considered fully accepted:
- [x] Natively collapsed sections reclaim vertical space without clipping, overlap, or anchor drift.
- [x] Manual expansion restores the exact Blizzard layout and remains open.
- [x] Manual collapse rearms Auto-Collapse without an immediate reopen or rehide race.
- [x] Blizzard content updates preserve native collapsed layout.
- [x] No direct addon-context collapse, dirty mark, or container update enters the call graph; section collapse uses only the centralized direct-function `securecall` boundary.
- [~] Superseded — No new taint attribution, secret-value error, protected-action failure, or tooltip geometry error appears across the reduced matrix
- [x] Reload restores the production implementation and Blizzard-owned geometry cleanly
- [~] Superseded — Module disable preserves user-owned state while restoring addon-owned geometry cleanly
- [x] Headless suites, changed-file LuaLS/Ketho, and routine fast checks pass.


## Immediate Rejection Conditions
Reject the candidate and restore the backed-up visibility implementation if any occurs:
- Native collapse state, related frame state, or downstream execution becomes addon-tainted by LsTweeks.
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

### 2026-08-22 — Production candidate repetition and cleanup
- Normal Campaign, Quests, and Achievements Auto-Collapse was active for another Void Incursion boss and Scenario update
- No visible Lua, secret-value, or blocked-action error appeared
- The fresh `taint.log` contained no Objective Tracker, Scenario tracker, `ShouldShowMawBuffs`, `GetAuraDataByIndex`, secret-value, or blocked-action entry
- The only LsTweeks entry was Blizzard reading `SLASH_LSTWEEKS1`, alongside the same normal slash-registration noise from other addons
- At this point the production candidate was retained while the remaining manual-interaction and update-resilience checklist items were completed
- The duplicate reload-scoped `/lst obnative` command, experiment runtime state, status fields, and headless tests were removed after promotion
- Auto-Collapse now tracks successful addon-issued collapses so module disable does not expand a section that was already collapsed by Blizzard or the user

### 2026-08-23 — Production candidate recurrence
- A later Void Incursion reproduced `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'LsTweeks'` in Blizzard Maw Buffs through Scenario Objective Tracker layout
- Objective progress stopped updating for the remainder of the event state and resumed immediately after `/reload`, confirming a reload-scoped functional failure rather than harmless log noise
- The captured Blizzard stack identifies the eventual consumer but contains no LsTweeks caller frame, so it does not distinguish section `securecall`, manual-button activity, background hooks, or another earlier Objectives mutation
- The prior two clean cycles remain valid observations but no longer support accepting the candidate as safe
- User approved continued `securecall` testing with a bounded persistent trace instead of an immediate rollback

### 2026-08-23 — First persistent trace result
- An Auto-Collapse-on Void Incursion completed without a visible error
- All 54 captured Scenario snapshots attributed Campaign, Quests, and Achievements `isCollapsed` and `contentsHeight` to LsTweeks while parent, Scenario, and section `dirty` fields remained secure
- The state is unsafe even though this event did not reach the secret-aura error
- Repeated Scenario events displaced the startup boundary records from copied chat history, so the collector now coalesces duplicates and repeats a bounded critical record set at the end
- The next test keeps Objectives enabled but disables all three Auto-Collapse settings before a clean reload to isolate other Objectives paths

### 2026-08-23 — Auto-Collapse-off control
- Objectives and its existing background hooks remained enabled while Campaign, Quests, and Achievements Auto-Collapse were disabled
- No post-reload `auto/securecall` occurred and the Incursion completed without a visible error
- All 75 represented Scenario events kept every inspected section, parent, and Scenario field secure
- Compared with the Auto-Collapse-on run, this isolates the section-field taint to Auto-Collapse rather than general Objectives background activity
- The next planned check was an immediate Quests-only pre/post-`securecall` capture

### 2026-08-23 — Immediate Quests boundary result
- Before `securecall`, Quests `SetCollapsed`, `isCollapsed`, `dirty`, and `contentsHeight` all reported secure
- Immediately after `securecall`, `isCollapsed` reported `tainted:LsTweeks`; method, dirty, and height remained secure at that instant
- The earlier Scenario trace showed `contentsHeight` becoming tainted during downstream layout
- Together with the clean no-`securecall` control, this conclusively rejects deferred direct-function `securecall` for native Auto-Collapse

### Pending
- Baseline client: Retail 12.1.0.69404, Interface 120100, synced FrameXML commit `81d15e42f16f3473131880500e7a8c8eb88fa5e6`.
- Reproduced limitation: Achievements header can remain truncated until a real Blizzard collapse of Quests releases the container's budgeted height.
- Rejected as a standalone candidate: `SetHeightModifier`; it changes physical frame height but not the `GetContentsHeight()` value used for container budgeting.
- Current decision: reject deferred direct-function native `securecall`; the active replacement is visibility-only Auto-Collapse with accepted spacing limitations


## Closeout
If accepted:
- [x] **a** (Agent) Remove the reload-scoped experiment command and diagnostic-only code
- [x] **b** (Agent) Keep only production per-section status fields
- [x] **c** (Agent) Promote the confirmed contract, secure-boundary lesson, and taint evidence to durable project and Objectives memory
- [x] **d** (Agent) Update README wording for native collapsed layout
- [x] **e** (Agent) Condense the investigation into a reusable case study and archive the raw working evidence

If rejected:
- Remove all experimental geometry code and hooks.
- Record the rejected mechanism, exact failure, and archived evidence in Objectives memory.
- Retain the visibility-only path and its manual-open state machine.
