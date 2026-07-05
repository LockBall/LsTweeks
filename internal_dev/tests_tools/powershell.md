# PowerShell Tool Notes
PowerShell notes for repo-local scripts, validation helpers, and coding-agent shell work.


## Table of Contents
- [File Writes And Newlines](#file-writes-and-newlines)
- [Region Helper](#region-helper)
- [Compatibility](#compatibility)
- [Validation Commands](#validation-commands)


## File Writes And Newlines
- Line-ending rule: project-owned Lua/docs/tools use LF. Vendored libraries under `libs/` keep upstream line endings. `.gitattributes` and `.editorconfig` enforce this; do not infer policy from local Git settings.
- Prefer `apply_patch` for manual source/doc edits.
- Use `Set-Content` or command-output capture for source rewrites only after newline behavior is explicitly tested. In this repo, PowerShell command-output arrays, implicit stringification, and careless joins have caused Lua files to collapse into one physical line during generated rewrites.
- For any future PowerShell script that must write text files, keep newline handling explicit with ``"`n"`` and verify with both `(Get-Content -LiteralPath <file>).Count` and `git diff --check`.
- Read-only scripts should use `[System.IO.File]::ReadAllLines()` or `[System.IO.File]::ReadAllText()` and should not rewrite files as a side effect.
- If a mechanical rewrite creates a huge diff, inspect `git diff --ignore-space-at-eol --stat` before continuing. If the meaningful diff is small but normal diff is large, the rewrite likely changed line endings.


## Region Helper
- Region validation and source outlines live in `check_regions.ps1`.
- Validate all non-vendored Lua files:
  ```powershell
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1
  ```
- Print live region line ranges and named function declarations for targeted source read-in:
  ```powershell
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_regions.ps1 -Outline modules/aura_frames/af_render.lua
  ```
- Treat the live outline as the source-file TOC. Add manual Lua TOCs only if a generated/validated TOC workflow is introduced.


## Compatibility
- Use `pwsh.exe` for project validation and helper scripts unless a command explicitly needs another shell.
- `check_regions.ps1` currently uses `[System.IO.Path]::GetRelativePath`. Windows PowerShell can fail on this machine when its loaded .NET runtime does not expose that method.
- If Windows PowerShell compatibility becomes required, add a relative-path fallback to `check_regions.ps1` and verify both `powershell.exe` and `pwsh.exe`.


## Validation Commands
- Routine fast check:
  ```powershell
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1
  ```
- The fast check runs Lua syntax, Lua region validation, and `git diff --check`.
