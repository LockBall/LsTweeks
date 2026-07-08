# Objectives Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/objectives/`. Full reads: `ob_defaults.lua`, `ob_main.lua`, `ob_position.lua`, `ob_auto_collapse.lua`, `ob_section_count.lua`, `ob_background.lua`; supporting reads of `functions/table_utils.lua`, `functions/color_picker.lua`, `functions/layout_grid.lua`, `functions/checkbox.lua`, `core/init.lua` (UPDATE_INTERVALS), and `LsTweeks.toc` load order. Deprecated-API sweep clean: no `GetSpellInfo`, no legacy spell globals; C_QuestLog/C_ContentTracking paths are modern and nil-guarded; no secret-value surfaces in this module. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Potential Bugs To Verify](#potential-bugs-to-verify)
- [Latent Traps](#latent-traps)
- [Optimization Candidates](#optimization-candidates)
- [Minor Cleanups](#minor-cleanups)
- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Potential Bugs To Verify
1. [x] Auto-Collapse tracker mutations are not combat-deferred. Fixed by routing collapse/expand through the Objectives combat deferral path, including queued next-frame collapse work that straddles combat start. Added `test_ob_auto_collapse.lua` coverage for direct in-combat apply and queued timer recheck; module memory now lists Auto-Collapse in the protected tracker mutation scope. Optional in-game smoke: toggle an Auto-Collapse checkbox during combat with a quest item button visible in the tracker and confirm no blocked-action warning.
2. [x] Module-disable opacity restore may not restore the user's real Edit Mode value. Fixed the immediate divergence by making module-disable restore write full opacity through Edit Mode when available, instead of only setting live `ObjectiveTrackerManager` opacity. Added `test_ob_background.lua` coverage for the disable path after `WoW BG` writes 0.
3. [x] `background_color_reset_pending` is never set to `true` anywhere in the repo, so the related non-cancel color-change branch was dead. Removed the unused flag and unreachable branch; the explicit reset path still auto-enables Border, and the separate cross-session auto-enabled flag issue remains tracked by potential bug 4.
4. [x] Stale `background_color_auto_enabled_border` across color-picker sessions. Fixed by adding a shared color-picker `open` callback reason and clearing the Objectives auto-border flag whenever a new picker session starts, so a later cancel cannot undo a previously accepted reset. Added `test_ob_background.lua` coverage for reset, reopen, cancel keeping Border enabled.


## Latent Traps
1. [x] `get_count_settings()` arity mismatch (`ob_section_count.lua:66-77`): the disabled path returned two values while the enabled path returned four. Fixed the disabled path to return four explicit false values and added `test_ob_section_count.lua` coverage for the helper contract.
2. [x] `hide_background_color_frame()` cleaned only legacy overlay fields that nothing creates anymore, while the live center overlay is managed by `apply_center_color_overlay()`. Removed the dead legacy cleanup branches and replaced the call site with an explicit `reset_background_regions()` helper.
3. [x] Unreachable border block in `set_background_color_enabled()`: `is_background_border_enabled()` does not depend on `background_color_enabled`, so `border_was_enabled ~= border_is_enabled` could never be true from this toggle. Removed the dead border offset/sync block so the code matches the documented independence of Border from the color toggle.
4. [x] `DEFAULT_BACKGROUND_COLOR` aliased the live defaults table (`DEFAULTS.objectives.background_color`). Replaced it with a file-scope copy so future accidental writes through the local default color cannot mutate module defaults for the session.
5. [x] Diagnostics-only falsy swallow in region status: the old `method and method(region) or nil` pattern reported `nil` when a region method returned `false`. Added a helper that preserves explicit falsy method results for `/lst status objectives` region diagnostics.


## Optimization Candidates
1. [x] `mark_tracker_dirty()` on already-satisfied state (`ob_auto_collapse.lua:110-112`, `128-130`): when the tracker was already collapsed/expanded, apply still forced a Blizzard relayout via `MarkDirty` or `ObjectiveTrackerManager:UpdateAll()`. Removed the dirty relayout helper and made already-satisfied collapse/expand state a no-op; added Auto-Collapse tests for already-collapsed and already-expanded paths.
2. [x] `sync_objective_border()` re-anchored unconditionally on every background sync. Cached the border anchor signature and shown state so unchanged syncs skip `ClearAllPoints`/`SetPoint` and repeated `Show`/`Hide`; added background tests for redundant sync calls.
3. Quest log scan frequency (`ob_section_count.lua:113-136`, `280-287`): with the Quests counter enabled, every QUEST_LOG_UPDATE burst triggers a `sync_section_titles` at next-frame debounce, each iterating the whole quest log with one `C_QuestLog.GetInfo()` table allocation per entry. The displayed count does not need frame accuracy; using `fifth_sec` for event-driven `queue_title_sync` would coalesce bursts at near-zero UX cost.
4. `get_priority_module_for_anchor()` allocates a `priority_modules` set per call (`ob_background.lua:613-635`) inside the `SetPoint`-hook path, which can churn while the tracker is collapsed with a blocked anchor. Iterating `tracker.modules` and walking each candidate's ancestry directly (or reusing a scratch table) avoids the allocation.
5. Per-sync allocation before the signature skip (`ob_background.lua:283-296`, `409-420`, `519`): every `sync_objective_background` builds a fresh color table (`get_background_color`) plus ~6 strings (`get_color_signature`/`get_background_signature`) even when the resulting signature matches and the call early-returns. Setting a dirty flag from the GUI write paths, or comparing raw db fields before building strings, would remove the churn from the hooked tracker-update path.


## Minor Cleanups
1. Duplicate `get_objective_tracker()` in `ob_position.lua:42-48` and `ob_background.lua:92-98`; identical body. Hoist one copy onto `M` per the one-deterministic-path rule.
2. Settings-page chrome constants duplicated across four files: `group_offset_x = 20`, `group_padding_x = 12`, `grid_offset_x = 12`, `grid_offset_y = -37` repeat in `ob_position.lua:13-23`, `ob_background.lua:32-42`, `ob_auto_collapse.lua:11-23`, `ob_section_count.lua:11-23`, and the page stacking order lives in scattered absolute `group_offset_y` values (-20, -180, -340, -514). Violates the constants-owned-in-one-place rule; changing one group's height requires editing other files. A single page-layout table (order + heights) in one owner file would fix both.
3. `set_wow_background_opacity()` double-writes on success (`ob_background.lua:320-345`): after `OnSystemSettingChange` (or `UpdateSystemSettingValue`) succeeds it also calls `ObjectiveTrackerManager:SetOpacity(percent)`. If the belt-and-suspenders write is load-bearing, comment why; otherwise drop it.
4. `set_count_setting()` calls `ensure_title_event_frame()` then `update_title_event_registrations()`, which calls ensure again (`ob_section_count.lua:376-377`, `317-318`).
5. `show_background_to_header()` computes `background_points_to_header(tracker, background)` twice (`ob_background.lua:587-589`); reuse the first result.
6. Naming drift: module memory calls the color toggle `Color BG`, the code label is `Custom BG` (`ob_background.lua:1116`). Align the memory wording on its next edit (do not rename the control without a request).


## Reviewed And Confirmed Deliberate
Checked against `proj_mem/modules/objectives.md` and code comments; do not re-flag without new evidence.
- `WoW BG` unchecked writing 0 into Blizzard's Edit Mode opacity setting: documented as the feature (mirrors the Edit Mode control). The 2026-06-28 `and/or` regression is properly fixed with an explicit `if not show_blizzard_background then opacity = 0 end` (`ob_background.lua:559-561`).
- Combat deferral for position apply/restore, move mode, background color/opacity, anchor correction, border sync, and `tracker:Update()` replay is complete and replays correctly: regen handler (`ob_main.lua:134-143`) routes enabled state through `apply_objectives -> apply_background` (which owns position + move mode, `ob_background.lua:908-926`) and disabled state through `restore_background`; settings values save immediately in combat as documented. The only gap found is Auto-Collapse (Potential Bugs item 1).
- Double PLAYER_ENTERING_WORLD apply (immediate + 0.2s, `ob_main.lua:128-132`) and the persistent Blizzard_ObjectiveTracker ADDON_LOADED apply path: documented `ObjectiveTrackerManager:Init()` race; remove only after in-game testing proves redundancy.
- `tracker:Update()` called once from addon context on module disable and on the `WoW BG` toggle (out of combat): documented handback of background layout to Blizzard.
- Force-expand only for `hasDisplayPriority` anchors, 2s collapse grace window delaying force-expansion but not ordinary anchor cleanup, and the `background_adjusting` guard around owned `SetPoint` calls: all documented in module memory.
- Disabling the module does not force-expand collapsed sections; unchecking an Auto-Collapse option calls `SetCollapsed(false)` once: documented.
- Objectives intentionally has no module reset panel: documented.
- Position offsets are relative to a once-captured startup center anchor (`capture_objective_position_base`, `ob_position.lua:103-123`); later Blizzard/Edit Mode moves are deliberately not re-baselined: documented coordinate design.
- `background_alpha` slider dual path (debounced shared callback plus `HookValueChanged` immediate preview, `ob_background.lua:1140-1142`): documented workaround for the debounced shared slider.
- Section Count design: event registration gated per setting, restore-Blizzard-title-once semantics via `title_applied_counts`, signature/text skip before `SetText`, quest scan exclusion set, capacity via `C_QuestLog.GetMaxNumQuestsCanAccept()`: all documented. Header `SetText` is an unprotected FontString write, so its absence from the combat deferral list is sound.
- Border inferred on for non-default `background_color` when `objective_tracker_border` is unset (`ob_background.lua:178-188`): documented; uses explicit `~= nil` checks, no falsy-fallback trap.
- Color picker reset auto-enabling Border plus the border position offset adjustment (`ob_background.lua:968-998`): documented behavior (its cross-session flag staleness is Potential Bugs item 4).
- The owned center color block living on the tracker (NineSlice parent) rather than the NineSlice itself keeps it independent of NineSlice alpha, matching the documented `Color BG`/`WoW BG` independence.
