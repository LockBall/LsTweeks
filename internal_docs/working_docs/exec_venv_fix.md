# Exec/Venv Fix Notes

Date: 2026-05-30

## Problem

Codex and direct shell commands could run `.venv\Scripts\python.exe`, but generated console entry points such as `.venv\Scripts\pip.exe` failed with exit code 1 and no output.

There was also an earlier transient Codex exec-launch failure while running `rg --files`:

```text
CreateProcessWithLogonW failed: 1056
```

`rg` itself was later verified as installed and working, so the reproducible project issue was the venv entry-point failure.

## Root Cause

The repository folder is:

```text
G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks
```

But `.venv\pyvenv.cfg` and the `pip*.exe` launchers had been created when the folder path was:

```text
G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\Ls_Tweeks
```

The Python executable in the venv still worked, but the generated console launcher shebangs embedded the old absolute path, so wrappers like `pip.exe` tried to launch a non-existent interpreter.

## Fix Applied

Refresh venv metadata:

```powershell
C:\Python313\python.exe -m venv --upgrade .venv
```

Regenerate pip console launchers from the bundled pip wheel, without network access:

```powershell
.\.venv\Scripts\python.exe -m pip install --force-reinstall --no-index --find-links C:\Python313\Lib\ensurepip\_bundled pip==25.2
```

## Verification

These commands now pass:

```powershell
.\.venv\Scripts\pip.exe --version
.\.venv\Scripts\pip.exe list
rg -a "Ls_Tweeks|LsTweeks" .venv\Scripts\pip.exe .venv\Scripts\pip3.exe .venv\Scripts\pip3.13.exe
```

The `pip*.exe` launchers now embed the current `LsTweeks` path.

Addon validation also passes:

```powershell
luac -p modules/player_frame.lua
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\package.ps1
```

