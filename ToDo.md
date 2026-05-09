## Remaining Work

# Aura Frames Module — Scan Report
*Generated: 2026-05-07 | Files: 13 | Total lines: ~5,850*
*Updated: 2026-05-08 | Completed dead-code cleanup and removed obsolete aura-learning remnants*

---

## 4. Structural / Maintainability Issues

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
| 4c | `af_gui_tree.lua` | Structural — layout state leaked to module table | Low |
| 4d | `af_main.lua` | Structural — font priority logic duplicated and inconsistent | Low |
| 4e | `af_render.lua` | Structural — 240-line render function, deep nesting | Medium |

**Medium-priority items (worth fixing soon):** 4e  
**Low-priority items (clean-up pass):** everything else  
No correctness bugs were found; all issues are quality/maintainability.


### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
