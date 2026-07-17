# Agent Start
Start here for a new coding-agent session. This file is the lead-in, not the project memory itself; follow the links instead of copying their contents here.


## Table of Contents
- [Session Start](#session-start)
- [Collaboration Rules](#collaboration-rules)
- [Documentation Rules](#documentation-rules)
- [Engineering Rules](#engineering-rules)
- [Asset And Reference Rules](#asset-and-reference-rules)


## Session Start
1. Run `git status --short` before edits so user changes, deleted docs, generated files, and untracked notes are visible.
2. Read only `code_map.md` `## Read-In Shortcuts` using its section-reader command; do not load the whole map as baseline context.
3. Follow every route directly matched by the request. Add another route only when the request also matches it.

| Request trigger | Required targeted read |
| --- | --- |
| Module code or module behavior | Matching module memory section and source outline before broad source reads |
| Shared helper, core, or settings factory | `code_map.md` `## Core And Shared Helpers`, then source outline |
| Session/doc workflow, ownership, or scratchpad rules | `project.md` `### Workflow` |
| Ketho/LuaLS setup or annotation lookup | `project.md` `### Ketho / LuaLS` |
| Packaging, release zip, or `package-policy.json` | `project.md` `### Packaging / Release` |
| AddOn identity, slash command, SavedVariables name, or version edit point | `project.md` `### AddOn Summary` |
| Top-level file/folder ownership | `project.md` `### File Map` |
| Module pattern, file naming, runtime/reset contracts, or other addon-wide code rules | `project.md` `### Core Architecture Rules` |
| Shared GUI/layout rules, widget anchoring, or settings-grid usage | `project.md` `### GUI/Layout Rules` |
| WoW API usage, taint, combat guard, or Lua gotcha | `project.md` `### Key WoW APIs And Lessons` |
| Public behavior, names, settings, slash commands, install/use, release docs, or user-facing terminology | `README.md` |
| Focused active review or follow-up | Matching `ToDo/` note |
| Tool, LuaLS, packaging, or sandbox problem | `internal_dev/tests_tools/tools_notes.md` |
| PowerShell file-writing or newline issue | `internal_dev/tests_tools/powershell.md` |

- Start investigation or editing after the baseline and directly matched reads are complete. Do not read adjacent modules, whole large memory files, public docs, or review notes merely for familiarity.
- Before changing a known LuaLS/Ketho suppression, read the relevant module memory `## Ketho / LuaLS` section.
- Use `code_map.md` `## Fast Commands` for command strings, source outlines, routine validation, package validation, and repo search.
- Update `project.md` for durable architecture/defaults/tooling changes and the relevant module memory for durable module changes.
- File scope: routing and session-start guidance only; project facts belong in `project.md`, feature facts in module memory.


## Collaboration Rules
- Treat user statements as hypotheses until code, docs, runtime behavior, or API annotations confirm them. Correct wrong assumptions directly.
- Prefer concrete evidence over memory or inference, especially for WoW APIs, taint/combat behavior, packaging contents, and generated diagnostics.
- Preserve user changes. Do not revert unrelated edits while cleaning, refactoring, or packaging.
- After significant changes, provide a concise git commit message.
- When suggesting a commit message, provide one complete combined message for the current work batch unless the user explicitly asks for multiple separate commits or alternatives. Do not show both a short and long option.
- Do not use apostrophes in suggested commit messages; they break the user's commit command quoting.


## Documentation Rules
- `agent_start.md`: single entry point.
- `project.md`: project-wide architecture, workflow, file maps, packaging, LuaLS/Ketho notes, durable cross-module lessons.
- `code_map.md`: compact file ownership, command routing, token-saving context shortcuts.
- Module memory files: module-specific settings, runtime lessons, regressions, ownership details.
- Project read-in docs: repo-local tools, validation commands, known failure modes, project-specific command rules. Keep tool-owned notes under `internal_dev/tests_tools/`; exclude platform-provided session tools.
- Memory/doc size: do not split files for token savings; use markdown headings, source responsibility headers, and `--#region` markers.
- Routing table size: keep `agent_start.md` `## Session Start` and `code_map.md` `## Read-In Shortcuts` tables at roughly one screen each. Push new detail into a `project.md` section/subsection or module memory instead of growing a routing table row-by-row; add a routing row only when a new section/file needs a lookup path.
- Path references: use the shortest unambiguous filename/path after the first full path or when section context already scopes the directory.
- Command references: keep copy/paste command strings in command-owner docs such as `code_map.md`; use command names elsewhere.
- Completed working logs: prune or summarize old completion bullets after the durable result is captured in `proj_mem`.
- `internal_dev/working_docs/code_notes.md` is user-owned personal scratch space. Treat it as read-only unless the user explicitly requests an edit, reorganization, or deletion.
- List/table wording: prefer compact labels over explanatory sentences when meaning stays clear.
- Markdown structure: one `#` title; multi-section docs include `## Table of Contents` and stable `##` headings.
- Token measurement: GUI-reported agent-token measurements only; no rough character-count/file-size estimates.
- Rule phrasing: prefer positive gating (`Only do X when Y`) for conditional guidance; keep direct negative language for hard prohibitions.
- `ToDo/`: temporary active review context and TODO/follow-up items.
- Future work: active/dormant TODOs belong in review notes; durable `proj_mem` can point to them but should not be the only owner.
- Root-level markdown files such as `README.md` and `sources.md` are public-facing release/user docs, not internal agent memory.
- Forbidden doc content: secrets, personal data, machine-local scratch notes, session logs.
- Durable markdown spacing: no blank lines between list items or between a section heading and its first item; two blank lines between sections. Active scratchpads/working notes may use readable spacing while being edited; compact before promotion to durable memory.


## Engineering Rules
- Keep defaults, category metadata, timing buckets, layout constants, and source-specific rules owned in one place.
- Prefer one deterministic runtime path. Centralize unavoidable branching and route callers through it.
- Match existing file ownership and visible GUI unless the request explicitly changes behavior.
- Avoid abstractions that hide WoW API, taint, combat, timing, or hot-path state.
- Treat aura scanning, rendering, layout, and GUI rebuilds as budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.
- Use modern PowerShell via `pwsh.exe` unless a command explicitly needs another shell.
- Vendored libraries under `libs/` are third-party dependencies. Do not edit them for style or type warnings unless intentionally updating the dependency.
- Runtime-logic bugs: reproduce as a failing headless Lua test (`internal_dev/tests_tools/lua_tests/`) before fixing when the bug is testable there (timers, events, state machines, DB handling); taint/visual/event-order bugs stay in-game-only. The fix then keeps the test as permanent regression coverage.


## Asset And Reference Rules
- Use external projects, mirrors, examples, and API sources as references only. Do not copy code from them unless they are intentionally added as compatible, attributed dependencies.
- Treat Blizzard assets and mirrors of Blizzard assets as reference material, not open-source vendorable assets.
- Do not add copied Blizzard art assets unless the project has an explicit, reviewed packaging/legal plan for that asset.
