## Remaining Work

# Aura Frames Module — Scan Report
*Generated: 2026-05-07 | Files: 13 | Total lines: ~5,850*
*Updated: 2026-05-08 | Completed dead-code cleanup and removed obsolete aura-learning remnants*

---

## 3. Inconsistencies

### 3d. Drag-stop sync only wired for preset frames, not custom frames
`build_preset_frame_panel` hooks `OnDragStop` on both title bars to call `sync_xy_sliders_to_frame()`, keeping the X/Y position sliders live after a drag. `build_custom_settings_panel` has no equivalent — after dragging a custom frame, its X/Y sliders show stale values until the panel is rebuilt.

---

### 3e. `build_preset_frame_panel` uses `SetScript` to chain drag stop vs `HookScript`
```lua
local old_drag_stop = tb:GetScript("OnDragStop")
tb:SetScript("OnDragStop", function(...)
    if old_drag_stop then old_drag_stop(...) end
    sync_xy_sliders_to_frame()
end)
```
`HookScript` is the correct WoW API for this pattern. Using `SetScript` with manual old-script preservation is fragile; if ever called a second time (e.g., a settings rebuild), the old script gets double-wrapped. Use `tb:HookScript("OnDragStop", sync_xy_sliders_to_frame)` directly.

---

### 3f. `af_gui_frame_builders.lua:create_bound_checkbox` wrapper hardcodes `M.db`
```lua
local function create_bound_checkbox(label, db_key, row, column, ...)
    return create_bound_checkbox_control(p, label, M.db, db_key, ...)
```
For preset frames `frame_config.value_table` is `M.db`, so this is harmless — but it bypasses the config abstraction and makes the wrapper unsafe to reuse for any context where the value table differs.

---

## 4. Structural / Maintainability Issues

### 4a. `af_scan.lua:unified_scan` — max_helpful hardcodes all helpful category names
```lua
local max_helpful = math_max(
    max_helpful_hint or 0,
    math_max(db.max_icons_static or M.MAX_ICONS_LIMIT,
        math_max(db.max_icons_short or M.MAX_ICONS_LIMIT,
            math_max(db.max_icons_long or M.MAX_ICONS_LIMIT,
                math_max(db.max_icons_essential or M.MAX_ICONS_LIMIT,
                    math_max(db.max_icons_utility or M.MAX_ICONS_LIMIT,
                        math_max(db.max_icons_tracked_buffs or M.MAX_ICONS_LIMIT,
                                 db.max_icons_tracked_bars  or M.MAX_ICONS_LIMIT)))))))
)
```
Seven levels of nesting, all category names written out by hand. A new non-debuff category added to `FRAME_DEFS` would silently not be covered. Should iterate `M.FRAME_DEFS` (or `M.CATEGORIES`) and skip `is_debuff == true` entries.

---

### 4b. `af_gui_tree.lua` — `CD_GROUP_KEYS` duplicates `M.WOW_COOLDOWN_CATEGORIES`
```lua
local CD_GROUP_KEYS = {
    essential = true, utility = true,
    tracked_buffs = true, tracked_bars = true,
}
```
`M.WOW_COOLDOWN_CATEGORIES` (a flat `{key = true}` table) already encodes exactly these four. `CD_GROUP_KEYS` can be replaced with `M.WOW_COOLDOWN_CATEGORIES` directly, eliminating a drift risk when CDM categories change.

---

### 4c. `af_gui_tree.lua` — `M._filters_add_y` and `M._custom_expanded` written to module table as layout side-effects
`M._filters_add_y` and `M._custom_expanded` are ephemeral layout/UI state written to the module table from inside `build_frames_tab`. Since the settings frame is a singleton this works in practice, but it makes `M` a grab-bag for transient closure state. Both should be closed-over locals inside `build_frames_tab` (which they nearly are — `_filters_add_y` just needs to be a plain upvalue; `_custom_expanded` is accessed by `rebuild_tree` which is a closure that could carry it directly).

---

### 4d. `af_main.lua:get_number_font_def` / `apply_number_font_to_text` — priority logic inconsistency
Both functions resolve a font key/bold setting via the same three-tier priority (frame-level → category-level → global) but implement it slightly differently. `get_number_font_def` has:
```lua
if cfg_db and db.timer_number_font then   -- cfg_db supplied → use flat key
elseif category and db["timer_number_font_"..category] then  -- category-specific
else db.timer_number_font                  -- same as first branch
```
`apply_number_font_to_text` has the same shape for `use_bold`. The shared priority resolution pattern should be a single utility (similar to `M.get_setting` in `af_functions.lua`) applied consistently.

---

### 4e. `af_render.lua` — `render_aura_map` is ~240 lines with deeply nested timer/bar logic
The non-static timer block (lines 449–536) contains 4–5 nested `if`/`elseif` branches where bar-mode and show-timer-text cross-cut. The block has grown organically and is difficult to follow. Splitting out a `set_obj_timer_and_bar(obj, entry, remaining, live_remaining, live_duration, cooldown_duration, ...)` helper would make the main loop readable.

---

## 5. Summary Table

| # | File | Type | Severity |
|---|------|------|----------|
| 3d | `af_gui_frame_builders.lua` | Inconsistent — drag sync missing for custom frames | Medium |
| 3e | `af_gui_frame_builders.lua` | Inconsistent — `SetScript` vs `HookScript` | Low |
| 3f | `af_gui_frame_builders.lua` | Inconsistent — `create_bound_checkbox` bypasses config | Low |
| 4a | `af_scan.lua` | Structural — max_helpful hardcodes category names | Medium |
| 4b | `af_gui_tree.lua` | Structural — `CD_GROUP_KEYS` duplicates `M.WOW_COOLDOWN_CATEGORIES` | Low |
| 4c | `af_gui_tree.lua` | Structural — layout state leaked to module table | Low |
| 4d | `af_main.lua` | Structural — font priority logic duplicated and inconsistent | Low |
| 4e | `af_render.lua` | Structural — 240-line render function, deep nesting | Medium |

**Medium-priority items (worth fixing soon):** 3d, 4a, 4e  
**Low-priority items (clean-up pass):** everything else  
No correctness bugs were found; all issues are quality/maintainability.


### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
