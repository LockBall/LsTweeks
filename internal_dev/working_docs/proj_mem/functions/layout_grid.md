# Layout Grid Function Memory
Durable contracts for shared settings-grid placement in `functions/layout_grid.lua`.


## Table of Contents
- [Ownership And API](#ownership-and-api)
- [Placement Model](#placement-model)
- [Composition Rules](#composition-rules)
- [Consumer And Validation Contract](#consumer-and-validation-contract)


## Ownership And API
- Low-level helpers: `addon.GetGridOffset()`, `addon.SetGridPoint()`, and `addon.CenterGridControl()`.
- `addon.CreateSettingsGrid(parent, opts)` owns shared row/column geometry and returns `grid:place_at()`, `grid:place()`, `grid:center()`, `grid:stack_below()`, `grid:add_row_separator()`, and `grid:add_row_separators()`.
- Control factories own only their internal geometry; the grid/caller owns external placement.


## Placement Model
- Grid geometry is explicit source data: column count/width/gap/offset/alignment, row start/heights/gap, slot offsets, content rows, and separator bounds/mode.
- `place_at()` accepts row/column coordinates directly. `place()` resolves a static placement table; `center()` measures the control when a dynamic width is required.
- Placement options carry dynamic width, alignment, vertical alignment, and offsets. Do not write derived runtime values back into module-local placement tables.
- Use the grid public methods instead of duplicating offset math or chaining controls by hand. Do not call `GetWidth()` during initial construction except through a grid operation specifically designed to measure an already-sized control.


## Composition Rules
- `grid:stack_below()` owns secondary controls within one cell. Place the first control normally, then stack related controls below it instead of repeating local vertical-offset arithmetic.
- Declare row heights large enough for the full cell stack. Module-specific taller rows remain in module layout configuration.
- Row separators are explicit. Supply only occupied divider rows so sparse grids do not render separators through empty content; choose fixed or stretch behavior through grid options rather than local lines.
- One placement owner sets external anchors. Avoid duplicate anchors in the same direction and do not mix grid placement with later manual offsets unless the module documents the deliberate override.


## Consumer And Validation Contract
- Current tuned consumers include Player Frame, Skyriding Vigor, and Aura Frames. Non-additive changes to defaults, alignment, row-height interpretation, separator math, centering, or slot offsets require reviewing them together.
- Module memory owns its row contents, special heights, cell stacks, and exceptions; this file owns shared coordinate and composition behavior.
- No dedicated headless layout suite currently models rendered geometry. Validate syntax/regions, inspect each impacted source outline/caller, and perform in-game visual checks at representative UI scales after shared geometry changes.
