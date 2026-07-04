# Agent Read-In Follow-Up
Optional follow-up after the read-in token review. Durable read-in policy lives in `agent_start.md`; command and routing details live in `code_map.md`.


## Table of Contents
- [Status](#status)
- [Remaining Idea](#remaining-idea)


## Status
- The startup route is already efficient: `agent_start.md` points to other docs instead of duplicating their contents, and `code_map.md` gives compact ownership plus commands.
- The main read-in cost comes from full module memory reads and broad source reads, not from the startup docs.
- Source responsibility headers, `--#region` markers, and module memory `##` headings are now part of the normal outline-first read-in path.


## Remaining Idea
- Consider a markdown section-read helper, such as `read_section.ps1 <file> <heading>`, only if agents keep over-reading large memory files after following `code_map.md` routing.
