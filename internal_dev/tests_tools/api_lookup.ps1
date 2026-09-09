param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ApiName,

    [ValidateSet("live", "ptr")]
    [string]$Channel = "live"
)

$ErrorActionPreference = "Stop"

function Invoke-SourceSearch {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $output = @(& rg --line-number --fixed-strings --glob "*.lua" -- $Pattern $Root 2>$null)
    if ($LASTEXITCODE -gt 1) {
        throw "rg failed while searching '$Root'."
    }

    $sourcePrefix = "$sourceInterface\"
    return @($output | ForEach-Object {
        if ($_.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            return $_.Substring($sourcePrefix.Length) -replace "\\", "/"
        }
        return $_
    })
}

$sourceRoot = Join-Path $PSScriptRoot ".wow-api-source\$Channel"
$sourceInterface = Join-Path $sourceRoot "Interface"
$statePath = Join-Path $PSScriptRoot ".wow-api-source\sync-state-$Channel.json"
$sourceResults = [System.Collections.Generic.List[string]]::new()
$seenSourceResults = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

if (Test-Path -LiteralPath $sourceInterface) {
    foreach ($line in (Invoke-SourceSearch -Pattern $ApiName -Root $sourceInterface)) {
        if ($seenSourceResults.Add($line)) {
            $sourceResults.Add($line)
        }
    }

    $apiLeaf = ($ApiName -split "\.")[-1]
    $generatedDocs = Join-Path $sourceInterface "AddOns\Blizzard_APIDocumentationGenerated"
    if ($apiLeaf -ne $ApiName -and (Test-Path -LiteralPath $generatedDocs)) {
        foreach ($line in (Invoke-SourceSearch -Pattern "Name = `"$apiLeaf`"" -Root $generatedDocs)) {
            if ($seenSourceResults.Add($line)) {
                $sourceResults.Add($line)
            }
        }
    }
}

if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $refreshedUtc = if ($state.refreshedAtUtc -is [DateTime]) {
        $state.refreshedAtUtc.ToUniversalTime().ToString("o")
    } else { [string]$state.refreshedAtUtc }
    Write-Host "Current $Channel source: $($state.sourceVersion) $($state.sourceCommit.Substring(0, 8)); refreshed=$refreshedUtc"
}
elseif (Test-Path -LiteralPath $sourceInterface) {
    Write-Host "Current $Channel source cache: $sourceRoot (refresh receipt missing)"
}
else {
    Write-Warning "Current $Channel source cache is missing. Run sync_wow_api_reference.ps1 -Channel $Channel."
}

if ($sourceResults.Count -gt 0) {
    Write-Host "Source matches:"
    $sourceResults | Select-Object -First 80
    if ($sourceResults.Count -gt 80) {
        Write-Host "... $($sourceResults.Count - 80) additional matches omitted"
    }
}
else {
    Write-Host "Source matches: none"
}

$annotationStatePath = Join-Path $PSScriptRoot ".wow-api-source\annotation-state-$Channel.json"
$annotationState = if (Test-Path -LiteralPath $annotationStatePath -PathType Leaf) {
    Get-Content -LiteralPath $annotationStatePath -Raw | ConvertFrom-Json
} else { $null }
$annotationResults = [System.Collections.Generic.List[object]]::new()
if ($annotationState) {
    $annotationRoots = @(
        [string]$annotationState.corePath
        [string]$annotationState.frameXmlPath
    )
    $escapedApi = [System.Text.RegularExpressions.Regex]::Escape($ApiName)
    $functionPattern = "^\s*function\s+$escapedApi\s*\("

    foreach ($root in $annotationRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.lua" | ForEach-Object {
            $file = $_
            $lines = [System.IO.File]::ReadAllLines($file.FullName)

            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -notmatch $functionPattern) { continue }

                $start = $i
                while ($start -gt 0 -and $lines[$start - 1] -match "^\s*---") {
                    $start--
                }

                $rootLabel = if ($root -eq $annotationState.corePath) { "Core" } else { "FrameXML" }
                $relativePath = "$rootLabel/" + ($file.FullName.Substring($root.Length).TrimStart("\") -replace "\\", "/")
                $annotationResults.Add([pscustomobject]@{
                    Path = $relativePath
                    Line = $i + 1
                    Text = @($lines[$start..$i])
                })
            }
        }
    }
}

Write-Host ""
if (-not $annotationState) {
    Write-Host "Generated LuaLS annotations: unavailable"
}
elseif ($annotationResults.Count -eq 0) {
    Write-Host "Generated LuaLS annotations: no exact function match"
}
else {
    Write-Host "Generated LuaLS annotations: generator=$($annotationState.generatorCommit.Substring(0, 8)) resources=$($annotationState.blizzardResourcesCommit.Substring(0, 8)) FrameXML=$($annotationState.frameXmlCommit.Substring(0, 8))"
    for ($i = 0; $i -lt $annotationResults.Count; $i++) {
        $match = $annotationResults[$i]
        Write-Host "$($match.Path):$($match.Line)"
        $match.Text
        if ($i -lt ($annotationResults.Count - 1)) {
            Write-Host ""
        }
    }
}

if ($sourceResults.Count -eq 0 -and $annotationResults.Count -eq 0) {
    throw "No source or exact Ketho annotation match found for '$ApiName'."
}
