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
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_fast.ps1 -Package
```

The first command runs Lua 5.1 syntax checks for addon-owned Lua files loaded by `LsTweeks.toc` excluding `libs/`, Lua region validation, and `git diff --check`. The `-Package` form also builds and verifies the release zip.

Lua region helper:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_regions.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\check_regions.ps1 -Outline modules\aura_frames\af_render.lua
```

PowerShell newline/write rules live in `internal_dev/tests_tools/powershell.md`.

Expected package result includes:

```text
Fast checks passed.
Package verification passed.
```


## LuaLS / Ketho Shell Diagnostics
The LuaLS CLI may not be on `PATH`. On this machine the working binary is installed by the Sumneko VS Code extension:

```text
%USERPROFILE%\.vscode\extensions\sumneko.lua-3.18.2-win32-x64\server\bin\lua-language-server.exe
```

Check tool locations:

```powershell
Get-Command lua-language-server, lua-language-server.exe -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions" -Directory | Where-Object { $_.Name -match 'lua|sumneko|ketho|wow-api' }
Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'lua-language-server(\.exe)?$' } | Select-Object -First 10 FullName
```

Do not rely on LuaLS automatically loading `.vscode/settings.json` during `--check`. A plain `--check` run ignored the Ketho libraries and produced hundreds of false undefined-global warnings. Use an explicit config file with absolute Ketho library paths.

Preferred helper script:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1
```

The script finds the local Sumneko LuaLS binary and Ketho extension, generates the ignored config file below, and writes logs/meta under `internal_dev/tests_tools/lua_checks/.lua-language-server/`.

Targeted helper modes:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1 -Changed
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev\tests_tools\lua_checks\kethos\run_luals_ketho.ps1 -Files modules\audio_volumes\av_gui_situations.lua
```

Use `-Files` for exact one-off file checks. Use `-Changed` for iteration after a work pass; if multiple changed Lua files share a module directory, the helper checks that directory once to avoid repeated LuaLS startup cost. Use the full helper before commit-level validation, after load-order changes, or after broad refactors because targeted runs do not replace whole-workspace diagnostics.

Working local config path:

```text
internal_dev\tests_tools\lua_checks\.lua-language-server\check-config.lua
```

That folder is ignored by git. If the file is missing, recreate it from `.vscode/settings.json` with explicit absolute libraries:

```lua
return {
    runtime = {
        version = "Lua 5.1",
        builtin = {
            basic = "disable",
            debug = "disable",
            io = "disable",
            math = "disable",
            os = "disable",
            package = "disable",
            string = "disable",
            table = "disable",
            utf8 = "disable",
        },
    },
    workspace = {
        library = {
            "<USERPROFILE>\\.vscode\\extensions\\ketho.wow-api-0.22.3\\Annotations\\Core",
            "<USERPROFILE>\\.vscode\\extensions\\ketho.wow-api-0.22.3\\Annotations\\FrameXML",
        },
        ignoreDir = {
            ".vscode",
            "libs",
            "internal_dev/tests_tools/lua_checks/.lua-language-server",
            "internal_dev/tests_tools/lua_checks/.luals-check",
            "internal_dev/tests_tools/lua_checks/.luacheck-logs",
            "internal_dev/tests_tools/lua_checks/.luacheck-meta",
        },
    },
    diagnostics = {
        ignoredFiles = "Disable",
        globals = {
            "SlashCmdList",
            "ColorPickerFrame",
            "SOUNDKIT",
            "AddonCompartmentFrame",
            "BuffFrame",
            "DebuffFrame",
            "PanelTemplates_SetNumTabs",
            "PanelTemplates_UpdateTabs",
            "PanelTemplates_TabResize",
            "StaticPopupDialogs",
            "StaticPopup_Show",
            "PanelTemplates_SelectTab",
            "PanelTemplates_DeselectTab",
            "Settings",
            "STANDARD_TEXT_FONT",
            "PlayerFrame",
            "MinimalSliderWithSteppersMixin",
            "CreateMinimalSliderFormatter",
        },
        disable = {
            "assign-type-mismatch",
        },
    },
    type = {
        weakUnionCheck = true,
    },
}
```

Manual diagnostics command from the repo root:

```powershell
& "$env:USERPROFILE\.vscode\extensions\sumneko.lua-3.18.2-win32-x64\server\bin\lua-language-server.exe" --check="$PWD" --configpath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\check-config.lua" --check_format=pretty --checklevel=Warning --logpath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\log" --metapath="$PWD\internal_dev\tests_tools\lua_checks\.lua-language-server\meta"
```

Expected Audio Volumes behavior as of 2026-07-03: verified `C_Sound.PlaySound(soundKitID, "SFX")` string-channel call sites use narrow inline `---@diagnostic disable-next-line: param-type-mismatch` suppressions. If similar warnings reappear, check `audio_volumes.md` `## Ketho / LuaLS` before changing the playback path.
