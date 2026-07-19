# One-shot coding-agent session baseline: prints agent_start.md, worktree status,
# and the code_map Read-In Shortcuts section in one call.
# Read-only; never writes files.

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$projMem = Join-Path $repoRoot "internal_dev\working_docs\proj_mem"

Write-Output "===== agent_start.md ====="
Write-Output ([System.IO.File]::ReadAllText((Join-Path $projMem "agent_start.md")))

Write-Output "===== git status --short ====="
$status = git -C $repoRoot status --short
if ($LASTEXITCODE -ne 0) {
    throw "git status --short failed with exit code $LASTEXITCODE."
}
if ($status) { Write-Output $status } else { Write-Output "(clean)" }
Write-Output ""

Write-Output "===== code_map.md Read-In Shortcuts ====="
& (Join-Path $PSScriptRoot "doc_section.ps1") (Join-Path $projMem "code_map.md") "Read-In Shortcuts"
