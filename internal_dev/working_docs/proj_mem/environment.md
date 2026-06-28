# Environment Notes

## PowerShell/.NET Compatibility

- `internal_dev/tests_tools/check_regions.ps1` uses `[System.IO.Path]::GetRelativePath`.
- Windows PowerShell on this machine can fail because its loaded .NET runtime does not expose that method.
- `pwsh` runs the same checker successfully:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 -Outline functions
```

- Later fix: update the script with a Windows PowerShell-compatible relative-path fallback so both `powershell` and `pwsh` work.
