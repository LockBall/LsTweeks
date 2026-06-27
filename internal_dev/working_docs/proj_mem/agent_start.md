# Agent Start

Start here for a new coding-agent session. This file is the lead-in, not the project memory itself; follow the links instead of copying their contents here.


## Session Start

1. Read `README.md` for the public addon overview, feature surface, user-facing terminology, and install/use expectations.

2. Read `internal_dev/working_docs/proj_mem/project.md` for the internal source of truth: architecture, file map, workflow, packaging, LuaLS/Ketho notes, and links to module memory.

3. Read `internal_dev/working_docs/proj_mem/code_map.md` for a compact file ownership map and common verification commands.

4. Read only the relevant module memory file before touching a module:
   `player_frame.md`, `objectives.md`, `sound_levels.md`, `skyriding_vigor.md`, or `aura_frames.md`.

5. Check focused review notes under `internal_dev/working_docs/review_2026Jun/` only when the task touches that area. Do not promote transient review notes into durable docs unless they are still true after code review.

6. For tool, LuaLS, packaging, or sandbox problems, check `internal_dev/tests_tools/tools_notes.md` before inventing a new recovery path.


## First Checks

- Run `git status --short` before edits so user changes, deleted docs, generated files, and untracked notes are visible.

- Use `rg` / `rg --files` for repo searches.

- Use `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1` for routine Lua syntax and whitespace validation.

- Use `git diff --check` before handing off code/doc edits to catch whitespace errors across the current diff.

- Use `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1 -Package` when packaging behavior or release contents matter.

- If a request touches public behavior, compare against `README.md` wording before changing settings names, feature names, slash commands, or user-facing docs.

- If a request touches architecture, defaults, packaging, tooling, or cross-module behavior, update `project.md` only when the new fact is durable.

- If a request touches one feature module, update that module's memory file only when the new fact is durable.

- Keep this file short. Add routing and session-start guidance here; put project facts in `project.md` and feature facts in module memory.


## Collaboration Rules

- Treat user statements as hypotheses until code, docs, runtime behavior, or API annotations confirm them. Correct wrong assumptions directly.

- Prefer concrete evidence over memory or inference, especially for WoW APIs, taint/combat behavior, packaging contents, and generated diagnostics.

- Preserve user changes. Do not revert unrelated edits while cleaning, refactoring, or packaging.

- After significant changes, provide a concise git commit message.

- When suggesting a commit message, provide one combined message for the current work batch unless the user explicitly asks for multiple separate commits or alternatives.


## Documentation Rules

- `agent_start.md` is the single entry point for future agents.

- `project.md` owns project-wide architecture, workflow, file maps, packaging, LuaLS/Ketho notes, and durable cross-module lessons.

- `code_map.md` owns compact file ownership, command routing, and token-saving context shortcuts.

- Module memory files own module-specific settings, runtime lessons, regressions, and ownership details.

- `internal_dev/completed_features/` owns completed feature investigations.

- Focused review notes under `review_2026Jun/` own temporary active review context only.

- Root markdown is public-facing release documentation.

- Do not store secrets, personal data, machine-local scratch notes, or session logs.

- Put a blank line between markdown list items in internal docs, and put two blank lines between markdown sections.


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
