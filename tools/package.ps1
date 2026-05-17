param(
    [string]$OutputDir = "dist",
    [switch]$KeepStage
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$addonName = "LsTweeks"
$tocPath = Join-Path $repoRoot "$addonName.toc"
$policyPath = Join-Path $PSScriptRoot "package-policy.json"

if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "Missing TOC file: $tocPath"
}

if (-not (Test-Path -LiteralPath $policyPath)) {
    throw "Missing package policy file: $policyPath"
}

$versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | Select-Object -First 1
$version = if ($versionLine -match '^##\s*Version:\s*(.+)$') { $Matches[1].Trim() } else { "dev" }

$outputRoot = Join-Path $repoRoot $OutputDir
$stageRoot = Join-Path $outputRoot "stage"
$stageAddonRoot = Join-Path $stageRoot $addonName
$zipPath = Join-Path $outputRoot "$addonName-$version.zip"

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$publicRoots = @($policy.includeRoots)
$publicFiles = @($policy.includeFiles)
$excludeNames = @($policy.excludeDirectories)
$excludeFiles = @($policy.excludeFiles)

function Assert-UnderRoot {
    param(
        [string]$Root,
        [string]$Path
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $resolvedPath = if (Test-Path -LiteralPath $Path) {
        (Resolve-Path -LiteralPath $Path).Path
    } else {
        [System.IO.Path]::GetFullPath($Path)
    }

    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside repository root: $resolvedPath"
    }
}

function Copy-PublicItem {
    param(
        [string]$RelativePath
    )

    if ($excludeNames -contains $RelativePath -or $excludeFiles -contains $RelativePath) {
        return
    }

    $source = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing public package item: $RelativePath"
    }

    $destination = Join-Path $stageAddonRoot $RelativePath
    $destinationParent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

function Test-TocReferences {
    $missing = @()

    Get-Content -LiteralPath $tocPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }

        if ($line -match '\.(lua|xml)$') {
            $path = Join-Path $repoRoot $line
            if (-not (Test-Path -LiteralPath $path)) {
                $missing += $line
            }
        }
    }

    if ($missing.Count -gt 0) {
        throw "TOC references missing files: $($missing -join ', ')"
    }
}

Assert-UnderRoot -Root $repoRoot -Path $outputRoot
Test-TocReferences

if (Test-Path -LiteralPath $stageRoot) {
    Assert-UnderRoot -Root $repoRoot -Path $stageRoot
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $stageAddonRoot | Out-Null

foreach ($file in $publicFiles) {
    Copy-PublicItem -RelativePath $file
}

foreach ($root in $publicRoots) {
    Copy-PublicItem -RelativePath $root
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
if (Test-Path -LiteralPath $zipPath) {
    Assert-UnderRoot -Root $repoRoot -Path $zipPath
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath $stageAddonRoot -DestinationPath $zipPath -CompressionLevel Optimal

if (-not $KeepStage) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

$zipItem = Get-Item -LiteralPath $zipPath
Write-Host "Created $($zipItem.FullName)"
Write-Host "Version $version"
Write-Host "Size $([Math]::Round($zipItem.Length / 1MB, 2)) MB"
