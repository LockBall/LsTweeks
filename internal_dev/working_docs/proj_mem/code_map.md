# LsTweeks Code Map
Compact routing map for coding agents. Start at `agent_start.md`; use this file to avoid rediscovering file ownership and routine validation commands.


## Table of Contents
- [Fast Commands](#fast-commands)
- [Read-In Shortcuts](#read-in-shortcuts)
- [Public Surface](#public-surface)
- [Core And Shared Helpers](#core-and-shared-helpers)
- [Feature Modules](#feature-modules)
- [Internal Docs And Tools](#internal-docs-and-tools)
- [Release Package](#release-package)
- [Edit Boundaries](#edit-boundaries)


## Fast Commands
These are repo-local or project-specific commands. Platform-provided agent tools are session context, not project read-in.

- Worktree check: `git status --short`
- Repo search: `rg <pattern>` or `rg --files`
- In-game status: `/lst status` for all modules; `/lst status <module key or label>` for one module, such as `/lst status objectives`.
- Line-ending and PowerShell write rules: `internal_dev/tests_tools/powershell.md`.
- Fast validation: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`
- Region validation / source outline: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 [-Outline <lua-file>]`
- Diff whitespace check: `git diff --check`
- Fast validation plus package build/verify: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Package`
- Full LuaLS/Ketho check: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1`
- Targeted LuaLS/Ketho check for changed Lua files: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Changed`
- Targeted LuaLS/Ketho check for specific files: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Files <lua-file> [<lua-file>...]`
- Release package only: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1`


## Read-In Shortcuts
- Default session read-in is `agent_start.md`, `git status --short`, then this file. Defer everything else until the request routes there.
- `project.md` workflow, docs ownership, or validation commands: `## Project Operations`.
- `project.md` addon identity, slash command, SavedVariables, or load-order map: `## Project Overview`.
- `project.md` module lifecycle, DB defaults, timing buckets, combat guards, or shared GUI rules: `## Shared Architecture`.
- Shared factory lookup: check `## Core And Shared Helpers` before searching source or hand-building controls. It maps the common addon factories/helpers for settings controls, layout, panels, tooltips, buttons, checkboxes, sliders, dropdowns, color pickers, reset panels, and table/default utilities to their owning files.
- `modules/aura_frames.md` large-section routing: `## Ownership`, `## Runtime Gates And Refresh`, `## Scanning, Rendering, Timers`, `## Aura Cancellation`, `## Aura Tooltips`, `## Position, Drag, Resize`, `## Profiles And Reset`, `## GUI`, `## Debug, Grid, Style`.
- `modules/skyriding_vigor.md` large-section routing: `## Settings And Defaults`, `## Position And GUI`, `## Assets And Credits`, `## Runtime Visibility And Fade`, `## Charge State`, `## Styles And Rendering`, `## Fill Test And Progress`, `## Module Gating And Race Profile`.
- `modules/player_frame.md` routing: `## Settings And Defaults` plus `## Runtime Notes`; source ownership is split between `pf_main.lua` settings/combat text and `pf_fade.lua` out-of-combat fade.
- `modules/objectives.md` routing: `## Settings And Defaults` plus `## Runtime Notes`; source ownership is split between `ob_defaults.lua` defaults, `ob_position.lua` All Objectives position/move controls, `ob_auto_collapse.lua` Auto-Collapse, `ob_section_count.lua` Section Count, `ob_background.lua` background/border runtime and settings, and `ob_main.lua` lifecycle/status shell.
- `modules/audio_volumes.md` routing: use targeted sections such as `## Saved Variables`, `## Ownership`, `## Runtime Rules`, `## Event Cache And Performance`, `## Situations And Quick Picks`, `## GUI`, and `## Ketho / LuaLS`; use source outlines for `av_*` ownership and search `modules/audio_volumes/sounds/sound_reference.md` only when public sound assets or presets matter.
- Memory heading command: `rg -n "^##" <memory-file>`. Use it before opening large memory files, then read only the matching section.
- Source outline command: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 -Outline <target paths>`. Use `rg -n "^--#region|^-- [A-Za-z].*" <target paths>` only for a quick fallback. Treat file responsibility headers and `--#region` markers as the source-code TOC before broad reads; keep those headers/regions current instead of copying detailed per-file maps into docs.
- Documentation/read-in policy owner: `agent_start.md` `## Documentation Rules`.
- Read `README.md`, public `sources.md`, research source references, focused review notes, CPU profiles, SoundKit constants, packaging docs, or LuaLS tool notes only when the request directly routes there.


## Public Surface
- `README.md`: public feature names, install/use wording, release-facing behavior.
- `sources.md`: public credits and embedded-library attribution.
- `LsTweeks.toc`: addon metadata, version, interface number, and Lua/XML load order.
- `LICENSE`: release license.


## Core And Shared Helpers
- `core/init.lua`: addon table bootstrap, saved-variable defaults entry points, slash command, feature module registry, timing buckets.
- `core/main_frame.lua`: settings shell, sidebar categories, disabled-module sidebar behavior.
- `core/minimap_button.lua`: LibDataBroker/LibDBIcon minimap launcher.
- `functions/checkbox.lua`: shared checkbox factory, including container APIs for checked/enabled state and checked-change hooks.
- `functions/buttons.lua`: shared text-fit button helpers, `addon.CreateMoveResetButton()`, and `addon.ApplyStandardButtonStyle()` for standard gold-normal/white-hover button text.
- `functions/color_picker.lua`: shared color picker plus reset button.
- `functions/dropdown.lua`: shared dropdown factory.
- `functions/group_column.lua`: shared Aura-style grouped selector column factory with section outlines, selected-group border highlighting, optional row delete buttons, and optional group actions.
- `functions/module_reset.lua`: ARM-code module reset panel.
- `functions/panel_riveted.lua`: shared riveted panel visuals.
- `functions/layout_grid.lua`: shared row/column settings grid helpers, including row divider lines: `addon.GetGridOffset()`, `addon.SetGridPoint()`, `addon.CenterGridControl()`, and `addon.CreateSettingsGrid()` with `grid:place()`, `grid:place_at()`, and `grid:center()` methods.
- `functions/slider_with_box.lua`: shared slider plus numeric edit box, including `slider:GetValue()`, `slider:SetValue(value)`, `slider:SetValueSilently(value)`, and `slider:HookValueChanged(fn[, opts])`.
- `functions/ui_helpers.lua`: shared settings UI helpers for common control-panel backdrops, gold outlined settings groups, and simple tooltip hooks.
- `functions/table_utils.lua`: shared table/default-copy and value helpers: `addon.deep_copy_into()`, `addon.apply_defaults()`, and `addon.clamp_number()`.


## Feature Modules
- `modules/settings/`: general addon settings and module toggles.
- `modules/player_frame/`: PlayerFrame portrait combat text and out-of-combat fade. Memory: `proj_mem/modules/player_frame.md`.
- `modules/objectives/`: All Objectives tracker behavior tweaks. Memory: `proj_mem/modules/objectives.md`.
- `modules/audio_volumes/`: Audio Volumes replacement presets and temporary situation runtime. Memory: `proj_mem/modules/audio_volumes.md`.
- `modules/skyriding_vigor/`: restored Skyriding Vigor display, style/layout state, charge detection, fade, and GUI. Memory: `proj_mem/modules/skyriding_vigor.md`.
- `modules/aura_frames/`: aura scanning/rendering, CDM integration, frame settings, profiles, and GUI. Memory: `proj_mem/modules/aura_frames.md`.
- `modules/about.lua`: about/public credits page.


## Internal Docs And Tools
- `agent_start.md`: single beginning point.
- `project.md`: project-wide architecture and durable cross-module rules.
- `research_sources.md`: internal API, FrameXML, tool, release, and debugging reference links.
- `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`: reusable in-game CPU profiling workflow and comparison rules.
- `internal_dev/tests_tools/powershell.md`: PowerShell newline rules, safe write notes, and region-helper usage.
- `proj_mem/modules/*.md`: module memory files.
- `ToDo/`: temporary focused TODO/review notes; read only when the task touches that area.
- `internal_dev/tests_tools/tools_notes.md`: shell, sandbox, LuaLS/Ketho, packaging, and tool recovery notes.
- `check_fast.ps1`: quick local verification wrapper.
- `check_regions.ps1`: validates Lua region markers and prints live source outlines.
- `packaging/`: release package builder, policy, and verifier.
- `lua_checks/`: LuaLS/Ketho helper and ignored generated diagnostics.
- `SoundKitConstants.lua`: large searchable sound reference; search only when sound IDs are needed.


## Release Package
The package policy includes only public addon roots/files and excludes all `internal_dev/` content. The verifier also treats `internal_dev` as an invariant forbidden root.
Included roots/files are controlled by `package-policy.json`. Do not infer release contents from `rg --files`; run the package verifier when packaging behavior matters.


## Edit Boundaries
- Do not edit `libs/` for style or diagnostics unless intentionally updating a vendored dependency.
- Do not copy Blizzard art assets into the addon without a reviewed packaging/legal plan.
- Keep generated output under ignored tool folders or `dist/`.
- Keep durable project facts in `project.md`; keep module facts in module memory; keep `agent_start.md` short.
