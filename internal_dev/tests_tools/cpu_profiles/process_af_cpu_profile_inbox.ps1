<#
.SYNOPSIS
Validates and converts one raw Aura Frames CPU profile report to Markdown.

.DESCRIPTION
Reads the dedicated Aura Frames profile inbox, selects the last complete report,
validates its generated metadata and automatic Aura context, and emits a run
section suitable for `af_cpu_profiles.md`. It does not modify the run history.

.EXAMPLE
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/cpu_profiles/process_af_cpu_profile_inbox.ps1
#>

[CmdletBinding()]
param(
    [string] $InputPath = "internal_dev/working_docs/ToDo/aura_frames_profile_results.txt",
    [string] $OutputPath = "",
    [string] $Title = "$(Get-Date -Format yyyy-MM-dd), Aura Frames Only, Post-Migration Baseline"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$text = [System.IO.File]::ReadAllText($resolvedInput)
$text = $text.Replace("&#x20;", " ")

$reportMarkers = [regex]::Matches($text, "(?m)^.*== LsTweeks CPU Profile report ==.*$")
if ($reportMarkers.Count -eq 0) {
    throw "No '/lstprofile report' block found in $resolvedInput."
}

$report = $text.Substring($reportMarkers[$reportMarkers.Count - 1].Index)
$stopMarker = [regex]::Match($report, "(?m)^.*== LsTweeks CPU Profile stopped ==.*$")
if ($stopMarker.Success) {
    $report = $report.Substring(0, $stopMarker.Index)
}

$metadataMatch = [regex]::Match($report, "(?m)^\s*(<!--\s*cpu-profile-run:\s*.*?\s*-->)\s*$")
if (-not $metadataMatch.Success) {
    throw "The report is missing its generated cpu-profile-run metadata line."
}
$metadata = $metadataMatch.Groups[1].Value

$requiredContext = @(
    "aura_specialization",
    "aura_cooldown_modes",
    "aura_test_auras",
    "aura_custom_frames"
)
foreach ($contextName in $requiredContext) {
    if ($report -notmatch "(?m)^\s*$([regex]::Escape($contextName))\b") {
        throw "The report is missing automatic context line '$contextName'. Reload the addon before collecting the baseline."
    }
}
if ($report -notmatch "(?m)^.*LsTweeks module status.*\(aura_frames\).*$") {
    throw "The report is missing automatic Aura Frames module status. Reload the addon before collecting the baseline."
}

$metricPattern = "(?m)^\s*(af\.[A-Za-z0-9_.]+)\s+calls=([0-9]+)\s+total=([0-9.]+)ms\s+avg=([0-9.]+)ms\s+max=([0-9.]+)ms(?:\s+cb_msps=([0-9.]+)\s+cb_callsps=([0-9.]+))?(?:\s+sv_msps=([0-9.]+)\s+sv_callsps=([0-9.]+))?\s*$"
$metricMatches = [regex]::Matches($report, $metricPattern)
if ($metricMatches.Count -eq 0) {
    throw "The report contains no Aura Frames metric rows."
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("### $Title")
$lines.Add($metadata)
$lines.Add("")
$lines.Add("Captured context:")
$lines.Add("")
$lines.Add('```text')

$contextEnd = $metricMatches[0].Index
$contextText = $report.Substring(0, $contextEnd)
foreach ($line in ($contextText -split "\r?\n")) {
    $cleanLine = $line -replace '\|c[0-9A-Fa-f]{8}', '' -replace '\|r', ''
    if (-not [string]::IsNullOrWhiteSpace($cleanLine)) {
        $lines.Add($cleanLine.TrimEnd())
    }
}
$lines.Add('```')
$lines.Add("")
$lines.Add("| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |")
$lines.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
foreach ($match in $metricMatches) {
    $combatMsPerSec = if ($match.Groups[6].Success) { $match.Groups[6].Value } else { "" }
    $combatCallsPerSec = if ($match.Groups[7].Success) { $match.Groups[7].Value } else { "" }
    $lines.Add((
        "| ``{0}`` | {1} | {2} | {3} | {4} | {5} | {6} |" -f
        $match.Groups[1].Value,
        $match.Groups[2].Value,
        $match.Groups[3].Value,
        $match.Groups[4].Value,
        $match.Groups[5].Value,
        $combatMsPerSec,
        $combatCallsPerSec
    ))
}
$lines.Add("")

$output = ($lines -join "`n") + "`n"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Output $output.TrimEnd()
} else {
    $resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    [System.IO.File]::WriteAllText($resolvedOutput, $output, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Wrote $resolvedOutput"
}
