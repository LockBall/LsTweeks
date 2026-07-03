# LsTweeks Project Memory
Shared memory for coding agents. Keep this file concise and durable: architecture, ownership, defaults, workflow rules, and hard-won debugging notes only. Module-specific memory lives in `proj_mem/modules/`.


## Table of Contents
- [Project Operations](#project-operations)
  - [Workflow](#workflow)
  - [Ketho / LuaLS](#ketho--luals)
  - [Packaging / Release](#packaging--release)
- [Project Overview](#project-overview)
  - [AddOn Summary](#addon-summary)
  - [File Map](#file-map)
- [Shared Architecture](#shared-architecture)
  - [Core Architecture Rules](#core-architecture-rules)
  - [GUI/Layout Rules](#guilayout-rules)
  - [Key WoW APIs And Lessons](#key-wow-apis-and-lessons)
- [Agent Start](agent_start.md)
- [Code Map](code_map.md)
- [Research Sources](research_sources.md)
- [Performance Profiling](../../tests_tools/cpu_profiles/profiling_workflow.md)
- [PowerShell Tool Notes](../../tests_tools/powershell.md)
- [Module Memory](#module-memory)
  - [Player Frame](modules/player_frame.md)
  - [Objectives](modules/objectives.md)
  - [Audio Volumes](modules/audio_volumes.md)
  - [Skyriding Vigor](modules/skyriding_vigor.md)
  - [Aura Frames](modules/aura_frames.md)


## Project Operations
### Workflow
- Source of truth: this file plus module files under `proj_mem/modules/`.
- Durable changes: update this file or the relevant module file for architecture, defaults, APIs, or debugging lessons.
- Session start: read `agent_start.md` first; `code_map.md` owns read-in shortcuts, validation commands, and source-outline routing.
- Internal docs: `internal_dev/`.
- Active working docs: `working_docs/`; project/module memory in `proj_mem/`, focused TODO/review notes in `ToDo/`.
- Completed feature facts are consolidated into this file or the relevant module memory; do not create separate completed-feature notes unless a new active review explicitly needs temporary handoff context.
- Public docs: root markdown.
- Public source credits: root `sources.md`. Internal research references: `research_sources.md`.
- Active verification/checklist scratchpads use numbered section headings and letter-only item labels, so references combine cleanly as `1a`, `2b`, etc. Example: `## 1. In-Game Behavior` with items `**a**`, `**b**`.
- Tool recovery: `internal_dev/tests_tools/tools_notes.md`.
- PowerShell/newlines/line endings/regions: `internal_dev/tests_tools/powershell.md`.
- Validation commands: `code_map.md` `## Fast Commands`.
- CPU profiling: workflow in `internal_dev/tests_tools/cpu_profiles/profiling_workflow.md`, run history in `internal_dev/tests_tools/cpu_profiles/`, durable conclusions in module memory.


### Ketho / LuaLS
- Use VS Code WoW API (`ketho.wow-api`) with LuaLS (`sumneko.lua`) for Blizzard API reviews. Enable `wowAPI.luals.frameXML` for FrameXML/CDM/widget work.
- Treat LuaLS diagnostics as review prompts, not automatic change requests.
- Shell LuaLS checks can run with `--check`, but need explicit Ketho `Annotations/Core` and `Annotations/FrameXML` library paths plus workspace-local `--logpath`/`--metapath`; keep Lua check output under `lua_checks/`.
- Preferred shell helper: Ketho/LuaLS helper in `code_map.md`.
- Direct annotation root: `%USERPROFILE%\.vscode\extensions\ketho.wow-api-<version>\Annotations\`.
- For APIs, grep annotations by name and cross-check call sites before changing code.


### Packaging / Release
- Release package command: `release package only` in `code_map.md`. It writes `dist/<toc-name>-<version>.zip` and runs the verifier.
- Packaging docs and policy live in `package_me.md` and `package-policy.json`.
- Packaging is data-driven. Update `package-policy.json` before changing public include/exclude behavior; verifier invariants still protect required/forbidden paths.
- README image assets and Audio Volumes reference/log files are public-facing and included.


## Project Overview
### AddOn Summary
**L's Tweeks** is a modular WoW 12.0.5+ UI addon by LockBall. Keep the intentional **Tweeks** spelling.

- Slash command: `/lst` (`SLASH_LSTWEEKS1`)
- SavedVariables: `Ls_Tweeks_DB`
- Version edit point: `LsTweeks.toc` only; verify interface number in-game with `/dump (select(4, GetBuildInfo()))`


### File Map
```
README.md               public release/readme documentation
sources.md              public source credits and embedded-library attribution
LsTweeks.toc            addon metadata, interface number, version, and load order

core/                   addon bootstrap, DB init, slash command, shared timing/theme, settings shell
functions/              shared UI factories and helpers: reset, sliders, dropdowns, grouped columns, color picker, riveted panels
modules/                feature modules; deeper ownership notes live in the module memory files below
  player_frame/         Player Frame settings, portrait combat text, and OOC fade
  objectives/           All Objectives tracker behavior tweaks
  audio_volumes/         Audio Volumes preset replacements and temporary situations
  skyriding_vigor/      restored vigor display, style/layout state, charge detection, fade, and GUI
  settings/             general addon settings
  aura_frames/          aura scanning/rendering, CDM integration, frame settings, profiles, and GUI

libs/                   embedded libraries, publicly credited in sources.md
media/                  public addon/readme assets
internal_dev/          internal docs excluded from release zips
  tests_tools/          probes, test helpers, diagnostics helpers, packaging helpers, CPU profiles, and tool notes
  working_docs/         active project docs, scratch notes, review notes, and proj_mem/
dist/                   generated package output, ignored
```

Every Lua file starts with a short responsibility header before `local addon_name, addon = ...`. `code_map.md` owns source/memory outline commands; keep durable ownership notes there or in the relevant module memory file instead of expanding this map.

Lua section headers use VS Code foldable region markers with visual dividers: `--#region SECTION NAME =====` and `--#endregion SECTION NAME =====`. Use uppercase section names and keep region markers paired. Put the explanatory section comment directly under `--#region` with no blank line, put no blank line before `--#endregion`, and leave two blank lines before the next `--#region`.


## Shared Architecture
### Core Architecture Rules
- Module pattern: `local addon_name, addon = ...`; share state through `addon` and `addon.aura_frames` (`M`).
- Avoid accidental globals in addon files. Keep helpers, constants, builder functions, and cached API references `local` by default; expose values through `addon` or a module table `M` only when another file genuinely needs that public contract.
- Sidebar categories use `addon.register_category(name, builder, { order = n })`; equal order values preserve registration order. Default order is 100.
- Feature modules are listed in `addon.FEATURE_MODULES` (`core/init.lua`) and can be disabled with `Ls_Tweeks_DB.modules.<module_key> = false`. Categories for feature modules pass `opts.module_key`; `core/main_frame.lua` keeps disabled module pages visible and selectable in the sidebar, greys them out, and overlays the selected page so options can be inspected but not changed.
- Runtime modules that have side effects implement `M.set_module_enabled(enabled)` so Settings tab toggles can stop/restart owned runtime state without changing each module's own feature-level settings.
- Current module toggles are soft-disable gates after addon files have loaded; they stop owned runtime work but do not unload code or free all memory. `/lst status` reports each feature module's enabled flag and module-owned runtime signals such as registered events, tickers/timers, preview handles, and visible frames. Use `/lst status <module key or label>` for focused diagnostics, such as `/lst status objectives`. Reopen lazy construction or LoadOnDemand child addons only with an explicit memory-footprint target in the review folder.
- Before adding a small feature with runtime side effects, define its runtime contract: owned events, hooks, timers, queued work, off-state behavior, module-disable behavior, and restore path.
- When adding or changing runtime work in a feature module, audit disabled behavior before finishing: events, hooks, timers, callbacks, tickers, queued `C_Timer` work, frames, and status fields must either stop at disable time or cheaply no-op before doing owned work.
- Before handoff, do a focused cleanup pass for duplicated helpers, stale fallbacks, dead status fields, repeated formatting, and broad API fallbacks.
- Stateful modules implement `on_reset_complete()` and resync controls/runtime after reset. Module reset panels use `CreateModuleReset()` and pass `opts.after_reset = M.on_reset_complete` so only that module is synchronized.
- Apply defaults with `addon.apply_defaults(defaults, db)`; guard DB tables with `or {}`.
- Shared timing values live in `addon.UPDATE_INTERVALS`; do not hardcode repeated refresh/debounce delays.
- Behavior-specific runtime timing aliases live in `addon.UPDATE_INTERVALS` immediately after the generic buckets. Use aliases such as `aura_visible_icon_tick`, `aura_event_bucket`, `aura_hover_check`, `player_frame_fade_tick`, and `skyriding_vigor_progress` as profiling/test adjustment points instead of changing generic buckets directly.
- Cache hot globals at file top (`local floor = math.floor`, `local GetTime = GetTime`, etc.).
- Keep high-frequency runtime paths narrow. If code runs every frame/tick or many
  times per second, avoid repeated DB/style/layout/atlas/config resolution there;
  do that work in a lower-frequency refresh/setup path and pass or store the
  resolved state for the hot path. Make the mutability boundary explicit first,
  such as disabling settings edits during an active runtime state while still
  allowing controlled test modes.
- Never call protected Blizzard frame methods such as `UpdateAuras` or `UpdateLayout` from addon context. Restore addon-owned suppression state and let Blizzard handlers run; module-specific stricter rules such as Aura Frames' `BuffFrame` / `DebuffFrame` handling take precedence.
- Defer layout/geometry changes in combat. `update_auras()` skips scale, anchors, size, layout setup, and height changes during combat or while `frame._is_user_positioning`.


### GUI/Layout Rules
Violations here can create invisible or unstable controls.

- Widget internals anchor only to their own container.
- One `SetPoint` per anchor direction per frame; duplicate TOPLEFT/TOPRIGHT constraints can produce undefined layout.
- Do not use `frame:GetWidth()` at build time; it can be 0 before render.
- Factory functions should not place controls externally when the caller owns placement.
- Before adding settings UI, check `code_map.md` `## Core And Shared Helpers` for an existing shared factory/helper. Use the shared factory's public control API when one exists instead of hand-building equivalent controls, reaching into inner widgets, or rediscovering the owner by broad search.
- Standard button text styling lives in `functions/buttons.lua` via `addon.ApplyStandardButtonStyle()`. Use it for raw `UIPanelButtonTemplate` buttons instead of setting normal/highlight fonts directly; `addon.CreateTextButton()`, `addon.CreateMoveResetButton()`, dropdowns, sliders, and color-picker reset buttons route through it.
- Shared color controls live in `functions/color_picker.lua` via `addon.CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb)`. Use that factory for settings color pickers instead of hand-building ColorPickerFrame wiring.
- Shared dropdown hover arrows are owned by `functions/dropdown.lua` through `addon.CreateDropdown()`. They use `Interface\ChatFrame\ChatFrameExpandArrow` at `15x15`, anchored directly below the dropdown with `0` px vertical offset and rotated 90 degrees clockwise via `Texture:SetTexCoord()`. Reusable asset details live in `media_notes.md`.
- Shared grouped selector columns live in `functions/group_column.lua` through `addon.CreateGroupColumn()`. It is based on Aura Frames' grouped tree structure: thin-border outer frame, thin-border group boxes, centered titles inside group outlines, outlined row labels, one selected-row highlight, and a gold border on the selected row's group. Use it for left-side grouped list/tree columns that need selectable rows, optional row delete buttons, and optional group actions. Group boxes are clickable and select the header `default_key` or first row, so clicking empty space/title inside a section activates that section. For Audio Volumes, Triggered is the fixed primary group equivalent to Aura Frames' Buffs group, and Quick Picks is the custom group with the same Aura-style group title/outline presentation.
- Shared settings UI chrome lives in `functions/ui_helpers.lua`: use `addon.CreateControlPanel()` / `addon.ApplyControlPanelBackdrop()` for the standard dark framed control background, `addon.CreateSettingsGroup()` / `addon.ApplySettingsGroupOutline()` / `addon.CreateSettingsGroupTitleBar()` for the gold outlined settings group style with a 24px grey title bar used by Audio Volumes and Objectives, and the addon-owned tooltip factory/helpers (`addon.CreateOwnedTooltip()`, `addon.GetOwnedTooltip()`, `addon.ShowOwnedTooltip()`, `addon.HideOwnedTooltip()`, `addon.AttachTooltip()`, `addon.AttachTooltipToTargets()`) instead of direct module use of global `GameTooltip`.
- Repeated standard control-panel backdrops and simple settings tooltip hooks are consolidated into `functions/ui_helpers.lua`. Remaining repeated-looking UI code is mostly specialized composition: Aura Frames runtime/tooltips, main-frame chrome, Audio Volumes custom panels, and feature-specific list/tree rendering.
- Shared grid placement helpers live in `functions/layout_grid.lua`: `addon.GetGridOffset()`, `addon.SetGridPoint()`, `addon.CenterGridControl()`, and `addon.CreateSettingsGrid()`. Use `addon.CreateSettingsGrid()` for row/column settings panels, including row divider lines through `row_separators`; keep divider rows explicit so sparse layouts do not draw empty separators. Prefer the grid object's `grid:place(control, placement)` and `grid:center(control, placement)` helpers when using module-local placement tables, so modules do not duplicate alignment/y-offset/width option mapping.
- Treat module-local grid placement tables as static source data. Pass dynamic widths or centering details through grid placement options instead of writing derived runtime values back into placement tables.
- Make non-additive `CreateSettingsGrid()` changes only when current consumers are reviewed together. Player Frame, Skyriding Vigor, and Aura Frames rely on tuned row-height, separator, centering, and column-offset behavior.
- Settings grid cells may contain a small vertical stack of related controls. Use `grid:stack_below()` for secondary controls in the same cell instead of hand-anchoring repeated checkbox/button stacks; keep the first control placed through `grid:place()` or `grid:place_at()`.
- When splitting a long settings builder into local section-builder functions, pass a small local `context` table for repeated build inputs such as config, DB handles, defaults, grid helpers, and reused proxies. Keep layout constants and private builders local unless another file genuinely needs them; do not expand a module's public `M` surface just to share implementation details inside one settings file.
- `CreateSliderWithBox` already debounces callbacks at `addon.UPDATE_INTERVALS.tenth_sec`; use its public control API for routine value handling: `slider:GetValue()`, `slider:SetValue(value)`, `slider:SetValueSilently(value)`, and `slider:HookValueChanged(fn[, opts])`. Reach into `slider.slider` only for template-specific behavior not exposed by the factory.
- `CreateCheckbox` exposes container-level state APIs: `checkbox:GetChecked()`, `checkbox:SetChecked(value)`, `checkbox:SetCheckedSilently(value)`, `checkbox:SetEnabled(value)`, `checkbox:Enable()`, `checkbox:Disable()`, and `checkbox:HookCheckedChanged(fn[, opts])`. Store the returned container in module control tables for routine sync, use `SetCheckedSilently()` for programmatic reset/profile/reload sync, and use the raw returned button/label only for specialized layout or tooltip targets.


### Key WoW APIs And Lessons
- Aura APIs: `C_UnitAuras.GetBuffDataByIndex`, `GetDebuffDataByIndex`, `GetAuraDuration`, `GetUnitAuraInstanceIDs`, `DoesAuraHaveExpirationTime`, `GetAuraApplicationDisplayCount`.
- Tooltip APIs: prefer `tooltip:SetUnitAuraByAuraInstanceID("player", auraInstanceID)` on the addon-owned tooltip frame, fall back to `tooltip:SetSpellByID`.
- CDM APIs/hooks: `CooldownViewerItemDataMixin`, `hooksecurefunc`, `Settings.OpenToCategory("Cooldown Viewer")`.
- Combat/taint: `InCombatLockdown()` guards protected paths. If Blizzard's blocked-action dialog appears, treat it as taint first.
- Sound APIs: `PlaySoundFile(fileDataID_or_path, channel?)` returns `(willPlay, soundHandle)`. `C_Sound.PlaySound(soundKitID, uiSoundSubType?)` returns `(success, soundHandle)`, though in-game testing confirmed `PlaySound(soundKitID, "SFX")` works on this client. `MuteSoundFile` / `UnmuteSoundFile` accept `number|string`; Ketho lists them as globals, not `C_Sound` members. Resolve sound API upvalues at file load.
- Objective Tracker APIs: `ObjectiveTrackerFrame`, `CampaignQuestObjectiveTracker`, `QuestObjectiveTracker`, and `AchievementObjectiveTracker` expose `SetCollapsed`/`IsCollapsed`. Objective module frames also inherit `ToggleCollapsed` and `MarkDirty`; apply startup/default state with `SetCollapsed`, but do not hook re-collapse behavior when the user must retain normal manual expand/collapse control.
- Lua operator precedence trap: `and` binds tighter than `or`, so `a and b ~= nil or false` parses as `(a and (b ~= nil)) or false`. The trailing `or false` is always a no-op when the left side already evaluates to a boolean. Write `a and b ~= nil` directly.
- Lua ternary trap: do not use `condition and value_if_true or value_if_false` when `value_if_true` can be `nil` or `false`; Lua will take the false branch. Use an explicit `if` block for optional override values, especially when `nil` means "fall through to default behavior".


## Module Memory
Module-specific memory files are linked in the table of contents above.
