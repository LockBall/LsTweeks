# Skyriding Vigor Adjustments Review

Started: 2026-06-24

Updated: 2026-06-25


## Context Read
1. [x] Followed `internal_dev/working_docs/proj_mem/agent_start.md`.

2. [x] Read public and internal context: `README.md`, `project.md`, `code_map.md`, `skyriding_vigor.md`, and `scratchpad.md`.

3. [x] Reviewed current Skyriding Vigor implementation files: `sv_defaults.lua`, `sv_styles.lua`, `sv_bar.lua`, `sv_fade.lua`, `sv_state.lua`, `sv_gui.lua`, and `sv_main.lua`.


## Current Worktree Notes
1. [ ] Existing unrelated modified files before Skyriding Vigor work: `internal_dev/completed_features/aura_frames.md`, `internal_dev/working_docs/proj_mem/aura_frames.md`, and `modules/aura_frames/af_core.lua`.

2. [ ] Leave the Aura Frames changes untouched while making Skyriding Vigor edits.


## Discrepancies And Issues To Revisit

1. [ ] Dropdown hover indicators now use a small custom gold triangle from line textures in `functions/dropdown.lua`, but it looks worse than the native WoW dropdown arrow. Revisit later with a proper in-game asset. Rejected attempts are recorded in `project.md`: text glyph rendered as an empty box, `Interface\Buttons\UI-SortArrow` was too thin/barely visible, and `Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up` was a different bad arrow shape.


## GUI Streamlining Review
1. [ ] `sv_gui.lua` is long enough to justify streamlining. At review time it was 1,062 lines, larger than sibling GUI files checked in the same pass: `modules/sound_levels/sl_gui.lua` at 644 lines and `modules/aura_frames/af_gui.lua` at 453 lines.

2. [x] Grid placement-table mapping was moved into the shared `addon.CreateSettingsGrid()` object on 2026-06-25. Skyriding Vigor now routes normal control placement through `grid:place(control, placement)` and dynamic centering through `grid:center(control, placement)`, leaving only module-specific placement data local.

3. [ ] The main maintainability issue is not total line count alone. The largest concrete issue is that `M.BuildSettings()` is one linear construction function from line 489 to EOF, mixing setup, proxy construction, row layout, control creation, callbacks, runtime button wiring, race profile panel sizing, and reset panel placement.

4. [ ] Recommended first step: keep `sv_gui.lua` as the owner of Skyriding Vigor settings UI construction and control synchronization, but extract local section-builder functions inside the same file before considering a multi-file split.

5. [ ] Suggested local builder seams: `build_top_row(parent, context)`, `build_position_row(parent, context)`, `build_decor_row(parent, context)`, `build_fade_row(parent, context)`, `build_spark_row(parent, context)`, `build_race_profile_panel(parent, context)`, and `build_reset_panel(parent, context)`.

6. [ ] Use a small local `context` table for `cfg`, `db`, `root_db`, `defaults`, `col_step_x`, `row_step_y`, and commonly reused proxies. Keep layout constants and private builders local instead of pushing them onto `M`.

7. [ ] Avoid an immediate multi-file split unless the file keeps growing after local builders are extracted. The `.toc` currently loads `sv_gui.lua` before `sv_main.lua`; GUI callbacks reference runtime functions assigned later but generally call them only after user interaction. Splitting GUI sync/build/layout into separate files would require more careful `.toc` ordering and durable ownership notes.

8. [ ] Most shared GUI data is intentionally local (`UI_CONFIG`, `ROWS`, `CONTROL_GRID`, `STRINGS`). A multi-file split would either duplicate those tables or expose them through `M`, increasing module surface area.

9. [ ] If a later split becomes worthwhile, a plausible shape is `sv_gui_layout.lua` for layout constants and placement helpers, `sv_gui_sync.lua` for exported `M.sync_*` functions, and `sv_gui.lua` for settings construction and section builders. Before doing that, update `LsTweeks.toc` load order and `internal_dev/working_docs/proj_mem/skyriding_vigor.md`, because current memory says `sv_gui.lua` owns both construction and sync helpers.
