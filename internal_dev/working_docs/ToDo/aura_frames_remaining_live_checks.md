# Aura Frames Remaining Live Checks
Temporary checklist for the remaining post-12.1 in-game validation and migration work. Items 1–2, the disabled settings lifecycle and Blizzard Buff/Debuff hiding/restoration, were completed and recorded in `proj_mem/modules/aura_frames.md`.


## Table of Contents
- [3. Managed Aura Hover With OOC Fade](#3-managed-aura-hover-with-ooc-fade)
- [4. Objective Tracker Secret-Aura Taint Isolation](#4-objective-tracker-secret-aura-taint-isolation)
- [5. Remaining Aura Migration, Presentation, And Performance](#5-remaining-aura-migration-presentation-and-performance)


## 3. Managed Aura Hover With OOC Fade
The local/global policy conflict is fixed in code: checking a frame-specific **Fade OOC** now clears global **Disable OOC Fade** and unchecks both linked controls. The first live recheck then showed that the shell alpha changed while Blizzard's managed AuraContainer stayed visually opaque, so the fade path now applies the same alpha to both aggregate frames without touching protected AuraButtons. Repeat this matrix after reload to validate that visual fix.

### Test
1. Enable **Fade OOC** on Static / Long Buffs or Debuffs and choose an obviously reduced OOC alpha.
2. Leave combat and confirm the managed frame fades.
3. Enter combat and confirm it returns to full alpha.
4. Leave combat and confirm it fades again.
5. Hover an actual managed AuraButton and confirm its native tooltip appears.
6. Observe whether the faded frame brightens while the AuraButton is hovered.
7. In Move Mode, hover the move border and resize grip; both should restore full alpha and fade again when the cursor leaves.

### Decision
- If managed AuraButton hover must restore full alpha, keep AF12-14 open when the tooltip appears over a faded frame.
- If native tooltip access while retaining the configured fade is acceptable, close AF12-14 with that behavior documented.


## 4. Objective Tracker Secret-Aura Taint Isolation
### Test
1. Reload with the current Objective Tracker corrections enabled.
2. Reproduce the prior scenario: a Void Incursion boss death, combat exit, or another event that refreshes Scenario Objective Tracker/Maw Buffs.
3. Watch for `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by LsTweeks`.
4. If it does not recur, repeat through several combat and tracker transitions before considering it resolved.
5. If it recurs, disable only the Objectives module, reload, and repeat the same scenario.
6. Preserve any new error export in `new_issue.txt`.

### Interpretation
- Error stops with Objectives disabled: continue isolating Objective Tracker writes.
- Error persists with Objectives disabled: move the audit boundary outside that module.
- No recurrence across repeated tests: record the clean run while retaining caution because the original taint was event-specific.


## 5. Remaining Aura Migration, Presentation, And Performance
This is an implementation group rather than one pass/fail test.

### Migration And Presentation
- The obsolete Static and Long presets and their shared scanner have been removed; validate the surviving managed Static / Long Buffs frame only.
- Managed icon cooldown swipe is not implemented; add and bind it natively before testing it.
- Validate Short Buffs beside Timed Buffs with its default 300-second maximum: a helpful Aura with a total duration at or below five minutes must appear in both, a longer timed Aura only in Timed Buffs, and permanent Auras in neither. Confirm Short remains ordered by next expiration and that changing Max Duration Sec updates both Bar and Icon modes without reload, Lua errors, secret-value errors, or blocked actions across combat.
- Validate Static / Long Buffs learning in Bar and Icon modes: acquire readable permanent, longer-than-five-minute, and Short buffs outside combat; only the first two should appear. Reload and confirm the learned inclusion persists. Enter combat, add/remove known buffs, and confirm native display updates without addon Aura reads or blocked actions. Return OOC with a changed readable duration and confirm reclassification. Clear Learned Buffs OOC and confirm the frame empties, then relearns active helpful Auras; confirm the button cannot mutate the cache in combat.
- Validate Frame BG on Short Buffs, Static / Long Buffs, Timed Buffs, and Debuffs in Bar and Icon modes: local Frame BG should toggle immediately, Aura Shared BG Colors participation should force it visible and apply the shared Frame BG color, and the matching Buff or Debuff All the Colors override should replace the final RGBA independently. With no matching Auras, the background must remain one configured-width row; as Auras populate, native-visibility extension rows must grow without gaps, overlapping alpha, stale rows, Lua errors, or blocked actions. Repeat OOC, in combat, and after returning OOC.
- Change Bar BG and non-duration bar-text settings while managed Auras are visible and out of combat. Record which changes apply immediately and which require reload or group rebuild.

### CDM Regression
Use `internal_dev/tests_tools/aura_frames_cdm_regression.md` for the complete matrix.

- Test Divine Protection and Blessing of Freedom across Essential and Utility.
- Active Aura duration must appear before cooldown, including when the Aura expires during combat.
- Moving a spell between CDM groups must not leave a stale spell name or icon.

### Performance Run
1. Follow the `/lstprofile` workflow in `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`.
2. Collect roughly 60–100 seconds of sustained combat and record the Timer Tick setting.
3. Preserve the report for comparison with the 2026-06-27 Aura Frames baseline.
4. Remove the temporary profiler probe from `LsTweeks.toc` when performance work closes.
