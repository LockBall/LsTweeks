# LsTweeks Project Memory

## Purpose
This file is shared project memory for coding agents working on LsTweeks. Keep it current when architecture, defaults, APIs, workflow rules, or hard-won debugging notes change.

## Agent Workflow
- Treat this file as the project-level source of truth before making non-trivial edits.
- Update it when the current project state changes in a way future agents need to know.
- Prefer concise, durable notes over session logs or speculative plans.
- Do not store secrets, personal data, machine-local paths, or temporary scratch notes here.

## What This Is
**L's Tweeks** — a modular WoW UI addon (patch 12.0 / Interface 120000) by LockBall.  
Slash command: `/lst` (registered as `SLASH_LSTWEEKS1`). SavedVariables: `Ls_Tweeks_DB`. Note the intentional "Tweeks" spelling throughout.

## File Map
```
core/
  init.lua           — addon entry, theme constants (addon.UI_THEME), DB init, slash cmd
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
    af_defaults.lua      — all default config values, single source of truth; M.CATEGORIES, M.TIMER_CATEGORIES
    af_functions.lua     — small shared Aura Frames helpers: CDM viewer lookup, frame position sync, setting/font-size fallback lookup, custom-frame entry/filter helpers
    af_scan.lua          — aura scanning: unified_scan(), custom AuraFilters scans, CDM viewer reads, session classification memory
    af_render.lua        — render_aura_map(), set_timer_text(), merge_aura_info()
    af_icon_layout.lua   — setup_layout(), set_height_for_growth(), get_bar_layout_params(), is_timer_text_enabled()
    af_core.lua          — tick_visible_icons(), update_auras(), toggle_blizz_buffs/debuffs()
    af_gui.lua           — Aura Frames settings shell; M.BuildSettings(), dropdown wrappers, sync_general_controls_from_db()
    af_gui_tree.lua      — Frames tab tree/sidebar; Buffs, WoW Cooldown, and Filters groups
    af_gui_frame_builders.lua — all Aura Frames content panels; General, Spell ID, preset Buff/CDM, and custom Filters builders
    af_main.lua          — init, frame creation, icon pool, drag/resize, on_reset_complete
    af_test_aura.lua     — fake aura preview system
    af_debug_outlines.lua — add_debug_outline(), refresh_section_outlines()
    af_grid.lua          — snap_to_grid(), build_grid_lines(), create_grid_overlay(), set_grid_visible()
libs/            — LibStub, LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0
media/fonts/     — monospace TTFs: SourceCodePro (selectable), Inconsolata, JetBrainsMono, RobotoMono, 0xProto (on disk, not yet selectable)
```

## File Header Standard
Every lua file must open with a brief comment (up to a few sentences) explaining what the file does, placed before `local addon_name, addon = ...`. The comment should describe the file's role/responsibility in plain terms and mention its key public functions or how it fits into the larger system. Do not use a bare filename label as a substitute.

## Architecture Rules
- **Module pattern:** `local addon_name, addon = ...` at top of every file; modules share the `addon` namespace table.
- **Self-registration:** modules call `addon.register_category(name, builder_fn)` to appear in the settings sidebar.
- **Versioning:** `LsTweeks.toc` is the only version edit point. Runtime display must read through `addon.get_version()`, which caches `C_AddOns.GetAddOnMetadata(addon_name, "Version")`; do not hardcode version fallbacks in Lua/docs.
- **DB access:** `Ls_Tweeks_DB.module_key = Ls_Tweeks_DB.module_key or {}` — always guard with `or {}`.
- **Init pattern:** every module creates a loader frame, registers ADDON_LOADED, and unregisters after first fire.
- **Hot paths:** cache WoW globals at file top — `local floor = math.floor`, `local GetTime = GetTime`, etc.
- **Theme constants:** spacing, fonts, widths live in `addon.UI_THEME` (set in `core/init.lua`) — don't hardcode.
- **Deferred batching:** UNIT_AURA events are bucketed at 0.1s; timer ticker runs at 0.1s.
- **InCombatLockdown:** defer layout/geometry changes; `update_auras()` skips frame scale, anchoring, sizing, layout setup, and height changes during combat. Never call protected WoW API during combat.
- **Reset contract:** every module must implement `M.on_reset_complete()` to resync controls from DB after reset. Apply defaults via `addon.apply_defaults(defaults, db)`, not manual `or` guards.
- **Taint safety:** never call Blizzard frame methods (UpdateAuras, UpdateLayout) from addon context — even deferred. Restore events + Show() only and let Blizzard's handlers fire naturally.

## Layout Rules (critical — violations cause invisible controls)
- **All widget internals anchor to their own container** — never chain anchors off a sibling inside a factory function.
- **One SetPoint per anchor direction per frame** — two TOPLEFT calls on the same frame = conflicting constraint, undefined result.
- **Never call `frame:GetWidth()` at build time** — returns 0 until the frame is rendered; use hardcoded constants for layout math.
- **External placement is always one `SetPoint` call** — factory functions must NOT call SetPoint themselves if the caller will place them.
- **`CreateSliderWithBox` has a built-in 0.1s debounce** — do not add an external debounce in the callback.

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
    -- learned static/long spell IDs are session-scoped in M._known_static / M._known_long, not persisted
    -- per-category keys: <setting>_<cat> e.g. show_static, color_debuff, scale_short
    positions = { static={x,y}, short={x,y}, long={x,y}, essential={x,y}, utility={x,y}, tracked_buffs={x,y}, tracked_bars={x,y}, debuff={x,y} },
    custom_frames = {                  -- array of custom filtered frame entry tables
      -- each entry: { id, name, aura_base_filter="HELPFUL|HARMFUL", aura_modifier="NONE|...",
      --               position={x,y},
      --               show, move, bg, bg_color, bar_mode, color, bar_bg_color,
      --               growth, timer, scale, spacing, max_icons, width, ... }
    },
  }
}
```

## Aura Frame Categories
Preset categories: `static`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`, `debuff`.
`essential`, `utility`, `tracked_buffs`, and `tracked_bars` are backed by live WoW Cooldown Manager viewers.
DB keys follow the pattern `aura_frames.<setting>_<category>` (e.g. `show_static`, `color_debuff`).
Positions are stored under `aura_frames.positions.<category>`.
First-install/default visible frames are only the four player-aura presets: `static`, `short`, `long`, and `debuff`. CDM-backed defaults keep `show_*`, `move_*`, and `test_aura_*` false so they do not appear as live frames, empty movable frames, or previews until enabled by the user.

Custom aura frames are filter-driven, not whitelist-driven. Each custom frame has the same main settings grid as preset categories, plus a `Filters` child node with two dropdowns rendered as `HELPFUL | MODIFIER` or `HARMFUL | MODIFIER`. Modifier `"NONE"` omits the suffix. Some modifiers force the base (`CANCELABLE`, `NOT_CANCELABLE`, `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE` -> `HELPFUL`; `CROWD_CONTROL`, `RAID_PLAYER_DISPELLABLE` -> `HARMFUL`). Custom frames scan only when enabled/previewed with `C_UnitAuras.GetAuraDataByIndex("player", index, M.get_custom_aura_filter(entry))` from `af_scan.lua`, tag entries with `custom_order`, and render in selected-filter scan order instead of the preset time/name sort path. Runtime call-chain variables use `aura_filter` for the selected AuraFilters string. Custom scans are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; `af_main.lua` clears that cache on aura-affecting events.

## Aura Frames GUI Layout System
`af_gui.lua` owns the settings shell: `BuildSettings` creates three tabs, restores the selected tab, and dispatches to panel builders. It should stay focused on GUI orchestration and shared dropdown wrappers.

`BuildSettings` has three tabs: **General** (manual anchoring), **Frames** (tree + grid), and **Spell ID** (tooltip spell ID toggle).

`af_gui_tree.lua` owns the **Frames** tab left tree sidebar (140px wide) with three outlined groups: **Buffs** (Static/DeBuff/Short/Long), **WoW Cooldown** (button title + Sync to CDM + Essential/Utility/Tracked Buffs/Tracked Bars), and **Filters** (+ Custom button first, then custom entries with expandable Filters child nodes). Selecting a node lazy-builds a content panel to the right. The active tree node colors its group outline gold; inactive group outlines are gray. Group spacing is controlled by `GROUP_INNER_PAD`, `GROUP_ELEMENT_GAP`, and `GROUP_GAP` in `af_gui_tree.lua`.

`af_gui_frame_builders.lua` owns all content panel builders: **General**, **Spell ID**, preset Buff/CDM frame panels, custom frame settings, and custom filter child panels.

TODO: Examine consolidating the preset/custom `place_at()` grid helpers in `af_gui_frame_builders.lua` into one shared helper. Highlander rule: there can be only one placement path unless the layouts genuinely diverge.

Preset and custom content panels each use `place_at(control, row, column, slot, opts)` with a 4-column grid:
- `col_gap=150`, `col_offset=-20` → `grid[1]=-20`, `grid[2]=130`, `grid[3]=280`, `grid[4]=430`
- `col_width=190` — centering zone within each column
- All 4 columns center-aligned by default (`col_align = {"center","center","center","center"}`)
- `opts.align` overrides per-call ("left", "center", "right")
- 5 rows: `row_heights = {130, 60, 90, 120, 110}`, `row_start=10`, `row_gap=20`
- `slot` maps to `grid.offsets`: `dropdown=8`, `picker=4`, `default=0`
- `opts.valign="bottom"` descends one extra row height

Aura frame saved positions are stored in unscaled UIParent-center coordinates. Runtime placement uses `M.apply_frame_position(frame, pos, scale)` and drag/slider sync uses `M.read_frame_position(frame)` / `M.sync_frame_position_to_db(frame, pos)` so scaled frames do not jump when moved.

## UI Shared Controls — Quick Reference
| Function | Key args | Notes |
|---|---|---|
| `CreateCheckbox(parent, label, checked, cb)` | returns container, checkbox, label | container width is dynamic |
| `CreateSliderWithBox(name, parent, label, min, max, step, db, key, defaults, cb)` | returns container (130×95) | has built-in 0.1s debounce; `container.slider` exposed |
| `CreateDropdown(name, parent, label, options, cfg)` | cfg: width, row_height, get_value, on_select | custom popup |
| `M.CreateListDropdown(name, parent, label, opts, get_val, on_sel, width)` | returns dropdown | af_gui wrapper with font support |
| `CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb)` | integrated reset | container is 95×45 |
| `CreateRivetedPanel(parent, w, h, anchorTo, point, x, y, levelOffset)` | returns panel, fontstring | |
| `CreateGlobalReset(parent, db, defaults)` | ARM-code safety reset; blocked in combat | |

## Debug Outlines (af_debug_outlines.lua)
`M.db.show_bar_section_outlines` toggles 1px borders on aura icon slots.  
Toggle via `M.refresh_section_outlines()`. Outline textures are tagged `._is_outline = true` for safe removal.  
Do NOT use `SetParent(nil)` to remove textures — use `Hide()` + `SetTexture(nil)` on tagged textures only.

## Grid Snap (af_grid.lua)
20px grid, screen-center origin — matches LsTweeks coordinate system exactly.  
`M.snap_to_grid(v, is_y)` — snaps a coordinate. `M.set_grid_visible(show)` — toggles overlay. 
DB keys: `aura_frames.snap_to_grid`, `aura_frames.show_grid`.

## Riveted Panel Style
Marble background, ornate dialog-frame borders, 4 corner rivet textures. Apply via `addon.ApplyRivetedPanelStyle(frame, opts)` or `addon.AddRivetCorners(frame, inset, offX, offY)`.

## Key WoW API Used
- `C_UnitAuras.GetBuffDataByIndex / GetDebuffDataByIndex` — aura scanning
- `C_UnitAuras.GetAuraDuration` — returns a Duration object (12.0+); use `:GetRemainingDuration()`, `:GetExpirationTime()`
- `C_UnitAuras.GetUnitAuraInstanceIDs` — sort-ordered ID list for render
- `C_UnitAuras.DoesAuraHaveExpirationTime` — secret-safe boolean expiry check
- `C_UnitAuras.GetAuraApplicationDisplayCount` — stack count fallback
- `ColorPickerFrame` — system color picker
- `InCombatLockdown()` — combat guard
- `LibDataBroker`, `LibDBIcon` — minimap button

## error lesson
error on reload, a window is immediately displayed with a message and 2 buttons, disable, ignore
LsTweeks has been blocked from an action only available tot he Blizzard UI. You can disable this addon and relaod the UI.
was result of CLEU issue
