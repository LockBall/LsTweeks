# Agent Read-In Token Usage

Goal: manage and reduce agent read-in token usage while preserving enough project context for safe review and implementation work.


## Measurements
kiloTokens  
modularization pass

- 2: 16,209

- 1: 15.786 kT

- 0 Baseline: 19-20 kT

### estimates
- Estimated from file character counts on 2026-06-27, using chars / 4 as a rough token proxy.

- `agent_start.md` + `code_map.md`: ~2.7 kTokens.

- Full `project.md`: ~3.9 kTokens.

- Full `aura_frames.md`: ~4.2 kTokens.

- Full `skyriding_vigor.md`: ~4.4 kTokens.

- `README.md`: ~1.8 kTokens.


## Current Assessment

- The startup route is already efficient: `agent_start.md` points to other docs instead of duplicating their contents, and `code_map.md` gives compact ownership plus commands.

- The main read-in cost comes from full module memory reads and broad source reads, not from the startup docs. Aura Frames and Skyriding Vigor are the largest module contexts.

- Source responsibility headers and `--#region` markers are strong enough to support outline-first code reads. Full file reads should be reserved for files directly touched by the task.

- `project.md` is useful but should be section-read unless the task is architecture, packaging, shared GUI rules, tooling, or cross-module behavior.


## Proposed Read-In Policy

- Always read `agent_start.md`, `code_map.md`, and `git status --short`.

- Read targeted `project.md` sections only when the request touches their area.

- Read only the relevant module memory file before touching a module. For large module memories, prefer heading search first, then open the matching section.

- For source review, start with `rg -n "^--#region|^-- [A-Za-z].*" <target paths>` to build an outline before opening whole files.

- Avoid reading `README.md`, completed-feature notes, review notes, CPU profiles, SoundKit constants, packaging docs, or LuaLS tool notes unless the request directly routes there.


## High-Leverage Follow-Ups

- Done 2026-06-27: added section-level routing hints to `code_map.md` for `project.md`, `aura_frames.md`, and `skyriding_vigor.md` so agents can open specific headings first.

- Done 2026-06-27: updated `agent_start.md` to prefer section-first module memory reads and source outline searches before opening large Lua files.

- Done 2026-06-27: added matching `code_map.md` routing notes for `player_frame.md`, `objectives.md`, and `sound_levels.md`; these are small enough to keep as single module memory files.

- Done 2026-06-27: clarified in `code_map.md` that Lua file responsibility headers and `--#region` markers are the source-code TOC, so docs should route to outlines instead of duplicating detailed per-file maps.

- Done 2026-06-27: aligned `project.md` with the new read-in model so it points to `code_map.md` as the single owner of read-in shortcuts and source-outline routing.

- Split large module memory files only if section-level routing is not enough. Splitting too early can increase search overhead and stale-context risk.

- Keep review notes focused and temporary. Promote only durable conclusions into `proj_mem`.

- Keep each Lua file's responsibility header current; those headers are now part of the token-saving read-in path.

