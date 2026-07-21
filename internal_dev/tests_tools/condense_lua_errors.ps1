<#
.SYNOPSIS
Condenses repeated World of Warcraft Lua errors into grouped Markdown or JSON.

.DESCRIPTION
Parses WoW Lua error exports that use Message/Time/Count/Stack/Locals fields,
plus the compact "1x file.lua:line: message" format. Errors are grouped by
normalized message, common stack prefixes are shown once, distinct caller tails
are counted, and addon ownership/taint signals are surfaced. Locals are omitted
by default because they usually dominate exports without helping first-pass triage.

.EXAMPLE
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/condense_lua_errors.ps1 -Path internal_dev/working_docs/ToDo/new_issue.txt

.EXAMPLE
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/condense_lua_errors.ps1 -Path errors.txt -OutputPath condensed.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Path,

    [string] $OutputPath,

    [ValidateSet("Markdown", "Json")]
    [string] $Format = "Markdown",

    [string] $AddonName = "LsTweeks",

    [ValidateRange(1, 100)]
    [int] $MaxStackFrames = 14,

    [switch] $IncludeLocals,

    [ValidateRange(1, 200)]
    [int] $MaxLocalLines = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Line {
    param([AllowEmptyString()][string] $Text)

    if ($null -eq $Text) { return "" }
    $normalized = $Text -replace '\\', '/'
    $normalized = $normalized -replace '\|c[0-9A-Fa-f]{8}', ''
    $normalized = $normalized -replace '\|r', ''
    return ($normalized -replace '\s+', ' ').Trim()
}

function New-ErrorRecord {
    param(
        [string] $Message,
        [string] $Time,
        [int] $Count,
        [string[]] $Stack,
        [string[]] $Locals,
        [int] $InputIndex
    )

    $normalizedStack = @(
        foreach ($line in $Stack) {
            $value = Normalize-Line $line
            if ($value -and $value -ne "Stack:") { $value }
        }
    )

    return [pscustomobject]@{
        Message = Normalize-Line $Message
        Time = if ($Time) { $Time.Trim() } else { $null }
        Count = [math]::Max(1, $Count)
        Stack = $normalizedStack
        Locals = @($Locals)
        InputIndex = $InputIndex
    }
}

function ConvertFrom-FieldedExport {
    param([string[]] $Lines)

    $starts = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*Message:\s*(.*)$') {
            $starts += $i
        }
    }
    if ($starts.Count -eq 0) { return @() }

    $records = @()
    for ($entryIndex = 0; $entryIndex -lt $starts.Count; $entryIndex++) {
        $start = $starts[$entryIndex]
        $end = if ($entryIndex + 1 -lt $starts.Count) { $starts[$entryIndex + 1] - 1 } else { $Lines.Count - 1 }
        $message = ($Lines[$start] -replace '^\s*Message:\s*', '')
        $time = $null
        $count = 1
        $stackStart = $null
        $localsStart = $null

        for ($i = $start + 1; $i -le $end; $i++) {
            if ($Lines[$i] -match '^\s*Time:\s*(.*)$') { $time = $Matches[1]; continue }
            if ($Lines[$i] -match '^\s*Count:\s*(\d+)') { $count = [int] $Matches[1]; continue }
            if ($Lines[$i] -match '^\s*Stack:\s*$') { $stackStart = $i + 1; continue }
            if ($Lines[$i] -match '^\s*Locals:\s*$') { $localsStart = $i + 1; break }
        }

        $stack = @()
        if ($null -ne $stackStart) {
            $stackEnd = if ($null -ne $localsStart) { $localsStart - 2 } else { $end }
            if ($stackEnd -ge $stackStart) { $stack = @($Lines[$stackStart..$stackEnd]) }
        }

        $locals = @()
        if ($null -ne $localsStart -and $localsStart -le $end) {
            $locals = @($Lines[$localsStart..$end])
            while ($locals.Count -gt 0 -and [string]::IsNullOrWhiteSpace($locals[-1])) {
                if ($locals.Count -eq 1) {
                    $locals = @()
                } else {
                    $locals = @($locals[0..($locals.Count - 2)])
                }
            }
        }

        $records += New-ErrorRecord -Message $message -Time $time -Count $count -Stack $stack -Locals $locals -InputIndex ($entryIndex + 1)
    }
    return $records
}

function ConvertFrom-CompactExport {
    param([string[]] $Lines)

    $starts = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*(\d+)x\s+(.+)$') {
            $starts += [pscustomobject]@{ Line = $i; Count = [int] $Matches[1]; Message = $Matches[2] }
        }
    }
    if ($starts.Count -eq 0) { return @() }

    $records = @()
    for ($entryIndex = 0; $entryIndex -lt $starts.Count; $entryIndex++) {
        $start = $starts[$entryIndex]
        $end = if ($entryIndex + 1 -lt $starts.Count) { $starts[$entryIndex + 1].Line - 1 } else { $Lines.Count - 1 }
        $body = if ($end -gt $start.Line) { @($Lines[($start.Line + 1)..$end]) } else { @() }
        $localsAt = -1
        for ($i = 0; $i -lt $body.Count; $i++) {
            if ($body[$i] -match '^\s*Locals:\s*$') { $localsAt = $i; break }
        }
        $stack = if ($localsAt -gt 0) { @($body[0..($localsAt - 1)]) } elseif ($localsAt -eq 0) { @() } else { $body }
        $locals = if ($localsAt -ge 0 -and $localsAt + 1 -lt $body.Count) { @($body[($localsAt + 1)..($body.Count - 1)]) } else { @() }
        $records += New-ErrorRecord -Message $start.Message -Time $null -Count $start.Count -Stack $stack -Locals $locals -InputIndex ($entryIndex + 1)
    }
    return $records
}

function Get-Origin {
    param([string] $Message, [string] $ProjectAddonName)

    if ($Message -match '(?i)Interface/AddOns/([^/]+)/') {
        $owner = $Matches[1]
        if ($owner -ieq $ProjectAddonName) { return "project addon ($owner)" }
        if ($owner -like 'Blizzard_*') { return "Blizzard UI ($owner)" }
        return "third-party addon ($owner)"
    }
    if ($Message -match '(?i)(?:^|/)(Blizzard_[^/:]+)') { return "Blizzard UI ($($Matches[1]))" }
    return "unknown"
}

function Get-AddonOwner {
    param([string] $Frame)

    if ($Frame -match '(?i)Interface/AddOns/([^/]+)/') { return $Matches[1] }
    return $null
}

function Get-CommonPrefixLength {
    param([object[]] $Records)

    if ($Records.Count -eq 0) { return 0 }
    $limit = $Records[0].Stack.Count
    foreach ($record in $Records) { $limit = [math]::Min($limit, $record.Stack.Count) }

    for ($i = 0; $i -lt $limit; $i++) {
        $expected = $Records[0].Stack[$i]
        foreach ($record in $Records) {
            if ($record.Stack[$i] -cne $expected) { return $i }
        }
    }
    return $limit
}

function Get-TimeLabel {
    param([object[]] $Records)

    $times = @($Records | ForEach-Object { $_.Time } | Where-Object { $_ } | Select-Object -Unique)
    if ($times.Count -eq 0) { return $null }
    if ($times.Count -eq 1) { return $times[0] }
    return "$($times[0]) -> $($times[-1])"
}

function Build-Families {
    param([object[]] $Records, [string] $ProjectAddonName)

    $families = @()
    foreach ($messageGroup in ($Records | Group-Object -Property Message)) {
        $groupRecords = @($messageGroup.Group | Sort-Object InputIndex)
        $commonLength = Get-CommonPrefixLength $groupRecords
        $variantMap = [ordered]@{}

        foreach ($record in $groupRecords) {
            $signature = [string]::Join([char] 0x1F, $record.Stack)
            if (-not $variantMap.Contains($signature)) {
                $variantMap[$signature] = [pscustomobject]@{
                    Count = 0
                    Records = @()
                    Stack = $record.Stack
                }
            }
            $variant = $variantMap[$signature]
            $variant.Count += $record.Count
            $variant.Records = @($variant.Records) + $record
        }

        $addons = [ordered]@{}
        foreach ($record in $groupRecords) {
            foreach ($frame in $record.Stack) {
                $owner = Get-AddonOwner $frame
                if ($owner -and -not $addons.Contains($owner)) { $addons[$owner] = $true }
            }
        }

        $taintOwner = $null
        if ($messageGroup.Name -match '(?i)execution tainted by [''"]([^''"]+)[''"]') {
            $taintOwner = $Matches[1]
        }

        $families += [pscustomobject]@{
            Message = $messageGroup.Name
            Origin = Get-Origin -Message $messageGroup.Name -ProjectAddonName $ProjectAddonName
            TaintOwner = $taintOwner
            Occurrences = ($groupRecords | Measure-Object -Property Count -Sum).Sum
            RecordCount = $groupRecords.Count
            TimeRange = Get-TimeLabel $groupRecords
            CommonStack = @($groupRecords[0].Stack | Select-Object -First $commonLength)
            Variants = @($variantMap.Values | Sort-Object Count -Descending)
            Addons = @($addons.Keys)
            Records = $groupRecords
        }
    }

    return @($families | Sort-Object @{ Expression = 'Occurrences'; Descending = $true }, Message)
}

function Add-CodeBlock {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [string[]] $Content,
        [int] $Limit = 0
    )

    $Lines.Add('```text')
    $shown = if ($Limit -gt 0) { @($Content | Select-Object -First $Limit) } else { @($Content) }
    foreach ($line in $shown) { $Lines.Add($line) }
    if ($Limit -gt 0 -and $Content.Count -gt $Limit) {
        $Lines.Add("... $($Content.Count - $Limit) more line(s) omitted")
    }
    $Lines.Add('```')
}

function ConvertTo-MarkdownReport {
    param(
        [object[]] $Records,
        [object[]] $Families,
        [string] $SourcePath,
        [int] $StackLimit,
        [bool] $ShowLocals,
        [int] $LocalLimit,
        [string] $ProjectAddonName
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $totalOccurrences = ($Records | Measure-Object -Property Count -Sum).Sum
    $totalVariants = ($Families | ForEach-Object { $_.Variants.Count } | Measure-Object -Sum).Sum
    $lines.Add('# Condensed Lua Errors')
    $lines.Add('')
    $lines.Add("- Source: ``$SourcePath``")
    $lines.Add("- Parsed records: $($Records.Count)")
    $lines.Add("- Reported occurrences: $totalOccurrences")
    $lines.Add("- Unique messages: $($Families.Count)")
    $lines.Add("- Distinct stack variants: $totalVariants")
    $lines.Add("- Locals: $(if ($ShowLocals) { 'representative excerpts included' } else { 'omitted; consult the source export when needed' })")

    for ($familyIndex = 0; $familyIndex -lt $Families.Count; $familyIndex++) {
        $family = $Families[$familyIndex]
        $lines.Add('')
        $lines.Add('')
        $lines.Add("## Error $($familyIndex + 1)")
        $lines.Add('')
        Add-CodeBlock -Lines $lines -Content @($family.Message)
        $lines.Add('')
        $lines.Add("- Reported occurrences: $($family.Occurrences) across $($family.RecordCount) record(s)")
        $lines.Add("- Stack variants: $($family.Variants.Count)")
        $lines.Add("- Message origin: $($family.Origin)")
        if ($family.TimeRange) { $lines.Add("- Captured: $($family.TimeRange)") }
        if ($family.TaintOwner) { $lines.Add("- Explicit taint attribution: $($family.TaintOwner)") }

        $projectFramesPresent = $family.Addons -contains $ProjectAddonName
        $lines.Add("- Project frames in captured stacks: $(if ($projectFramesPresent) { 'yes' } else { 'none' })")
        if ($family.Addons.Count -gt 0) {
            $lines.Add("- Addons appearing in stacks: $([string]::Join(', ', $family.Addons))")
        }

        if ($family.CommonStack.Count -gt 0) {
            $lines.Add('')
            $lines.Add('### Common stack prefix')
            $lines.Add('')
            Add-CodeBlock -Lines $lines -Content $family.CommonStack -Limit $StackLimit
        }

        $lines.Add('')
        $lines.Add('### Stack variants')
        for ($variantIndex = 0; $variantIndex -lt $family.Variants.Count; $variantIndex++) {
            $variant = $family.Variants[$variantIndex]
            $lines.Add('')
            $timeLabel = Get-TimeLabel $variant.Records
            $label = "Variant $($variantIndex + 1): $($variant.Count)x"
            if ($timeLabel) { $label += "; $timeLabel" }
            $lines.Add("#### $label")
            $tail = if ($family.CommonStack.Count -lt $variant.Stack.Count) {
                @($variant.Stack[$family.CommonStack.Count..($variant.Stack.Count - 1)])
            } else {
                @('(no caller tail; stack matches the common prefix)')
            }
            Add-CodeBlock -Lines $lines -Content $tail -Limit $StackLimit

            if ($ShowLocals) {
                $representative = @($variant.Records | Where-Object { $_.Locals.Count -gt 0 } | Select-Object -First 1)
                if ($representative.Count -gt 0) {
                    $lines.Add('')
                    $lines.Add('Representative locals:')
                    Add-CodeBlock -Lines $lines -Content $representative[0].Locals -Limit $LocalLimit
                }
            }
        }
    }

    return [string]::Join("`n", $lines) + "`n"
}

$resolvedInput = (Resolve-Path -LiteralPath $Path).Path
$raw = [System.IO.File]::ReadAllText($resolvedInput)
$sourceLines = @($raw -split '\r?\n')
$records = @(ConvertFrom-FieldedExport $sourceLines)
if ($records.Count -eq 0) { $records = @(ConvertFrom-CompactExport $sourceLines) }

if ($records.Count -eq 0) {
    $firstLine = @($sourceLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
    if ($firstLine.Count -eq 0) { throw "No Lua errors found in empty input: $resolvedInput" }
    $records = @(New-ErrorRecord -Message $firstLine[0] -Time $null -Count 1 -Stack @($sourceLines | Select-Object -Skip 1) -Locals @() -InputIndex 1)
}

$families = @(Build-Families -Records $records -ProjectAddonName $AddonName)
if ($Format -eq 'Json') {
    $reportObject = [pscustomobject]@{
        source = $Path
        parsed_records = $records.Count
        reported_occurrences = ($records | Measure-Object -Property Count -Sum).Sum
        unique_messages = $families.Count
        families = @($families | ForEach-Object {
            [pscustomobject]@{
                message = $_.Message
                origin = $_.Origin
                taint_owner = $_.TaintOwner
                occurrences = $_.Occurrences
                record_count = $_.RecordCount
                time_range = $_.TimeRange
                common_stack = $_.CommonStack
                addons_in_stacks = $_.Addons
                variants = @($_.Variants | ForEach-Object {
                    [pscustomobject]@{
                        occurrences = $_.Count
                        time_range = Get-TimeLabel $_.Records
                        stack = $_.Stack
                    }
                })
            }
        })
    }
    $report = $reportObject | ConvertTo-Json -Depth 8
    $report += "`n"
} else {
    $report = ConvertTo-MarkdownReport -Records $records -Families $families -SourcePath $Path -StackLimit $MaxStackFrames -ShowLocals $IncludeLocals.IsPresent -LocalLimit $MaxLocalLines -ProjectAddonName $AddonName
}

if ($OutputPath) {
    $resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $outputDirectory = Split-Path -Parent $resolvedOutput
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        throw "Output directory does not exist: $outputDirectory"
    }
    [System.IO.File]::WriteAllText($resolvedOutput, $report, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Condensed report written to: $resolvedOutput"
} else {
    Write-Output $report
}
