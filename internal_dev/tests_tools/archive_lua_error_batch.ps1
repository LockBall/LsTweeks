<#
.SYNOPSIS
Archives one raw WoW Lua error inbox and writes its condensed report.

.DESCRIPTION
Copies the current inbox into a timestamped batch directory under
`working_docs/reference/error_batches/unreviewed/`, creates `condensed.md` with
`condense_lua_errors.ps1`, and optionally resets the inbox only after both
archive files exist. After assessment, move the batch to the `resolved` or
`monitoring` directory and update the archive index. Use `-ArchiveRoot` to
override the archive root.

.EXAMPLE
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/archive_lua_error_batch.ps1 -Path internal_dev/working_docs/ToDo/new_issue.txt -Label tooltip-taint -ClearInbox
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Path,

    [string] $Label = "batch",

    [string] $ArchiveRoot,

    [switch] $ClearInbox
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$inboxText = [System.IO.File]::ReadAllText($resolvedPath)
if ([string]::IsNullOrWhiteSpace($inboxText)) {
    throw "Error inbox is empty: $resolvedPath"
}

$safeLabel = ($Label -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
if (-not $safeLabel) { $safeLabel = "batch" }
if ($ArchiveRoot) {
    $archiveRoot = [System.IO.Path]::GetFullPath($ArchiveRoot)
} else {
    $archiveRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "working_docs/reference/error_batches"
}
$batchRoot = Join-Path $archiveRoot "unreviewed"
New-Item -ItemType Directory -Path $batchRoot -Force -ErrorAction Stop | Out-Null
$existingRaw = Get-ChildItem -LiteralPath $archiveRoot -Filter "raw.txt" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { [System.IO.File]::ReadAllText($_.FullName) -ceq $inboxText } |
    Select-Object -First 1
if ($existingRaw) {
    $existingReport = Join-Path $existingRaw.DirectoryName "condensed.md"
    if (Test-Path -LiteralPath $existingReport) {
        if ($ClearInbox) {
            $inboxNotice = "# Error Inbox`n`nPaste the next unprocessed WoW Lua error export here.`n"
            [System.IO.File]::WriteAllText($resolvedPath, $inboxNotice, [System.Text.UTF8Encoding]::new($false))
            Write-Output "Reset inbox: $resolvedPath"
        }
        Write-Output "Existing raw export: $($existingRaw.FullName)"
        Write-Output "Existing condensed report: $existingReport"
        return
    }
}
$batchName = "{0}_{1}" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $safeLabel
$batchPath = Join-Path $batchRoot $batchName
New-Item -ItemType Directory -Path $batchPath -ErrorAction Stop | Out-Null

$rawPath = Join-Path $batchPath "raw.txt"
$reportPath = Join-Path $batchPath "condensed.md"
[System.IO.File]::WriteAllText($rawPath, $inboxText, [System.Text.UTF8Encoding]::new($false))

& (Join-Path $PSScriptRoot "condense_lua_errors.ps1") -Path $rawPath -OutputPath $reportPath -SourceLabel "raw.txt"
if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Condensed report was not created; inbox was left unchanged."
}

if ($ClearInbox) {
    $inboxNotice = "# Error Inbox`n`nPaste the next unprocessed WoW Lua error export here.`n"
    [System.IO.File]::WriteAllText($resolvedPath, $inboxNotice, [System.Text.UTF8Encoding]::new($false))
}

Write-Output "Archived raw export: $rawPath"
Write-Output "Condensed report: $reportPath"
if ($ClearInbox) { Write-Output "Reset inbox: $resolvedPath" }
