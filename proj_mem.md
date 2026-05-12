# LsTweeks Project Memory

Shared memory for coding agents. Keep this file concise and durable: architecture, ownership, defaults, workflow rules, and hard-won debugging notes only.

## Workflow
- Treat this file as the project source of truth before non-trivial edits.
- Update it when architecture, defaults, APIs, or debugging lessons change.
- Do not store secrets, personal data, machine-local scratch notes, or session logs.
- Format ToDo plans with numbered sections (`### 1. file/topic`) and lettered checkbox substeps (`- [ ] a) ...`).
- After significant changes, provide a concise git commit message.
- Lua syntax check: `& 'C:\Program Files (x86)\Lua\5.1\luac.exe' -p <files>`.

## AddOn Summary
**L's Tweeks** is a modular WoW 12.0.5+ UI addon by LockBall. Keep the intentional **Tweeks** spelling.

- Slash command: `/lst` (`SLASH_LSTWEEKS1`)
- SavedVariables: `Ls_Tweeks_DB`
- Version edit point: `LsTweeks.toc` only
- Current TOC Interface: `120005`; re-verify future bumps in-game with `/dump (select(4, GetBuildInfo()))`

## Design Principles
- **Single source of truth:** Defaults, category metadata, timing buckets, layout constants, and source-specific rules should have one owner.
- **Single-path behavior:** Prefer one deterministic runtime path. Centralize unavoidable branching and route callers through it.
- **Readability:** Small helpers are fine when they clarify real work. Avoid abstractions that hide WoW API, taint, combat, timing, or hot-path state.
- **Efficiency:** Aura scanning, rendering, layout, and GUI rebuilds are budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.
- **Conservative refactors:** Match existing file ownership and visible GUI unless the request explicitly changes behavior.
- Treat what I say as a hypothesis, not a fact, unless we have proof. If I am wrong, then correct me directly.


## File Map
```
core/
  init.lua              addon entry, DB init, slash command, addon.UPDATE_INTERVALS, addon.UI_THEME
  main_frame.lua        settings shell and addon.register_category()
  minimap_button.lua    LibDataBroker / LibDBIcon minimap button
functions/
  utils.lua             deep_copy_into(), apply_defaults()
  checkbox.lua          CreateCheckbox()
  color_picker.lua      CreateColorPicker()
  dropdown.lua          CreateDropdown() custom popup, not UIDropDownMenu
  module_reset.lua      CreateGlobalReset() ARM-code reset
  panel_riveted.lua     riveted panel style helpers
  slider_with_box.lua   CreateSliderWithBox() with built-in tenth-sec debounce
modules/
  about.lua
  combat_text.lua
  sound_levels/          preset sound controls; mutes known FileDataIDs and plays addon replacement audio
  settings/             settings defaults + minimap/open-on-reload/interface alpha panel
  aura_frames/
    af_defaults.lua        Aura Frame defaults, FRAME_DEFS, category lists, custom template
    af_functions.lua       shared AF helpers: position, settings fallback, activity, timer behavior, custom filters, grid/backdrops
    af_scan.lua            unified aura scan, custom AuraFilters scan cache, CDM viewer reads/hooks
    af_render.lua          render_aura_map(), set_timer_text(), merge_aura_info()
    af_icon_layout.lua     icon/bar layout, growth metadata, bar params, height preservation
    af_core.lua            tick_visible_icons(), update_auras(), Blizzard frame/CDM visibility
    af_profiles.lua        Aura Frame profile save/load/apply schema
    af_gui*.lua            settings shell, tree, content panel builders
    af_main.lua            runtime init, frame/icon pool creation, events, drag/resize, reset
    af_test_aura.lua       preview aura entries
    af_debug_outlines.lua  optional icon-slot outlines
    af_screen_grid.lua     screen grid and snap helpers
libs/                    embedded libraries, documented in libs/sources.md
media/fonts/             SourceCodePro selectable; other monospace fonts on disk
```

Every Lua file starts with a short responsibility header before `local addon_name, addon = ...`.

## Core Architecture Rules
- Module pattern: `local addon_name, addon = ...`; share state through `addon` and `addon.aura_frames` (`M`).
- Sidebar categories use `addon.register_category(name, builder, { order = n })`; equal order values preserve registration order. Default order is 100.
- Stateful modules implement `on_reset_complete()` and resync controls/runtime after reset.
- Apply defaults with `addon.apply_defaults(defaults, db)`; guard DB tables with `or {}`.
- Shared timing values live in `addon.UPDATE_INTERVALS`; do not hardcode repeated refresh/debounce delays.
- Cache hot globals at file top (`local floor = math.floor`, `local GetTime = GetTime`, etc.).
- Never call protected Blizzard frame methods such as `UpdateAuras` or `UpdateLayout` from addon context. Restore events/Show and let Blizzard handlers run.
- Defer layout/geometry changes in combat. `update_auras()` skips scale, anchors, size, layout setup, and height changes during combat or while `frame._is_user_positioning`.

## GUI/Layout Rules
Violations here can create invisible or unstable controls.

- Widget internals anchor only to their own container.
- One `SetPoint` per anchor direction per frame; duplicate TOPLEFT/TOPRIGHT constraints can produce undefined layout.
- Do not use `frame:GetWidth()` at build time; it can be 0 before render.
- Factory functions should not place controls externally when the caller owns placement.
- `CreateSliderWithBox` already debounces callbacks at `addon.UPDATE_INTERVALS.tenth_sec`.
- `M.create_settings_grid()` owns the Aura Frames 4-column settings grid used by preset and custom panels.

## Saved Variables Shape
Top-level keys include:
`minimap.hide`, `open_on_reload`, `interface_alpha`, `last_open_module`, `combat_text`, `sound_levels`, and `aura_frames`.

Important `sound_levels` keys:
- `sound_levels.enabled`
- `sound_levels.targets.<target>.preset` where current presets are `original`, `shush`, `shusher`, `shushest`
- `sound_levels.targets.<target>.play_replacement`

## Sound Levels Ownership
- Sound target metadata lives in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_TARGETS`.
- WoW does not expose true per-sound volume control or custom channels. This module uses preset replacement behavior: mute known original FileDataIDs with `MuteSoundFile` / `C_Sound.MuteSoundFile`, then optionally play addon-owned replacement files with `PlaySoundFile` / `C_Sound.PlaySoundFile`.
- Replacement audio files live under `modules/sound_levels/sounds/`; current planned dungeon-ready paths are `dungeon_ready_shush.ogg`, `dungeon_ready_shusher.ogg`, and `dungeon_ready_shushest.ogg`.
- Keep the UI preset-based unless we add generated audio variants for each slider step.

Important `aura_frames` keys:
- Session/UI: `last_tab_index`, `last_frames_node`, `last_profile_name`
- Global AF settings: `short_threshold`, `enable_blizz_buffs`, `enable_blizz_debuffs`, `snap_to_grid`, `show_grid`, `show_bar_section_outlines`
- CDM fade: `fade_wow_cooldown_ooc`, `wow_cooldown_ooc_alpha`
- Timer fallback: `timer_number_font`, `timer_number_font_size`, `timer_number_font_bold`
- Preset per-category keys: `<setting>_<category>` such as `show_static`, `color_debuff`, `scale_short`
- Positions: `aura_frames.positions.<category> = { point, x, y }`
- Custom frames: array entries with `id`, `name`, filter fields, flat presentation keys, and `position`
- Profiles: complete Aura Frames snapshots excluding editor/session state such as selected tabs/nodes, grid visibility, and debug outlines

## Aura Frames Ownership
- Built-in category metadata lives in `M.FRAME_DEFS` (`af_defaults.lua`). Derive category lists, labels, CDM viewer names, preset key names, and test labels from it.
- Preset categories: `static`, `debuff`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- CDM-backed categories: `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- First-install visible frames are only `static`, `short`, `long`, `debuff`. CDM defaults keep `show_*`, `move_*`, and `test_aura_*` false.
- Preset DB keys use `aura_frames.<setting>_<category>`; custom frame entries use flat keys.
- Preset and custom frame settings share the same presentation model via normalized `frame_config.keys` and `build_frame_settings_panel()` in `af_gui_frame_builders.lua`.

### Runtime Gates And Refresh
- Frame processing is enabled-rooted. Disabled frames must not do move-shell work, previews, scans, render, layout, or CDM viewer prep.
- Use `M.get_frame_activity_state()` for activity decisions and `M.cdm_category_needs_viewer()` for CDM prep.
- UNIT_AURA is batched at `UPDATE_INTERVALS.tenth_sec`; timer text/bar updates also tick at `tenth_sec`.
- `render_aura_map()` stores `frame._display_count`; `tick_visible_icons()` should tick only displayed pooled icons, not the full pool.
- CDM refresh scheduling is centralized in `af_main.lua` via `M.queue_wow_cooldown_refresh(profile)`. Use profiles `"immediate"`, `"startup"`, `"settings"`, `"hook"` instead of local timer chains.
- CDM viewer frames are alpha-hidden with mouse disabled; do not `Hide()` them or they stop producing useful child state.
- CDM Blizzard-viewer hide settings must be applied for every CDM category on startup/reload, independent of whether the matching addon CDM frame is enabled.

### Scanning, Rendering, Timers
- Aura classification uses live timing plus scan-local old-map fallback for secret fields. Do not reintroduce learned static/long spell tables.
- `M._aura_map` remains the master auraInstanceID map; `M.unified_scan()` rebuilds `M._aura_maps_by_category` as derived preset buckets each scan.
- Sorted aura ID results are shared in `af_render.lua`; invalidate them through `M.clear_sorted_aura_ids_cache()` when aura data is marked dirty or rescanned.
- Render helpers guard stable visual setters where practical; timer countdown and bar progress must continue updating live.
- Custom frames are AuraFilters-driven, not whitelist-driven. They scan with `C_UnitAuras.GetAuraDataByIndex("player", i, M.get_custom_aura_filter(entry))`.
- Custom scan results are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; aura-affecting events clear the cache.
- Timer text enable/format behavior is centralized in `af_functions.lua` via `M.get_timer_behavior()` and `M.is_timer_text_enabled()`. Timer alignment remains layout behavior in `af_icon_layout.lua`.

### Position, Drag, Resize
- Aura frame positions are stored as unscaled UIParent-center coordinates.
- CDM default positions are dynamic: new/missing or untouched legacy CDM positions are placed outside the current main GUI right edge with a 32px gap via `M.refresh_cdm_default_positions()` / `M.apply_cdm_default_positions_to_db()`.
- New custom frame default positions are also based on the current main GUI right edge with a 32px gap; existing saved/profile custom positions are not overwritten.
- Use `M.apply_frame_position()`, `M.read_frame_position()`, `M.sync_frame_position_to_db()`, `M.apply_saved_frame_position()`, and `M.sync_frame_position_from_drag()` rather than branching on preset vs custom manually.
- Drag/resize state is centralized through `M.start_frame_drag()` / `M.stop_frame_drag()` and `frame._is_user_positioning`.
- Runtime refreshes, especially CDM refreshes, must not reapply saved anchors, scale, size, layout, or height while the user is positioning.
- `update_auras()` guards stable frame-shell setters for scale, position, size, height, alpha, backdrop, and move-shell visibility.
- Move Reset uses `M.create_move_reset_button()` and `M.reset_frame_move_placement()`. It resets position/width, not Move Mode.

### Profiles And Reset
- Aura Frame Profiles live under `M.db.profiles`; save/load is owned by `af_profiles.lua` with an explicit schema.
- Loading a profile is blocked in combat, replaces `M.db.custom_frames`, creates missing custom runtime frames, then runs reset refresh.
- General reset uses `CreateGlobalReset(..., opts)` with checked-by-default **Keep Profiles**. When unchecked, `profiles` and `last_profile_name` must be cleared and cached profile UI refreshed.
- If reset replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present.

## Aura Frames GUI
- `af_gui.lua` owns the shell: tabs are **General**, **Frames**, **Profiles**.
- `af_gui_tree.lua` owns the Frames sidebar groups: **Buffs**, **WoW Cooldown**, **Filters**.
- `af_gui_frame_builders.lua` owns General, preset/CDM, custom settings, and custom filter panels.
- CDM controls are source-specific additions layered through `opts.build_source_controls`.
- Shared presentation controls stay in the common builder; use hooks only for real source-specific behavior.

## Debug, Grid, Style
- Debug outlines: `M.db.show_bar_section_outlines`; remove tagged textures with `Hide()` + `SetTexture(nil)`, not `SetParent(nil)`.
- Screen grid: `M.snap_to_grid()`, `M.snap_frame_position()`, `M.set_grid_visible()`. Grid preserves flush screen-edge positions before rounding.
- Riveted panel style: `addon.ApplyRivetedPanelStyle()` / `addon.AddRivetCorners()`.

## Key WoW APIs And Lessons
- Aura APIs: `C_UnitAuras.GetBuffDataByIndex`, `GetDebuffDataByIndex`, `GetAuraDuration`, `GetUnitAuraInstanceIDs`, `DoesAuraHaveExpirationTime`, `GetAuraApplicationDisplayCount`.
- Tooltip APIs: prefer `GameTooltip:SetUnitAuraByAuraInstanceID("player", auraInstanceID)`, fall back to `GameTooltip:SetSpellByID`.
- CDM APIs/hooks: `CooldownViewerItemDataMixin`, `hooksecurefunc`, `Settings.OpenToCategory("Cooldown Viewer")`.
- Combat/taint: `InCombatLockdown()` guards protected paths. If Blizzard’s blocked-action dialog appears, treat it as taint first.
