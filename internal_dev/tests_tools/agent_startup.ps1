# One-shot coding-agent session baseline: prints agent_start.md, the active
# compatibility sentinel, offline API-reference status, worktree status, and
# code_map Read-In Shortcuts.
# Read-only; never writes files.

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$projMem = Join-Path $repoRoot "internal_dev\working_docs\proj_mem"

Write-Output "===== agent_start.md ====="
Write-Output ([System.IO.File]::ReadAllText((Join-Path $projMem "agent_start.md")))

Write-Output "===== project.md Active Compatibility Sentinel ====="
& (Join-Path $PSScriptRoot "doc_section.ps1") (Join-Path $projMem "project.md") "Active Compatibility Sentinel"

Write-Output "===== WoW API reference status ====="
& (Join-Path $PSScriptRoot "sync_wow_api_reference.ps1") -Channel live -StatusOnly -CompactStatus

Write-Output "===== git status --short ====="
$status = git -C $repoRoot status --short
if ($LASTEXITCODE -ne 0) {
    throw "git status --short failed with exit code $LASTEXITCODE."
}
if ($status) { Write-Output $status } else { Write-Output "(clean)" }
Write-Output ""

Write-Output "===== code_map.md Read-In Shortcuts ====="
& (Join-Path $PSScriptRoot "doc_section.ps1") (Join-Path $projMem "code_map.md") "Read-In Shortcuts"
