param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Position = 1)]
    [string]$Heading,

    [switch]$List
)

$ErrorActionPreference = "Stop"

function Normalize-Heading {
    param([string]$Value)

    return ($Value -replace "^\s*#+\s*", "").Trim()
}

function Get-MarkdownHeadings {
    param([string[]]$Lines)

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^(#{1,6})\s+(.+?)\s*$") {
            [pscustomobject]@{
                Line = $i
                Number = $i + 1
                Level = $matches[1].Length
                Text = $matches[2].Trim()
            }
        }
    }
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$lines = [System.IO.File]::ReadAllLines($resolvedPath)
$headings = @(Get-MarkdownHeadings $lines)

if ($List) {
    foreach ($entry in $headings) {
        if ($entry.Level -eq 2) {
            "{0}: {1}" -f $entry.Number, $entry.Text
        }
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Heading)) {
    throw "Provide a heading to print, or use -List to list ## headings."
}

$targetHeading = Normalize-Heading $Heading
$matches = @($headings | Where-Object { ($_.Level -eq 2 -or $_.Level -eq 3) -and $_.Text -eq $targetHeading })

if ($matches.Count -eq 0) {
    throw "No ## or ### heading named '$targetHeading' found in $Path. Use -List to inspect available ## headings."
}

if ($matches.Count -gt 1) {
    throw "Multiple headings named '$targetHeading' found in $Path."
}

$targetLevel = $matches[0].Level
$start = $matches[0].Line
$end = $lines.Count

for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^(#{1,6})\s+") {
        $lineLevel = ($lines[$i] -replace "^(#{1,6}).*", '$1').Length
        if ($lineLevel -le $targetLevel) {
            $end = $i
            break
        }
    }
}

for ($i = $start; $i -lt $end; $i++) {
    $lines[$i]
}
