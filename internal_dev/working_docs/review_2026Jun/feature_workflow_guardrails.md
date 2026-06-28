# Feature Workflow Guardrails
Working note for improving future code generation on small addon features. Do not treat this as a project rule until it has been reviewed and promoted into `proj_mem`.


## Problem
The Objectives Section Count feature was small, but it still needed follow-up cleanup for disabled behavior, runtime cost, duplicated helpers, formatting ownership, and Blizzard API interpretation. The mistake was treating a small feature as low-risk before defining its runtime contract.


## Candidate Checklist
1. **Read module memory first.** Confirm ownership, disabled behavior, runtime cost expectations, and existing patterns before writing code.
2. **Define the runtime contract before coding.** State when the feature runs, what events/hooks/timers it owns, what happens when the feature option is off, what happens when the whole module is disabled, and what state must be restored.
3. **Prefer event-driven updates.** Avoid tracker-update hooks, movement-triggered refreshes, repeating timers, or broad scans unless there is a clear reason.
4. **Centralize constants and formatting.** Defaults, labels, formats, limits, UI metadata, and shared helpers should have one owner from the start.
5. **Run an off-state audit before final.** Check that unchecked options and disabled modules stop events, skip queued work cheaply, and restore only what LsTweeks changed.
6. **Do a redundancy pass before handoff.** Search for duplicated helpers, stale fallbacks, dead status fields, repeated formatting, and broad API fallbacks.
7. **Use scratch notes for uncertain behavior.** Anything requiring in-game confirmation, especially Blizzard API interpretation, goes into a short scratch TODO instead of being silently assumed.


## Possible Promotion Path
- Project-wide rule: add the checklist, or a shorter version of it, under `project.md` Engineering Rules.
- Module-specific rule: add Objectives-specific runtime contract notes to `proj_mem/modules/objectives.md`.
- Agent start reminder: add only a compact pointer if this proves broadly useful; keep `agent_start.md` as an entry point, not the checklist owner.
