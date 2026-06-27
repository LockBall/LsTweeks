# Agent Read-In Token Usage
Goal: manage and reduce agent read-in token usage while preserving enough project context for safe review and implementation work.


## Table of Contents
- [Measurements](#measurements)
- [Current Assessment](#current-assessment)
- [Promoted Policy](#promoted-policy)
- [High-Leverage Follow-Ups](#high-leverage-follow-ups)


## Measurements
kiloTokens  
modularization pass

- 2: 16,209
- 1: 15.786 kT
- 0 Baseline: 19-20 kT

Measurement policy is promoted to `agent_start.md`; this note records GUI-reported values only.


## Current Assessment
- The startup route is already efficient: `agent_start.md` points to other docs instead of duplicating their contents, and `code_map.md` gives compact ownership plus commands.
- The main read-in cost comes from full module memory reads and broad source reads, not from the startup docs. Aura Frames and Skyriding Vigor are the largest module contexts.
- Source responsibility headers and `--#region` markers are strong enough to support outline-first code reads. Full file reads should be reserved for files directly touched by the task.
- `project.md` is useful but should be section-read unless the task is architecture, packaging, shared GUI rules, tooling, or cross-module behavior.
- Durable policy now lives in `agent_start.md`; command/routing details live in `code_map.md`.


## Promoted Policy
The read-in policy from this review is now owned by `agent_start.md` and `code_map.md`; do not maintain a second copy here.


## High-Leverage Follow-Ups
- Add and maintain enough `##` headings in large module memory files that agents can read the matching section instead of the whole file.
- Keep review notes focused and temporary. Promote only durable conclusions into `proj_mem`.
- Keep each Lua file's responsibility header current; those headers are now part of the token-saving read-in path.
