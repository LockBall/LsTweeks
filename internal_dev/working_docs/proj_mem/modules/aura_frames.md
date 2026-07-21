# Aura Frames Memory
Important `aura_frames` keys:
- Session/UI: `last_tab_index`, `last_frames_node`, `last_profile_name`
- Global AF settings: `short_threshold`, `enable_blizz_buffs`, `enable_blizz_debuffs`, `snap_to_grid`, `show_grid`, `show_bar_section_outlines`
- Timer fallback: `timer_number_font`, `timer_number_font_size`, `timer_number_font_bold`
- Preset per-category keys: `<setting>_<category>` such as `show_static`, `color_debuff`, `scale_short`
- OOC fade: preset frames use `fade_ooc_<category>`, `ooc_alpha_<category>`, `fade_delay_<category>`, and `fade_length_<category>`; custom frames use flat `fade_ooc`, `ooc_alpha`, `fade_delay`, and `fade_length`. `af_defaults.lua` owns the `ooc_alpha` range/step constants (`0.00..1.00`, step `0.05`) so the slider and runtime clamp stay aligned; zero lets users fully hide a faded frame background. Fade timing defaults are 2s delay and 3s fade length.
- Aura Frames OOC fade immediately restores full alpha while the mouse is over title bars, the resize handle, or visible icons/bars; leaving the visible frame controls resumes the configured delay/fade.
- Timer swipe keys: preset frames use `timer_swipe_<category>` and custom frames use `timer_swipe`; Bar Mode suppresses normal icon timer swipes regardless of the saved timer swipe value, and CDM cooldown-mode swipe overlays intentionally remain visible even when timer swipe is off.
- Aura cancel modifier: `cancel_modifier` is a global Aura Frames setting (`OFF`, `CTRL`, `ALT`, `SHIFT`; default `CTRL`). Modifier + right `OnMouseUp` cancellation is out-of-combat only, owned by `M.try_cancel_aura_icon()` in `af_functions.lua`, and only cancels auras resolved through a fresh `HELPFUL|CANCELABLE` scan.
- Positions: `aura_frames.positions.<category> = { point, x, y }`
- Custom frames: array entries with `id`, `name`, filter fields, flat presentation keys, and `position`
- Profiles: complete Aura Frames snapshots excluding editor/session state such as selected tabs/nodes, grid visibility, and debug outlines


## Table of Contents
- [Ownership](#ownership)
- [Runtime Gates And Refresh](#runtime-gates-and-refresh)
- [Scanning, Rendering, Timers](#scanning-rendering-timers)
- [Aura Cancellation](#aura-cancellation)
- [Aura Tooltips](#aura-tooltips)
- [Position, Drag, Resize](#position-drag-resize)
- [Profiles And Reset](#profiles-and-reset)
- [GUI](#gui)
- [Debug, Grid, Style](#debug-grid-style)


## Ownership
- Built-in category metadata lives in `M.FRAME_DEFS` (`af_defaults.lua`). Derive category lists, labels, CDM viewer names, preset key names, and test labels from it.
- The rounded/chamfered background investigation remains in `ToDo/background_shapes.md`. Do not re-add that option without a dedicated tintable asset or NineSlice plan.
- Preset categories: `static`, `debuff`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- CDM-backed categories: `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- First-install visible frames are only `static`, `short`, `long`, `debuff`. CDM defaults keep `show_*`, `move_*`, and `test_aura_*` false.
- Preset DB keys use `aura_frames.<setting>_<category>`; custom frame entries use flat keys.
- `M.normalize_saved_colors()` clamps preset and custom `color`, `bar_bg_color`, `bar_text_color`, `bg_color`, and `timer_color` components at startup and profile load. Keep this normalization before runtime-config caching so edited or malformed saved values cannot reach frame color APIs unchanged.
- Preset and custom frame settings share the same presentation model via normalized `frame_config.keys` and `build_frame_settings_panel()` in `af_gui_frame_builders.lua`.
- Aura update logic is split by runtime responsibility: `af_logic_ticker.lua` owns visible icon timer/bar ticking, `af_logic_native_visibility.lua` owns Blizzard/native BuffFrame, DebuffFrame, and CooldownViewer visibility suppression, and `af_logic_main.lua` owns runtime config cache, OOC fade, and the main per-frame aura refresh pipeline.
- `af_functions.lua` is still a broad Aura Frames shared-helper bucket. Its current ownership includes CDM viewer lookup, frame positioning, custom frame setup, frame/category setting fallback resolution, aura cancellation, timer behavior, timer-boundary normalization, and preview category reclassification. Prefer splitting future work by subsystem instead of adding more helpers there; likely split names are `af_frame_helpers.lua`, `af_settings_helpers.lua`, `af_cancel.lua`, and `af_timer_helpers.lua`.


## Runtime Gates And Refresh
- Runtime module gating is centralized through `M.MODULE_KEY`, `M.is_runtime_enabled()`, and `M.stop_runtime()`. Keep Settings Module Enabler checks routed through those helpers instead of repeating direct `addon.is_module_enabled("aura_frames")` checks across runtime files.
- Frame processing is enabled-rooted. Disabled frames must not do move-shell work, previews, scans, render, layout, or CDM viewer prep.
- Re-enabling the Aura Frames module must mark the aura scan dirty, restart runtime services, then refresh/rebind all existing frames. Do not rely on individual frame enable checkboxes to recover icon contents; that masked a stale/empty shared-scan state where frame shells/title bars appeared without icons after module re-enable.
- Blizzard `BuffFrame` / `DebuffFrame` suppression must preserve Blizzard-owned events and scripts. Use addon-owned hide state plus alpha/mouse suppression; the one-time `OnShow` hook may reapply alpha/mouse only, never `Hide()`. Restore by clearing LsTweeks' forced-hidden state and alpha/mouse settings only. Do not call `Hide()`, `Show()`, `UpdateShownState()`, `UpdateAuras()`, `UnregisterAllEvents()`, register guessed restore events, or replace scripts on those frames; direct hidden-state changes tainted Blizzard's secret `expirationTime` arithmetic in `BuffFrame:UpdatePlayerBuffs()`.
- Tooltip ownership: route Aura icons and settings help through `functions/tooltip.lua`; the complete safety contract and incident history live in `## Aura Tooltips`.
- Use `M.get_frame_activity_state()` for activity decisions and `M.cdm_category_needs_viewer()` for CDM prep.
- UNIT_AURA is batched at `UPDATE_INTERVALS.aura_event_bucket`; timer text/bar updates tick at `UPDATE_INTERVALS.aura_visible_icon_tick`.
- General CPU profiling workflow lives in `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`; this file keeps only Aura Frames-specific profiling conclusions.
- Focused Aura profile history and generated comparisons live in `internal_dev/tests_tools/cpu_profiles/af_cpu_profiles.md`; regenerate the normalized comparison with `internal_dev/tests_tools/cpu_profiles/analyze_af_cpu_profiles.ps1`.
- `aura_event_bucket` remains `0.20s`. Raising it would reduce scan/render frequency only by delaying real aura appearance/removal updates, so treat any future increase as a visible-latency experiment, not a low-risk CPU cleanup.
- Visible-icon ticker cost scales with `aura_visible_icon_tick`; treat the three measured choices (`0.10s`, `0.15s`, `0.20s`) as a CPU/visual-cadence tradeoff, not a per-tick optimization win.
- `render_aura_map()` stores `frame._display_count`; `tick_visible_icons()` should tick only displayed pooled icons, not the full pool.
- Aura Frames visible-icon ticker is managed on demand by `M.refresh_visible_icon_ticker()` / `M.ensure_visible_icon_ticker()`. It starts only when visible rendered icons need timer/bar/preview/CDM cooldown updates and cancels itself when no frame needs ticking.
- CDM refresh scheduling is centralized in `M.queue_wow_cooldown_refresh(profile)` (`af_main.lua`). Use profiles `"immediate"`, `"startup"`, `"settings"`, `"hook"` instead of local timer chains.
- CDM viewer frames are alpha-hidden with mouse disabled; do not `Hide()` them or they stop producing useful child state.
- Enabled LsTweeks CDM frames require the matching Blizzard CDM Edit Mode Visibility to be `Always`. `M.prepare_blizz_cdm_viewer(category)` enforces this outside combat before showing/prepping the viewer, then `M.update_blizz_cdm_visibility(category)` applies the user-facing alpha hide if requested. Capture the prior visibility only when LsTweeks overrides it; module disable restores it through `UpdateSystemSettingValue` after combat when needed, without overwriting an external setting change made while active.
- When a CDM hide setting is off, leave the matching Blizzard viewer under Blizzard control except for restoring a viewer that LsTweeks knows it previously alpha-hidden. Do not treat arbitrary alpha-zero state as addon-owned; Blizzard/WoW CDM settings may intentionally hide a viewer.
- Do not write addon metadata directly onto Blizzard CooldownViewer frames or child item frames. Store CDM hook/read state in addon-owned weak tables keyed by the Blizzard frames; direct `_lstweeks_*` fields on CDM internals are a taint risk during combat refresh.
- Public `C_CooldownViewer` APIs do not expose enough live rendered state to replace CDM viewer child reads/hooks. They provide category cooldown IDs/static metadata/layout/availability/alert types, but not active aura instance IDs, rendered child order, per-item active state, or cooldown widget timing. Prefer Blizzard child mixin methods such as `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()` before fallback field reads.
- CDM Blizzard-viewer hide settings must be applied for every CDM category on startup/reload, independent of whether the matching addon CDM frame is enabled.
- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.
- CDM cooldown-mode entries must transition from active aura display to grey/cooldown display while already in combat. Divine Protection on Utility is the regression test: cast out of combat, enter combat, let the active aura expire, and verify the cooldown appears without waiting for combat exit. Do not gate cooldown fallback only on a missing child aura instance ID; Blizzard children can retain stale aura instance state after the active aura is gone.
- Manual CDM regression matrix: `internal_dev/tests_tools/aura_frames_cdm_regression.md`.
- CDM viewer child frames are reused by Blizzard across categories/spells. When cached child identity changes (`cooldownID` or spell ID), clear the addon-owned child-state name/icon before refilling them. Do not revert this: stale child display caches caused Utility to render active/cooldown states with mismatched Essential spell identity.


## Scanning, Rendering, Timers
- Aura classification uses live timing plus scan-local old-map fallback for secret fields. Do not reintroduce learned static/long spell tables.
- `update_auras()` still owns the necessary scan/render pipeline for enabled frames. Live aura data, CDM child state, custom filter results, test previews, timer/bar metadata, display count, height, and ticker eligibility can change independently, so do not skip the whole update path without a new narrow proof.
- If Aura performance work reopens, start with a focused profile around the regressed row. For render cost, profile `render_aura_map()` and the conservative display-signature skip. For scan/map cost, focus on `unified_scan`, `add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`; preset bucket copying was below the focused-profile report cutoff and should not be treated as the next meaningful CPU target.
- `M._aura_map` remains the master auraInstanceID map. `M.unified_scan()` rebuilds `M._aura_maps_by_category` as derived preset buckets each scan.
- Preset static/short/long/debuff frames can render directly from scan-built category buckets when no test preview mutation is needed. Profiling showed the old preset bucket copy was below the report cutoff, so this is a safe cleanup rather than a major CPU target.
- Sorted aura ID results are shared in `af_render.lua`; invalidate them through `M.clear_sorted_aura_ids_cache()` when aura data is marked dirty or rescanned.
- `M.mark_aura_scan_dirty()` clears custom and sorted scan caches only on the clean-to-dirty transition. Repeated events before the pending unified scan must retain the dirty flag but skip duplicate cache wipes.
- `render_aura_map()` reuses timer behavior for preset frames and caches timer behavior by category for custom frames during each render. Keep timer behavior resolution centralized; do not reintroduce per-icon timer behavior lookups.
- The render display-signature skip is intentionally conservative. It must be blocked by test previews, secret values, `scan_remaining`, unstable timing, or changed identity/visual/cooldown/stack/order data to avoid stale icon visuals.
- Frame-local runtime config cache is shared between `update_auras()` and layout setup for scalar/layout values, including copied scalar color components. Invalidate it through existing preset/custom settings updates, resize refresh, profile/reset refresh, and module re-enable refresh paths instead of adding a broad global cache.
- `af_icon_layout.lua` owns Aura frame content-height calculations through `M.get_aura_frame_height()`. Keep bar, icon, timer, padding, wrapping, and growth dimensions there; `update_auras()` only supplies current layout/runtime state and applies the stable height result. When no layout cache exists, preserve the legacy 44px-per-icon fallback until `setup_layout()` rebuilds cached geometry.
- Render helpers guard stable visual setters where practical; timer countdown and bar progress must continue updating live.
- Custom frames are AuraFilters-driven, not whitelist-driven. They scan with `C_UnitAuras.GetAuraDataByIndex("player", i, M.get_custom_aura_filter(entry))`.
- Custom frames can contain mixed static, short, long, and debuff entries. Bar/timer rendering and visible-icon ticking must treat `entry.category == "static"` as static per icon; do not rely only on `frame.category == "static"` for custom frames.
- Custom helpful scan classification must use `DoesAuraHaveExpirationTime()` and then the previous custom entry category before defaulting unreadable combat-entry timing to short; otherwise static custom bars such as Devotion Aura can empty when the custom scan cache rebuilds on `PLAYER_REGEN_DISABLED`.
- Preserve/snapshot the custom frame's previous `_aura_map` inside `scan_custom_aura_map()` before wiping it when the custom scan cache is being built or extended, so combat-sensitive rescans retain old category/timing fallbacks without copying old maps on the steady cached path.
- Custom scan results are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; aura-affecting events clear the cache.
- Narrowing custom scans from `UNIT_AURA` payloads remains higher risk because custom filters/modifiers, secret values, full updates, and threshold/category changes can invalidate a simple affected-aura path.
- Use a central Aura dispatcher or invasive CDM rewrite only when a focused profile shows a material regression or a concrete behavior issue gives a narrower target.
- Timer text enable/format behavior is centralized in `af_functions.lua` via `M.get_timer_behavior()` and `M.is_timer_text_enabled()`, with formatting in `af_render.lua`: 100d+ uses whole days; 1d–99.9d, 10h–<24h, and 10m–<60m use fixed one-decimal labels; 1h–<10h uses fixed `hmm` fields including `00m`; 1m–<10m uses fixed `mss` fields including `00s`; sub-minute values use fixed decimal seconds. Long timers are right-aligned inside a fixed slot so format changes do not shift their trailing edge.
- Floating-point timer boundaries route through `M.normalize_aura_timer_remaining()` and `M.is_aura_timer_phase_active()` in `af_functions.lua`; do not add local epsilon patches in render, preview, or phase-selection code. The shared epsilon policy clamps final zero states, compensates arithmetic residue only after a countdown step, and advances exact phase boundaries consistently.
- `af_test_aura.lua` owns the configurable long-preview ranges, phase order, handoff/zero holds, and optional per-range `seconds_per_unit` pacing. Runtime builds the phase list and exposes its derived starts/cycle time to tests; tests must not duplicate phase order or duration arithmetic. Restored saved previews initialize paused so the button offers Play after reload, while manually enabling a preview starts it. The shared cycling long preview must reclassify both Long→Short at the threshold and Short→Long after its restart; real auras only move Long→Short. Tooltip fallbacks display full days/hours/minutes/seconds.


## Aura Cancellation
- Aura cancellation is supported only out of combat, only for real cancelable player buffs, and only when the configured modifier key is held (`OFF`, `CTRL`, `ALT`, or `SHIFT`). Do not add in-combat cancel support without a secure-button redesign.
- Addon aura icons are plain frames, not secure aura buttons.
- Never pass `obj.aura_index` directly to `CancelUnitBuff`; in LsTweeks it stores `auraInstanceID`, while `CancelUnitBuff("player", index, filter)` requires the current positional buff index.
- On click, reject cheaply first: feature off, combat lockdown, wrong modifier, nonnumeric aura identity, test preview, spell cooldown, disallowed frame/source.
- Allowed sources are preset `static` and `long` buff frames, plus custom frames when the clicked icon resolves to a current cancelable player buff.
- Treat a fresh `C_UnitAuras.GetBuffDataByIndex("player", i, "HELPFUL|CANCELABLE")` scan as authoritative. Cancel only when the scan finds the clicked `auraInstanceID`.
- Ignore unsupported states silently, then queue a normal aura refresh after a successful cancel attempt.
- `CancelUnitBuff` is restricted and `#nocombat`; secure templates support modifier attributes and `cancelaura`, but combat-safe support would require secure action buttons and careful out-of-combat attribute updates.
- Non-goals: in-combat cancellation, debuff cancellation, preset short-buff cancellation unless intentionally changed later, CDM/cooldown-viewer cancellation unless backed by a real cancelable player buff, and global keyboard-only cancellation.


## Aura Tooltips
- Real Aura icons first use the centralized isolated native delegate: one dedicated LsTweeks `GameTooltip` receives `SetUnitAuraByAuraInstanceID`, or `SetSpellByID` for a readable spell-only identity. This preserves Blizzard's full rich rendering for restricted/secret short buffs and debuffs without placing addon-tainted Aura state on the shared global tooltip later used by map POIs. Call the setter directly under `pcall`; never use `securecallfunction` or read `NumLines`, text, width, height, or other rendered state. Track the successful native owner; an Aura leave may hide only when its caller, stored owner, and the dedicated tooltip's current owner match, and must clear stale local ownership without hiding a replacement tooltip. Tests must explicitly prove that Aura hover never calls `SetOwner` or an Aura setter on global `GameTooltip`.
- Taint incident history: 2026-06-28 Area POI `UIWidgetTemplateTextWithStateMixin:Setup()` secret `textHeight`; 2026-07-01 and 2026-07-03 world quest `EmbeddedItemTooltip_UpdateSize()` secret width; 2026-07-03 Area POI `UIWidgetTemplateStatusBarMixin:InitPartitions()` secret `barWidth`; 2026-07-19 map POI `Setup()` secret `textHeight` with an isolated tooltip plus `securecallfunction` and rendered-line inspection; 2026-07-20 Area POI `LayoutFrame.lua` secret comparison after direct shared-global Aura delegation.
- Guarded cached `C_TooltipInfo` lines rendered by the addon-owned plain tooltip remain the fallback when the native delegate or identity is unavailable; guarded name/duration is the final fallback. Visible icons prewarm safe fallback lines out of combat, retry missed reads twice, and make one pre-combat attempt on `PLAYER_REGEN_DISABLED`. The cache is runtime-only: clear aura-instance keys on `PLAYER_ENTERING_WORLD`, retain reusable spell keys, and clear all keys on reload/logout.
- Combat tooltip fallback must treat a safe remaining/expiration value as timed even when the restricted aura scan has no readable total duration; show its remaining countdown and omit unavailable total duration instead of labeling it permanent.
- Aura tooltip cache keys must stay numeric and non-secret (`auraInstanceID`, `spellID`). Do not key caches by `aura_name`; in restricted aura contexts it can be a secret string, and indexing an addon table with it causes `attempted to index a table that cannot be indexed with secret keys`.
- Test by hovering addon aura icons/bars for active player buffs and debuffs both out of combat and in combat; they must retain Blizzard's rich descriptions. Then hover world quests, delve entrances, and other map POIs with widget content. Blizzard tooltip layout must not report secret-number arithmetic tainted by LsTweeks.


## Position, Drag, Resize
- Aura frame positions are stored as unscaled UIParent-center coordinates: `SetPoint("TOPLEFT", UIParent, "CENTER", pos.x / scale, pos.y / scale)`. Chosen because center-relative values are small and resolution-independent; do not switch to BOTTOMLEFT origin without updating defaults, saved positions, and slider ranges together.
- CDM default positions are dynamic: new/missing CDM positions are placed outside the current main GUI right edge with a 32px gap via `M.refresh_cdm_default_positions()` / `M.apply_cdm_default_positions_to_db()`.
- New custom frame default positions also use the current main GUI right edge with a 32px gap; existing saved/profile custom positions are not overwritten.
- Use `M.apply_frame_position()`, `M.read_frame_position()`, `M.sync_frame_position_to_db()`, `M.apply_saved_frame_position()`, and `M.sync_frame_position_from_drag()` rather than branching on preset vs custom manually.
- Drag/resize state is centralized through `M.start_frame_drag()` / `M.stop_frame_drag()` and `frame._is_user_positioning`.
- Runtime refreshes, especially CDM refreshes, must not reapply saved anchors, scale, size, layout, or height while the user is positioning.
- `update_auras()` guards stable frame-shell setters for scale, position, size, height, alpha, backdrop, and move-shell visibility.
- Move Reset uses shared `addon.CreateMoveResetButton()` through the Aura Frames wrapper and `M.reset_frame_move_placement()`. It resets position/width, not Move Mode.


## Profiles And Reset
- Aura Frame Profiles live under `M.db.profiles`; `af_profiles.lua` owns the explicit snapshot and runtime apply hook while the shared profile manager owns CRUD and storage.
- Loading a profile is blocked in combat. It replaces `M.db.custom_frames`, creates missing custom runtime frames, then runs reset refresh.
- General reset uses `CreateModuleReset(..., opts)` with checked-by-default **Keep Profiles**. When unchecked, `profiles` and `last_profile_name` must be cleared and cached profile UI refreshed.
- If reset replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present.
- Custom-frame deletion removes its runtime frame/events/fades, DB entry, controls, and custom aura scan cache; the Frames tree chooses the visible fallback selection.
- Aura Frame profiles are local unreleased snapshots. If a future storage change makes one unsuitable, delete it and save a new profile; do not add compatibility or migration code.


## GUI
- `af_gui.lua` owns the shell: tabs are **General**, **Frames**, **Profiles**.
- `M.BuildSettings()` stays as the tab-shell coordinator and routes through local helpers plus a small `context` table.
- `af_gui.lua` routes its Profiles tab through the shared Profiles-tab factory. Timer-font dropdown construction is local to `af_gui_frame_builders.lua`. `M.build_general_tab` and `M.build_frames_tab` remain exported because they live in separate Aura Frames GUI files and are called by the shell.
- `af_gui_tree.lua` owns the Frames sidebar groups: **Buffs**, **WoW Cooldown**, **Filters**.
- `af_gui_frame_builders.lua` owns General, preset/CDM, custom settings, and custom filter panels.
- Aura Frames settings grids call the shared `addon.CreateSettingsGrid()` helper directly.
- Aura Frames frame settings use `grid:stack_below()` for repeated in-cell stacks. Keep color pickers grid-placed in their own columns so centering comes from `CreateSettingsGrid()`, not manual offsets.
- Aura Frames tab and tree heights derive from `addon.main_frame:GetContentAreaSize()`, so the main settings window height in `core/main_frame.lua` is the single height knob.
- CDM controls are source-specific additions layered through `opts.build_source_controls`.
- Shared presentation controls stay in the common builder; use hooks only for real source-specific behavior.


## Debug, Grid, Style
- Debug outlines: `M.db.show_bar_section_outlines`; remove tagged textures with `Hide()` + `SetTexture(nil)`, not `SetParent(nil)`.
- Screen grid: `M.snap_to_grid()`, `M.snap_frame_position()`, `M.set_grid_visible()`. Grid preserves flush screen-edge positions before rounding.
- Riveted panel style: `addon.ApplyRivetedPanelStyle()` / `addon.AddRivetCorners()`.
- `addon.CreateRivetedPanel()` owns default text padding through `addon.RIVETED_PANEL_STYLE.padding`; callers should not clear/reanchor returned text just to avoid rivets.
