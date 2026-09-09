# Tools Notes
Date: 2026-06-02

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

Observed working tools:

```text
cmd         -> ver                  -> Microsoft Windows 10.0.26200.8457
pwsh.exe    -> $PSVersionTable...   -> PowerShell 7.6.2
powershell  -> $PSVersionTable...   -> PowerShell 7.6.2 in Codex shell mapping; `Get-Command powershell` may still resolve to legacy Windows PowerShell
.venv       -> Python 3.13.7, pip 25.2
```


## Codex Shell Fix
Codex native shell execution on this machine requires:

```toml
[windows]
sandbox = "unelevated"
```

Global config:

```text
%USERPROFILE%\.codex\config.toml
```

Use the Codex "setup sandbox" button only when intentionally retesting sandbox setup. It has repeatedly restored:

```toml
[windows]
sandbox = "elevated"
```

That broken mode failed before commands could start:

```text
windows sandbox failed: spawn setup refresh
Failed to create unified exec process: spawn setup refresh
```

Check the active setting:

```powershell
Select-String -Path "$env:USERPROFILE\.codex\config.toml" -Pattern '^\[windows\]|^sandbox\s*=|sandbox|windows'
```

Expected output:

```text
[windows]
sandbox = "unelevated"
```

If the config reverts to `elevated`, repair it from the helper workspace:

```text
<local helper workspace>\agent_config
```

```cmd
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File repair_codex_config.ps1
```

The script backs up `%USERPROFILE%\.codex\config.toml`, removes any existing `[windows]` block, and appends the working `sandbox = "unelevated"` block.


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

The current `LsTweeks` path should be present. The old `Ls_Tweeks` path should not be embedded.

If activation reports the wrong `$env:VIRTUAL_ENV`, check:

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
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_regions.ps1 -Outline modules\aura_frames\af_render.lua
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
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1 -Files modules\audio_volumes\av_gui_situations.lua
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

The updater fails rather than replacing a non-Git directory, changing branches, accepting an unexpected remote, overwriting source or Numy cache edits, accepting unexpected Ketho generator edits, resolving a non-fast-forward update, or accepting a source interface absent from `LsTweeks.toc`. `-AllowInterfaceMismatch` is only for intentional future-channel research. Startup prints a compact offline source/annotation summary. If network refresh is unavailable, use `-StatusOnly` and report cached commits instead of describing them as current. Run the focused source-updater regression test after updater changes; it uses isolated local Git repositories and skips the online annotation stage.

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
