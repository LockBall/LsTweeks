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
Reference routes not covered by the `agent_start.md` routing table; that table is the primary router.
- Section reader: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/doc_section.ps1 <markdown-file> "<heading>"`; use `-List` to list stable `##` headings.

| Request trigger | Next targeted read |
| --- | --- |
| Aura Frames CDM regression | `internal_dev/tests_tools/aura_frames_cdm_regression.md` |
| Audio Volumes public sound asset or preset | `modules/audio_volumes/sounds/sound_reference.md` |
| Public credits/attribution | `sources.md` |
| Internal API/FrameXML/tool/release reference links | `research_sources.md` |
| CPU profiling workflow or run history | `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`, then `internal_dev/tests_tools/cpu_profiles/` |
| Sound ID lookup | `internal_dev/working_docs/SoundKitConstants.lua` |
| Packaging policy/doc | `internal_dev/tests_tools/packaging/package_me.md` |

- Source outlines are the source-file TOC: every project Lua file has a short responsibility header and every declared function belongs to a named `--#region`. Keep those markers current instead of duplicating detailed source maps in docs.


## Fast Commands
These are repo-local or project-specific commands. Platform-provided agent tools are session context, not project read-in.

- Session baseline (agent_start.md + worktree status + Read-In Shortcuts in one call): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/agent_startup.ps1`
- Worktree check: `git status --short`
- Repo search: `rg <pattern>` or `rg --files`
- In-game status: `/lst status` for all modules; `/lst status <module key or label>` for one module, such as `/lst status objectives`.
- Line-ending and PowerShell write rules: `internal_dev/tests_tools/powershell.md`.
- Fast validation with impact-selected headless tests: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Changed`
- Fast non-test validation after targeted suites already passed: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Changed -SkipTests`
- Fast validation with every headless suite: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Changed -AllTests`
- Region validation / source outline: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 [-Outline <lua-file> [<lua-file> ...]]`; pass several files to one `-Outline` call instead of invoking per file
- Memory section size check (flags oversized `proj_mem` `##`/`###` sections; included in fast validation): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_memory_sections.ps1`
- Diff whitespace checks: `git diff --check` and `git diff --cached --check`
- Fast validation plus package build/verify: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Package`
- Full LuaLS/Ketho check: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1`
- Changed-file LuaLS/Ketho check: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Changed`; multiple changed files use one smallest-common workspace so Ketho initializes once while retaining cross-file diagnostics.
- Targeted LuaLS/Ketho check for one specific file: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1 -Files <lua-file>`; use `-Changed` for several changed Lua files.
- Ketho API lookup: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/api_lookup.ps1 <ApiName>`
- Condense repeated WoW Lua errors: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/condense_lua_errors.ps1 -Path <error-export.txt> [-OutputPath <report.md>]`; add `-IncludeLocals` only for deeper follow-up.
- Release package only: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1`
- Headless Lua tests (all suites): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1`
- Headless Lua tests (one suite): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1 <name-substring>`
- Headless Lua tests (several named suites): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1 -Suite <name>,<name>`
- Headless Lua tests (impact-selected from current changes): `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1 -Changed`
- List impacted suites without running them: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_tests/run_tests.ps1 -Changed -ListOnly`


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
- `functions/buttons.lua`: shared text-fit button helpers, `addon.CreateMoveResetButton()`, `addon.ApplyStandardButtonStyle()` for standard gold-normal/white-hover button text, and `addon.CreatePlayPauseButton()` for native-art media play/pause controls (asset details in `media/media_notes.md`).
- `functions/color_picker.lua`: shared color picker plus reset button.
- `functions/dropdown.lua`: shared dropdown factory.
- `functions/group_column.lua`: shared Aura-style grouped selector column factory with section outlines, selected-group border highlighting, optional row delete buttons, and optional group actions.
- `functions/module_reset.lua`: ARM-code module reset panel.
- `functions/panel_riveted.lua`: shared riveted panel visuals.
- `functions/profiles.lua`: shared profile mechanics via `addon.CreateProfileManager()` and `addon.BuildProfilesTab()`; each module keeps its own profile file for snapshot contents and post-load refresh.
- `functions/layout_grid.lua`: shared row/column settings grid helpers, including row divider lines: `addon.GetGridOffset()`, `addon.SetGridPoint()`, `addon.CenterGridControl()`, and `addon.CreateSettingsGrid()` with `grid:place()`, `grid:place_at()`, and `grid:center()` methods.
- `functions/slider_with_box.lua`: shared slider plus numeric edit box, including `slider:GetValue()`, `slider:SetValue(value)`, `slider:SetValueSilently(value)`, and `slider:HookValueChanged(fn[, opts])`.
- `functions/ui_helpers.lua`: shared settings UI helpers for common control-panel backdrops and gold outlined settings groups.
- `functions/tooltip.lua`: centralized tooltip factory. The owned path uses `addon.CreateOwnedTooltip()` (plain frame skinned with native `TooltipBackdropTemplate` nine-slice, auto-sized width, quadrant anchoring), `addon.ShowOwnedTooltipLines()`, `addon.ShowOwnedTooltip()`, and `addon.AttachTooltip()`; the restricted Aura path uses one dedicated native tooltip through `addon.ShowNativeAuraTooltip()` / `addon.ShowNativeSpellTooltip()`. Never mutate Blizzard's shared global `GameTooltip` (see project.md Tooltip APIs rule).
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
- `condense_lua_errors.ps1`: groups WoW Lua error exports by message and stack variant, surfaces taint/addon ownership signals, and omits repetitive locals by default; `test_condense_lua_errors.ps1` owns focused regression checks.
- `check_fast.ps1`: quick local verification wrapper.
- `check_regions.ps1`: validates Lua region markers and prints live source outlines with named functions.
- `doc_section.ps1`: prints one named `##` markdown section or lists `##` headings.
- `agent_startup.ps1`: one-shot session baseline printer (agent_start.md, worktree status, Read-In Shortcuts); read-only.
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
