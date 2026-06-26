# Aura Frames Memory

Important `aura_frames` keys:
- Session/UI: `last_tab_index`, `last_frames_node`, `last_profile_name`

- Global AF settings: `short_threshold`, `enable_blizz_buffs`, `enable_blizz_debuffs`, `snap_to_grid`, `show_grid`, `show_bar_section_outlines`

- Timer fallback: `timer_number_font`, `timer_number_font_size`, `timer_number_font_bold`

- Preset per-category keys: `<setting>_<category>` such as `show_static`, `color_debuff`, `scale_short`

- OOC fade: preset frames use `fade_ooc_<category>`, `ooc_alpha_<category>`, `fade_delay_<category>`, and `fade_length_<category>`; custom frames use flat `fade_ooc`, `ooc_alpha`, `fade_delay`, and `fade_length`. Fade timing defaults are 2s delay and 3s fade length. Legacy global CDM fade keys are migrated into per-CDM-frame settings when missing.

- Aura Frames OOC fade immediately restores full alpha while the mouse is over title bars, the resize handle, or visible icons/bars; leaving the visible frame controls resumes the configured delay/fade.

- Timer swipe keys: preset frames use `timer_swipe_<category>` and custom frames use `timer_swipe`; Bar Mode suppresses normal icon timer swipes regardless of the saved timer swipe value, and CDM cooldown-mode swipe overlays intentionally remain visible even when timer swipe is off.

- Aura cancel modifier: `cancel_modifier` is a global Aura Frames setting (`OFF`, `CTRL`, `ALT`, `SHIFT`; default `CTRL`). Modifier + right `OnMouseUp` cancellation is out-of-combat only, owned by `M.try_cancel_aura_icon()` in `af_functions.lua`, and only cancels auras resolved through a fresh `HELPFUL|CANCELABLE` scan.

- Positions: `aura_frames.positions.<category> = { point, x, y }`

- Custom frames: array entries with `id`, `name`, filter fields, flat presentation keys, and `position`

- Profiles: complete Aura Frames snapshots excluding editor/session state such as selected tabs/nodes, grid visibility, and debug outlines


## Ownership

- Built-in category metadata lives in `M.FRAME_DEFS` (`af_defaults.lua`). Derive category lists, labels, CDM viewer names, preset key names, and test labels from it.

- Completed Aura Frames feature notes are consolidated in `internal_dev/completed_features/aura_frames.md`.

- Preset categories: `static`, `debuff`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`.

- CDM-backed categories: `essential`, `utility`, `tracked_buffs`, `tracked_bars`.

- First-install visible frames are only `static`, `short`, `long`, `debuff`. CDM defaults keep `show_*`, `move_*`, and `test_aura_*` false.

- Preset DB keys use `aura_frames.<setting>_<category>`; custom frame entries use flat keys.

- Preset and custom frame settings share the same presentation model via normalized `frame_config.keys` and `build_frame_settings_panel()` in `af_gui_frame_builders.lua`.


## Runtime Gates And Refresh

- Runtime module gating is centralized through `M.MODULE_KEY`, `M.is_runtime_enabled()`, and `M.stop_runtime()`. Keep Settings Module Enabler checks routed through those helpers instead of repeating direct `addon.is_module_enabled("aura_frames")` checks across runtime files.

- Frame processing is enabled-rooted. Disabled frames must not do move-shell work, previews, scans, render, layout, or CDM viewer prep.

- Re-enabling the Aura Frames module must mark the aura scan dirty, restart runtime services, then refresh/rebind all existing frames. Do not rely on individual frame enable checkboxes to recover icon contents; that masked a stale/empty shared-scan state where frame shells/title bars appeared without icons after module re-enable.

- Blizzard `BuffFrame` / `DebuffFrame` suppression must preserve Blizzard-owned events and scripts. Use addon-owned hide state plus alpha/mouse suppression; the one-time `OnShow` hook may reapply alpha/mouse only, never `Hide()`. Restore by clearing LsTweeks' forced-hidden state and alpha/mouse settings only. Do not call `Hide()`, `Show()`, `UpdateShownState()`, `UpdateAuras()`, `UnregisterAllEvents()`, register guessed restore events, or replace scripts on those frames; direct hidden-state changes tainted Blizzard's secret `expirationTime` arithmetic in `BuffFrame:UpdatePlayerBuffs()`.

- Use `M.get_frame_activity_state()` for activity decisions and `M.cdm_category_needs_viewer()` for CDM prep.

- UNIT_AURA is batched at `UPDATE_INTERVALS.aura_event_bucket`; timer text/bar updates tick at `UPDATE_INTERVALS.aura_visible_icon_tick`.

- General CPU profiling workflow lives in `performance_profiling.md`; this file keeps only Aura Frames-specific profiling conclusions.

- `aura_event_bucket` remains `0.20s`. Raising it would reduce scan/render frequency only by delaying real aura appearance/removal updates, so treat any future increase as a visible-latency experiment, not a low-risk CPU cleanup.

- 2026-06-24 visible-icon tick profiling with combat timing showed the ticker cost scales almost linearly with `aura_visible_icon_tick`: `0.10s` baseline was 9.57 calls/sec and 2.98ms/sec combat-normalized, `0.15s` was 6.54 calls/sec and 2.02ms/sec, and `0.20s` was 4.98 calls/sec and 1.50ms/sec. Treat this as a tick-rate tradeoff: the CPU win is real and expected, visual difference was minor, and the user-facing setting should stay limited to the three measured choices (`0.10s`, `0.15s`, `0.20s`).

- `render_aura_map()` stores `frame._display_count`; `tick_visible_icons()` should tick only displayed pooled icons, not the full pool.

- Aura Frames visible-icon ticker is managed on demand by `M.refresh_visible_icon_ticker()` / `M.ensure_visible_icon_ticker()`. It starts only when visible rendered icons need timer/bar/preview/CDM cooldown updates and cancels itself when no frame needs ticking.

- CDM refresh scheduling is centralized in `M.queue_wow_cooldown_refresh(profile)` (`af_main.lua`). Use profiles `"immediate"`, `"startup"`, `"settings"`, `"hook"` instead of local timer chains.

- CDM viewer frames are alpha-hidden with mouse disabled; do not `Hide()` them or they stop producing useful child state.

- Enabled LsTweeks CDM frames require the matching Blizzard CDM Edit Mode Visibility to be `Always`. `M.prepare_blizz_cdm_viewer(category)` enforces this outside combat before showing/prepping the viewer, then `M.update_blizz_cdm_visibility(category)` applies the user-facing alpha hide if requested.

- When a CDM hide setting is off, leave the matching Blizzard viewer under Blizzard control except for restoring a viewer that LsTweeks knows it previously alpha-hidden. Do not treat arbitrary alpha-zero state as addon-owned; Blizzard/WoW CDM settings may intentionally hide a viewer.

- Do not write addon metadata directly onto Blizzard CooldownViewer frames or child item frames. Store CDM hook/read state in addon-owned weak tables keyed by the Blizzard frames; direct `_lstweeks_*` fields on CDM internals are a taint risk during combat refresh.

- Public `C_CooldownViewer` APIs do not expose enough live rendered state to replace CDM viewer child reads/hooks. They provide category cooldown IDs/static metadata/layout/availability/alert types, but not active aura instance IDs, rendered child order, per-item active state, or cooldown widget timing. Prefer Blizzard child mixin methods such as `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()` before fallback field reads.

- CDM Blizzard-viewer hide settings must be applied for every CDM category on startup/reload, independent of whether the matching addon CDM frame is enabled.

- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.

- CDM cooldown-mode entries must transition from active aura display to grey/cooldown display while already in combat. Divine Protection on Utility is the regression test: cast out of combat, enter combat, let the active aura expire, and verify the cooldown appears without waiting for combat exit. Do not gate cooldown fallback only on a missing child aura instance ID; Blizzard children can retain stale aura instance state after the active aura is gone.

- CDM viewer child frames are reused by Blizzard across categories/spells. When cached child identity changes (`cooldownID` or spell ID), clear the addon-owned child-state name/icon before refilling them. Do not revert this: stale child display caches caused Utility to render active/cooldown states with mismatched Essential spell identity.


## Scanning, Rendering, Timers

- Aura classification uses live timing plus scan-local old-map fallback for secret fields. Do not reintroduce learned static/long spell tables.

- `update_auras()` still owns the necessary scan/render pipeline for enabled frames. Live aura data, CDM child state, custom filter results, test previews, timer/bar metadata, display count, height, and ticker eligibility can change independently, so do not skip the whole update path without a new narrow proof.

- `M._aura_map` remains the master auraInstanceID map. `M.unified_scan()` rebuilds `M._aura_maps_by_category` as derived preset buckets each scan.

- Preset static/short/long/debuff frames can render directly from scan-built category buckets when no test preview mutation is needed. Profiling showed the old preset bucket copy was below the report cutoff, so this is a safe cleanup rather than a major CPU target.

- Sorted aura ID results are shared in `af_render.lua`; invalidate them through `M.clear_sorted_aura_ids_cache()` when aura data is marked dirty or rescanned.

- `render_aura_map()` reuses timer behavior for preset frames and caches timer behavior by category for custom frames during each render. Keep timer behavior resolution centralized; do not reintroduce per-icon timer behavior lookups.

- The render display-signature skip is intentionally conservative. It must be blocked by test previews, secret values, `scan_remaining`, unstable timing, or changed identity/visual/cooldown/stack/order data to avoid stale icon visuals.

- Frame-local runtime config cache is shared between `update_auras()` and layout setup for scalar/layout values, including copied scalar color components. Invalidate it through existing preset/custom settings updates, resize refresh, profile/reset refresh, and module re-enable refresh paths instead of adding a broad global cache.

- Render helpers guard stable visual setters where practical; timer countdown and bar progress must continue updating live.

- Custom frames are AuraFilters-driven, not whitelist-driven. They scan with `C_UnitAuras.GetAuraDataByIndex("player", i, M.get_custom_aura_filter(entry))`.

- Custom scan results are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; aura-affecting events clear the cache.

- Narrowing custom scans from `UNIT_AURA` payloads remains higher risk because custom filters/modifiers, secret values, full updates, and threshold/category changes can invalidate a simple affected-aura path.

- Timer text enable/format behavior is centralized in `af_functions.lua` via `M.get_timer_behavior()` and `M.is_timer_text_enabled()`. Timer alignment remains layout behavior in `af_icon_layout.lua`.


## Position, Drag, Resize

- Aura frame positions are stored as unscaled UIParent-center coordinates.

- CDM default positions are dynamic: new/missing CDM positions are placed outside the current main GUI right edge with a 32px gap via `M.refresh_cdm_default_positions()` / `M.apply_cdm_default_positions_to_db()`.

- New custom frame default positions also use the current main GUI right edge with a 32px gap; existing saved/profile custom positions are not overwritten.

- Use `M.apply_frame_position()`, `M.read_frame_position()`, `M.sync_frame_position_to_db()`, `M.apply_saved_frame_position()`, and `M.sync_frame_position_from_drag()` rather than branching on preset vs custom manually.

- Drag/resize state is centralized through `M.start_frame_drag()` / `M.stop_frame_drag()` and `frame._is_user_positioning`.

- Runtime refreshes, especially CDM refreshes, must not reapply saved anchors, scale, size, layout, or height while the user is positioning.

- `update_auras()` guards stable frame-shell setters for scale, position, size, height, alpha, backdrop, and move-shell visibility.

- Move Reset uses `M.create_move_reset_button()` and `M.reset_frame_move_placement()`. It resets position/width, not Move Mode.


## Profiles And Reset

- Aura Frame Profiles live under `M.db.profiles`; save/load is owned by `af_profiles.lua` with an explicit schema.

- Loading a profile is blocked in combat. It replaces `M.db.custom_frames`, creates missing custom runtime frames, then runs reset refresh.

- General reset uses `CreateModuleReset(..., opts)` with checked-by-default **Keep Profiles**. When unchecked, `profiles` and `last_profile_name` must be cleared and cached profile UI refreshed.

- If reset replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present.

- There is no legacy saved-profile corpus for Aura Frames as of 2026-06-21. Do not revisit deleted/renamed custom-frame profile compatibility unless real saved variables are found or profile storage is intentionally changed; for storage changes, create synthetic profiles specific to that change.


## GUI

- `af_gui.lua` owns the shell: tabs are **General**, **Frames**, **Profiles**.

- `M.BuildSettings()` stays as the tab-shell coordinator and routes through local helpers plus a small `context` table.

- `af_gui.lua` keeps the Profiles tab builder local. `M.build_general_tab` and `M.build_frames_tab` remain exported because they live in separate Aura Frames GUI files and are called by the shell.

- `af_gui_tree.lua` owns the Frames sidebar groups: **Buffs**, **WoW Cooldown**, **Filters**.

- `af_gui_frame_builders.lua` owns General, preset/CDM, custom settings, and custom filter panels.

- `M.create_settings_grid()` in `af_gui_grid.lua` is a compatibility wrapper around the shared `addon.CreateSettingsGrid()` helper in `functions/layout_grid.lua`. Use the shared helper for new row/column settings grids instead of duplicating grid math inside modules.

- Aura Frames frame settings use `grid:stack_below()` for repeated in-cell stacks. Keep color pickers grid-placed in their own columns so centering comes from `CreateSettingsGrid()`, not manual offsets. In-game visual check passed on 2026-06-25.

- Aura Frames tab and tree heights derive from `addon.main_frame:GetContentAreaSize()`, so the main settings window height in `core/main_frame.lua` is the single height knob.

- CDM controls are source-specific additions layered through `opts.build_source_controls`.

- Shared presentation controls stay in the common builder; use hooks only for real source-specific behavior.


## Debug, Grid, Style

- Debug outlines: `M.db.show_bar_section_outlines`; remove tagged textures with `Hide()` + `SetTexture(nil)`, not `SetParent(nil)`.

- Screen grid: `M.snap_to_grid()`, `M.snap_frame_position()`, `M.set_grid_visible()`. Grid preserves flush screen-edge positions before rounding.

- Riveted panel style: `addon.ApplyRivetedPanelStyle()` / `addon.AddRivetCorners()`.

- `addon.CreateRivetedPanel()` owns default text padding through `addon.RIVETED_PANEL_STYLE.padding`; callers should not clear/reanchor returned text just to avoid rivets.

