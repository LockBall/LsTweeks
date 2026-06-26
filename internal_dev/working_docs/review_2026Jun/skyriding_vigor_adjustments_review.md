# Skyriding Vigor Adjustments Review


## Current Worktree Notes
1. [ ] Existing unrelated modified files before Skyriding Vigor work: `internal_dev/completed_features/aura_frames.md`, `internal_dev/working_docs/proj_mem/aura_frames.md`, and `modules/aura_frames/af_core.lua`.

2. [ ] Leave the Aura Frames changes untouched while making Skyriding Vigor edits.


## Discrepancies And Issues To Revisit

1. [ ] Dropdown hover indicators now use a small custom gold triangle from line textures in `functions/dropdown.lua`, but it looks worse than the native WoW dropdown arrow. Revisit later with a proper in-game asset. Rejected attempts are recorded in `project.md`: text glyph rendered as an empty box, `Interface\Buttons\UI-SortArrow` was too thin/barely visible, and `Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up` was a different bad arrow shape.


## GUI Streamlining Review
1. [ ] Future modularization pass: consider splitting `sv_gui.lua` after or alongside the cross-module settings-grid consolidation review. The local-builder refactor addressed the immediate `BuildSettings()` density problem, but Skyriding still keeps more GUI construction/sync work in one file than the smaller `af_gui.lua` wrapper. Do not split around module-local grid patterns that should become addon-wide. Durable details and split cautions are saved in `skyriding_vigor.md`; cross-module grid/modularization follow-up is tracked in `cross_module_todo.md`.
