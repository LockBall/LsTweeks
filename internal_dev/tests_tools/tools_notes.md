# Tools Notes
Last shell review: 2026-10-30

Durable notes for fixing Codex shell execution, local tool checks, Ketho/LuaLS diagnostics, and the local Python venv in this repo.


## Table of Contents
- [Known Good State](#known-good-state)
- [Codex Shell Fix](#codex-shell-fix)
- [Shell Verification](#shell-verification)
- [Project Venv Check](#project-venv-check)
- [Project Venv Repair](#project-venv-repair)
- [Project Validation](#project-validation)
- [Lua Error Condenser](#lua-error-condenser)
- [LuaLS / Ketho Shell Diagnostics](#luals-ketho-shell-diagnostics)


## Known Good State
Repo path:

```text
<repo root>
```

Historical tool observations (2026-06-02; not current version requirements):

```text
cmd         -> ver                  -> Microsoft Windows 10.0.26200.8457
pwsh.exe    -> $PSVersionTable...   -> PowerShell 7.6.2
powershell  -> $PSVersionTable...   -> PowerShell 7.6.2 in Codex shell mapping; `Get-Command powershell` may still resolve to legacy Windows PowerShell
.venv       -> Python 3.13.7, pip 25.2
```


## Codex Shell Fix
The 2026-10-30 review supersedes the June workaround that prescribed `unelevated`. The current verified local selection is:

```toml
[windows]
sandbox = "elevated"

[features]
prefer_mxc = false
```

Global config:

```text
%USERPROFILE%\.codex\config.toml
```

Evidence: the active VS Code extension uses Codex CLI `0.164.0-alpha.11.1`. Under `unelevated`, Git metadata worked but Git for Windows 2.51.2/MSYS 3.6.5 shell startup failed with a signal-pipe access denial. A .NET named-pipe server could be created but its same-process client was denied connection; the approved-context control succeeded. The official one-command MXC startup probe passed, but the actual MSYS shell still failed creating its named-object directory. Basic sandbox startup therefore did not establish tool compatibility.

The already-provisioned legacy `elevated` sandbox passed the same Git shell probe and both repositories' local-origin updater suites (7/7 each), using managed workspace permissions. These tests ran sandboxed, not unrestricted. A fresh Codex process then passed the shell probe using the saved configuration with no selection overrides. After the VS Code window reload, ordinary agent execution also passed the direct Git shell probe and both updater suites (7/7 each). Live-session acceptance is complete for these previously failing workloads.

The user config was backed up beside itself as `config.toml.before-sandbox-repair-20261030T103918`. Only the sandbox selection and MXC preference were changed; no global ACL, proxy, Git installation, or full-access setting was changed. The June `spawn setup refresh` failure is historical evidence, not a current prohibition on `elevated`. Do not rerun the old `repair_codex_config.ps1` helper that forces `unelevated` without reviewing/updating it.

This is a machine/tool-version-specific verified selection, not a universal sandbox requirement. Current [official Windows sandbox guidance](https://learn.chatgpt.com/docs/windows/windows-sandbox) prefers MXC when compatible, then legacy `elevated`; commands in legacy `elevated` use lower-privilege sandbox accounts rather than administrator execution. Re-evaluate after host/tool updates using the actual failing workload, not only a version command.

Saved-config diagnostic (uses the configured selection, not a per-command sandbox override):

```powershell
codex sandbox --include-managed-config --permission-profile :workspace -- "C:\Program Files\Git\usr\bin\sh.exe" -c "exit 0"
```


## Shell Verification
In a fresh Codex session or after restarting VS Code, verify native shell access directly:

```text
shell: cmd         command: ver
shell: pwsh.exe    command: $PSVersionTable.PSVersion
shell: powershell  command: $PSVersionTable.PSVersion  # compatibility check only
```

Default to `pwsh.exe` for project work unless there is an explicit reason to use another shell. `powershell.exe` is legacy Windows PowerShell on a normal Windows PATH, even when the Codex `shell: powershell` mapping currently reports PowerShell 7. PowerShell launched through `cmd` is only a workaround. The intended fixed state is direct native execution for all required shells.

If shell execution still fails after the config is correct:

1. Confirm VS Code is not running as administrator.
2. Confirm no VS Code or Codex `RUNASADMIN` AppCompat entry.
3. Restart the Codex session or VS Code extension host.
4. Re-check native shell access.

AppCompat check:

```powershell
$layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$props = Get-ItemProperty -Path $layersPath -ErrorAction SilentlyContinue
$props.PSObject.Properties | Where-Object {
    $_.Name -like '*Code.exe*' -or
    $_.Name -like '*codex*' -or
    $_.Value -like '*RUNASADMIN*'
}
```

If standalone `codex sandbox ...` works but native Codex shell execution still fails, the active VS Code/Codex tool host is probably holding stale spawn state. Restart the Codex session or VS Code extension host instead of continuing to probe through nested shells.


## Project Venv Check
From the repo root:

```powershell
. .\.venv\Scripts\Activate.ps1
Get-Command python | Select-Object -ExpandProperty Source
python --version
Get-Command pip | Select-Object -ExpandProperty Source
pip --version
$env:VIRTUAL_ENV
```

Expected paths point at:

```text
<repo root>\.venv
```

Known stale old path:

```text
<old repo root>\Ls_Tweeks
```

The old failure was caused by `.venv` metadata and generated `pip*.exe` launchers embedding the renamed `Ls_Tweeks` path. `python.exe` still worked, but `pip.exe` tried to launch an interpreter at the old path and failed.


## Project Venv Repair
Refresh venv metadata:

```powershell
C:\Python313\python.exe -m venv --upgrade .venv
```

Regenerate pip launchers from the bundled pip wheel, without network access:

```powershell
.\.venv\Scripts\python.exe -m pip install --force-reinstall --no-index --find-links C:\Python313\Lib\ensurepip\_bundled pip==25.2
```

Verify:

```powershell
.\.venv\Scripts\pip.exe --version
.\.venv\Scripts\pip.exe list
rg -a "Ls_Tweeks|LsTweeks" .venv\Scripts\pip.exe .venv\Scripts\pip3.exe .venv\Scripts\pip3.13.exe
```

The current outer workspace path ending in `dev_LsTweeks\.venv` should be embedded; former game-install and workspace paths should not be embedded.

A metadata upgrade alone may leave activation scripts and non-pip console launchers stale. After a workspace move, verify the selected environment Python, every installed console launcher actually used by tools, and activation separately. Use python -m pip for reliable package access while diagnosing launcher failures.

The migration audit repaired activation using the selected base interpreter's venv.EnvBuilder.setup_scripts and rebuilt the existing pip/fontTools entry points from installed metadata using the bundled ScriptMaker. This was an offline local-environment repair, not an addon dependency or a package upgrade. Package names/versions stayed unchanged; all seven console launchers passed invocation checks. pyftmerge has no --help option: its normal no-argument usage response is the suitable startup probe.

Before such a repair, preserve launcher/activation files and installed package versions; prefer recreating a disposable environment from reviewed dependency declarations when available. After verification, remove repair backups and successful scratch logs unless they still have a specific recovery/debugging purpose. The completed audit is recorded in the existing migration/security review notes; no separate summary file or raw repair backup is retained.

If activation reports the wrong $env:VIRTUAL_ENV, check:

```text
.venv\Scripts\Activate.ps1
.venv\Scripts\activate.bat
.venv\Scripts\activate
.venv\Scripts\activate.fish
```


## Project Validation
After shell and venv checks pass, validate the addon:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_fast.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_fast.ps1 -Changed
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_fast.ps1 -Package
```

The first command runs Lua 5.1 syntax checks for addon-owned Lua files loaded by `LsTweeks.toc` excluding `libs/`, Lua region validation, internal helper/table ownership checks, and staged plus unstaged whitespace checks. The ownership check rejects defensive addon-table initialization, repeated initialization of stable module tables, probing of TOC-guaranteed addon helpers, fallbacks around canonical constant/schema tables, and optional-method checks on addon-created controls. Its allowlists are limited to lazily installed settings callbacks, optional tooltip diagnostics, and runtime tables whose nil state has lifecycle meaning. Before extending an allowlist, classify and document the durable exception under `project.md` `### Deterministic Ownership And Optionality`; an isolated-test failure is not an exception. The `-Changed` form narrows only the Lua syntax step to changed Lua files; region validation, ownership checks, whitespace diff, and line-ending checks still run normally. The `-Package` form also builds and verifies the release zip.

Lua region helper:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_regions.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_regions.ps1 -Outline LsTweeks/modules\aura_frames\af_render.lua
```

The `-Outline` form prints region ranges plus named function declarations inside each region.

Markdown section helper:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\doc_section.ps1 internal_dev\working_docs\proj_mem\modules\aura_frames.md "Runtime Gates And Refresh"
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\doc_section.ps1 internal_dev\working_docs\proj_mem\modules\aura_frames.md -List
```

PowerShell newline/write rules live in `internal_dev/tests_tools/powershell.md`.

Expected package result includes:

```text
Fast checks passed.
Package verification passed.
```


## Lua Error Condenser
Archive a WoW Lua error inbox with its agent-readable condensed report, then clear the inbox only after both files exist:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/archive_lua_error_batch.ps1 -Path internal_dev/working_docs/ToDo/new_issue.txt -Label <short-label> -ClearInbox
```

The archived report groups normalized messages, sums reported counts, extracts common stack prefixes, retains distinct caller tails, and surfaces message origin, explicit taint attribution, and addons present in captured stacks. Use `condense_lua_errors.ps1` directly only for a temporary alternate output or structured JSON; do not leave a generated `new_issue_condensed.md` beside the inbox.

Focused tool regression:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/test_condense_lua_errors.ps1
```


## LuaLS / Ketho Shell Diagnostics
The LuaLS CLI may not be on `PATH`. On this machine the working binary is installed by the Sumneko VS Code extension:

```text
%USERPROFILE%\.vscode\extensions\sumneko.lua-<version>-win32-x64\server\bin\lua-language-server.exe
```

Check tool locations:

```powershell
Get-Command lua-language-server, lua-language-server.exe -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions" -Directory | Where-Object { $_.Name -match 'lua|sumneko' }
Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'lua-language-server(\.exe)?$' } | Select-Object -First 10 FullName
```

Do not rely on LuaLS automatically loading `.vscode/settings.json` during `--check`. Use the helper's explicit config containing the generated Core and FrameXML receipt paths.

Preferred helper script:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1
```

The script finds the local Sumneko LuaLS binary, requires the repo-managed live annotation receipt, generates the ignored config file below, and writes logs/meta under `internal_dev/tests_tools/lua_checks/.lua-language-server/`. LuaLS reads Ketho Core for generated API types and Numy for supplemental mixin/template annotations; Gethe remains the source authority used by lookup and review rather than a second large LuaLS input. It has no dependency on the Ketho VS Code extension.

Targeted helper modes:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1 -Changed
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1 -Files LsTweeks/modules\audio_volumes\av_gui_situations.lua
```

Use `-Files` for exact one-off file checks. Use `-Changed` for iteration after a work pass; if multiple changed Lua files share a module directory, the helper checks that directory once to avoid repeated LuaLS startup cost. Use the full helper before commit-level validation, after load-order changes, or after broad refactors because targeted runs do not replace whole-workspace diagnostics.

Current-source-first API lookup:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\api_lookup.ps1 C_Spell.GetSpellInfo
```

The lookup reports the refreshed channel source version/commit, searches current generated docs and FrameXML first, then prints an exact function block from the generated Core or FrameXML annotations. Source remains the code authority; annotations provide a compact typed view.

Patch-sensitive API reference refresh:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\sync_wow_api_reference.ps1 -Channel live
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\sync_wow_api_reference.ps1 -Channel live -StatusOnly
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\test_sync_wow_api_reference.ps1
```

Run the refresh once per session/channel before the first patch-sensitive API task, retain its reported commits in session context, and reuse that snapshot for later work in the same session. Rerun only when the channel/target changes, the first refresh failed, or evidence indicates upstream moved. One command updates the Gethe source, Ketho generator, and Numy FrameXML annotation checkouts, resolves the current BlizzardInterfaceResources commit, and regenerates only when an input commit changed. It records the source, generator, resource, and FrameXML commits independently; never compare a VS Code extension package version with a WoW build version.

After a successful refresh, keep API investigation local. Prefer `api_lookup.ps1` for the declaration-plus-annotation view and focused `rg` searches in the cached `Interface` tree for implementation and call sites. Do not repeatedly browse the hosted repositories, query their refs, or rerun the refresh during the same task unless the channel changes or local evidence demonstrates that the receipt is stale or incomplete. Keep tool output focused so large generated trees do not consume working context.

The cache stores each necessary dataset once: one Gethe source checkout, one sparse Ketho generator/Core checkout, and Numy's annotations-only checkout per channel. Generation reuses the Gethe checkout through a managed junction, and lookup searches that same checkout directly; LuaLS consumes only the smaller generated annotation roots. The refresh downloads only `LuaEnum.lua` and `CVars.lua` from BlizzardInterfaceResources at the recorded commit, and clears generator scratch output after use. It skips Ketho's extension packaging, TypeScript, editor/image assets, locale assets, wiki refresh, duplicate Gethe clone/pull, Numy's source-mixed branch, and a full BlizzardInterfaceResources clone. Generated and upstream cache files are disposable and must never be hand-edited.

Expose a refresh channel only when every required upstream publishes that channel. The managed pipeline currently supports `live` and `ptr`; BlizzardInterfaceResources does not publish `beta`, so there is deliberately no beta fallback to another channel's resource data.

One-time WSL setup:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\setup_wow_annotations_wsl.ps1
```

The setup installs WSL compiler/SSL prerequisites and a self-contained, version-pinned Lua 5.4/LuaRocks toolchain under `~/.local/share/lstweeks-ketho/.lua`. Its temporary Python/hererocks build environment is removed when setup finishes, and normal refreshes do not reinstall it. The Ketho Marketplace extension is optional editor UI and is not used by lookup, generation, or validation.

Search the matching source checkout for current declarations and implementation:

```powershell
rg -n "C_UnitAuras|AuraContainer" internal_dev\tests_tools\.wow-api-source\live\Interface
```

The updater fails rather than replacing a non-Git directory, changing branches, accepting an unexpected remote, overwriting source or Numy cache edits, accepting unexpected Ketho generator edits, resolving a non-fast-forward update, or accepting a source interface absent from `LsTweeks.toc`. `-AllowInterfaceMismatch` is only for an explicitly requested newer-patch compatibility review or deliberate future-channel research after confirming the reported channel/build is the intended target. When the mismatch is already established, use the flag on the planned refresh instead of repeating the expected stop; never make it a startup default. Do not bump the TOC merely to unblock reference preparation: review source/API compatibility first, then declare the interface and distinguish automated validation from pending in-game acceptance. Source can advance before a mismatch stop while the receipt/annotations remain old; complete refresh/generation and verify matching provenance before using LuaLS. The override leaves origin, branch, dirty-cache, and annotation checks intact.

Startup prints a compact offline source/annotation summary. If network refresh is unavailable, use `-StatusOnly` and report cached commits instead of describing them as current. Run the focused source-updater regression test after updater changes; it uses isolated local Git repositories and skips the online annotation stage.

Working local config path:

```text
internal_dev\tests_tools\lua_checks\.lua-language-server\check-config.lua
```

That folder is ignored by git. If the generated file is missing or stale, rerun the reference refresh; the helper renders `internal_dev/tests_tools/lua_checks/kethos/check-config-template.lua` with receipt-owned annotation paths.

Manual diagnostics command from the repo root:

```powershell
& "$env:USERPROFILE\.vscode\extensions\sumneko.lua-3.18.2-win32-x64\server\bin\lua-language-server.exe" --check="$PWD" --configpath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\check-config.lua" --check_format=pretty --checklevel=Warning --logpath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\log" --metapath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\meta"
```

Expected Audio Volumes behavior as of 2026-07-03: verified `C_Sound.PlaySound(soundKitID, "SFX")` string-channel call sites use narrow inline `---@diagnostic disable-next-line: param-type-mismatch` suppressions. If similar warnings reappear, check `audio_volumes.md` `## Ketho / LuaLS` before changing the playback path.
