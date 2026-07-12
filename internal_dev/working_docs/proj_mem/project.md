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
- Session start: read `agent_start.md` first, then only `code_map.md` `## Read-In Shortcuts`; `code_map.md` owns targeted routing, validation commands, and source-outline routing.
- Internal docs: `internal_dev/`.
- Active working docs: `working_docs/`; project/module memory in `proj_mem/`, focused TODO/review notes in `ToDo/`.
- Completed feature facts are consolidated into this file or the relevant module memory; do not create separate completed-feature notes unless a new active review explicitly needs temporary handoff context.
- Before closing a resolved review finding, decide whether its cause or fix pattern can recur outside the module. Add unresolved addon-wide checks to `ToDo/cross_module_followups.md` immediately; keep only durable generalized lessons in this file.
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
- Packaging docs and policy live in `internal_dev/tests_tools/packaging/package_me.md` and `internal_dev/tests_tools/packaging/package-policy.json`.
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

Every project Lua file starts with a short responsibility header before code, and each declared function belongs to a named `--#region` so source outlines form a complete source TOC. `code_map.md` owns source/memory outline commands; keep durable ownership notes there or in the relevant module memory file instead of expanding this map.

Lua section headers use VS Code foldable region markers with visual dividers: `--#region SECTION NAME =====` and `--#endregion SECTION NAME =====`. Use uppercase section names and keep region markers paired. Put the explanatory section comment directly under `--#region` with no blank line, put no blank line before `--#endregion`, and leave two blank lines before the next `--#region`.


## Shared Architecture
### Core Architecture Rules
- Module pattern: `local addon_name, addon = ...`; share state through `addon` and `addon.aura_frames` (`M`).
- Avoid accidental globals in addon files. Keep helpers, constants, builder functions, and cached API references `local` by default; expose values through `addon` or a module table `M` only when another file genuinely needs that public contract.
- Module file naming pattern: use `<prefix>_defaults.lua` for DB defaults/metadata, `<prefix>_gui*.lua` for settings UI, `<prefix>_logic_<subsystem>.lua` for larger runtime subsystems, and `<prefix>_main.lua` for entrypoint/controller/bootstrap. Avoid broad `logic.lua`, `runtime.lua`, or `functions.lua` buckets unless the file is genuinely a small shared-helper owner; when a module grows, split by owned subsystem before adding vague catch-all files.
- Sidebar categories use `addon.register_category(name, builder, { order = n })`; equal order values preserve registration order. Default order is 100.
- Feature modules are listed in `addon.FEATURE_MODULES` (`core/init.lua`) and can be disabled with `Ls_Tweeks_DB.modules.<module_key> = false`. Categories for feature modules pass `opts.module_key`; `core/main_frame.lua` keeps disabled module pages visible and selectable in the sidebar, greys them out, and overlays the selected page so options can be inspected but not changed.
- Runtime modules that have side effects implement `M.set_module_enabled(enabled)` so Settings tab toggles can stop/restart owned runtime state without changing each module's own feature-level settings.
- Current module toggles are soft-disable gates after addon files have loaded; they stop owned runtime work but do not unload code or free all memory. `/lst status` reports each feature module's enabled flag and module-owned runtime signals such as registered events, tickers/timers, preview handles, and visible frames. Use `/lst status <module key or label>` for focused diagnostics, such as `/lst status objectives`. Reopen lazy construction or LoadOnDemand child addons only with an explicit memory-footprint target in the review folder.
- Before adding a small feature with runtime side effects, define its runtime contract: owned events, hooks, timers, queued work, off-state behavior, module-disable behavior, and restore path.
- When adding or changing runtime work in a feature module, audit disabled behavior before finishing: events, hooks, timers, callbacks, tickers, queued `C_Timer` work, frames, and status fields must either stop at disable time or cheaply no-op before doing owned work.
- Event, hook, timer, ticker, `OnUpdate`, scan, and layout paths must make unchanged state cheap first. Compare the smallest stable state before frame writes, Blizzard layout calls, follow-up scheduling, table rebuilds, or diagnostic string formatting. Use cached signatures, dirty flags, or explicit state fields for hot/noisy paths; keep one-shot settings-page code simple unless it fans out into runtime refresh work.
- Filter early by default: use the narrowest event registration available, then reject disabled, irrelevant, invisible, stale, or unchanged work at the entry point before DB/config resolution, allocations, scheduling, scans, or frame writes. Add broader work only when the behavior requires it.
- Before handoff, do a focused cleanup pass for duplicated helpers, stale fallbacks, dead status fields, repeated formatting, and broad API fallbacks.
- Stateful modules implement `on_reset_complete()` and resync controls/runtime after reset. Module reset panels use `CreateModuleReset()` and pass `opts.after_reset = M.on_reset_complete` so only that module is synchronized.
- Apply defaults with `addon.apply_defaults(defaults, db)`; guard DB tables with `or {}`.
- Use shared/default registries only when another path consumes that public key. Treat TOC-ordered defaults, metadata, and module helpers as required dependencies; keep fallback literals and absence guards only for optional/status/debug paths that intentionally tolerate partial load.
- Keep setting ranges, shared widget footprints, runtime clamp metadata, and tolerance constants single-owned and domain-named.
- Timed visual progress should use real elapsed time, aura expiration, or WoW duration objects. Fixed-interval timers belong to debounces, event buckets, polling, retry/follow-up work, and preview restore delays where nominal cadence is the contract.
- Delayed work and state helpers must be safe when called in isolation: gate cheap no-op states before queuing, stop stale tickers as soon as no work remains, refresh combat/enablement/lifecycle guards inside helpers, and add headless tests when the harness can model the risk.
- Shared timing values live in `addon.UPDATE_INTERVALS`; do not hardcode repeated refresh/debounce delays.
  - Reusable profile mechanics live in `functions/profiles.lua` through `addon.CreateProfileManager()` and `addon.BuildProfilesTab()`. Each module keeps its own profile file for the explicit snapshot schema, migrations, and post-load runtime refresh.
  - Profile/default imports must select a fallback only when the source key is `nil`; explicit `false` is saved data and must survive the copy.
- When a reset, profile system, preview workflow, or shared UI factory changes, review five cross-module concerns before handoff: live DB references after table replacement; ownership and cancellation of delayed restores; symmetry between normal and temporary-state reads/writes; reset/profile-load synchronization of controls, runtime, and session flags; and every consumer of the changed shared factory. Keep the durable rule here and record only unresolved module-specific work in a ToDo review.
- Behavior-specific runtime timing aliases live in `addon.UPDATE_INTERVALS` immediately after the generic buckets. Use aliases such as `aura_visible_icon_tick`, `aura_event_bucket`, `aura_hover_check`, `player_frame_fade_tick`, and `skyriding_vigor_progress` as profiling/test adjustment points instead of changing generic buckets directly.
- Cache hot globals at file top (`local floor = math.floor`, `local GetTime = GetTime`, etc.).
- Keep high-frequency runtime paths narrow. If code runs every frame/tick or many
  times per second, avoid repeated DB/style/layout/atlas/config resolution there;
  do that work in a lower-frequency refresh/setup path and pass or store the
  resolved state for the hot path. Make the mutability boundary explicit first,
  such as disabling settings edits during an active runtime state while still
  allowing controlled test modes.
- When a settings control has both a broad runtime lock and a local eligibility rule, register the local rule with the centralized gate. Local state synchronization must reapply that composite gate rather than directly enabling the control.
- Give each direct `OnUpdate` assignment one owning subsystem. Use `HookScript` when extending a Blizzard-owned frame, or a dedicated driver frame when independent addon lifecycles need concurrent updates; only the owner may clear its callback.
- Programmatic control synchronization may suppress callbacks only for the setter call. Restore the prior suppression state through a protected cleanup path and rethrow setter errors, so a failed sync cannot mute later user input.
- Normalize persisted RGBA tables at each module startup/profile-import boundary. Clamp readable components to 0–1 before cached or runtime visual paths use them; do not rely solely on a color picker to sanitize manually edited or legacy saved variables.
- Release initialization-only listeners such as `ADDON_LOADED` as soon as their own initialization completes. Retain one only for a named later-load dependency and document that dependency beside the listener.
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
- Shared color controls live in `functions/color_picker.lua` via `addon.CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb)`. Use that factory for settings color pickers instead of hand-building ColorPickerFrame wiring. The shared system picker clears its live swatch/opacity callbacks when a session cancels or hides, so a later picker session cannot write the closed control state.
- Shared dropdown hover arrows are owned by `functions/dropdown.lua` through `addon.CreateDropdown()`. They use `Interface\ChatFrame\ChatFrameExpandArrow` at `15x15`, anchored directly below the dropdown with `0` px vertical offset and rotated 90 degrees clockwise via `Texture:SetTexCoord()`. Reusable asset details live in `media_notes.md`.
- Shared grouped selector columns live in `functions/group_column.lua` through `addon.CreateGroupColumn()`. It is based on Aura Frames' grouped tree structure: thin-border outer frame, thin-border group boxes, centered titles inside group outlines, outlined row labels, one selected-row highlight, and a gold border on the selected row's group. Use it for left-side grouped list/tree columns that need selectable rows, optional row delete buttons, and optional group actions. Group boxes are clickable and select the header `default_key` or first row, so clicking empty space/title inside a section activates that section. For Audio Volumes, Triggered is the fixed primary group equivalent to Aura Frames' Buffs group, and Quick Picks is the custom group with the same Aura-style group title/outline presentation.
- Shared settings UI chrome lives in `functions/ui_helpers.lua`: use `addon.CreateControlPanel()` / `addon.ApplyControlPanelBackdrop()` for the standard dark framed control background, `addon.CreateSettingsGroup()` / `addon.ApplySettingsGroupOutline()` / `addon.CreateSettingsGroupTitleBar()` for the gold outlined settings group style with a 24px grey title bar used by Audio Volumes and Objectives, and the addon-owned tooltip factory/helpers (`addon.CreateOwnedTooltip()`, `addon.GetOwnedTooltip()`, `addon.ShowOwnedTooltip()`, `addon.HideOwnedTooltip()`, `addon.AttachTooltip()`, `addon.AttachTooltipToTargets()`) instead of direct module use of global `GameTooltip`.
- Repeated standard control-panel backdrops and simple settings tooltip hooks are consolidated into `functions/ui_helpers.lua`. Remaining repeated-looking UI code is mostly specialized composition: Aura Frames runtime/tooltips, main-frame chrome, Audio Volumes custom panels, and feature-specific list/tree rendering.
- Shared grid placement helpers live in `functions/layout_grid.lua`: `addon.GetGridOffset()`, `addon.SetGridPoint()`, `addon.CenterGridControl()`, and `addon.CreateSettingsGrid()`. Use `addon.CreateSettingsGrid()` for row/column settings panels, including row divider lines through `row_separators`; keep divider rows explicit so sparse layouts do not draw empty separators. Prefer the grid object's `grid:place(control, placement)` and `grid:center(control, placement)` helpers when using module-local placement tables, so modules do not duplicate alignment/y-offset/width option mapping.
- Treat module-local grid placement tables as static source data. Pass dynamic widths or centering details through grid placement options instead of writing derived runtime values back into placement tables.
- Make non-additive `CreateSettingsGrid()` changes only when current consumers are reviewed together. Player Frame, Skyriding Vigor, and Aura Frames rely on tuned row-height, separator, centering, and column-offset behavior.
- Settings grid cells may contain a small vertical stack of related controls. Use `grid:stack_below()` for secondary controls in the same cell instead of hand-anchoring repeated checkbox/button stacks; keep the first control placed through `grid:place()` or `grid:place_at()`.
- When splitting a long settings builder into local section-builder functions, pass a small local `context` table for repeated build inputs such as config, DB handles, defaults, grid helpers, and reused proxies. Keep layout constants and private builders local unless another file genuinely needs them; do not expand a module's public `M` surface just to share implementation details inside one settings file.
- `CreateSliderWithBox` debounces callbacks at `addon.UPDATE_INTERVALS.tenth_sec` by default. Use `opts.immediate_callback` only for direct visual previews whose callback is safe and inexpensive at every drag step; retain debounce for scans, reconstruction, external API work, and other costly processing. Use its public control API for routine value handling: `slider:GetValue()`, `slider:SetValue(value)`, `slider:SetValueSilently(value)`, and `slider:HookValueChanged(fn[, opts])`. Reach into `slider.slider` only for template-specific behavior not exposed by the factory.
- `CreateCheckbox` exposes container-level state APIs: `checkbox:GetChecked()`, `checkbox:SetChecked(value)`, `checkbox:SetCheckedSilently(value)`, `checkbox:SetEnabled(value)`, `checkbox:Enable()`, `checkbox:Disable()`, and `checkbox:HookCheckedChanged(fn[, opts])`. Store the returned container in module control tables for routine sync, use `SetCheckedSilently()` for programmatic reset/profile/reload sync, and use the raw returned button/label only for specialized layout or tooltip targets.
- Module reset preserve checkboxes also follow the shared checkbox container rule; read preserve state through the container API instead of the raw CheckButton.


### Key WoW APIs And Lessons
- Aura APIs: `C_UnitAuras.GetBuffDataByIndex`, `GetDebuffDataByIndex`, `GetAuraDuration`, `GetUnitAuraInstanceIDs`, `DoesAuraHaveExpirationTime`, `GetAuraApplicationDisplayCount`.
- Tooltip APIs: use addon-owned tooltips. Rich renderers such as `SetUnitAuraByAuraInstanceID()` or `SetSpellByID()` must run through `securecallfunction` wrappers with a `C_TooltipInfo` line-cache fallback.
- CDM APIs/hooks: `CooldownViewerItemDataMixin`, `hooksecurefunc`, `Settings.OpenToCategory("Cooldown Viewer")`.
- Combat/taint: `InCombatLockdown()` guards protected paths. If Blizzard's blocked-action dialog appears, treat it as taint first.
- Secret API values: guard only known restricted API outputs before comparisons, arithmetic, string construction, table keys, cache writes, or ordinary UI calls. Keep the safe local result through the path; direct pass-through is acceptable only to a Blizzard display API that supports the value, without inspecting or caching it.
- Sound APIs: `PlaySoundFile(fileDataID_or_path, channel?)` returns `(willPlay, soundHandle)`. `C_Sound.PlaySound(soundKitID, uiSoundSubType?)` returns `(success, soundHandle)`, though in-game testing confirmed `PlaySound(soundKitID, "SFX")` works on this client. `MuteSoundFile` / `UnmuteSoundFile` accept `number|string`; Ketho lists them as globals, not `C_Sound` members. Resolve sound API upvalues at file load.
- Objective Tracker APIs: `ObjectiveTrackerFrame`, `CampaignQuestObjectiveTracker`, `QuestObjectiveTracker`, and `AchievementObjectiveTracker` expose `SetCollapsed`/`IsCollapsed`. Objective module frames also inherit `ToggleCollapsed` and `MarkDirty`; apply startup/default state with `SetCollapsed`, but do not hook re-collapse behavior when the user must retain normal manual expand/collapse control.
- Lua operator precedence trap: `and` binds tighter than `or`, so `a and b ~= nil or false` parses as `(a and (b ~= nil)) or false`. The trailing `or false` is always a no-op when the left side already evaluates to a boolean. Write `a and b ~= nil` directly.
- Lua ternary trap: do not use `condition and value_if_true or value_if_false` when `value_if_true` can be `nil` or `false`; Lua will take the false branch. Use an explicit `if` block for optional override values, especially when `nil` means "fall through to default behavior".


## Module Memory
Module-specific memory files are linked in the table of contents above.
