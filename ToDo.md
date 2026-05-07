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

- [ ]  8. **CDM viewer frame lookup** — this 3-line guard appears 4+ times across [af_core.lua](af_core.lua) and [af_scan.lua](af_scan.lua):
```lua
local frame_name = M.CDM_VIEWER_FRAMES and M.CDM_VIEWER_FRAMES[category]
local frame = frame_name and _G[frame_name]
if not frame then return end
```
Candidate for `M.get_cdm_viewer_frame(category)`.

- [ ]  9. **Frame position sync** — appears 3 times across [af_gui_frame_builders.lua](af_gui_frame_builders.lua) and [af_main.lua](af_main.lua):
```lua
local x, y = M.read_frame_position(frame)
if x and y then pos.point = "TOPLEFT"; pos.x = x; pos.y = y end
```
Candidate for `M.sync_frame_position_to_db(frame, pos_table)`.

- [ ]  10. **Color setting lookup with fallback chain** — appears 5+ times in [af_render.lua](af_render.lua):
```lua
local c = cfg_db and cfg_db.timer_color
    or (category and M.db and M.db["timer_color_"..category])
    or (M.db and M.db.timer_color)
```
Candidate for `M.get_color_setting(cfg_db, category, key)`.

- [ ]  11. **Backdrop setup** — near-identical `BackdropTemplate` + color setup blocks appear in [af_main.lua](af_main.lua), [af_gui_frame_builders.lua](af_gui_frame_builders.lua), and [af_gui_tree.lua](af_gui_tree.lua). Could be a shared `apply_standard_backdrop(frame)` helper.

---

### Settings Panel Builder Duplication (Medium Priority)

- [ ]  12. [af_gui_frame_builders.lua](af_gui_frame_builders.lua) defines nearly identical grid layout infrastructure (`place_at`, `add_row_separator`, `create_bound_checkbox`, `create_bound_slider`) twice — once inside `M.build_preset_frame_panel` and again inside `M.build_custom_settings_panel`. These nested closures share the same signatures; the layouts are now close enough that the earlier `proj_mem.md` `place_at()` note should be handled here, not as a separate duplicate. A shared `build_settings_grid(parent, config)` factory could eliminate the duplication if it stays readable.

---

## Other

- CDM frames get turned on but not turned off when custom delete, adjust default behavior
- a brief guided tour would be nice
- portrait dim out of combat
- dungeon ready sound levels
- saves
