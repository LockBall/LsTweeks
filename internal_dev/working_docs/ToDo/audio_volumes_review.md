# Audio Volumes Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/audio_volumes/`. Full reads: `av_main.lua`, `av_functions.lua`, `av_defaults.lua`, `av_logic_main.lua`, `av_logic_situations.lua`, `av_gui.lua`, `av_gui_general.lua`, `av_gui_specifics.lua`, `av_gui_situations.lua`. Supporting partial reads for cross-checks: `functions/module_reset.lua`, `functions/table_utils.lua`, `functions/slider_with_box.lua` (write path only), `core/main_frame.lua` (category tab build only). Not reviewed: `sounds/` reference docs, `core/minimap_button.lua`. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Potential Bugs To Verify](#potential-bugs-to-verify)
- [Latent Traps](#latent-traps)
- [Optimization Candidates](#optimization-candidates)
- [Minor Cleanups](#minor-cleanups)
- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Potential Bugs To Verify
- [x] 1. Specifics controls retained stale target tables after ARM reset. `BuildSoundTargetSliderPanel` captured the target DB during construction, so post-reset slider interactions could update an orphaned table. Fixed by resolving `M.get_target_db(target_key)` in interaction callbacks; focused reset coverage verifies the fresh table is written.
- [x] 2. Situations controls retained stale Fishing, Combat, and Quick Pick tables after ARM reset. Rebuild the Situations tab before control synchronization so callbacks and sliders capture the fresh profile tables; focused coverage verifies a Fishing slider writes the reset table.
- [x] 3. Situations list and cached panels were not rebuilt after ARM reset. The same tab rebuild replaces list/panel closures and removes controls for reset-deleted custom Quick Picks; focused coverage verifies the stale custom control is gone.
- [x] 4. `read_channel_percent` ignored an active manual Quick Pick. The cached-profile read guard now matches the write guard, so Normal controls and copy/seed helpers use saved normal values while a Quick Pick is active; focused coverage verifies the read path.
- [x] 5. Normal-panel test-sound preview wrote CVars. The no-profile preview path now plays the selected test sound directly without caching, writing, or scheduling a CVar restore; focused coverage verifies that contract.
- [x] 6. A situation-preview restore could overwrite a Normal Volume edit made during its two-second window. Normal edits now update the pending preview restore cache, so the preview ends at the new normal value; focused coverage verifies the restore.


## Latent Traps
- [x] 1. Enabling Fishing Focus while already channeling Fishing did not apply the profile until the next cast. `sync_fishing_focus_events` now checks `UnitChannelInfo("player")` after registration and applies Fishing Focus for spell `131476`; focused coverage models the existing channel. In-game check: toggle Fishing Focus once during an active Fishing cast and confirm the immediate volume change.
- [x] 2. `set_manual_situation_enabled("fishing"/"combat", true)` could disable every Quick Pick without enabling a triggered key. The manual-only API now resolves keys from `get_manual_situation_entries()` and rejects anything else before mutating state; focused coverage verifies Fishing leaves the active Quick Pick unchanged.
- [x] 3. `handle_event` returns after the first playable slot. Kept deliberately: `SOUND_EVENT_TARGETS` has a one-target-per-event contract, documented both where that map is built and at the early return; revisit the handler before assigning any event to multiple targets.
- [x] 4. Custom-situation control keys used mixed sanitized and raw forms. `get_situation_control_key()` now owns the raw `custom:N` convention for custom sliders and enable controls, and focused coverage verifies no second enable-key form is created.
- [x] 5. Post-delete selection had two owners: the data layer chose Fishing, then the GUI chose Quiet Custom. Deletion now clears only an invalid saved selection and restores Normal Volumes when it removes the enabled Quick Pick; the GUI alone selects the next visible panel. Focused coverage verifies the runtime fallback and cleared stale selection.
- [ ] 6. Deleted custom-situation controls linger in `M.controls`. Current DB-driven sync skips them, but cleanup during list/panel removal would make ownership explicit.


## Optimization Candidates
- [ ] 1. `apply_audio_volumes()` runs on every slider step during drag (`av_gui.lua:191-229` calls it at three exits): a full mute/unmute pass over all targets plus `rebuild_event_cache()` plus `sync_registered_events()` per 5% step, while the audible preview is already debounced at 0.12s (`av_logic_main.lua:183`). The mute decision only depends on `sound_off`/`use_original`, not the preset level, so mid-drag calls are redundant `MuteSoundFile` churn; debounce the apply alongside the preview or skip it when only `preset` changed between non-off values.
- [ ] 2. `resync_situation_runtime` on a Quick Pick slider change re-applies the active situation even when the edited situation is not the active one (`av_gui_situations.lua:285-293` routes to `resync_manual_situation_profile`, which applies `M._manual_situation_active_key` unconditionally): five redundant `SetCVar` writes per drag step while editing an inactive Quick Pick. Early-out when the edited entry key is not the active key.
- [ ] 3. `get_manual_situation_entries()` (`av_logic_situations.lua:279-299`) rebuilds the entry list and re-runs the per-channel clamp/validate loops in `get_situation_profile_db` on every call; `set_manual_situation_enabled` triggers it twice (directly and via `sync_manual_situation_profile`). Settings-time only, so minor.
- [ ] 4. `handle_delete_situation` calls `M.get_situation_profile_db(delete_key)` twice for the `was_enabled` check (`av_gui_situations.lua:570-573`); fold into one local.


## Minor Cleanups
- [ ] 1. `M._fishing_focus_cached` is a write-only legacy alias (`av_logic_situations.lua:412,527,544`) — never read anywhere in the repo; remove it or comment why it is kept.
- [ ] 2. Inner `situation_grid` local in `create_situation_sliders` (`av_gui_situations.lua:452`) shadows the tab-level `situation_grid` (`av_gui_situations.lua:148`); rename one.
- [ ] 3. Normal-slider defaults seeding has three owners: the build loop (`av_gui_situations.lua:295-299`), `refresh_current_values` (`av_gui_situations.lua:255-270`), and the slider on_change (`av_gui_situations.lua:313-314`) all write `focus_defaults`/`combat_defaults`/`quiet_custom_defaults`. One helper would satisfy the constants-owned-in-one-place rule.
- [ ] 4. `col_align = { "left", "left", "left", "left", "left" }` hardcodes five entries while `column_count = slider_count` is derived from `FISHING_FOCUS_CHANNELS` (`av_gui_situations.lua:159,281`); build the align table from `slider_count`.
- [ ] 5. `play_original_file` unmute loop (`av_logic_main.lua:72-74`) is redundant on its only reachable path (use_original targets are already unmuted by `apply_audio_volumes`); keep as defense with a comment or drop it.
- [ ] 6. `local profile_db = nil` immediately reassigned (`av_logic_situations.lua:451-452`); collapse to one line.
- [ ] 7. `set_quick_pick_from_menu` syncs controls twice, immediately and via `C_Timer.After(0)` (`av_logic_situations.lua:364-373`); if the deferred pass covers a menu-close timing issue, comment it, otherwise drop one.


## Reviewed And Confirmed Deliberate
Checked against `proj_mem/modules/audio_volumes.md`; do not re-flag without new evidence.
- Combat end restores normal volumes rather than returning to Fishing Volumes even if still channeling: `apply_combat_volumes` clearing `_fishing_focus_active` (`av_logic_situations.lua:656`) matches the documented combat-exits-fishing priority. The reverse case (fishing channel starting mid-combat sets the flag and resumes after combat if still channeling) also resolves correctly through `apply_active_sound_channel_profile` priority order.
- Event hot path matches the Event Cache And Performance section: `handle_event` reads only pre-resolved `M._event_cache` slots with no DB/preset/path work (`av_logic_main.lua:193-215`), Off and Original targets create no slots (`av_functions.lua:139-156`), `sync_registered_events` diffs registrations (`av_logic_main.lua:217-244`), and mute/unmute stays outside the hot path. No polling or OnUpdate anywhere in the module.
- `PlaySound(soundKitID, "SFX")` string-channel calls with inline Ketho `param-type-mismatch` suppressions: verified in-game per memory; do not convert to numeric `UISoundSubType`.
- Bloodlust test sound played via `PlaySoundFile(568812)` file-ID branch (`av_logic_situations.lua:505-506`): verified in-game per memory; `PlaySound(568812)` does not work.
- `achievmentsound1` spelling matches Blizzard's original asset naming and the on-disk replacement folder; do not correct in isolation.
- Fishing events registered player-only via `RegisterUnitEvent` and only while enabled; combat events only while enabled; disabled sync branches restore and unregister without creating frames or initializing situation DB values — matches the memory's disabled-sync and lazy-init rules.
- `apply_active_sound_channel_profile` calls `restore_bobber_preview_profile()` before writing runtime CVars (`av_logic_situations.lua:548`) — the documented preview-vs-active-situation ordering rule.
- `create_custom_situation` seeding `last_situation_key` so new Quick Picks open immediately in the unified Situations tab — documented GUI behavior.
- Sound API upvalues resolved once at file load in `av_logic_main.lua:8-12` and reused at call sites — documented ownership rule.
