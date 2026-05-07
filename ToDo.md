## Aura Frames Code Audit

### Duplicate Function Definitions (High Priority)

- [x]  1.  **`set_icon_greyed()`** — removed from af_core.lua entirely; render owns it, ticker calls eliminated.

- [x]  2. **`set_count_text()`** — removed from af_core.lua entirely; render owns it, ticker call eliminated.

- [x]  3. **`compute_remaining()`** — consolidated in [af_scan.lua](af_scan.lua); custom filtered scans now live there too.

---

### Post Custom-Scan Refactor Cleanup (Medium Priority)

- [x]  4. **`M.compute_remaining` public export** — removed orphaned `M.compute_remaining = compute_remaining`; all callers use the local helper in [af_scan.lua](af_scan.lua).

- [x]  5. **Custom scan entry assembly drift** — extracted shared timing/count helpers in [af_scan.lua](af_scan.lua) so custom, helpful, and debuff scan paths share live duration fallback, stack/live count lookup, and safe duration/expiration/remaining resolution.

- [x]  6. **Custom-frame sort lookup** — [af_core.lua](af_core.lua) now skips `sort_mode` resolution for custom frames; [af_render.lua](af_render.lua) keeps the explicit selected-filter scan-order path when `self.is_custom`.

- [x]  7. **Duplicate custom AuraFilters scans** — [af_scan.lua](af_scan.lua) now caches custom scan results by `aura_filter` and threshold, lazily extends the cache when a later frame needs more entries, and [af_main.lua](af_main.lua) clears the cache on aura-affecting events.

---

### Inline Sequences Worth Extracting (Medium Priority)

- [x]  8. **CDM viewer frame lookup** — added [af_functions.lua](af_functions.lua) and centralized CDM viewer resolution in `M.get_cdm_viewer_frame(category)`.

- [x]  9. **Frame position sync** — moved frame position helpers into [af_functions.lua](af_functions.lua) and added `M.sync_frame_position_to_db(frame, pos_table)` for shared TOPLEFT position writes.

- [x]  10. **Color setting lookup with fallback chain** — added generic `M.get_setting(cfg_db, category, key, fallback)` in [af_functions.lua](af_functions.lua) and applied it to shared runtime color lookups:
```lua
local c = cfg_db and cfg_db.timer_color
    or (category and M.db and M.db["timer_color_"..category])
    or (M.db and M.db.timer_color)
```

- [x]  11. **Backdrop setup** — added shared backdrop helpers in [af_functions.lua](af_functions.lua) for tooltip-border panels, title bars, and thin tree/sidebar borders; [af_main.lua](af_main.lua), [af_gui_frame_builders.lua](af_gui_frame_builders.lua), and [af_gui_tree.lua](af_gui_tree.lua) use them.

---

### Defaults File Purity (Medium Priority)

- [x]  12. **Move custom-frame runtime helpers out of defaults** — [af_defaults.lua](af_defaults.lua) now keeps custom-frame defaults/constants only; `next_custom_name()`, `next_custom_id()`, `M.new_custom_entry()`, `M.get_custom_aura_filter()`, and `M.get_custom_modifier_def()` live in [af_functions.lua](af_functions.lua).

- [x]  13. **Move timer font-size lookup out of defaults** — `M.get_timer_number_font_size(category, cfg_db)` now lives in [af_functions.lua](af_functions.lua), near `M.get_setting()`, and the [af_defaults.lua](af_defaults.lua) header now describes defaults/constants only.

- [x]  14. **Remove redundant position fallback blocks** — now that [af_functions.lua](af_functions.lua) loads before core/main/GUI, repeated fallback branches around `M.apply_frame_position` in [af_core.lua](af_core.lua), [af_main.lua](af_main.lua), and [af_gui_frame_builders.lua](af_gui_frame_builders.lua) are simplified to direct shared-helper calls.

---

### Settings Panel Builder Duplication (Medium Priority)

- [ ]  15. [af_gui_frame_builders.lua](af_gui_frame_builders.lua) preset/custom panels now share `M.create_settings_grid(parent, opts)` for `place_at` and `add_row_separator`. Remaining follow-up: evaluate whether `create_bound_checkbox`, `create_bound_slider`, and color-picker binding can share one helper without obscuring preset DB-vs-custom entry differences.

---

## Other

- CDM frames get turned on but not turned off when custom delete, adjust default behavior
- a brief guided tour would be nice
- portrait dim out of combat
- dungeon ready sound levels
- saves
