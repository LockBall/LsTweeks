# LsTweeks Code Map

Compact routing map for coding agents. Start at `agent_start.md`; use this file to avoid rediscovering file ownership and routine validation commands.


## Fast Commands

- Worktree check: `git status --short`

- Repo search: `rg <pattern>` or `rg --files`

- Fast validation: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`

- Diff whitespace check: `git diff --check`

- Fast validation plus package build/verify: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Package`

- Full LuaLS/Ketho check: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1`

- Release package only: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1`


## Read-In Shortcuts

- Default session read-in is `agent_start.md`, `git status --short`, then this file. Defer everything else until the request routes there.

- `project.md` workflow, docs ownership, or validation commands: `## Project Operations`.

- `project.md` addon identity, slash command, SavedVariables, or load-order map: `## Project Overview`.

- `project.md` module lifecycle, DB defaults, timing buckets, combat guards, or shared GUI rules: `## Shared Architecture`.

- `aura_frames.md` large-section routing: `## Ownership`, `## Runtime Gates And Refresh`, `## Scanning, Rendering, Timers`, `## Position, Drag, Resize`, `## Profiles And Reset`, `## GUI`, `## Debug, Grid, Style`.

- `skyriding_vigor.md` large-section routing: top summary plus `## Runtime Notes`; use source outlines for deeper `sv_*` ownership.

- `player_frame.md` routing: top summary plus `## Runtime Notes`; source ownership is split between `pf_main.lua` settings/combat text and `pf_fade.lua` out-of-combat fade.

- `objectives.md` routing: top summary plus `## Runtime Notes`; source ownership is split between `ob_defaults.lua` defaults and `ob_main.lua` runtime/settings.

- `sound_levels.md` routing: top summary plus `## Ketho / LuaLS`; use source outlines for `sl_*` ownership and search `modules/sound_levels/sounds/sound_reference.md` only when public sound assets or presets matter.

- Source outline command: `rg -n "^--#region|^-- [A-Za-z].*" <target paths>`. Treat file responsibility headers and `--#region` markers as the source-code TOC before broad reads; keep those headers/regions current instead of copying detailed per-file maps into docs.

- Do not split module memory files or other internal docs for token savings. Keep read-in efficient through this TOC, markdown heading searches, and Lua responsibility headers/regions.

- Avoid reading `README.md`, completed-feature notes, focused review notes, CPU profiles, SoundKit constants, packaging docs, or LuaLS tool notes unless the request directly routes there.


## Public Surface

- `README.md`: public feature names, install/use wording, release-facing behavior.

- `sources.md`: source ledger for APIs, release references, tools, and embedded libraries.

- `LsTweeks.toc`: addon metadata, version, interface number, and Lua/XML load order.

- `LICENSE`: release license.


## Core And Shared Helpers

- `core/init.lua`: addon table bootstrap, saved-variable defaults entry points, slash command, feature module registry, timing buckets.

- `core/main_frame.lua`: settings shell, sidebar categories, disabled-module sidebar behavior.

- `core/minimap_button.lua`: LibDataBroker/LibDBIcon minimap launcher.

- `functions/checkbox.lua`: shared checkbox factory.

- `functions/button.lua`: shared text-fit button helpers and `addon.ApplyStandardButtonStyle()` for standard gold-normal/white-hover button text.

- `functions/color_picker.lua`: shared color picker plus reset button.

- `functions/dropdown.lua`: shared dropdown factory.

- `functions/module_reset.lua`: ARM-code module reset panel.

- `functions/panel_riveted.lua`: shared riveted panel visuals.

- `functions/layout_grid.lua`: shared row/column settings grid helpers, including row divider lines: `addon.GetGridOffset()`, `addon.SetGridPoint()`, `addon.CenterGridControl()`, and `addon.CreateSettingsGrid()` with `grid:place()`, `grid:place_at()`, and `grid:center()` methods.

- `functions/slider_with_box.lua`: shared slider plus numeric edit box.

- `functions/ui_helpers.lua`: shared settings UI helpers for common control-panel backdrops and simple tooltip hooks.

- `functions/table_utils.lua`: shared table/default-copy and value helpers: `addon.deep_copy_into()`, `addon.apply_defaults()`, and `addon.clamp_number()`.


## Feature Modules

- `modules/settings/`: general addon settings and module toggles.

- `modules/player_frame/`: PlayerFrame portrait combat text and out-of-combat fade. Memory: `player_frame.md`.

- `modules/objectives/`: All Objectives tracker behavior tweaks. Memory: `objectives.md`.

- `modules/sound_levels/`: sound replacement presets and Fishing Focus runtime. Memory: `sound_levels.md`.

- `modules/skyriding_vigor/`: restored Skyriding Vigor display, style/layout state, charge detection, fade, and GUI. Memory: `skyriding_vigor.md`.

- `modules/aura_frames/`: aura scanning/rendering, CDM integration, frame settings, profiles, and GUI. Memory: `aura_frames.md`.

- `modules/about.lua`: about/public credits page.


## Internal Docs And Tools

- `internal_dev/working_docs/proj_mem/agent_start.md`: single beginning point.

- `internal_dev/working_docs/proj_mem/project.md`: project-wide architecture and durable cross-module rules.

- `internal_dev/working_docs/proj_mem/performance_profiling.md`: reusable in-game CPU profiling workflow and comparison rules.

- `internal_dev/working_docs/proj_mem/*.md`: module memory and this code map.

- `internal_dev/working_docs/review_2026Jun/`: temporary focused review notes; read only when the task touches that area.

- `internal_dev/completed_features/`: completed investigations; review on demand.

- `internal_dev/tests_tools/tools_notes.md`: shell, sandbox, LuaLS/Ketho, packaging, and tool recovery notes.

- `internal_dev/tests_tools/check_fast.ps1`: quick local verification wrapper.

- `internal_dev/tests_tools/packaging/`: release package builder, policy, and verifier.

- `internal_dev/tests_tools/lua_checks/`: LuaLS/Ketho helper and ignored generated diagnostics.

- `internal_dev/working_docs/SoundKitConstants.lua`: large searchable sound reference; search only when sound IDs are needed.


## Release Package

The package policy includes only public addon roots/files and excludes all `internal_dev/` content. The verifier also treats `internal_dev` as an invariant forbidden root.

Included roots/files are controlled by `internal_dev/tests_tools/packaging/package-policy.json`. Do not infer release contents from `rg --files`; run the package verifier when packaging behavior matters.


## Edit Boundaries

- Do not edit `libs/` for style or diagnostics unless intentionally updating a vendored dependency.

- Do not copy Blizzard art assets into the addon without a reviewed packaging/legal plan.

- Keep generated output under ignored tool folders or `dist/`.

- Keep durable project facts in `project.md`; keep module facts in module memory; keep `agent_start.md` short.
