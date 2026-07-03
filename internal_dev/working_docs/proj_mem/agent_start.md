# Agent Start
Start here for a new coding-agent session. This file is the lead-in, not the project memory itself; follow the links instead of copying their contents here.


## Table of Contents
- [Session Start](#session-start)
- [First Checks](#first-checks)
- [Collaboration Rules](#collaboration-rules)
- [Documentation Rules](#documentation-rules)
- [Engineering Rules](#engineering-rules)
- [Asset And Reference Rules](#asset-and-reference-rules)


## Session Start
1. Run `git status --short` before edits so user changes, deleted docs, generated files, and untracked notes are visible.
2. Read `code_map.md` first for compact file ownership, routing, and verification commands.
3. Read targeted sections of `project.md` when the request touches architecture, workflow, packaging, LuaLS/Ketho, shared GUI rules, cross-module behavior, or durable project docs.
4. Read only the relevant module memory file before touching a module. For large module memories, use `code_map.md` section hints or `rg -n "^##" <memory-file>`, then open only the matching section instead of the whole file:
   `modules/player_frame.md`, `modules/objectives.md`, `modules/audio_volumes.md`, `modules/skyriding_vigor.md`, or `modules/aura_frames.md`.
5. Read `README.md` only when the request touches public behavior, feature names, settings names, slash commands, install/use expectations, release docs, or user-facing terminology.
6. Check focused review notes under `review_2026Jun/` only when the task touches that area. Promote transient review notes into durable docs only after code review confirms they are still true.
7. For tool, LuaLS, packaging, or sandbox problems, check `internal_dev/tests_tools/tools_notes.md` before inventing a new recovery path.
8. For PowerShell file-writing or newline issues, check `internal_dev/tests_tools/powershell.md` before scripting rewrites.


## First Checks
- Repo search: `rg` / `rg --files`.
- Command strings: `code_map.md` `## Fast Commands`.
- Source read-in: start with `region validation / source outline` before opening whole large Lua files.
- Routine validation: `fast validation`.
- Known diagnostic suppressions: when touching suppressed LuaLS/Ketho lines, read the relevant module memory `## Ketho / LuaLS` section before changing or removing the suppression.
- Package validation: `fast validation plus package build/verify`.
- Public behavior: compare against `README.md` wording before changing settings names, feature names, slash commands, or user-facing docs.
- Durable architecture/defaults/tooling changes: update `project.md`.
- Durable module changes: update that module's memory file.
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
- Path references: use the shortest unambiguous filename/path after the first full path or when section context already scopes the directory.
- Command references: keep copy/paste command strings in command-owner docs such as `code_map.md`; use command names elsewhere.
- Completed working logs: prune or summarize old completion bullets after the durable result is captured in `proj_mem`.
- List/table wording: prefer compact labels over explanatory sentences when meaning stays clear.
- Markdown structure: one `#` title; multi-section docs include `## Table of Contents` and stable `##` headings.
- Token measurement: GUI-reported agent-token measurements only; no rough character-count/file-size estimates.
- Rule phrasing: prefer positive gating (`Only do X when Y`) for conditional guidance; keep direct negative language for hard prohibitions.
- `review_2026Jun/`: temporary active review context and TODO/follow-up items.
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


## Asset And Reference Rules
- Use external projects, mirrors, examples, and API sources as references only. Do not copy code from them unless they are intentionally added as compatible, attributed dependencies.
- Treat Blizzard assets and mirrors of Blizzard assets as reference material, not open-source vendorable assets.
- Do not add copied Blizzard art assets unless the project has an explicit, reviewed packaging/legal plan for that asset.
