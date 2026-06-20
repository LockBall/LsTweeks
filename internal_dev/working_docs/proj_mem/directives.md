# Directives And Philosophy
Working directives for coding agents on this project.


## Collaboration
- Treat what I say as a hypothesis, not a fact, unless we have proof. If I am wrong, then correct me directly.

- Prefer concrete evidence from code, docs, runtime tests, or API annotations over assumptions.

- Preserve user changes. Do not revert unrelated edits while cleaning or refactoring.

- After significant changes, provide a concise git commit message.


## Workflow And Documentation
- Do not store secrets, personal data, machine-local scratch notes, or session logs.

- Use modern PowerShell via `pwsh.exe` unless a command explicitly needs another shell.

- Vendored libraries under `libs/` are excluded from LuaLS diagnostics in workspace settings. Do not edit third-party library files for style/type warnings unless intentionally updating the library.

- Keep durable knowledge in `proj_mem/` or `internal_dev/completed_features/`; keep transient notes in `scratchpad.md`.

- Project-wide architecture belongs in `project.md`.

- Module-specific ownership, settings, runtime lessons, and regressions belong in that module's memory file.

- Completed feature investigations belong in `internal_dev/completed_features/`.

- Review checklist files under `review_2026Jun/` should stay actionable and can be deleted once complete.

- `internal_dev/tests_tools/` is long-term capture for probes, experiments, developing tests, and local diagnostic helpers. Do not delete files from it during cleanup unless the user explicitly asks to remove that specific artifact.

- Format ToDo plans in `internal_dev/working_docs/ToDo.md` with numbered sections (`### 1. file/topic`) and lettered checkbox substeps (`- [ ] a) ...`).

- Put a blank line between markdown list items in internal docs so dense notes stay readable.

- Put two blank lines between markdown sections so headings do not run into the previous block.


## Assets And References
- Use external projects, mirrors, examples, and API sources as references only. Do not copy code from them; implementations in this addon must be original unless the source is an explicitly vendored dependency with compatible licensing and attribution.

- Open-source libraries and similar third-party dependencies are acceptable when they are intentionally added as dependencies, their license is compatible with the project, and required attribution/source tracking is maintained.

- Treat Blizzard assets and mirrors of Blizzard assets as reference material, not open-source vendorable assets.

- Do not add copied Blizzard art assets unless the project has an explicit, reviewed packaging/legal plan for that asset.


## Engineering Philosophy
- **Single source of truth:** Defaults, category metadata, timing buckets, layout constants, and source-specific rules should have one owner.

- **Single-path behavior:** Prefer one deterministic runtime path. Centralize unavoidable branching and route callers through it.

- **Readability:** Small helpers are fine when they clarify real work. Avoid abstractions that hide WoW API, taint, combat, timing, or hot-path state.

- **Efficiency:** Aura scanning, rendering, layout, and GUI rebuilds are budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.

- **Conservative refactors:** Match existing file ownership and visible GUI unless the request explicitly changes behavior.

