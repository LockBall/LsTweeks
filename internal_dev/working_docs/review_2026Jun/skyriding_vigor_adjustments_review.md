# Skyriding Vigor Adjustments Review

Started: 2026-06-24


## Context Read
- Followed `internal_dev/working_docs/proj_mem/agent_start.md`.

- Read public and internal context: `README.md`, `project.md`, `code_map.md`, `skyriding_vigor.md`, and `scratchpad.md`.

- Reviewed current Skyriding Vigor implementation files: `sv_defaults.lua`, `sv_styles.lua`, `sv_bar.lua`, `sv_fade.lua`, `sv_state.lua`, `sv_gui.lua`, and `sv_main.lua`.


## Current Worktree Notes
- Existing unrelated modified files before Skyriding Vigor work: `internal_dev/completed_features/aura_frames.md`, `internal_dev/working_docs/proj_mem/aura_frames.md`, and `modules/aura_frames/af_core.lua`.

- Leave the Aura Frames changes untouched while making Skyriding Vigor edits.


## Discrepancies And Issues To Revisit
- The requested Skyriding Vigor "adjustments" were not specified yet, so no code-path-specific change target is confirmed.

- `sv_gui.lua` creates several controls with closures that capture the initial `db` local from `BuildSettings()`. Most mutations route through `M.get_db()`, but dropdown `get_value` closures for `style` and `decor_style` read the captured table. If the Race Profile Test toggles the active profile after the settings page is already built, these dropdowns may report the stale profile unless control sync fully overrides them.

- `M.NODE_COLOR_OPTIONS` and `M.DECOR_COLOR_OPTIONS` omit the `"default"` option even though the default style uses `"default"` as the only valid color key. The controls are disabled when unsupported, but the selected value can still be `"default"` while the dropdown options only list Storm Race colors.

- Spark size memory notes say default-style spark placement still needs style-specific in-game tuning. Treat spark visual changes as empirical tuning work unless backed by a clear runtime observation.

- The End Decor `Disabled` option is implemented as a decor style that preserves the default decor footprint and hides via alpha. This keeps nodes stationary when toggling Default <-> Disabled, but Storm Race <-> Disabled can still change layout because Disabled is not a separate visibility flag for the currently selected decor style.

- Dropdown hover indicators now use a small custom gold triangle from line textures in `functions/dropdown.lua`. Revisit this against the official WoW options dropdown hover asset/behavior; earlier attempts with a text glyph rendered as a box and `Interface\Buttons\UI-SortArrow` was too thin/barely visible.


## Pending Questions
- None currently.
