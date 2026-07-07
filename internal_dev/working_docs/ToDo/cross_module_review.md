# Cross Module Review
Temporary follow-up notes for patterns found while reviewing one module that may deserve a focused pass across other modules.


## Table of Contents
- [Follow-Ups](#follow-ups)


## Follow-Ups
1. Audit state-machine helper functions for hidden caller-order dependencies like Player Frame latent trap 1. Look for functions that set runtime state to idle/normal while combat, enablement, visibility, or lifecycle flags still indicate a guarded state, and verify they are correct without relying on the caller to immediately run a full refresh. [headless-testable: the lua_tests harness can call each state helper in isolation (no follow-up refresh) and assert the resulting state against the combat/enablement flags — pin each audited helper with a test as it is reviewed.]
2. Audit duplicated setting numeric metadata across modules. Look for min/max/step/default values repeated between defaults files, runtime clamps, GUI controls, and reset/sync helpers; prefer defaults-owned metadata for numeric ranges while GUI files own only labels, control keys, layout, and tooltips. [headless-testable: for modules with public clamp helpers or runtime getters, assert boundary clamping from the centralized metadata.]
3. Audit duration-based animations and timed visual progress for nominal-interval drift. Look for ticker/OnUpdate code that advances progress by a fixed interval per callback; when a user-facing duration should mean real elapsed time, prefer cached `GetTime()` start timestamps. Do not apply this to debounces, event batching, polling, or retry timers where exact visual duration is not the contract. [headless-testable: where the stub clock can skip ahead, assert a delayed tick catches up to the configured duration instead of requiring every nominal interval callback.]
4. Audit no-op animation and periodic-work refresh paths. Look for refresh/update handlers that restart tickers, OnUpdate loops, scans, or animations when current state already equals the target; skip or collapse the work when the refresh can apply the final state once. [headless-testable: drive the module to the steady state, trigger its public refresh, and assert no new ticker/OnUpdate/scan work remains queued.]
