# Environment Tools Recovery Notes

Date: 2026-06-02

Durable notes for fixing Codex shell execution and the local Python venv in this repo.

## Known Good State

Repo path:

```text
G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks
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
C:\Users\D00D\.codex\config.toml
```

Do not use the Codex "setup sandbox" button unless intentionally retesting sandbox setup. It has repeatedly restored:

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
F:\from_git\agent_config
```

```cmd
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File repair_codex_config.ps1
```

The script backs up `C:\Users\D00D\.codex\config.toml`, removes any existing `[windows]` block, and appends the working `sandbox = "unelevated"` block.

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
G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\.venv
```

Known stale old path:

```text
G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\Ls_Tweeks
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
luac -p modules/player_frame/pf_main.lua modules/player_frame/pf_fade.lua
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File tools\package.ps1
```

Expected package result:

```text
Package verification passed.
```
