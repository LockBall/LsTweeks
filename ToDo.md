## Aura Frames Code Audit

### Duplicate Function Definitions (High Priority)

- [x]  1.  **`set_icon_greyed()`** — removed from af_core.lua entirely; render owns it, ticker calls eliminated.

- [ ]  2. **`set_count_text()`** — two variants exist. [af_core.lua](af_core.lua) has a simplified version; [af_render.lua](af_render.lua) has an extended version with point anchoring params. These should be merged into one function with optional params.

- [ ]  3. **`compute_remaining()`** — defined independently in both [af_custom_filter.lua](af_custom_filter.lua) and [af_scan.lua](af_scan.lua). Should live in one place.

---

### Inline Sequences Worth Extracting (Medium Priority)

- [ ]  4. **CDM viewer frame lookup** — this 3-line guard appears 4+ times across [af_core.lua](af_core.lua) and [af_scan.lua](af_scan.lua):
```lua
local frame_name = M.CDM_VIEWER_FRAMES and M.CDM_VIEWER_FRAMES[category]
local frame = frame_name and _G[frame_name]
if not frame then return end
```
Candidate for `M.get_cdm_viewer_frame(category)`.

- [ ]  5. **Frame position sync** — appears 3 times across [af_gui_frame_builders.lua](af_gui_frame_builders.lua) and [af_main.lua](af_main.lua):
```lua
local x, y = M.read_frame_position(frame)
if x and y then pos.point = "TOPLEFT"; pos.x = x; pos.y = y end
```
Candidate for `M.sync_frame_position_to_db(frame, pos_table)`.

- [ ]  6. **Color setting lookup with fallback chain** — appears 5+ times in [af_render.lua](af_render.lua):
```lua
local c = cfg_db and cfg_db.timer_color
    or (category and M.db and M.db["timer_color_"..category])
    or (M.db and M.db.timer_color)
```
Candidate for `M.get_color_setting(cfg_db, category, key)`.

- [ ]  7. **Backdrop setup** — near-identical `BackdropTemplate` + color setup blocks appear in [af_main.lua](af_main.lua), [af_gui_frame_builders.lua](af_gui_frame_builders.lua), and [af_gui_tree.lua](af_gui_tree.lua). Could be a shared `apply_standard_backdrop(frame)` helper.

---

### Settings Panel Builder Duplication (Medium Priority)

- [ ]  8. [af_gui_frame_builders.lua](af_gui_frame_builders.lua) defines nearly identical grid layout infrastructure (`place_at`, `add_row_separator`, `create_bound_checkbox`, `create_bound_slider`) twice — once inside `M.build_preset_frame_panel` and again inside `M.build_custom_settings_panel`. These nested closures share the same signatures; the only differences are column gap/offset constants. A shared `build_settings_grid(parent, config)` factory could eliminate the duplication.

---

## Other

- CDM frames get turned on but not turned off when custom delete, adjust default behavior
- a brief guided tour would be nice
- portrait dim out of combat
- dungeon ready sound levels
- saves

