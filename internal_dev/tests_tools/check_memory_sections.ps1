# Flags proj_mem markdown ## / ### sections that exceed a line-count budget, so oversized
# sections get caught mechanically instead of relying on periodic manual review.
param(
    [int]$MaxLines = 40
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$memRoot = Join-Path $repoRoot "internal_dev/working_docs/proj_mem"

function Get-RelativePath {
    param([string]$FullName)

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $FullName)
    return ($relative -replace "\\", "/")
}

function Get-Sections {
    param([string[]]$Lines)

    $headings = for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^(#{2,3})\s+(.+?)\s*$") {
            [pscustomobject]@{
                Line = $i
                Level = $Matches[1].Length
                Text = $Matches[2].Trim()
            }
        }
    }

    for ($h = 0; $h -lt $headings.Count; $h++) {
        $current = $headings[$h]
        # For a ## heading, measure only its own content up to the first ### child (or the
        # next ## if it has none) so a wrapper heading is not penalized for its children's
        # combined size; ### headings still measure their full span like before.
        $stopLevel = if ($current.Level -eq 2) { 3 } else { $current.Level }
        $end = $Lines.Count
        for ($j = $h + 1; $j -lt $headings.Count; $j++) {
            if ($headings[$j].Level -le $stopLevel) {
                $end = $headings[$j].Line
                break
            }
        }
        [pscustomobject]@{
            Level = $current.Level
            Text = $current.Text
            StartLine = $current.Line + 1
            LineCount = $end - $current.Line - 1
        }
    }
}

$failed = $false

Get-ChildItem -LiteralPath $memRoot -Recurse -File -Filter "*.md" | Sort-Object FullName | ForEach-Object {
    $relative = Get-RelativePath $_.FullName
    $lines = [System.IO.File]::ReadAllLines($_.FullName)
    foreach ($section in (Get-Sections $lines)) {
        if ($section.LineCount -gt $MaxLines) {
            $failed = $true
            $marker = "#" * $section.Level
            Write-Error "${relative}:$($section.StartLine): '$marker $($section.Text)' is $($section.LineCount) lines (budget $MaxLines)" -ErrorAction Continue
        }
    }
}

if ($failed) {
    throw "Memory section size check failed. Split oversized sections into narrower headings so targeted reads stay small."
}

Write-Host "Memory section size checks passed."
