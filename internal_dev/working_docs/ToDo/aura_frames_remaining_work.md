# Aura Frames Remaining Work
Temporary owner for unfinished Aura Frames implementation, live acceptance, and performance decisions after the Retail 12.1 migration

Deferred feature design is tracked separately in `aura_frames_deferred_features.md`.


## Table of Contents
- [1 Managed Aura Fade Live Check](#1-managed-aura-fade-live-check)
- [2 Managed Presentation And Migration](#2-managed-presentation-and-migration)
- [3 Cooldown Manager Live Regression](#3-cooldown-manager-live-regression)
- [4 Current Architecture Performance Reassessment](#4-current-architecture-performance-reassessment)


## 1 Managed Aura Fade Live Check
The shell and aggregate managed AuraContainer now receive the same OOC alpha without touching protected AuraButtons. Native AuraButton hover intentionally remains Blizzard-owned
- [x] **a** Enable **Fade OOC** on Static / Long Buffs or Debuffs and choose an obviously reduced OOC alpha
- [x] **b** Leave combat and confirm the managed frame fades
- [x] **c** Enter combat and confirm it returns to full alpha
- [x] **d** Leave combat and confirm it fades again
- [x] **e** Hover a managed AuraButton and confirm its native tooltip appears
- [x] **f** Decide whether tooltip access while retaining configured fade is acceptable or AF12-14 needs another outer-layer design
- [x] **g** In Move Mode confirm the move border and resize grip restore full alpha and resume fading when the cursor leaves
- [x] **h** Confirm entering Move Mode turns on Frame BG when it has not been manually disabled
- [x] **i** Uncheck Frame BG, leave and re-enter Move Mode, and confirm it stays off until manually turned on


## 2 Managed Presentation And Migration
- [x] **a** Validate the surviving managed Static / Long Buffs frame after removal of the obsolete Static and Long presets
- [x] **b** (Agent) Add managed icon cooldown swipe during AuraButton initialization and bind it natively without live-Aura reads
- [x] **c** Validate Short Buffs beside Timed Buffs at the 300-second boundary in Bar and Icon modes across combat
- [x] **d** Validate Static / Long Buff learning, persistence, combat updates, duration reclassification, and OOC cache clearing in Bar and Icon modes
- [x] **e1** Validate the local Frame BG toggle on Short Buffs in Bar and Icon modes with active and empty contents
- [x] **e2** Validate the local Frame BG toggle on Static / Long Buffs in Bar and Icon modes with active and empty contents
- [x] **e3** Validate the local Frame BG toggle on Timed Buffs in Bar and Icon modes with active and empty contents
- [x] **e4** Validate the local Frame BG toggle on Debuffs in Bar and Icon modes with active and empty contents
- [ ] **e5** Validate shared Frame BG colors on one managed Buff frame and the Debuff frame
- [ ] **e6** Validate All the Colors Frame BG overrides on one managed Buff frame and the Debuff frame
- [x] **e7** Confirm managed Frame BG visibility, color, and empty geometry remain stable through combat transitions
- [x] **f** Validate Bar BG and non-duration bar-text settings update managed Auras immediately while visible OOC
- [x] **g** Validate managed-frame Scale changes apply immediately while preserving the saved screen position


## 3 Cooldown Manager Live Regression
Use `internal_dev/tests_tools/aura_frames_cdm_regression.md` as the complete matrix
- [x] **a** Test Essential, Utility, Tracked Buffs, and Tracked Bars in Aura and cooldown modes
- [x] **b** Test Divine Protection and Blessing of Freedom across Essential and Utility
- [x] **c** Confirm active Aura duration precedes cooldown and hands off cleanly when the Aura expires during combat
- [x] **d** Move a spell between CDM groups through WoW settings and confirm the source frame clears and the destination frame refreshes after saving
- [x] **e** Reload during an encounter and confirm order, tooltips, presentation, and slot handoff recover without blocked actions or Lua errors


## 4 Current Architecture Performance Reassessment
The June profiles predate the managed/native migration and remain historical evidence only. Establish a new baseline from the real current configuration before choosing any optimization. Do not create a Custom Filtered frame solely for the baseline. The temporary Aura Frames profiler is loaded last from `LsTweeks.toc`, targets Aura Frames only, and must be removed when this work closes. Follow `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`.

Pre-check findings, in priority order:
1. `aura_icon_needs_tick()` currently treats every visible spell-cooldown cell as active ticker work before checking whether addon-updated timer text or bar progress exists. Inactive cooldown cells and icon-mode cooldowns with a native WoW swipe may therefore keep the ticker alive unnecessarily.
2. Every addon-owned CDM shell registers `UNIT_AURA`, spell cooldown, and charge events. The handler checks whether the frame is enabled but does not reject events that its current Aura/cooldown mode does not consume, so native Aura-mode and Tracked frames may queue redundant `update_auras()` work.
3. An out-of-combat cooldown-mode update can discover ordered CDM records once for the addon cooldown map and again for managed-backend reconciliation, then reanchor slots and reapply style across all accessible managed AuraButtons. A shared record snapshot plus data, anchor, and style invalidation signatures may remove repeated setup work.
4. Lower-priority candidates are unchanged managed-backend visibility writes, full-frame scans in `refresh_visible_icon_ticker()`, inactive cooldown processing while another frame owns the ticker, and OOC learned-buff scans under heavy Aura churn.

Do not implement these candidates before the unchanged baseline. The first run determines which current path is material and gives every accepted change a before/after comparison.

Baseline collection procedure:
1. Set Aura Frames **Timer Tick** to `0.15`, close addon settings, and leave Move Mode off.
2. Run `/lstprofile reset`, followed by `/lstprofile start`.
3. Enter representative combat for roughly 60–100 seconds. Keep combat active for at least 90% of the measured time and exercise the Aura Frames normally; do not open settings or Move Mode during the run.
4. While still in combat, run `/lstprofile report 40` and paste the complete report into `internal_dev/working_docs/ToDo/aura_frames_profile_results.txt`, replacing its placeholder text. The report automatically includes Aura Frames module status, Timer Tick, character specialization, Essential/Utility cooldown modes, enabled Test Auras, Custom Filtered frame details, and the generated `<!-- cpu-profile-run: ... -->` line. No separate `/lst status aura_frames` command, manual context notes, calculation, or metadata editing is required.
5. Run `/lstprofile stop` after the report has been captured.
6. Tell the agent the inbox is ready. The agent runs `process_af_cpu_profile_inbox.ps1`, preserves the validated run and metadata in `internal_dev/tests_tools/cpu_profiles/af_cpu_profiles.md`, and performs the analysis in 4d.

- [x] **a** Confirm `/lstprofile report 40` automatically prints Aura Frames module status, Timer Tick, character specialization, Essential/Utility cooldown-mode state, enabled Test Auras, and Custom Filtered frame details
  - Confirmed with the context-only preflight saved on 2026-08-31: Timer Tick `0.15`, Retribution (`70`), Essential and Utility cooldown modes enabled, no enabled per-frame/global Test Auras, no Custom Filtered frames, and complete Aura Frames module status. The `elapsed=0.0` capture intentionally has no performance metrics and is not the 4b/4c baseline.
- [x] **b** With Timer Tick at `0.15`, settings and Move Mode closed, collect roughly 60–100 seconds through `/lstprofile`; keep combat near or above 90% of elapsed time and capture the report while combat is still active
  - Accepted baseline: `100.2s` elapsed, `98.5s` combat (`98.3%`), one segment, captured while combat remained active.
- [x] **c** Paste the complete `/lstprofile report 40` output into `aura_frames_profile_results.txt`; (Agent) process it with `process_af_cpu_profile_inbox.ps1` and preserve the validated run in `af_cpu_profiles.md` as the new post-migration baseline
  - Processor validation passed; the complete 40-row report and automatic context are preserved under `2026-08-31, Aura Frames Only, Post-Migration Baseline`.
- [x] **d** (Agent) Assess current combat-normalized cost and call rate for `af.update_auras`, `af.render_aura_map`, `af.tick_visible_icons`, `af.frame_needs_visible_icon_tick`, `af.any_frame_needs_visible_icon_tick`, `af.add_cooldown_viewer_category_entries`, `af.refresh_managed_cdm_backend`, `af.set_managed_aura_backend_enabled`, `af.for_each_accessible_managed_aura_button`, `af.scan_custom_aura_map`, and `af.get_frame_activity_state`; do not use the June `6.50 ms/sec` result as a pass/fail threshold
  - Dominant inclusive path: `af.update_auras` `9.245ms/sec` at `10.56 calls/sec`.
  - Clearest attributed cost: `af.add_cooldown_viewer_category_entries` `4.839ms/sec` at `5.28 calls/sec`, including `af.get_ordered_cdm_records` `1.421ms/sec`; `af.render_aura_map` was `2.725ms/sec`.
  - `af.get_frame_activity_state` reached `1.176ms/sec` at `62.18 calls/sec`. Individual managed-backend refresh/enable paths were below `0.15ms/sec`; accessible-button setup was not measurable during combat, and `af.scan_custom_aura_map` was inactive because no Custom Filtered frame existed.
- [x] **e** If `af.tick_visible_icons` remains material, confirm whether native-swipe icon mode or inactive cooldown cells keep it alive, repeat matched `0.10` and `0.20` runs only if cadence still affects necessary addon-owned text/bar work, and decide whether to narrow ticker eligibility, retain the slider, or use one fixed cadence
  - Not material in the new baseline: `0.614ms/sec` at `6.10 calls/sec`. Do not spend additional live runs or change ticker cadence/eligibility on this evidence.
- [x] **f** If `af.update_auras` call rate is amplified, attribute calls by event and mode before changing ownership; test event-specific rejection of `UNIT_AURA` for native CDM Aura transport and cooldown/charge events for frames without an addon cooldown layer, preserving first-cast and Aura-to-cooldown handoff behavior
  - Attribution captured with both cooldown modes restored. Combat coverage was only 76.4%, so its CPU rates are not a matched comparison, but the event ownership evidence is valid: Aura-mode Tracked Buffs/Bars each scheduled 200 scans from `UNIT_AURA`, cooldown, and charge events; cooldown-mode Essential/Utility each scheduled 89 scans from `UNIT_AURA`. Together these were 578 of 876 measured updates (66.0%).
  - Implemented a mode-aware predicate: reject `UNIT_AURA` for every CDM shell; reject spell cooldown/charge events for CDM Aura mode; retain those spell events for cooldown mode and retain viewer-data/override, world-entry, specialization, and combat events for both modes. Focused headless coverage passes.
  - Post-change live validation:
    1. Keep Essential and Utility in **Cooldown Mode**, keep Timer Tick at `0.15`, and `/reload`.
    2. Confirm Tracked Buffs and Tracked Bars still add, update, and remove active Auras normally.
    3. Use an Essential or Utility ability and confirm its cooldown appears immediately; for an ability that grants an active Aura, confirm the native Aura overlay appears and the underlying cooldown remains correct when the Aura expires or is removed. Exercise a charged ability if available.
    4. With settings and Move Mode closed, run `/lstprofile reset` and `/lstprofile start`, then collect 60–100 seconds with combat at or above 90% of elapsed time.
    5. While still in combat, run `/lstprofile report 40`, replace `aura_frames_profile_results.txt` with the complete report, then run `/lstprofile stop` and tell the agent the validation inbox is ready.
    6. (Agent) Confirm `aura_event` rows show CDM `UNIT_AURA` ignored, spell cooldown/charge events ignored for Tracked Aura mode but scheduled for Essential/Utility cooldown mode, and compare post-change CPU/call rates with the 2026-08-31 baseline before completing 4f.
  - Accepted post-change validation: `92.2s` elapsed, `90.8s` combat (`98.5%`). Event rows match the intended routing exactly. Against baseline, `af.update_auras` fell from `10.56` to `6.30 calls/sec` (40.3%) and from `9.245` to `6.723ms/sec` (27.3%); the predicate itself cost `0.057ms/sec`.
- [x] **g** If CDM scan/render or managed-backend work is material, repeat a matched control with Essential and Utility cooldown modes disabled, then assess sharing one ordered-record snapshot and gating record reconciliation, slot anchoring, style application, and unchanged backend visibility writes
  - Accepted control: `81.7s` elapsed, `79.5s` combat (`97.3%`), with Essential and Utility enabled but both Cooldown Mode settings disabled.
  - `af.update_auras` call rate was effectively unchanged (`10.47` versus `10.56 calls/sec`), while cost fell from `9.245` to `1.558ms/sec` (83.1%). `af.render_aura_map` fell from `2.725` to `0.366ms/sec` (86.6%); CDM category-entry and ordered-record rows disappeared from the top 40.
  - This isolates the major cost to repeated addon cooldown-map rebuilding, not to cooldown mode increasing event frequency. Managed-backend refresh/enable paths remained immaterial, so do not prioritize record sharing, slot/style invalidation, or unchanged visibility writes. Complete 4f event/mode attribution next to identify which updates unnecessarily rebuild cooldown maps.
- [x] **h** (Agent) Add a narrower probe or optimize only when the new baseline or control runs attribute material cost or clear call amplification to a current path; do not presume that a central `UNIT_AURA` dispatcher is the solution
  - Event/category/mode attribution justified the narrow mode-aware predicate. Remaining record discovery was `1.124ms/sec`; broader record caching was rejected because its invalidation complexity is not warranted by this result.
- [x] **i** (Agent) If code changes result, run focused ticker/event/CDM regression coverage, full fast validation, and the smallest relevant live recheck before accepting the result
  - Focused event/CDM coverage, all 15 Aura Frames suites, the accepted live validation, and full fast validation pass. Full validation completed all 27 headless suites plus Lua syntax, region, memory-section, whitespace, and line-ending checks.
- [x] **j** (Agent) Remove the temporary profiler line from `LsTweeks.toc` when performance work closes
