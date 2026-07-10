# LsTweeks Code Map
Compact routing map for coding agents. Start at `agent_start.md`; use this file to avoid rediscovering file ownership and routine validation commands.


## Table of Contents
- [Read-In Shortcuts](#read-in-shortcuts)
- [Fast Commands](#fast-commands)
- [Public Surface](#public-surface)
- [Core And Shared Helpers](#core-and-shared-helpers)
- [Feature Modules](#feature-modules)
- [Internal Docs And Tools](#internal-docs-and-tools)
- [Release Package](#release-package)
- [Edit Boundaries](#edit-boundaries)


## Read-In Shortcuts
- Baseline after `agent_start.md`: run the worktree check, then read this section only. Defer all other project docs and code-map sections until the request routes to them.
- Section reader: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/doc_section.ps1 <markdown-file> "<heading>"`; use `-List` to list stable `##` headings.

| Request trigger | Next targeted read |
| --- | --- |
| Project workflow, docs ownership, validation, packaging, LuaLS/Ketho, or durable cross-module rule | Matching `project.md` section: `Project Operations`, `Project Overview`, or `Shared Architecture` |
| Shared helper, settings control, layout, panel, tooltip, button, checkbox, slider, dropdown, color picker, reset panel, or table/default utility | `## Core And Shared Helpers` |
| Feature module | `## Feature Modules`, then matching module-memory heading; use `rg -n "^##" <memory-file>` before opening a large memory file |
| Aura Frames CDM regression | `internal_dev/tests_tools/aura_frames_cdm_regression.md` |
| Audio Volumes public sound asset or preset | `modules/audio_volumes/sounds/sound_reference.md` |
| Public wording, credits, research, review note, CPU profile, SoundKit constant, package doc, or LuaLS tool note | Read only the directly matched file |

- For source work, run a source outline before broad file reads. Outlines are the source-file TOC; every project Lua file has a short responsibility header and every declared function belongs to a named `--#region`. Keep those markers current instead of duplicating detailed source maps in docs.
- Documentation/read-in policy owner: `agent_start.md` `## Documentation Rules`.


## Fast Commands
These are repo-local or project-specific commands. Platform-provided agent tools are session context, not project read-in.

- Worktree check: `git status --short`
- Repo search: `rg <pattern>` or `rg --files`
- In-game status: `/lst status` for all modules; `/lst status <module key or label>` for one module, such as `/lst status objectives`.
- Line-ending and PowerShell write rules: `internal_dev/tests_tools/powershell.md`.
- Fast validation (includes headless Lua tests; add `-SkipTests` to skip them): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`
- Changed-file fast validation: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Changed`
- Region validation / source outline: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 [-Outline <lua-file>]`
- Diff whitespace checks: `git diff --check` and `git diff --cached --check`
- Fast validation plus package build/verify: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Package`
- Full LuaLS/Ketho check: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1`
- Targeted LuaLS/Ketho check for changed Lua files: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Changed`
- Targeted LuaLS/Ketho check for one specific file: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Files <lua-file>`; use `-Changed` for several changed Lua files.
- Ketho API lookup: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/api_lookup.ps1 <ApiName>`
- Release package only: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1`
- Headless Lua tests (all suites): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1`
- Headless Lua tests (one suite): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1 <name-substring>`


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
- `modules/settings/`: general addon settings and module toggles; `st_defaults.lua` owns defaults, `st_gui.lua` owns settings UI, and `st_main.lua` owns alpha runtime/reset/category registration.
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
- `internal_dev/tests_tools/aura_frames_cdm_regression.md`: manual in-game CDM regression matrix for Aura Frames.
- `internal_dev/tests_tools/powershell.md`: PowerShell newline rules, safe write notes, and region-helper usage.
- `proj_mem/modules/*.md`: module memory files.
- `ToDo/`: temporary focused TODO/review notes; read only when the task touches that area.
- `internal_dev/tests_tools/tools_notes.md`: shell, sandbox, LuaLS/Ketho, packaging, and tool recovery notes.
- `internal_dev/tests_tools/lua_tests/`: headless Lua 5.1 tests against a stubbed WoW API; see `lua_tests/tests_nfo.md` for the stub, harness, and test-writing rules.
- `api_lookup.ps1`: prints exact Ketho annotation blocks for WoW API functions.
- `check_fast.ps1`: quick local verification wrapper.
- `check_regions.ps1`: validates Lua region markers and prints live source outlines with named functions.
- `doc_section.ps1`: prints one named `##` markdown section or lists `##` headings.
- `packaging/`: release package builder, policy, and verifier.
- `lua_checks/`: LuaLS/Ketho helper and ignored generated diagnostics.
- `internal_dev/working_docs/SoundKitConstants.lua`: large searchable sound reference; search only when sound IDs are needed.


## Release Package
The package policy includes only public addon roots/files and excludes all `internal_dev/` content. The verifier also treats `internal_dev` as an invariant forbidden root.
Included roots/files are controlled by `package-policy.json`. Do not infer release contents from `rg --files`; run the package verifier when packaging behavior matters.


## Edit Boundaries
- Do not edit `libs/` for style or diagnostics unless intentionally updating a vendored dependency.
- Do not copy Blizzard art assets into the addon without a reviewed packaging/legal plan.
- Keep generated output under ignored tool folders or `dist/`.
- Keep durable project facts in `project.md`; keep module facts in module memory; keep `agent_start.md` short.
