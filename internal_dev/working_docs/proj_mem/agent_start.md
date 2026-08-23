# Agent Start
Start here for a new coding-agent session. This file is the lead-in, not the project memory itself; follow the links instead of copying their contents here. Paths are relative to `internal_dev/working_docs/proj_mem/` unless they begin with another top-level repository directory.


## Table of Contents
- [Session Start](#session-start)
- [Collaboration Rules](#collaboration-rules)
- [Engineering Rules](#engineering-rules)
- [Handoff Audit](#handoff-audit)


## Session Start
1. Baseline = this file + `project.md` `### Active Compatibility Sentinel` + offline WoW API reference status + `git status --short` + `code_map.md` `## Read-In Shortcuts` (all printed by `internal_dev/agent-start.ps1`; run the pieces manually only if the script fails). Do not re-read baseline pieces or load the whole code map.
2. `ToDo/` holds review notes and findings; read it only when the user directs you there or the request routes to a specific note.
3. Follow every route directly matched by the request. Add another route only when the request also matches it.

| Request trigger | Required targeted read |
| --- | --- |
| Module code or module behavior | Matching module memory section (list `##` headings first on large files) and source outline before broad source reads |
| Shared helper, core, settings factory, or shared widget (button, checkbox, slider, dropdown, color picker, panel, grid) | Matching `proj_mem/functions/` memory when present, then `code_map.md` `## Core And Shared Helpers` and source outline |
| Session/doc workflow, ownership, or scratchpad rules | `project.md` `### Workflow` |
| Editing, creating, or reorganizing any doc/memory markdown | `project.md` `### Documentation Rules` |
| Adding media, referencing external code, or Blizzard assets | `project.md` `### Asset And Reference Rules` |
| Ketho/LuaLS setup or annotation lookup | `project.md` `### Ketho / LuaLS` |
| Packaging, release zip, or `package-policy.json` | `project.md` `### Packaging / Release` |
| AddOn identity, slash command, SavedVariables, version edit point, or top-level file/folder ownership | `project.md` `### AddOn Summary` or `### File Map` |
| Module pattern, file naming, registration, or module toggles | `project.md` `### Module Structure And Registration` |
| Runtime contracts, events/timers/hot paths, taint, or combat guards | `project.md` `### Runtime And Performance Rules` |
| Defaults, DB handling, resets, or profiles | `project.md` `### Data, Resets, And Profiles` |
| Shared GUI/layout rules, widget anchoring, or settings-grid usage | `project.md` `### GUI/Layout Rules` |
| WoW API usage, taint, combat guard, or Lua gotcha | `project.md` `### Ketho / LuaLS`, then `### Key WoW APIs And Lessons` |
| Public install/use steps, embedded libraries, license, or credits | `README.md` `## Installation`, `## Use Notes`, `## Embedded Libraries`, `## License`, or `## Credits` via `doc_section.ps1` |
| Public Aura Frames behavior, names, or terminology | `README.md` `### Aura Frames` via `doc_section.ps1` |
| Public Player Frame behavior, names, or terminology | `README.md` `### Player Frame` via `doc_section.ps1` |
| Public Objectives behavior, names, or terminology | `README.md` `### Objectives` via `doc_section.ps1` |
| Public Skyriding Vigor behavior, names, or terminology | `README.md` `### Skyriding Vigor` via `doc_section.ps1` |
| Public Audio Volumes behavior, names, or terminology | `README.md` `### Audio Volumes` via `doc_section.ps1` |
| Public Settings behavior, names, or terminology | `README.md` `### Settings` via `doc_section.ps1` |
| Full public capability overview across modules, or unclear which module a README request routes to | `README.md` `## Modules` via `doc_section.ps1`, then the matching row above |
| Focused active review or follow-up | Matching `ToDo/` note |
| Raw WoW Lua error export (including a directed `ToDo/new_issue.txt`) | First run `condense_lua_errors.ps1 -Path <error-export.txt>` from `code_map.md` `## Fast Commands`; use raw locals only for follow-up |
| Tool, LuaLS, packaging, or sandbox problem | `internal_dev/tests_tools/tools_notes.md` |
| PowerShell file-writing or newline issue | `internal_dev/tests_tools/powershell.md` |

- Shared-function memory index: `functions/tooltip.md`, `functions/profiles.md`, `functions/controls.md`, and `functions/layout_grid.md`. Read only the file matched by the task.
- After baseline and matched reads, avoid adjacent modules, whole large memory files, public docs, or review notes unless necessary.
- Before changing a known LuaLS/Ketho suppression, read the relevant module memory `## Ketho / LuaLS` section.
- Use `code_map.md` `## Fast Commands` for command strings, source outlines, routine validation, package validation, and repo search.
- Update the owning project, module, or shared-function memory for durable architecture, defaults, APIs, and debugging lessons.
- File scope: routing and session-start guidance only; project facts belong in `project.md`, feature facts in module memory, and non-obvious shared-subsystem contracts in function memory.


## Collaboration Rules
- Interpret questions using “can,” “could,” or “is it possible” literally as capability questions: answer yes or no with a brief explanation, then wait for a separate instruction before taking the discussed action.
- Treat user statements as hypotheses until code, docs, runtime behavior, or API annotations confirm them. Correct wrong assumptions directly.
- Prefer concrete evidence over memory or inference, especially for WoW APIs, taint/combat behavior, packaging contents, and generated diagnostics.
- Proactively volunteer concise, evidence-grounded improvements noticed during work—even when not explicitly requested—when they would materially improve correctness, observability, maintainability, performance, or user experience. State the benefit, tradeoff, and required authority; suggest rather than expand implementation scope without authorization. For uncertain runtime causes, include the smallest safe diagnostic and avoid collecting secret, user, or unnecessary data.
- Apply calibrated skepticism to repository memory: treat it as evidence-backed working knowledge, not absolute truth. Use `project.md` `### Key WoW APIs And Lessons` `Evidence posture` to distinguish observation, inference, assumption, and history; revisit a claim only when a defined trigger appears, and otherwise avoid re-litigating stable evidence. When a request conflicts with a rule, examine what the rule protects, whether that applies, and what verification would justify an exception. Prohibitions backed by live incident logs deserve the most caution but still change when stronger evidence arrives; update the owning doc when they do. Tooltip evidence is owned in `functions/tooltip.md` `## Incident Evidence`.
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
- Failed-path investigations: reject only the exact API/caller/timing/target/argument combination supported by evidence, then apply `project.md` `### Key WoW APIs And Lessons` `Failure scope` before building a non-native workaround.
- Treat aura scanning, rendering, layout, and GUI rebuilds as budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.
- Use modern PowerShell via `pwsh.exe` unless a command explicitly needs another shell.
- Before the first patch-sensitive WoW API task in a session, run `sync_wow_api_reference.ps1` once for the matching channel, retain its reported client version and commit in session context, and reuse that snapshot. Rerun only when the channel/target changes, the refresh failed, or evidence indicates upstream moved; details live in `project.md` `### Ketho / LuaLS`.
- Vendored libraries under `libs/` are third-party dependencies. Do not edit them for style or type warnings unless intentionally updating the dependency.
- Runtime-logic bugs: reproduce as a failing headless Lua test (`internal_dev/tests_tools/lua_tests/`) before fixing when the bug is testable there (timers, events, state machines, DB handling); taint/visual/event-order bugs stay in-game-only. The fix then keeps the test as permanent regression coverage.
- Headless validation is one-pass and impact-selected: run the smallest red-to-green suite once, then only the remaining non-test checks; use all suites only when broad or uncertain impact justifies them. Commands live in `code_map.md` `## Fast Commands`; detailed selection policy lives in `tests_nfo.md` `## Workflow Integration`.
- LuaLS/Ketho changed-file validation uses one smallest-common workspace, not one process per directory; repeated language-server initialization is slower than a broader single pass and provides no additional diagnostics.


## Handoff Audit
Before saying work is complete, resolve these questions internally; ask the user only when required evidence cannot be obtained safely.
- Scope: does the final diff implement only the requested behavior, preserve unrelated/user-owned changes, and cover every consumer of changed shared state?
- Evidence timing: did relevant validation run after the last behavior-changing edit, without counting stale or duplicate runs?
- Assumptions: could a bad reload, stale client state, delayed callback, cached data, combat state, or incomplete stub make the apparent result misleading; did any failure reject more than the exact path tested?
- Regression value: did the test fail before the fix and enforce the actual safety boundary, not merely the visible happy path?
- Environment gap: what cannot headless tests or static analysis prove, and was the smallest necessary in-game check completed and recorded?
- Documentation: after behavior or architecture changes, did a repository-wide markdown search find and correct superseded rules in project/module memory, `code_map.md`, test docs, applicable public docs, and temporary ToDos?
- Closeout: are diagnostics, scratch files, generated output, deleted review notes, untracked files, and the proposed commit scope all intentional?
