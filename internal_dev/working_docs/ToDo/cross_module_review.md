# Cross-Module Review Patterns
Reusable findings from recent Audio Volumes reset, preview, and profile work. Apply these checks across feature modules before treating a workflow as complete.


## Table of Contents
- [Reset And Profile References](#reset-and-profile-references)
- [Delayed Restore Ownership](#delayed-restore-ownership)
- [Temporary-State Symmetry](#temporary-state-symmetry)
- [UI And Runtime Synchronization](#ui-and-runtime-synchronization)
- [Shared Factory Contracts](#shared-factory-contracts)
- [Priority Scan Targets](#priority-scan-targets)


## Reset And Profile References
- [ ] Check whether ARM reset, profile load, defaults application, or table replacement replaces nested DB tables while built controls, callbacks, dropdowns, or cached panels retain old table references.
- [ ] Rebuild affected panels or resolve the live DB table at interaction time; do not make a control only appear synchronized while its write callback still targets an orphaned table.
- [ ] Cover the replacement path with a headless test that proves post-reset/profile-load interaction writes the fresh table and leaves the stale table unchanged.


## Delayed Restore Ownership
- [ ] Find previews, debounce callbacks, timers, tickers, delayed C_Timer work, and deferred restores that can run after a newer user edit, reset, disable, profile load, or panel rebuild.
- [ ] Cancel stale work or update its restore/cache state so it cannot overwrite the newer value.
- [ ] Verify both the normal completion path and interruption by a newer user action.


## Temporary-State Symmetry
- [ ] Compare every read path with its matching write path when a temporary runtime override is active. Fishing/Combat/Quick Pick-style states must use the same activation guard for cached normal values.
- [ ] Confirm copy, seed, default, display, and restore helpers read the intended normal or temporary source.
- [ ] Add a focused test for each temporary state that differs from the primary state.


## UI And Runtime Synchronization
- [ ] After reset/profile load, synchronize runtime state, events, timers, control values, cached panels, selected entries, and any module-specific frame ownership.
- [ ] Reset session-only flags and test modes when they would otherwise reactivate unexpectedly after defaults restore.
- [x] Skyriding Vigor reset clears Fill Test, Race Profile Test, and race-active session state, and its General reset retains the active-flight gate.
- [ ] Recheck disabled and combat-locked behavior; a reset/load must not leave runtime active against newly replaced settings.


## Shared Factory Contracts
- [ ] Shared factories own shared safety behavior: confirmation dialogs, deep-copy isolation, versioned profile envelopes, combat guards, and public control synchronization APIs.
- [ ] Module profile files own only module-specific snapshot allowlists, migrations, validation, and runtime application.
- [ ] Audit every existing consumer when changing a shared factory so behavior remains consistent across Aura Frames, Audio Volumes, Objectives, Skyriding Vigor, and future modules.


## Priority Scan Targets
- [ ] Aura Frames: profile/reset custom-frame references, cached panel/tree ownership, delayed CDM/aura refresh work, and profile UI rebuilds.
- [ ] Objectives: new reset/profile application, Objective Tracker control synchronization, background deferred work, and session move-mode state.
- [ ] Skyriding Vigor: reset/profile test flags, active normal/race profile switching, fill/fade timers, and flight-lock synchronization.
- [ ] Player Frame: fade timers, settings callbacks, and any profile/reset work added later.
- [ ] Audio Volumes: continue the active review through Latent Traps, Optimization Candidates, and Minor Cleanups using these patterns.
