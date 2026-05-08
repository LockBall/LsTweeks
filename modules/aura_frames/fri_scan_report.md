# Aura Frames Module — Scan Report
*Generated: 2026-05-07 | Files: 13 | Total lines: ~5,850*

---

## 1. Dead Code

### 1a. `af_scan.lua:828–832` — unreachable `belongs = true` guard
```lua
else
    belongs = true   -- set here
    if not belongs and ... then  -- can never be true
        belongs = true
    end
end
```
`belongs` is set unconditionally on line 830; the `if not belongs` check immediately below can never fire. Leftover from an older conditional structure.

---

### 1b. `af_gui_tree.lua:562–616` — entire "Learned" preset child scaffold is inert
```lua
local learned_key, expanded_key, learned_builder  -- all nil, never assigned
local has_learned_child = learned_key ~= nil       -- always false
```
`has_learned_child` is always `false`, so the arrow button, child row, and expand/collapse logic inside the `for _, data in ipairs(frames_data)` loop (lines 566–616) are never activated. This appears to be scaffolding for a "Learned spells" sub-node that was never finished or was later backed out without removing the host code. All of the following within that block are permanently dead:
- The `arrow`/`arrow_fs` frame creation
- The `child_btn`/`child_fs` row creation and its `OnClick`
- The arrow expand/collapse `OnClick` for preset nodes

---

### 1c. `af_gui_tree.lua:392–393` — stale `y` correction before `rebuild_tree()`
```lua
if not M._custom_expanded[id] then
    y = y + (ROW_H + GROUP_ELEMENT_GAP)  -- dead
end
if add_btn_ref then
    rebuild_tree()  -- recalculates everything from scratch
end
```
The `y` variable being modified here is the loop-local cursor from the iteration that built this arrow's script. `rebuild_tree()` ignores it and recomputes the full layout independently. The `y =` line has no effect.

---

### 1d. `af_render.lua:38–39` — `format_time` last two branches produce identical output
```lua
if s >= 1 then return format("%.1f s", s) end
return format("%.1f s", s)  -- identical format
```
For any `s < 5`, both the `if s >= 1` branch and the final `return` produce `"%.1f s"` — same format string, same value. The `if s >= 1` check is therefore a no-op; the only meaningful threshold boundary missing is between whole-second and sub-second display. Either the `>= 1` branch was intended to use `"%d s"` or the sub-second case was meant to drop the space/suffix.

---

## 2. Repeated / Duplicate Code

### 2a. `af_render.lua` — `show_cooldown_overlay` recalculated inside every loop iteration
```lua
for i = 1, display_count do
    ...
    local show_cooldown_overlay = M.uses_cooldown_icon_overlay(self.category, bar_mode, M.db)
```
`self.category`, `bar_mode`, and `M.db` do not change across iterations. This call (which does a hash lookup on `M.db`) runs once per displayed aura. It should be hoisted above the loop alongside `bar_mode`.

---

### 2b. `af_render.lua` — `show_timer_text and not show_cooldown_overlay` guard repeated 4+ times
Within the ~80-line non-static timer block (lines 455–536), the pattern:
```lua
if show_timer_text and not show_cooldown_overlay then
    M.set_timer_text(obj.time_text, timer_category, rem)
else
    obj.time_text:SetText("")
end
```
appears in four structurally identical call sites (secret-rem path, positive-rem path, fallback-expiration path, and the `entry.duration > 0` branch). This is the dominant repeat in the render function and would compress significantly into a local `show_text` bool or a small inline helper.

---

### 2c. `af_gui_frame_builders.lua` — growth direction dropdown rebuilt inline for custom frames
`build_preset_frame_panel` uses:
```lua
M.CreateDirectionDropdown(addon_name..cat.."Growth", p, "Growth Direction",
    frame_setting_key(frame_config, "growth"), update)
```
`build_custom_settings_panel` manually duplicates the direction list and calls `addon.CreateDropdown` directly with its own `get_value`/`on_select`. `CreateDirectionDropdown` only hard-codes `M.db[db_key]`; the custom variant needs to read from `frame_config.value_table[key]` instead. The solution is either a `value_table` parameter on `CreateDirectionDropdown`, or a shared `make_growth_dropdown(name, parent, get_value, on_select)` local.

---

### 2d. Title-bar name update is written in two places
**`af_gui_frame_builders.lua:577–587`** — `update_custom_frame_title(entry)`:
```lua
frame.title_bar.label_text:SetText(entry.name or entry.id)
frame.bottom_title_bar.label_text:SetText(entry.name or entry.id)
```
**`af_gui_tree.lua:277–284`** — inside `commit_rename`:
```lua
frame.title_bar.label_text:SetText(new_name)
frame.bottom_title_bar.label_text:SetText(new_name)
```
Exact same logic, not sharing the function. `commit_rename` in the tree should call `update_custom_frame_title(entry)` (or `M.on_custom_frame_renamed` already exists for the tree-label side — the title-bar side just needs to be folded in).

---

### 2e. `af_main.lua:run_wow_cooldown_refresh` — three separate loops over `WOW_COOLDOWN_CATEGORIES`
```lua
if prepare_viewers then
    for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do ... end
end
if clear_child_cache then
    for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do ... end
end
for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do ... end  -- always
```
All three loops walk the same list. A single loop with conditional bodies inside would be cleaner and avoid the triple traversal.

---

## 3. Inconsistencies

### 3a. `af_core.lua:294` — mixed local-vs-module table check
```lua
if WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[category] then
```
`WOW_COOLDOWN_CATEGORIES` is the local assigned at file load time (`= M.WOW_COOLDOWN_CATEGORIES`). If `af_core.lua` loads before `af_defaults.lua` (which populates the table), the local would be `nil` and the guard short-circuits. The actual lookup then uses `M.WOW_COOLDOWN_CATEGORIES` directly. The local guard is a reliability workaround that obscures whether the module table is expected to be set yet; use only `M.WOW_COOLDOWN_CATEGORIES` for both guard and lookup.

---

### 3b. `af_core.lua:update_auras` — `self:Show()` called three times
```lua
self:Show()                              -- line 262 (after activity check)
...
self:Show()                              -- line 331 (after height calc)
if not self:IsVisible() then self:Show() end  -- line 336 (guard)
```
Lines 331 and 336 are redundant with each other. Line 262 is the meaningful early-show; lines 331 and 336 can be collapsed to one (either the explicit call or the guard, not both).

---

### 3c. `af_functions.lua:read_frame_bool` — check 2 and check 3 hit the same table for preset frames
```lua
if cfg_db and cfg_db[key] ~= nil then ...              -- check 1: flat key
if category and cfg_db and cfg_db[key.."_"..category] ~= nil -- check 2: prefixed key in cfg_db
if category and M.db and M.db[key.."_"..category] ~= nil    -- check 3: prefixed key in M.db
```
For preset frames `cfg_db == M.db`, so checks 2 and 3 are identical lookups. Check 3 is unreachable when check 2 would succeed. The function works correctly but the redundant path adds reader confusion.

---

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
The non-static timer block (lines 449–536) contains 4–5 nested `if`/`elseif` branches where bar-mode and show-timer-text cross-cut. The block has grown organically and is difficult to follow. Splitting out a `set_obj_timer_and_bar(obj, entry, rem, live_rem, live_duration, cooldown_duration, ...)` helper would make the main loop readable.

---

## 5. Summary Table

| # | File | Type | Severity |
|---|------|------|----------|
| 1a | `af_scan.lua:830` | Dead code — unreachable `belongs` guard | Low |
| 1b | `af_gui_tree.lua:562–616` | Dead code — entire Learned child scaffold | Medium |
| 1c | `af_gui_tree.lua:392` | Dead code — stale `y` before rebuild | Low |
| 1d | `af_render.lua:38–39` | Dead code — identical `format_time` branch | Low |
| 2a | `af_render.lua` | Repeated — `show_cooldown_overlay` inside loop | Low |
| 2b | `af_render.lua` | Repeated — timer text guard 4× in 80 lines | Medium |
| 2c | `af_gui_frame_builders.lua` | Repeated — growth dropdown rebuilt inline | Low |
| 2d | `af_gui_tree.lua` / `af_gui_frame_builders.lua` | Repeated — title bar rename logic | Low |
| 2e | `af_main.lua` | Repeated — 3 loops over same category list | Low |
| 3a | `af_core.lua:294` | Inconsistent — local vs module table guard | Low |
| 3b | `af_core.lua` | Inconsistent — `self:Show()` × 3 | Low |
| 3c | `af_functions.lua` | Inconsistent — `read_frame_bool` check 3 unreachable | Low |
| 3d | `af_gui_frame_builders.lua` | Inconsistent — drag sync missing for custom frames | Medium |
| 3e | `af_gui_frame_builders.lua` | Inconsistent — `SetScript` vs `HookScript` | Low |
| 3f | `af_gui_frame_builders.lua` | Inconsistent — `create_bound_checkbox` bypasses config | Low |
| 4a | `af_scan.lua` | Structural — max_helpful hardcodes category names | Medium |
| 4b | `af_gui_tree.lua` | Structural — `CD_GROUP_KEYS` duplicates `M.WOW_COOLDOWN_CATEGORIES` | Low |
| 4c | `af_gui_tree.lua` | Structural — layout state leaked to module table | Low |
| 4d | `af_main.lua` | Structural — font priority logic duplicated and inconsistent | Low |
| 4e | `af_render.lua` | Structural — 240-line render function, deep nesting | Medium |

**Medium-priority items (worth fixing soon):** 1b, 2b, 3d, 4a, 4e  
**Low-priority items (clean-up pass):** everything else  
No correctness bugs were found; all issues are quality/maintainability.
