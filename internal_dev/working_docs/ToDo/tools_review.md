# Tools Review Findings 2026-07-05
Token-usage and agent-efficiency review of the repo-local tooling. Full reads: `check_fast.ps1`, `check_regions.ps1`, `lua_checks/kethos/run_luals_ketho.ps1`, `tests_tools/tools_notes.md`, `proj_mem/agent_start.md`, `proj_mem/code_map.md`. Measurements: proj_mem file sizes, `LsTweeks.toc` Lua list vs the check_fast hardcoded list, live `rg` probe of the Ketho annotations. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Confirmed Bug](#confirmed-bug)
- [Token Savers](#token-savers)
- [New Tool Candidates](#new-tool-candidates)
- [Minor Improvements](#minor-improvements)
- [Considered And Rejected](#considered-and-rejected)


## Confirmed Bug
1. [x] Resolved: `check_fast.ps1` now parses `LsTweeks.toc` for `.lua` entries excluding `libs/`, so `modules/settings/st_gui.lua`, `modules/player_frame/pf_defaults.lua`, and `modules/player_frame/pf_gui.lua` are covered by the Lua syntax check and future loaded addon Lua files cannot be silently skipped.


## Token Savers
1. Single-source the LuaLS check config; three copies exist today. The config with its 18-entry globals list lives in the here-string at `run_luals_ketho.ps1:119-179`, duplicated in full at `tools_notes.md:250-310`, plus the generated file. Every agent read of tools_notes.md pays roughly 1.5K tokens for the embedded copy, and adding a global requires editing two sources. Fix: check in a `check-config-template.lua` with `<CORE>`/`<FRAMEXML>` placeholders that the script fills at run time; replace the tools_notes.md copy with a one-line pointer to the template. Removes the drift risk and shrinks a frequently-routed doc by about a third.

2. One-step markdown section reader. Reading a named `##` section of a memory file is currently two steps: `rg -n "^##" <file>` then a Read with offset/limit and manual line math. A `doc_section.ps1 <file> <heading>` that prints only that section makes it one step and removes offset mistakes. Modest saving per use but it is the most repeated read pattern in the workflow; `modules/aura_frames.md` alone is 21.6 KB (~6K tokens) if read whole.


## New Tool Candidates
1. `api_lookup.ps1 <ApiName>`: local WoW API verification against the Ketho annotations. The audit-verification and deprecated-API rules require confirming signatures and return types before use, which agents currently do via exploratory reads of other addons or web lookups. Verified live: `rg "function C_Spell.GetSpellInfo"` against `%USERPROFILE%\.vscode\extensions\ketho.wow-api-*\Annotations` returns the annotation location instantly (`Annotations\Core\Blizzard_APIDocumentationGenerated\SpellDocumentation.lua:138`). The script should locate the newest ketho extension dir (same discovery logic as `run_luals_ketho.ps1:22-25`), rg for the API name, and print the annotation block including the `---@param`/`---@return` lines above the match. Turns API verification into one cheap command with ~10 lines of output. Biggest quality-per-effort win in this review.
2. Richer source outlines. Extend `check_regions.ps1 -Outline` to also list top-level `local function` / `function` names with line numbers inside each region. Agents could then jump straight to a targeted 30-line Read instead of reading a whole region. Current fallback `rg -n "^--#region|^-- [A-Za-z].*"` in code_map.md `## Read-In Shortcuts` does not capture function names.


## Minor Improvements
1. `-Changed` mode for check_fast.ps1: run luac only on changed Lua files during iteration, mirroring `run_luals_ketho.ps1 -Changed` (its `Get-ChangedLuaFiles` at lines 66-80 is reusable). Minor since luac is fast; also shortens output.
2. check_fast.ps1 spawns a child `pwsh.exe` for the region check (`check_fast.ps1:135-137`); running it in-process or dot-sourcing saves about one second of shell startup per validation run. Time, not tokens.


## Considered And Rejected
1. Splitting memory files for token savings: forbidden by `agent_start.md` `## Documentation Rules`; section-targeted reads solve it better.
2. Caching LuaLS results between runs: complexity outweighs the gain given `-Changed` and `-Files` targeted modes already exist.
3. Further trimming agent_start.md / code_map.md: both are already dense; the small overlap between them serves routing, and code_map.md is 10 KB with high routing value per line.
