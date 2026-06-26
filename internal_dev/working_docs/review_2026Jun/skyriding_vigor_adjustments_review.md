# Skyriding Vigor Adjustments Review


## Current Worktree Notes
1. [ ] Existing unrelated modified files before Skyriding Vigor work: `internal_dev/completed_features/aura_frames.md`, `internal_dev/working_docs/proj_mem/aura_frames.md`, and `modules/aura_frames/af_core.lua`.

2. [ ] Leave the Aura Frames changes untouched while making Skyriding Vigor edits.


## Discrepancies And Issues To Revisit

1. [ ] Dropdown hover indicators now use a small custom gold triangle from line textures in `functions/dropdown.lua`, but it looks worse than the native WoW dropdown arrow. Revisit later with a proper in-game asset. Rejected attempts are recorded in `project.md`: text glyph rendered as an empty box, `Interface\Buttons\UI-SortArrow` was too thin/barely visible, and `Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up` was a different bad arrow shape.


## GUI Streamlining Review
1. [x] `sv_gui.lua` is long enough to justify streamlining, but the main maintainability issue is that `M.BuildSettings()` is one linear construction function from line 449 to 1018. Reviewed on 2026-06-25: `sv_gui.lua` is 1,020 lines, still larger than sibling GUI files checked in the same pass: `modules/sound_levels/sl_gui.lua` at 644 lines and `modules/aura_frames/af_gui.lua` at 453 lines. `M.BuildSettings()` mixes setup, proxy construction, row layout, control creation, callbacks, runtime button wiring, race profile panel sizing, and reset panel placement.

2. [x] First refactor pass: keep `sv_gui.lua` as the owner of Skyriding Vigor settings UI construction and control synchronization, but extract local section-builder functions inside the same file.

    a. [x] Suggested builders: `build_top_row(parent, context)`, `build_position_row(parent, context)`, `build_decor_row(parent, context)`, `build_fade_row(parent, context)`, `build_spark_row(parent, context)`, `build_race_profile_panel(parent, context)`, and `build_reset_panel(parent, context)`.

        Completed 2026-06-25: `build_top_row(parent, context)`, `build_position_row(parent, context)`, `build_decor_row(parent, context)`, `build_fade_row(parent, context)`, `build_spark_row(parent, context)`, `build_race_profile_panel(parent, context)`, and `build_reset_panel(parent, context)` extracted. Existing `ROWS` / `CONTROL_GRID` placement data stayed unchanged. `build_spark_row()` owns the row 5 Skyriding Talents button because its placement is `ROWS.spark`. In-game inspection after the initial top/position/decor/fade/spark extractions looked good. `check_fast.ps1` passed after the full builder extraction.

    b. [x] Apply the addon-wide settings-builder rule from `project.md`: use a small local `context` table for repeated Skyriding Vigor build inputs such as `cfg`, `db`, `root_db`, `defaults`, grid helpers, and commonly reused proxies. Keep layout constants and private builders local instead of pushing them onto `M`.

3. [ ] Defer a multi-file split until after local builders are extracted and the file still proves too large or hard to maintain.

    a. [ ] Current split risks: `.toc` loads `sv_gui.lua` before `sv_main.lua`; GUI callbacks reference runtime functions assigned later but generally call them only after user interaction; shared GUI data is intentionally local (`UI_CONFIG`, `ROWS`, `CONTROL_GRID`, `STRINGS`), so a split would either duplicate those tables or expose them through `M`.

    b. [ ] If a later split becomes worthwhile, a plausible shape is `sv_gui_layout.lua` for layout constants and placement helpers, `sv_gui_sync.lua` for exported `M.sync_*` functions, and `sv_gui.lua` for settings construction and section builders. Before doing that, update `LsTweeks.toc` load order and `internal_dev/working_docs/proj_mem/skyriding_vigor.md`, because current memory says `sv_gui.lua` owns both construction and sync helpers.
