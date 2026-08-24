# Aura Frames Remaining Work
Temporary owner for unfinished Aura Frames implementation, live acceptance, and performance decisions after the Retail 12.1 migration


## Table of Contents
- [1 Managed Aura Fade Live Check](#1-managed-aura-fade-live-check)
- [2 Managed Presentation And Migration](#2-managed-presentation-and-migration)
- [3 Cooldown Manager Live Regression](#3-cooldown-manager-live-regression)
- [4 Performance Run And Conditional Optimization](#4-performance-run-and-conditional-optimization)
- [5 Deferred Feature Design](#5-deferred-feature-design)


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
- [ ] **e7** Confirm managed Frame BG visibility, color, and empty geometry remain stable through combat transitions
- [ ] **f** Change Bar BG and non-duration bar-text settings while managed Auras are visible OOC and record which changes apply immediately versus requiring a safe rebuild
- [ ] **g** (Agent) Diagnose the managed-frame Scale regression; `update_managed_preset_frame` currently returns before the generic `SetScale` path in `update_auras`


## 3 Cooldown Manager Live Regression
Use `internal_dev/tests_tools/aura_frames_cdm_regression.md` as the complete matrix
- [ ] **a** Test Essential, Utility, Tracked Buffs, and Tracked Bars in Aura and cooldown modes
- [ ] **b** Test Divine Protection and Blessing of Freedom across Essential and Utility
- [ ] **c** Confirm active Aura duration precedes cooldown and hands off cleanly when the Aura expires during combat
- [ ] **d** Move a spell between CDM groups and confirm no stale spell name or icon remains
- [ ] **e** Reload during an encounter and confirm order, tooltips, presentation, and slot handoff recover without blocked actions or Lua errors


## 4 Performance Run And Conditional Optimization
The temporary Aura Frames profiler probe is already configured. Follow `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`
- [ ] **a** Collect roughly 60–100 seconds of sustained combat with `/lstprofile`
- [ ] **b** Record the Timer Tick setting and preserve the paste-ready `cpu-profile-run` metadata
- [ ] **c** Save the report in `af_cpu_profiles.md`
- [ ] **d** (Agent) Compare the report through `analyze_af_cpu_profiles.ps1` against the 2026-06-27 `update_auras` baseline of 6.50 ms/sec combat-normalized
- [ ] **e** (Agent) Reopen a central `UNIT_AURA` dispatcher only if profiling attributes material cost to per-frame payload merging or timers
- [ ] **f** (Agent) If reopened, require explicit disabled-frame, custom-frame, combat, stale-payload, lifecycle, event-order, and taint ownership tests
- [ ] **g** (Agent) Remove the temporary probe line from `LsTweeks.toc` when performance work closes


## 5 Deferred Feature Design
- [ ] **a** (Agent) Map Custom Filtered Frames only to live-supported standard Aura filters and managed candidate filters; reject arbitrary predicates requiring protected Aura data
- [ ] **b** (Agent) Implement native numeric rule formatters for compact and decimal timer modes with boundary tests and secret-Aura live validation
- [ ] **c** (Agent) Map sorting only to live-supported AuraContainer methods and remove choices that require addon comparators or unavailable enum members
- [ ] **d** Live-validate restored Test Aura previews on Short, Static / Long, Timed, and Debuff frames in Bar and Icon modes; implementation uses one addon-owned mock with its own Frame BG cell on the side opposite native growth and never injects synthetic data into managed AuraButtons
