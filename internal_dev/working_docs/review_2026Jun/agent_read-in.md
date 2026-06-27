# Agent Read-In Token Usage

Goal: manage and reduce agent read-in token usage while preserving enough project context for safe review and implementation work.


## Table of Contents
- [Measurements](#measurements)
- [Current Assessment](#current-assessment)
- [Proposed Read-In Policy](#proposed-read-in-policy)
- [High-Leverage Follow-Ups](#high-leverage-follow-ups)


## Measurements
kiloTokens  
modularization pass

- 2: 16,209

- 1: 15.786 kT

- 0 Baseline: 19-20 kT

Measurements are taken from the GUI's reported agent-token usage. Do not add rough token estimates from character counts or file sizes here.

Memory files stay whole. Do not split `proj_mem` or other internal documentation files for token reduction; improve headings, routing, and source outlines instead.


## Current Assessment

- The startup route is already efficient: `agent_start.md` points to other docs instead of duplicating their contents, and `code_map.md` gives compact ownership plus commands.

- The main read-in cost comes from full module memory reads and broad source reads, not from the startup docs. Aura Frames and Skyriding Vigor are the largest module contexts.

- Source responsibility headers and `--#region` markers are strong enough to support outline-first code reads. Full file reads should be reserved for files directly touched by the task.

- `project.md` is useful but should be section-read unless the task is architecture, packaging, shared GUI rules, tooling, or cross-module behavior.

- Platform-provided agent tools are session context, not project read-in. This note should track repo-local tools, command routing, and project-specific failure modes only.


## Proposed Read-In Policy

- Always read `agent_start.md`, `code_map.md`, and `git status --short`.

- Read targeted `project.md` sections only when the request touches their area.

- Read only the relevant module memory file before touching a module. For large module memories, run a heading search first, then open only the matching section.

- For source review, start with `rg -n "^--#region|^-- [A-Za-z].*" <target paths>` to build an outline before opening whole files.

- Avoid reading `README.md`, completed-feature notes, review notes, CPU profiles, SoundKit constants, packaging docs, or LuaLS tool notes unless the request directly routes there.


## High-Leverage Follow-Ups

- Done 2026-06-27: added section-level routing hints to `code_map.md` for `project.md`, `aura_frames.md`, and `skyriding_vigor.md` so agents can open specific headings first.

- Done 2026-06-27: updated `agent_start.md` to prefer section-first module memory reads and source outline searches before opening large Lua files.

- Done 2026-06-27: added matching `code_map.md` routing notes for `player_frame.md`, `objectives.md`, and `sound_levels.md`; these are small enough to keep as single module memory files.

- Done 2026-06-27: clarified in `code_map.md` that Lua file responsibility headers and `--#region` markers are the source-code TOC, so docs should route to outlines instead of duplicating detailed per-file maps.

- Done 2026-06-27: aligned `project.md` with the new read-in model so it points to `code_map.md` as the single owner of read-in shortcuts and source-outline routing.

- Done 2026-06-27: made GUI token measurements the only measurement source in this note and removed rough character-count estimates.

- Done 2026-06-27: made the no-splitting rule explicit. Large memory files stay whole; section headings and routing do the token-saving work.

- Done 2026-06-27: added Skyriding Vigor `##` headings and updated `code_map.md` routing so agents can section-read that large module memory file.

- Done 2026-06-27: added TOCs to multi-section markdown docs and documented the title/TOC/heading standard in the durable read-in docs.

- Add and maintain enough `##` headings in large module memory files that agents can read the matching section instead of the whole file.

- Keep review notes focused and temporary. Promote only durable conclusions into `proj_mem`.

- Keep each Lua file's responsibility header current; those headers are now part of the token-saving read-in path.
