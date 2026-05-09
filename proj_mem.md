# LsTweeks Project Memory

## Purpose
This file is shared project memory for coding agents working on LsTweeks. Keep it current when architecture, defaults, APIs, workflow rules, or hard-won debugging notes change.

## Agent Workflow
- Treat this file as the project-level source of truth before making non-trivial edits.
- Update it when the current project state changes in a way future agents need to know.
- Prefer concise, durable notes over session logs or speculative plans.
- Do not store secrets, personal data, machine-local paths, or temporary scratch notes here.
- after significant changes, provide a concise git commit message
- Lua 5.1 tools are installed at `C:\Program Files (x86)\Lua\5.1\`; this path is not always on PATH. Use `& 'C:\Program Files (x86)\Lua\5.1\luac.exe' -p <files>` for syntax checks.

## What This AddOn Is
**L's Tweeks** — a modular World of Warcraft (WoW) UI addon for WoW 12.0.5+ by LockBall.  
Slash command: `/lst` (registered as `SLASH_LSTWEEKS1`). SavedVariables: `Ls_Tweeks_DB`. Note the intentional "Tweeks" spelling throughout.

## Design Principles
- **Single source of truth:** Store each decision, default, category definition, timing interval, and layout constant in one owning place. Other files should derive from that owner instead of copying parallel lists, fallback values, or magic numbers.

- **Single-path deterministic behavior:** Prefer one clear runtime path for each behavior. Avoid alternate code paths that can disagree by timing, combat state, GUI state, or frame type; when branching is required, centralize the branch and make every caller use it.

- **Readability:** Keep code easy to audit under addon-debug conditions. Use plain names, small helpers, local ownership, and comments only where they explain non-obvious WoW API, taint, combat-lockdown, timing, or layout constraints.

- **Modularity:** Each file should own a coherent responsibility and expose a small surface through the shared `addon` table or the Aura Frames `M` table. Shared helpers belong where they reduce real duplication without hiding source-specific behavior.

- **Efficiency:** Treat aura scanning, rendering, layout, and GUI rebuilds as budgeted work. Cache WoW globals on hot paths, batch repeated events through named update intervals, skip disabled/inactive frames early, and avoid unnecessary frame churn.

## File Map
```
core/
  init.lua           — addon entry, font theme tokens (addon.UI_THEME), timing buckets, DB init, slash cmd
  main_frame.lua     — sidebar + tabbed settings window; addon.register_category()
  minimap_button.lua — LibDataBroker minimap button
functions/
  utils.lua           — addon.deep_copy_into(), addon.apply_defaults()
  checkbox.lua        — addon.CreateCheckbox()
  color_picker.lua    — addon.CreateColorPicker()
  dropdown.lua        — addon.CreateDropdown() — custom popup, NOT UIDropDownMenu
  module_reset.lua    — addon.CreateGlobalReset() — ARM-code safety reset
  panel_riveted.lua   — addon.CreateRivetedPanel() / ApplyRivetedPanelStyle() / AddRivetCorners()
  slider_with_box.lua — addon.CreateSliderWithBox()
modules/
  about.lua        — intro/version page
  settings/
    st_defaults.lua — default values for settings module (interface_alpha, minimap, open_on_reload)
    st_main.lua     — minimap toggle, open-on-reload, interface transparency slider; on_reset_complete
  combat_text.lua  — hide portrait combat text; on_reset_complete
  aura_frames/
    af_defaults.lua      — all default config values and built-in Aura Frame metadata; M.FRAME_DEFS derives category lists
    af_functions.lua     — small shared Aura Frames helpers: CDM viewer lookup, frame position sync, setting/font-size fallback lookup, custom-frame entry/filter helpers, backdrop helpers, settings grid maker
    af_scan.lua          — aura scanning: unified_scan(), custom AuraFilters scans, CDM viewer reads/cooldown hooks, session classification memory
    af_render.lua        — render_aura_map(), set_timer_text(), merge_aura_info()
    af_icon_layout.lua   — setup_layout(), set_height_for_growth(), get_bar_layout_params(), is_timer_text_enabled()
    af_core.lua          — tick_visible_icons(), update_auras(), Blizzard buff/debuff/CDM visibility prep
    af_gui.lua           — Aura Frames settings shell; M.BuildSettings(), dropdown wrappers, sync_general_controls_from_db()
    af_gui_tree.lua      — Frames tab tree/sidebar; Buffs, WoW Cooldown, and Filters groups
    af_gui_frame_builders.lua — all Aura Frames content panels; General, Spell ID, preset Buff/CDM, and custom Filters builders
    af_main.lua          — runtime state tables, init, frame creation, icon pool, drag/resize, on_reset_complete
    af_test_aura.lua     — fake aura preview system
    af_debug_outlines.lua — add_debug_outline(), refresh_section_outlines()
    af_screen_grid.lua   — snap_to_grid(), snap_frame_position(), build_grid_lines(), create_grid_overlay(), set_grid_visible()
libs/            — LibStub, LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0
media/fonts/     — monospace TTFs: SourceCodePro (selectable), Inconsolata, JetBrainsMono, RobotoMono, 0xProto (on disk, not yet selectable)
```

## File Header Standard
Every lua file must open with a brief comment (up to a few sentences) explaining what the file does, placed before `local addon_name, addon = ...`. The comment should describe the file's role/responsibility in plain terms and mention its key public functions or how it fits into the larger system. Do not use a bare filename label as a substitute.

## Architecture Rules
- **Module pattern:** `local addon_name, addon = ...` at top of every file; modules share the `addon` namespace table.
- **Self-registration:** modules call `addon.register_category(name, builder_fn)` to appear in the settings sidebar.
- **Versioning:** `LsTweeks.toc` is the only addon version edit point. Runtime display must read through `addon.get_version()`, which caches `C_AddOns.GetAddOnMetadata(addon_name, "Version")`; do not hardcode version fallbacks in Lua/docs.
- **TOC Interface:** `LsTweeks.toc` declares `## Interface: 120005`, verified in-game on WoW 12.0.5 with `/dump (select(4, GetBuildInfo()))`. Re-verify with that command before bumping for future patches.
- **Timing buckets:** shared timing values live in `addon.UPDATE_INTERVALS` (`core/init.lua`) with generic names such as `tenth_sec`. Repeated runtime behavior should reference those buckets directly, with a nearby comment explaining why that interval fits the work.
- **DB access:** `Ls_Tweeks_DB.module_key = Ls_Tweeks_DB.module_key or {}` — always guard with `or {}`.
- **Init pattern:** modules that register settings or runtime behavior create a loader frame, register ADDON_LOADED, and unregister once their startup work is complete. Some modules also wait for PLAYER_ENTERING_WORLD when they need Blizzard frames to exist.
- **Hot paths:** cache WoW globals at file top — `local floor = math.floor`, `local GetTime = GetTime`, etc.
- **Theme/style constants:** shared font tokens live in `addon.UI_THEME` (`core/init.lua`); riveted panel spacing/sizing/art constants live in `addon.RIVETED_PANEL_STYLE` (`functions/panel_riveted.lua`). Module-specific layout constants may stay local when they are not shared.
- **Deferred batching:** UNIT_AURA events are bucketed with `addon.UPDATE_INTERVALS.tenth_sec`; timer text/bar updates also tick at `tenth_sec` because they are cheap visual updates.
- **InCombatLockdown:** defer layout/geometry changes; `update_auras()` skips frame scale, anchoring, sizing, layout setup, and height changes during combat or while `._is_user_positioning` is true. Never call protected WoW API during combat.
- **Reset contract:** every stateful settings/runtime module must implement `M.on_reset_complete()` to resync controls from DB after reset. Apply defaults via `addon.apply_defaults(defaults, db)`, not manual `or` guards.
- **Taint safety:** never call Blizzard frame methods (UpdateAuras, UpdateLayout) from addon context — even deferred. Restore events + Show() only and let Blizzard's handlers fire naturally.

## Layout Rules (critical — violations cause invisible controls)
- **All widget internals anchor to their own container** — never chain anchors off a sibling inside a factory function.
- **One SetPoint per anchor direction per frame** — two TOPLEFT calls on the same frame = conflicting constraint, undefined result.
- **Never call `frame:GetWidth()` at build time** — returns 0 until the frame is rendered; use hardcoded constants for layout math.
- **External placement is always one `SetPoint` call** — factory functions must NOT call SetPoint themselves if the caller will place them.
- **`CreateSliderWithBox` has a built-in debounce** via `addon.UPDATE_INTERVALS.tenth_sec` — do not add an external debounce in the callback.

## Saved Variables — Known Keys
```
Ls_Tweeks_DB = {
  minimap = { hide = bool },
  open_on_reload = bool,
  interface_alpha = number,            -- main frame transparency (0–1)
  last_open_module = string,           -- last sidebar tab name (survives reset intentionally)
  combat_text = bool,                  -- hide portrait combat text
  aura_frames = {
    last_tab_index = number,           -- last selected aura tab (1=General, 2=Frames, 3=Spell ID)
    last_frames_node = string,         -- last selected frame node in category tabs
    short_threshold = number,
    enable_blizz_buffs = bool,
    enable_blizz_debuffs = bool,
    snap_to_grid = bool,
    show_grid = bool,
    show_bar_section_outlines = bool,  -- debug outline toggle (now under aura_frames, not root)
    show_spell_id = bool,              -- show spell ID in icon tooltips
    fade_wow_cooldown_ooc = bool,      -- CDM-backed addon frames fade out of combat
    wow_cooldown_ooc_alpha = number,   -- CDM-backed frame alpha while out of combat
    timer_number_font = string,         -- global fallback; currently "source_code_pro" or "game_default"
    timer_number_font_size = number,
    timer_number_font_bold = bool,
    -- per-category keys: <setting>_<cat> e.g. show_static, color_debuff, scale_short
    -- common per-category settings include show/move/timer/bg/scale/spacing/width/bar_mode/color/bar_bg_color/bg_color/max_icons/growth/sort/test_aura/timer_number_font/timer_number_font_size/timer_number_font_bold/timer_color/bar_text_color
    -- CDM-only per-category settings include cooldown_mode_<cat> and hide_blizz_cdm_<cat>
    positions = { static={point,x,y}, short={point,x,y}, long={point,x,y}, essential={point,x,y}, utility={point,x,y}, tracked_buffs={point,x,y}, tracked_bars={point,x,y}, debuff={point,x,y} },
    custom_frames = {                  -- array of custom filtered frame entry tables
      -- each entry: { id, name, aura_base_filter="HELPFUL|HARMFUL", aura_modifier="NONE|...",
      --               position={point,x,y},
      --               show, move, bg, bg_color, bar_mode, color, bar_bg_color,
      --               growth, timer, scale, spacing, max_icons, width,
      --               test_aura, timer_number_font, timer_number_font_size,
      --               timer_number_font_bold, timer_color, bar_text_color }
    },
  }
}
```

## Aura Frame Categories
Preset categories: `static`, `debuff`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
The `essential`, `utility`, `tracked_buffs`, and `tracked_bars` are backed by live WoW Cooldown Manager viewers.
Built-in category metadata lives in `M.FRAME_DEFS` (`af_defaults.lua`). Derive category lists, GUI labels, CDM viewer names, preset key names, and test-aura labels from that table instead of adding separate hardcoded category lists.
Shared Aura Frames behavioral defaults live in `af_defaults.lua` as named constants, including frame width limits, default/max icons, short-threshold fallback, default timer font key, and CDM out-of-combat alpha. Runtime fallbacks and GUI limits should reference those constants rather than repeating numeric/string literals.
Timer font choices are currently defined in `af_main.lua`: Source Code Pro plus Game Default. Other font files exist on disk but are not exposed unless `M.NUMBER_FONT_OPTIONS` and `M.NUMBER_FONT_BOLD_PATHS` are updated.
Aura frame processing is enabled-rooted. `show/enabled` is the first activity gate for preset and custom frames; disabled frames must not do move-shell work, test-aura work, aura/custom/CDM scans, render, layout, or CDM viewer prep. Use `M.get_frame_activity_state()` for runtime activity decisions and `M.cdm_category_needs_viewer()` for CDM prep decisions. Aura classification uses live timing data plus scan-local old-map fallback for secret fields; do not reintroduce learned static/long spell tables.
Preset and custom frame settings should be treated as the same presentation model over different backing stores. Use normalized frame settings configs and shared builders in `af_gui_frame_builders.lua` for common presentation controls, including position/move/reset and timer controls. Preserve the current visible GUI and hide unsupported controls rather than adding/removing controls during refactors.
DB keys follow the pattern `aura_frames.<setting>_<category>` (e.g. `show_static`, `color_debuff`).
Positions are stored under `aura_frames.positions.<category>`.
First-install/default visible frames are only the four player-aura presets: `static`, `short`, `long`, and `debuff`. CDM-backed defaults keep `show_*`, `move_*`, and `test_aura_*` false so they do not appear as live frames, empty movable frames, or previews until enabled by the user.

CDM refresh scheduling is centralized in `af_main.lua` via `M.queue_wow_cooldown_refresh(profile)`. Its local profile table uses `addon.UPDATE_INTERVALS` buckets for the retry delays. Use the named profiles (`"immediate"`, `"startup"`, `"settings"`, `"hook"`) instead of adding local timer chains. Startup/settings refreshes prepare Blizzard viewers and clear child identity cache; hook refreshes defer one frame and do not clear child cache so live CooldownViewer hook data is preserved.
CDM-backed frames have two CDM-specific controls: `cooldown_mode_<cat>` switches a CDM frame from aura-display mode into spell-cooldown mode, and `hide_blizz_cdm_<cat>` alpha-hides the matching Blizzard viewer without calling `Hide()`. Addon CDM frames can also fade out of combat using `fade_wow_cooldown_ooc` and `wow_cooldown_ooc_alpha`.

Within `modules/aura_frames`, refresh/debounce scheduling must not hardcode raw timing numbers. `C_Timer.After`, `C_Timer.NewTicker`, and `C_Timer.NewTimer` calls should use `M.UPDATE_INTERVALS` directly, or receive a delay from the centralized CDM scheduler. Numeric values are still fine for non-timing data such as slider steps, alpha/color values, layout math, and test-aura duration settings.

Custom aura frames are filter-driven, not whitelist-driven. Each custom frame has the same main settings grid as preset categories, plus a `Filters` child node with two dropdowns rendered as `HELPFUL | MODIFIER` or `HARMFUL | MODIFIER`. Modifier `"NONE"` omits the suffix. Some modifiers force the base (`CANCELABLE`, `NOT_CANCELABLE`, `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE` -> `HELPFUL`; `CROWD_CONTROL`, `RAID_PLAYER_DISPELLABLE` -> `HARMFUL`). Custom frames scan only when enabled/previewed with `C_UnitAuras.GetAuraDataByIndex("player", index, M.get_custom_aura_filter(entry))` from `af_scan.lua`, tag entries with `custom_order`, and render in selected-filter scan order instead of the preset time/name sort path. Runtime call-chain variables use `aura_filter` for the selected AuraFilters string. Custom scans are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; `af_main.lua` clears that cache on aura-affecting events.

When aura-frame reset replaces `M.db.custom_frames`, `af_main.lua` removes orphan custom runtime frames and stale custom controls, then asks `af_gui_tree.lua` to rebuild the Frames tree/content if it exists. Do not leave custom WoW frames alive without a matching saved custom entry.

## Aura Frames GUI Layout System
`af_gui.lua` owns the settings shell: `BuildSettings` creates three tabs, restores the selected tab, and dispatches to panel builders. It should stay focused on GUI orchestration and shared dropdown wrappers.

`BuildSettings` has three tabs: **General** (manual anchoring), **Frames** (tree + grid), and **Spell ID** (tooltip spell ID toggle).

`af_gui_tree.lua` owns the **Frames** tab left tree sidebar (140px wide) with three outlined groups: **Buffs** (Static/DeBuff/Short/Long), **WoW Cooldown** (button title that opens Blizzard Cooldown Viewer settings + Sync to CDM + Essential/Utility/Tracked Buffs/Tracked Bars), and **Filters** (+ Custom button first, then custom entries with expandable Filters child nodes). Selecting a node lazy-builds a content panel to the right. The active tree node colors its group outline gold; inactive group outlines are gray. Group spacing is controlled by `GROUP_INNER_PAD`, `GROUP_ELEMENT_GAP`, and `GROUP_GAP` in `af_gui_tree.lua`.

`af_gui_frame_builders.lua` owns all content panel builders: **General**, **Spell ID**, preset Buff/CDM frame panels, custom frame settings, and custom filter child panels.

Preset, CDM-backed preset, and custom frame settings panels share `M.create_settings_grid(parent, opts)` from `af_functions.lua` and the local superset builder `build_frame_settings_panel(parent, frame_config, opts)` in `af_gui_frame_builders.lua`. CDM frames are preset categories (`essential`, `utility`, `tracked_buffs`, `tracked_bars`) with extra controls layered into the shared builder through `opts.build_source_controls`. `frame_config.keys` normalizes preset suffixed DB keys and custom flat entry keys into logical names (`show`, `move`, `timer`, `bg`, `scale`, etc.). Keep shared presentation controls in this builder; use small `opts` hooks only for real source-specific capabilities such as CDM controls, custom frame naming, static timer hiding, and source-specific update/reload callbacks.

Preset and custom content panels each use `place_at(control, row, column, slot, opts)` with a 4-column grid:
- `col_gap=150`, `col_offset=-20` → `grid[1]=-20`, `grid[2]=130`, `grid[3]=280`, `grid[4]=430`
- `col_width=190` — centering zone within each column
- All 4 columns center-aligned by default (`col_align = {"center","center","center","center"}`)
- `opts.align` overrides per-call ("left", "center", "right")
- 5 rows: `row_heights = {130, 60, 90, 120, 110}`, `row_start=10`, `row_gap=20`
- `slot` maps to `grid.offsets`: `dropdown=8`, `picker=4`, `default=0`
- `opts.valign="bottom"` descends one extra row height

Aura frame saved positions are stored in unscaled UIParent-center coordinates. Runtime placement uses `M.apply_frame_position(frame, pos, scale)` and drag/slider sync uses `M.read_frame_position(frame)` / `M.sync_frame_position_to_db(frame, pos)` so scaled frames do not jump when moved.

Position ownership is centralized in `af_functions.lua`: use `M.get_frame_position_table(frame)`, `M.get_frame_position_scale(frame, scale_key)`, `M.apply_saved_frame_position(frame, scale_key, fallback_y)`, and `M.sync_frame_position_from_drag(frame, scale_key)` for saved aura-frame placement. Other files should not branch separately on preset vs custom position storage except when directly editing the DB table values for controls/reset.

Move Reset is also centralized in `af_functions.lua`: settings panels should create it with `M.create_move_reset_button()` and perform the action through `M.reset_frame_move_placement()`. Move Reset only resets saved position and width; it must not toggle the frame's Move Mode setting.

Drag/resize interaction state is centralized with `M.start_frame_drag()` / `M.stop_frame_drag()` and the frame flag `._is_user_positioning`. Runtime refreshes, especially CDM refreshes, must not reapply saved anchors, scale, size, layout, or height while this flag is set, or the frame can jump back to an older saved position under the cursor.

## UI Shared Controls — Quick Reference
| Function | Key args | Notes |
|---|---|---|
| `CreateCheckbox(parent, label, checked, cb)` | returns container, checkbox, label | container width is dynamic |
| `CreateSliderWithBox(name, parent, label, min, max, step, db, key, defaults, cb)` | returns container (130×95) | has built-in `addon.UPDATE_INTERVALS.tenth_sec` debounce; `container.slider` exposed |
| `CreateDropdown(name, parent, label, options, cfg)` | cfg: width, row_height, get_value, on_select | custom popup |
| `M.CreateListDropdown(name, parent, label, opts, get_val, on_sel, width)` | returns dropdown | af_gui wrapper with font support |
| `CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb)` | integrated reset | container is 95×45 |
| `CreateRivetedPanel(parent, w, h, anchorTo, point, x, y, levelOffset)` | returns panel, fontstring | |
| `CreateGlobalReset(parent, db, defaults)` | ARM-code safety reset for the passed DB table; blocked in combat | not positioned by the factory |

## Debug Outlines (af_debug_outlines.lua)
`M.db.show_bar_section_outlines` toggles 1px borders on aura icon slots.  
Toggle via `M.refresh_section_outlines()`. Outline textures are tagged `._is_outline = true` for safe removal.  
Do NOT use `SetParent(nil)` to remove textures — use `Hide()` + `SetTexture(nil)` on tagged textures only.

## Screen Grid Snap (af_screen_grid.lua)
20px grid with small X/Y offsets (`GRID_OFFSET_X=-1.5`, `GRID_OFFSET_Y=-0.5`) to align with Blizzard Edit Mode grid spacing while still using LsTweeks' UIParent-center coordinate system.  
`M.snap_to_grid(v, is_y)` — snaps a coordinate. `M.snap_frame_position(pos, frame)` preserves flush screen-edge positions before applying grid rounding, so clamped edge placement wins over grid snap. `M.set_grid_visible(show)` — toggles overlay.
DB keys: `aura_frames.snap_to_grid`, `aura_frames.show_grid`.

## Riveted Panel Style
Marble background, ornate dialog-frame borders, 4 corner rivet textures. Apply via `addon.ApplyRivetedPanelStyle(frame, opts)` or `addon.AddRivetCorners(frame, inset, offX, offY)`.

## Key WoW API Used
- `C_UnitAuras.GetBuffDataByIndex / GetDebuffDataByIndex` — aura scanning
- `C_UnitAuras.GetAuraDuration` — returns a Duration object (12.0+); use `:GetRemainingDuration()`, `:GetExpirationTime()`
- `C_UnitAuras.GetUnitAuraInstanceIDs` — sort-ordered ID list for render
- `C_UnitAuras.DoesAuraHaveExpirationTime` — secret-safe boolean expiry check
- `C_UnitAuras.GetAuraApplicationDisplayCount` — stack count fallback
- `GameTooltip:SetUnitAuraByAuraInstanceID("player", auraInstanceID)` — stable tooltip lookup
- `CooldownViewerItemDataMixin` + `hooksecurefunc` — CDM cooldown identity/timing cache
- `Settings.OpenToCategory("Cooldown Viewer")` — opens Blizzard's CDM settings panel from the tree title button
- `ColorPickerFrame` — system color picker
- `InCombatLockdown()` — combat guard
- `LibDataBroker`, `LibDBIcon` — minimap button

## Taint Lesson
If reload shows Blizzard's blocked-action dialog ("LsTweeks has been blocked from an action only available to the Blizzard UI" with Disable/Ignore buttons), treat it as a taint regression first. A previous instance came from a CLEU-related path calling protected Blizzard behavior from addon context; the fix was to avoid direct Blizzard frame method calls and let Blizzard handlers run naturally.
