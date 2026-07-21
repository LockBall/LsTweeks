# Agent Start
Start here for a new coding-agent session. This file is the lead-in, not the project memory itself; follow the links instead of copying their contents here.


## Table of Contents
- [Session Start](#session-start)
- [Collaboration Rules](#collaboration-rules)
- [Engineering Rules](#engineering-rules)
- [Handoff Audit](#handoff-audit)


## Session Start
1. Baseline = this file + `git status --short` + `code_map.md` `## Read-In Shortcuts` (all printed by `internal_dev/tests_tools/agent_startup.ps1`; run the pieces manually only if the script fails). Do not re-read baseline pieces or load the whole code map.
2. `ToDo/` holds review notes and findings; read it only when the user directs you there or the request routes to a specific note.
3. Follow every route directly matched by the request. Add another route only when the request also matches it.

| Request trigger | Required targeted read |
| --- | --- |
| Module code or module behavior | Matching module memory section (list `##` headings first on large files) and source outline before broad source reads |
| Shared helper, core, settings factory, or shared widget (button, checkbox, slider, dropdown, color picker, panel, grid) | `code_map.md` `## Core And Shared Helpers`, then source outline |
| Session/doc workflow, ownership, or scratchpad rules | `project.md` `### Workflow` |
| Editing, creating, or reorganizing any doc/memory markdown | `project.md` `### Documentation Rules` |
| Adding media, referencing external code, or Blizzard assets | `project.md` `### Asset And Reference Rules` |
| Ketho/LuaLS setup or annotation lookup | `project.md` `### Ketho / LuaLS` |
| Packaging, release zip, or `package-policy.json` | `project.md` `### Packaging / Release` |
| AddOn identity, slash command, SavedVariables name, or version edit point | `project.md` `### AddOn Summary` |
| Top-level file/folder ownership | `project.md` `### File Map` |
| Module pattern, file naming, registration, or module toggles | `project.md` `### Module Structure And Registration` |
| Runtime contracts, events/timers/hot paths, taint, or combat guards | `project.md` `### Runtime And Performance Rules` |
| Defaults, DB handling, resets, or profiles | `project.md` `### Data, Resets, And Profiles` |
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
- Documented rules are guidelines encoding past evidence, not immutable law. When a request conflicts with a rule, examine what the rule protects against, whether that applies here, and what verification would justify an exception, instead of citing the rule and stopping. Prohibitions with live incident logs (taint, combat) deserve the most caution, yet even those get revised when validated evidence arrives; update the owning doc when they do. Example: short testing initially appeared to validate shared-native Aura delegates, but delayed taint evidence required a dedicated native tooltip instead (2026-07-20).
- Preserve user changes. Do not revert unrelated edits while cleaning, refactoring, or packaging.
- After significant changes, provide a concise git commit message.
- When suggesting a commit message, provide one complete combined message for the current work batch unless the user explicitly asks for multiple separate commits or alternatives. Do not show both a short and long option.
- Do not use apostrophes in suggested commit messages; they break the user's commit command quoting.
- HARD GATE: before editing, creating, or reorganizing any markdown under `working_docs/` or `proj_mem/`, read `project.md` `### Documentation Rules` first. Code sessions usually end with doc/memory updates; this gate applies then too.
- `internal_dev/working_docs/code_notes.md` is user-owned personal scratch space. Treat it as read-only unless the user explicitly requests an edit, reorganization, or deletion.


## Engineering Rules
- Keep defaults, category metadata, timing buckets, layout constants, and source-specific rules owned in one place.
- Prefer one deterministic runtime path. Centralize unavoidable branching and route callers through it.
- Match existing file ownership and visible GUI unless the request explicitly changes behavior.
- Avoid abstractions that hide WoW API, taint, combat, timing, or hot-path state.
- Treat aura scanning, rendering, layout, and GUI rebuilds as budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.
- Use modern PowerShell via `pwsh.exe` unless a command explicitly needs another shell.
- Vendored libraries under `libs/` are third-party dependencies. Do not edit them for style or type warnings unless intentionally updating the dependency.
- Runtime-logic bugs: reproduce as a failing headless Lua test (`internal_dev/tests_tools/lua_tests/`) before fixing when the bug is testable there (timers, events, state machines, DB handling); taint/visual/event-order bugs stay in-game-only. The fix then keeps the test as permanent regression coverage.
- Headless validation is one-pass and impact-selected: run the smallest red-to-green suite once, then only the remaining non-test checks; use all suites only when broad or uncertain impact justifies them. Commands live in `code_map.md` `## Fast Commands`; detailed selection policy lives in `tests_nfo.md` `## Workflow Integration`.
- LuaLS/Ketho changed-file validation uses one smallest-common workspace, not one process per directory; repeated language-server initialization is slower than a broader single pass and provides no additional diagnostics.


## Handoff Audit
Before saying work is complete, resolve these questions internally; ask the user only when required evidence cannot be obtained safely.
- Scope: does the final diff implement only the requested behavior, preserve unrelated/user-owned changes, and cover every consumer of changed shared state?
- Evidence timing: did relevant validation run after the last behavior-changing edit, without counting stale or duplicate runs?
- Assumptions: could a bad reload, stale client state, delayed callback, cached data, combat state, or incomplete stub make the apparent result misleading?
- Regression value: did the test fail before the fix and enforce the actual safety boundary, not merely the visible happy path?
- Environment gap: what cannot headless tests or static analysis prove, and was the smallest necessary in-game check completed and recorded?
- Documentation: after behavior or architecture changes, did a repository-wide markdown search find and correct superseded rules in project/module memory, `code_map.md`, test docs, applicable public docs, and temporary ToDos?
- Closeout: are diagnostics, scratch files, generated output, deleted review notes, untracked files, and the proposed commit scope all intentional?
