param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

function Get-AddonLuaFilesFromToc {
    param([string]$TocPath)

    foreach ($line in [System.IO.File]::ReadAllLines($TocPath)) {
        $entry = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($entry) -or $entry.StartsWith("#")) { continue }

        $normalized = $entry -replace "\\", "/"
        if ($normalized -notmatch "(?i)\.lua$" -or $normalized -match "(?i)^libs/") { continue }
        $normalized
    }
}

function Add-HelperDefinition {
    param(
        [System.Collections.Generic.HashSet[string]]$Definitions,
        [string]$Owner,
        [string]$Name
    )

    [void]$Definitions.Add("${Owner}:${Name}")
}

$tocPath = Join-Path $RepoRoot "LsTweeks.toc"
$luaFiles = @(Get-AddonLuaFilesFromToc $tocPath)
$ownersByFile = @{}
$helperDefinitions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

foreach ($relativePath in $luaFiles) {
    $fullPath = Join-Path $RepoRoot $relativePath
    $text = [System.IO.File]::ReadAllText($fullPath)
    $ownerMatch = [regex]::Match($text, "(?m)^\s*local M = addon\.([A-Za-z_][A-Za-z0-9_]*)\s*$")
    $owner = if ($ownerMatch.Success) { $ownerMatch.Groups[1].Value } else { $null }
    $ownersByFile[$relativePath] = $owner

    $localFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($match in [regex]::Matches($text, "(?m)^\s*local function ([A-Za-z_][A-Za-z0-9_]*)\s*\(")) {
        [void]$localFunctions.Add($match.Groups[1].Value)
    }

    foreach ($match in [regex]::Matches($text, "(?m)^\s*function addon\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")) {
        Add-HelperDefinition $helperDefinitions "addon" $match.Groups[1].Value
    }
    foreach ($match in [regex]::Matches($text, "(?m)^\s*addon\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")) {
        if ($localFunctions.Contains($match.Groups[2].Value)) {
            Add-HelperDefinition $helperDefinitions "addon" $match.Groups[1].Value
        }
    }

    if (-not $owner) { continue }
    foreach ($match in [regex]::Matches($text, "(?m)^\s*function M\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")) {
        Add-HelperDefinition $helperDefinitions $owner $match.Groups[1].Value
    }
    foreach ($match in [regex]::Matches($text, "(?m)^\s*M\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(")) {
        Add-HelperDefinition $helperDefinitions $owner $match.Groups[1].Value
    }
    foreach ($match in [regex]::Matches($text, "(?m)^\s*M\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")) {
        if ($localFunctions.Contains($match.Groups[2].Value)) {
            Add-HelperDefinition $helperDefinitions $owner $match.Groups[1].Value
        }
    }
    foreach ($match in [regex]::Matches($text, "(?m)^\s*M\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*addon\.BuildProfilesTab\s*\(")) {
        Add-HelperDefinition $helperDefinitions $owner $match.Groups[1].Value
    }
}

# Every allowlist entry needs a durable optional-lifecycle reason under project.md
# "Deterministic Ownership And Optionality". Fix incomplete test fixtures instead.
# These callbacks are installed only after their corresponding settings tab is built.
# Tooltip diagnostics are intentionally optional user-facing debug facilities.
$allowedHelperProbes = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        "addon:MarkTooltipDebugTrace",
        "addon:PrintTooltipRendererHistory",
        "addon:SetNativeAuraTooltipTestEnabled",
        "audio_volumes:rebuild_situations_tab",
        "audio_volumes:refresh_profiles_tab",
        "aura_frames:refresh_frames_tree",
        "aura_frames:refresh_profiles_tab",
        "objectives:rebuild_tracker_tab",
        "objectives:refresh_profiles_tab",
        "skyriding_vigor:refresh_profiles_tab"
    ),
    [System.StringComparer]::Ordinal
)

# Nil means no temporary profile is active; this snapshot exists only for that lifecycle.
$allowedLazyTables = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("audio_volumes:_temporary_sound_profile_cached"),
    [System.StringComparer]::Ordinal
)

$violations = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $luaFiles) {
    $fullPath = Join-Path $RepoRoot $relativePath
    $owner = $ownersByFile[$relativePath]
    $lines = [System.IO.File]::ReadAllLines($fullPath)

    for ($index = 0; $index -lt $lines.Length; $index++) {
        $line = $lines[$index]
        $code = ($line -split "--", 2)[0]
        if ([string]::IsNullOrWhiteSpace($code)) { continue }
        $lineNumber = $index + 1

        if ($code -match "addon\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*addon\.\1\s+or\s+\{") {
            $violations.Add("${relativePath}:${lineNumber}: defensive addon-table initializer; use the TOC owner's table directly")
        }
        if ($code -match "local\s+M\s*=\s*addon\.[A-Za-z_][A-Za-z0-9_]*\s+or\s+\{") {
            $violations.Add("${relativePath}:${lineNumber}: fallback module table; load its owning initializer first")
        }
        $lazyTableMatch = [regex]::Match(
            $code,
            "M\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*M\.\1\s+or\s+\{"
        )
        if ($lazyTableMatch.Success -and $owner) {
            $lazyTableKey = "${owner}:$($lazyTableMatch.Groups[1].Value)"
            if (-not $allowedLazyTables.Contains($lazyTableKey)) {
                $violations.Add("${relativePath}:${lineNumber}: repeated module-table initialization; allocate the stable table at its owner")
            }
        }
        if ($code -cmatch "\b(?:M|addon)\.[A-Z][A-Z0-9_]*\s+(?:and|or)\b") {
            $violations.Add("${relativePath}:${lineNumber}: fallback for a required canonical constant or schema table")
        }
        if ($code -match "\b(?:defaults|DEFAULTS|M\.defaults)(?:\.[A-Za-z_][A-Za-z0-9_]*)+\s+or\s+(?:[-+]?\d|[`"']|\{)") {
            $violations.Add("${relativePath}:${lineNumber}: hardcoded fallback after a canonical default")
        }
        if ($code -match "\b(?:not\s+)?M\.(controls|frames|frames_list|grid_lines|flight_locked_controls)\b\s*(?:and|or|then)\b") {
            $violations.Add("${relativePath}:${lineNumber}: probes a stable module table allocated by its owner")
        }

        if ($relativePath.StartsWith("modules/") -and (
            $code -match "\b([A-Za-z_][A-Za-z0-9_]*)\s+and\s+\1\.(GetValue|SetValue|SetValueSilently|GetChecked|SetChecked|SetCheckedSilently|SetEnabled|Enable|Disable|HookValueChanged|HookCheckedChanged|SetTextToFit|Refresh|SetState)\b" -or
            $code -match "if\s+(M\.controls\.[A-Za-z_][A-Za-z0-9_]*)\s+and\s+\1\.(SetValue|SetValueSilently|SetChecked|SetCheckedSilently|SetEnabled|Enable|Disable|HookValueChanged|HookCheckedChanged|SetTextToFit|Refresh|SetState)\s+then"
        )) {
            $violations.Add("${relativePath}:${lineNumber}: addon control method probe; the factory contract guarantees the method")
        }

        $conditionalText = $null
        $conditionalMatch = [regex]::Match($code, "^\s*(?:if|elseif)\s+(.*?)(?:\s+then\b|$)")
        if ($conditionalMatch.Success) {
            $conditionalText = $conditionalMatch.Groups[1].Value
        } elseif ($code -match "^\s*(?:and|or)\b") {
            $conditionalText = $code
        }

        foreach ($match in [regex]::Matches($code, "\b(?<kind>M|addon)\.(?<name>[A-Za-z_][A-Za-z0-9_]*)\b")) {
            $kind = $match.Groups["kind"].Value
            $name = $match.Groups["name"].Value
            $helperOwner = if ($kind -eq "addon") { "addon" } else { $owner }
            if (-not $helperOwner) { continue }

            $key = "${helperOwner}:${name}"
            if (-not $helperDefinitions.Contains($key) -or $allowedHelperProbes.Contains($key)) { continue }
            if ($code -match "^\s*(?:function\s+)?(?:M|addon)\.${name}\s*=") { continue }
            if ($code -match "^\s*function\s+(?:M|addon)\.${name}\s*\(") { continue }

            $token = [regex]::Escape("${kind}.${name}")
            $isProbe = $false
            if ($conditionalText -and $conditionalText -match "\b${token}\b(?!\s*\()") {
                $isProbe = $true
            }
            if ($code -match "\b(?:type|pcall|xpcall)\s*\(\s*${token}\b") {
                $isProbe = $true
            }
            if ($code -match "\b${token}\b\s*(?:and|or)\b") {
                $isProbe = $true
            }

            if ($isProbe) {
                $violations.Add("${relativePath}:${lineNumber}: probes required helper ${kind}.${name}; call the TOC-guaranteed dependency directly")
                break
            }
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | Sort-Object -Unique | ForEach-Object { Write-Host $_ }
    throw "Internal contract check failed with $($violations.Count) violation(s)."
}

Write-Host "Internal contract checks passed."
