param(
    [string]$InputPath = "internal_dev/tests_tools/cpu_profiles/af_cpu_profiles.md",
    [string]$OutputPath = "",
    [string]$BaselineTitle = "2026-06-22, Aura Frames Only",
    [double]$TickerReferenceSec = 0.10,
    [string[]]$Metrics = @(
        "af.update_auras",
        "af.render_aura_map",
        "af.tick_visible_icons",
        "af.unified_scan",
        "af.scan_custom_aura_map",
        "af.get_setting"
    )
)

$ErrorActionPreference = "Stop"

function Convert-ToNullableDouble {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq "unknown") {
        return $null
    }

    return [double]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Format-Number {
    param(
        $Value,
        [int]$Places = 2
    )

    if ($null -eq $Value) {
        return ""
    }

    return ([double]$Value).ToString("F$Places", [Globalization.CultureInfo]::InvariantCulture)
}

function Format-PercentChange {
    param(
        $Current,
        $Baseline
    )

    if ($null -eq $Current -or $null -eq $Baseline -or [double]$Baseline -eq 0) {
        return ""
    }

    $change = (([double]$Current - [double]$Baseline) / [double]$Baseline) * 100
    return ("{0:+0.0;-0.0;0.0}%" -f $change)
}

function Get-ProfileMetadata {
    param([string]$SectionText)

    $metadata = @{}
    $metadataMatch = [regex]::Match($SectionText, "<!--\s*cpu-profile-run:\s*(.*?)\s*-->")
    if ($metadataMatch.Success) {
        foreach ($token in ($metadataMatch.Groups[1].Value -split "\s+")) {
            if ($token -match "^([^=]+)=(.*)$") {
                $metadata[$matches[1]] = $matches[2]
            }
        }
    }

    if (-not $metadata.ContainsKey("elapsed") -and $SectionText -match "Context:\s*([0-9.]+)s run") {
        $metadata["elapsed"] = $matches[1]
    }

    if (-not $metadata.ContainsKey("combat") -and $SectionText -match "Combat was active for ([0-9.]+)s") {
        $metadata["combat"] = $matches[1]
    }

    if (-not $metadata.ContainsKey("timer_tick")) {
        if ($SectionText -match "Timer Tick\s+was set to\s+``?([0-9.]+)s?``?") {
            $metadata["timer_tick"] = $matches[1]
        } elseif ($SectionText -match "``Timer Tick\s+Sec``\s+set to\s+``?([0-9.]+)s?``?") {
            $metadata["timer_tick"] = $matches[1]
        }
    }

    return ,$metadata
}

function Get-RunSections {
    param([string]$Text)

    $headingMatches = [regex]::Matches($Text, "(?m)^### (2026-[0-9]{2}-[0-9]{2}, Aura Frames Only[^\r\n]*)\r?\n")
    $sections = @()

    for ($i = 0; $i -lt $headingMatches.Count; $i++) {
        $heading = $headingMatches[$i]
        $start = $heading.Index
        if ($i + 1 -lt $headingMatches.Count) {
            $end = $headingMatches[$i + 1].Index
        } else {
            $nextMajor = [regex]::Match($Text.Substring($heading.Index + $heading.Length), "(?m)^## ")
            if ($nextMajor.Success) {
                $end = $heading.Index + $heading.Length + $nextMajor.Index
            } else {
                $end = $Text.Length
            }
        }

        $sections += [pscustomobject]@{
            Title = $heading.Groups[1].Value.Trim()
            Text = $Text.Substring($start, $end - $start)
        }
    }

    return $sections
}

function Get-MetricRows {
    param(
        [string]$SectionText,
        [double]$ElapsedSec,
        $CombatSec
    )

    $metricsByName = @{}

    foreach ($line in ($SectionText -split "\r?\n")) {
        if ($line -notmatch "^\|\s*``([^``]+)``\s*\|\s*([0-9]+)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*(?:\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*)?\|") {
            continue
        }

        $name = $matches[1]
        $calls = [int]$matches[2]
        $totalMs = [double]::Parse($matches[3], [Globalization.CultureInfo]::InvariantCulture)
        $avgMs = [double]::Parse($matches[4], [Globalization.CultureInfo]::InvariantCulture)
        $maxMs = [double]::Parse($matches[5], [Globalization.CultureInfo]::InvariantCulture)
        $reportedCombatMsPerSec = Convert-ToNullableDouble $matches[6]
        $reportedCombatCallsPerSec = Convert-ToNullableDouble $matches[7]

        $elapsedMsPerSec = $totalMs / $ElapsedSec
        $elapsedCallsPerSec = $calls / $ElapsedSec
        $derivedCombatMsPerSec = $null
        $derivedCombatCallsPerSec = $null

        if ($null -ne $CombatSec -and [double]$CombatSec -gt 0) {
            $derivedCombatMsPerSec = $totalMs / [double]$CombatSec
            $derivedCombatCallsPerSec = $calls / [double]$CombatSec
        }

        $metricsByName[$name] = [pscustomobject]@{
            Name = $name
            Calls = $calls
            TotalMs = $totalMs
            AvgMs = $avgMs
            MaxMs = $maxMs
            ElapsedMsPerSec = $elapsedMsPerSec
            ElapsedCallsPerSec = $elapsedCallsPerSec
            CombatMsPerSec = if ($null -ne $reportedCombatMsPerSec) { $reportedCombatMsPerSec } else { $derivedCombatMsPerSec }
            CombatCallsPerSec = if ($null -ne $reportedCombatCallsPerSec) { $reportedCombatCallsPerSec } else { $derivedCombatCallsPerSec }
        }
    }

    return ,$metricsByName
}

function Get-TickerNormalizedMsPerSec {
    param(
        [object]$Metric,
        $TimerTickSec,
        [double]$ReferenceSec
    )

    if ($null -eq $Metric -or $null -eq $TimerTickSec -or $ReferenceSec -le 0) {
        return $null
    }

    return $Metric.ElapsedMsPerSec * ([double]$TimerTickSec / $ReferenceSec)
}

$resolvedInput = Resolve-Path $InputPath
$text = [System.IO.File]::ReadAllText($resolvedInput)
$runs = @()

foreach ($section in (Get-RunSections $text)) {
    $metadata = Get-ProfileMetadata $section.Text
    $elapsedSec = Convert-ToNullableDouble $metadata["elapsed"]
    if ($null -eq $elapsedSec -or [double]$elapsedSec -le 0) {
        Write-Warning "Skipping '$($section.Title)' because elapsed time is missing."
        continue
    }

    $combatSec = Convert-ToNullableDouble $metadata["combat"]
    $timerTickSec = Convert-ToNullableDouble $metadata["timer_tick"]
    $metricsByName = Get-MetricRows $section.Text $elapsedSec $combatSec

    $runs += [pscustomobject]@{
        Title = $section.Title
        ElapsedSec = $elapsedSec
        CombatSec = $combatSec
        TimerTickSec = $timerTickSec
        Metrics = $metricsByName
    }
}

if ($runs.Count -eq 0) {
    throw "No Aura Frames whole-addon runs found in $InputPath."
}

$baseline = $runs | Where-Object { $_.Title -eq $BaselineTitle } | Select-Object -First 1
if ($null -eq $baseline) {
    $baseline = $runs[-1]
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Aura Frames CPU Profile Analysis")
$lines.Add("")
$lines.Add("Input: ``$InputPath``")
$lines.Add("")
$lines.Add("Baseline: ``$($baseline.Title)``. Ticker-normalized values estimate what ``af.tick_visible_icons`` would cost at the reference ticker cadence ``$($TickerReferenceSec.ToString("F2", [Globalization.CultureInfo]::InvariantCulture))s``. Raw elapsed ``ms/sec`` remains the real measured CPU rate for each run.")
$lines.Add("")
$lines.Add("| Run | Elapsed | Combat | Tick | ``af.update_auras`` ms/sec | Δ | ``af.render_aura_map`` ms/sec | Δ | ``af.tick_visible_icons`` ms/sec | Δ | Tick norm ms/sec | Δ | ``af.get_setting`` ms/sec | Δ |")
$lines.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")

$baselineUpdate = $baseline.Metrics["af.update_auras"]
$baselineRender = $baseline.Metrics["af.render_aura_map"]
$baselineTicker = $baseline.Metrics["af.tick_visible_icons"]
$baselineSetting = $baseline.Metrics["af.get_setting"]
$baselineTickerNorm = Get-TickerNormalizedMsPerSec $baselineTicker $baseline.TimerTickSec $TickerReferenceSec

foreach ($run in $runs) {
    $update = $run.Metrics["af.update_auras"]
    $render = $run.Metrics["af.render_aura_map"]
    $ticker = $run.Metrics["af.tick_visible_icons"]
    $setting = $run.Metrics["af.get_setting"]
    $tickerNorm = Get-TickerNormalizedMsPerSec $ticker $run.TimerTickSec $TickerReferenceSec

    $lines.Add((
        "| ``{0}`` | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} |" -f
        $run.Title,
        (Format-Number $run.ElapsedSec 1),
        (Format-Number $run.CombatSec 1),
        (Format-Number $run.TimerTickSec 2),
        (Format-Number $update.ElapsedMsPerSec 2),
        (Format-PercentChange $update.ElapsedMsPerSec $baselineUpdate.ElapsedMsPerSec),
        (Format-Number $render.ElapsedMsPerSec 2),
        (Format-PercentChange $render.ElapsedMsPerSec $baselineRender.ElapsedMsPerSec),
        (Format-Number $ticker.ElapsedMsPerSec 2),
        (Format-PercentChange $ticker.ElapsedMsPerSec $baselineTicker.ElapsedMsPerSec),
        (Format-Number $tickerNorm 2),
        (Format-PercentChange $tickerNorm $baselineTickerNorm),
        (Format-Number $setting.ElapsedMsPerSec 2),
        (Format-PercentChange $setting.ElapsedMsPerSec $baselineSetting.ElapsedMsPerSec)
    ))
}

$lines.Add("")
$lines.Add("## Selected Metric Detail")
$lines.Add("")
$lines.Add("| Metric | Run | Calls/sec | Avg ms | Max ms | Elapsed ms/sec | Δ vs baseline | Combat ms/sec |")
$lines.Add("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")

foreach ($metricName in $Metrics) {
    $baselineMetric = $baseline.Metrics[$metricName]
    foreach ($run in $runs) {
        $metric = $run.Metrics[$metricName]
        if ($null -eq $metric) {
            continue
        }

        $lines.Add((
            "| ``{0}`` | ``{1}`` | {2} | {3} | {4} | {5} | {6} | {7} |" -f
            $metricName,
            $run.Title,
            (Format-Number $metric.ElapsedCallsPerSec 2),
            (Format-Number $metric.AvgMs 4),
            (Format-Number $metric.MaxMs 3),
            (Format-Number $metric.ElapsedMsPerSec 2),
            (Format-PercentChange $metric.ElapsedMsPerSec $baselineMetric.ElapsedMsPerSec),
            (Format-Number $metric.CombatMsPerSec 2)
        ))
    }
}

$output = ($lines -join "`n") + "`n"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    foreach ($line in $lines) {
        Write-Output $line
    }
} else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $outputParent = Split-Path -Parent $resolvedOutput
    if (-not [string]::IsNullOrWhiteSpace($outputParent) -and -not (Test-Path -LiteralPath $outputParent)) {
        New-Item -ItemType Directory -Path $outputParent | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedOutput, $output, $utf8NoBom)
    Write-Output "Wrote $OutputPath"
}
