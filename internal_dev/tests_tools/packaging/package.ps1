param(
    [string]$OutputDir = "releases",
    [switch]$KeepStage
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$addonRoot = Join-Path $repoRoot "LsTweeks"
$policyPath = Join-Path $PSScriptRoot "package-policy.json"
$verifyScriptPath = Join-Path $PSScriptRoot "verify-package.ps1"

function Get-AddonToc {
    $tocFiles = @(Get-ChildItem -LiteralPath $addonRoot -File -Filter "*.toc")
    if ($tocFiles.Count -eq 0) {
        throw "Missing root TOC file."
    }
    if ($tocFiles.Count -gt 1) {
        throw "Expected exactly one root TOC file, found: $($tocFiles.Name -join ', ')"
    }
    return $tocFiles[0]
}

if (-not (Test-Path -LiteralPath $policyPath)) {
    throw "Missing package policy file: $policyPath"
}

if (-not (Test-Path -LiteralPath $verifyScriptPath)) {
    throw "Missing package verifier script: $verifyScriptPath"
}

$tocFile = Get-AddonToc
$addonName = [System.IO.Path]::GetFileNameWithoutExtension($tocFile.Name)
$tocPath = $tocFile.FullName
$versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | Select-Object -First 1
$version = if ($versionLine -match '^##\s*Version:\s*(.+)$') { $Matches[1].Trim() } else { "dev" }

$outputRoot = Join-Path $repoRoot $OutputDir
$stageRoot = Join-Path $repoRoot ('internal_dev/scratch/package-' + [guid]::NewGuid().ToString('N'))
$stageAddonRoot = Join-Path $stageRoot $addonName
$zipPath = Join-Path $outputRoot "$addonName-$version.zip"

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$publicRoots = @($policy.includeRoots)
$publicFiles = @($policy.includeFiles | ForEach-Object {
    if ($_ -eq "<toc>") { $tocFile.Name } else { $_ }
})
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

    $rootPrefix = $resolvedRoot.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
    $isRoot = $resolvedPath.Equals($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $isRoot -and -not $resolvedPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
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

    $source = Join-Path $addonRoot $RelativePath
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
            $path = Join-Path $addonRoot $line
            if (-not (Test-Path -LiteralPath $path)) {
                $missing += $line
            }
        }
    }

    if ($missing.Count -gt 0) {
        throw "TOC references missing files: $($missing -join ', ')"
    }
}

# Releases contain the current distributable and previous public versions.
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'releases'))
$outputRoot = [IO.Path]::GetFullPath($outputRoot)
$releasePrefix = $releaseRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($outputRoot -ine $releaseRoot -and -not $outputRoot.StartsWith($releasePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Package output must be under releases.'
}

function Assert-PlainRepositoryPath {
    param([string]$Path)
    Assert-UnderRoot -Root $repoRoot -Path $Path
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing package operations through a filesystem link: $cursor"
            }
        }
        if ($cursor -ieq $repoRoot) { break }
        $cursor = Split-Path -Parent $cursor
    }
}

$historyRoot = Join-Path $outputRoot 'previous_versions'
Assert-PlainRepositoryPath $outputRoot
Assert-PlainRepositoryPath $historyRoot
Assert-PlainRepositoryPath $stageRoot
if (Test-Path -LiteralPath $stageRoot) { throw 'Unique package staging directory already exists.' }
if (Test-Path -LiteralPath $outputRoot) {
    $unexpected = @(Get-ChildItem -LiteralPath $outputRoot -Force | Where-Object {
        if ($_.PSIsContainer) { $_.Name -ne 'previous_versions' }
        else { $_.Extension -ne '.zip' -and $_.Name -ne '.gitkeep' }
    })
    if ($unexpected.Count) { throw "Non-release artifacts in output: $($unexpected.Name -join ', ')" }

}
$archivePlan = @()
if (Test-Path -LiteralPath $outputRoot) {
    foreach ($old in Get-ChildItem -LiteralPath $outputRoot -File -Filter "$addonName-*.zip") {
        if ($old.FullName -ieq $zipPath) { continue }
        $destination = Join-Path $historyRoot $old.Name
        Assert-PlainRepositoryPath $old.FullName
        Assert-PlainRepositoryPath $destination
        $alreadyStored = Test-Path -LiteralPath $destination
        if ($alreadyStored -and ((Get-Item -LiteralPath $destination).PSIsContainer -or
            (Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath $old.FullName).Hash)) {
            throw "Previous-version collision; refusing to overwrite: $($old.Name)"
        }
        $archivePlan += [pscustomobject]@{ Source = $old.FullName; Destination = $destination; AlreadyStored = $alreadyStored }
    }
}
Test-TocReferences

try {
    New-Item -ItemType Directory -Force -Path $stageAddonRoot | Out-Null

    foreach ($file in $publicFiles) {
        Copy-PublicItem -RelativePath $file
    }

    foreach ($root in $publicRoots) {
        Copy-PublicItem -RelativePath $root
    }

    # Verify the new candidate before publishing it or moving previous versions.
    $candidateZip = Join-Path $stageRoot "$addonName-$version.zip"
    Compress-Archive -LiteralPath $stageAddonRoot -DestinationPath $candidateZip -CompressionLevel Optimal
    & pwsh.exe -NoProfile -File $verifyScriptPath $candidateZip
    if ($LASTEXITCODE -ne 0) {
        throw "Package verification failed with exit code $LASTEXITCODE."
    }
    Assert-PlainRepositoryPath $zipPath
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    Move-Item -LiteralPath $candidateZip -Destination $zipPath -Force
    if ($archivePlan.Count) {
        New-Item -ItemType Directory -Path $historyRoot -Force | Out-Null
        foreach ($item in $archivePlan) {
            if ($item.AlreadyStored) {
                Remove-Item -LiteralPath $item.Source
            } else {
                Move-Item -LiteralPath $item.Source -Destination $item.Destination
            }
        }
    }

} finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Assert-PlainRepositoryPath $stageRoot
        if ($KeepStage) {
            Write-Host "Staging retained: $stageRoot"
        } else {
            $links = @(Get-ChildItem -LiteralPath $stageRoot -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
            if ($links.Count) { throw 'Refusing to clean linked staging contents.' }
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
    }
}
$zipItem = Get-Item -LiteralPath $zipPath
Write-Host "Created $($zipItem.FullName)"
Write-Host "Version $version"
Write-Host "Size $([Math]::Round($zipItem.Length / 1MB, 2)) MB"
