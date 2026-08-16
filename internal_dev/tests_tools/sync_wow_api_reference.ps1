[CmdletBinding()]
param(
    [ValidateSet("live", "ptr", "beta")]
    [string]$Channel = "live",

    [switch]$SkipKethoUpdate,

    [switch]$StatusOnly,

    [switch]$CompactStatus,

    [switch]$AllowInterfaceMismatch,

    [Parameter(DontShow = $true)]
    [string]$SourceRepository,

    [Parameter(DontShow = $true)]
    [string]$CacheDirectory,

    [Parameter(DontShow = $true)]
    [string]$TocFile,

    [Parameter(DontShow = $true)]
    [string]$ExtensionsDirectory
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cacheRoot = if ($CacheDirectory) { $CacheDirectory } else { Join-Path $PSScriptRoot ".wow-api-source" }
$sourceRoot = Join-Path $cacheRoot $Channel
$sourceRepo = if ($SourceRepository) { $SourceRepository } else { "https://github.com/Gethe/wow-ui-source.git" }
$tocPath = if ($TocFile) { $TocFile } else { Join-Path $repoRoot "LsTweeks.toc" }
$extensionsRoot = if ($ExtensionsDirectory) { $ExtensionsDirectory } else { Join-Path $env:USERPROFILE ".vscode\extensions" }
$statePath = Join-Path $cacheRoot "sync-state-$Channel.json"

function Invoke-NativeVisible {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }

    return @($output)
}

function Get-TocInterfaces {
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        throw "AddOn TOC file was not found: $tocPath"
    }

    foreach ($line in [System.IO.File]::ReadAllLines($tocPath)) {
        if ($line -notmatch "^##\s+Interface:\s*(.+)$") { continue }

        $interfaces = @($Matches[1] -split "[,\s]+" | Where-Object { $_ -match "^\d+$" })
        if ($interfaces.Count -eq 0) {
            throw "No numeric interface values found in: $tocPath"
        }
        return $interfaces
    }

    throw "No Interface declaration found in: $tocPath"
}

function Convert-WowVersionToInterface {
    param([Parameter(Mandatory = $true)][string]$Version)

    if ($Version -notmatch "^(\d+)\.(\d+)\.(\d+)(?:\.|$)") {
        throw "Could not derive an interface number from WoW version '$Version'."
    }

    return "{0:D2}{1:D2}{2:D2}" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]
}

function Get-SyncState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $null }

    try {
        return Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    }
    catch {
        throw "Could not read API reference sync receipt: $statePath"
    }
}

function Get-KethoInfo {
    $candidates = Get-ChildItem -LiteralPath $extensionsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "ketho.wow-api-*" } |
        ForEach-Object {
            $packagePath = Join-Path $_.FullName "package.json"
            if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { return }

            $package = Get-Content -Raw -LiteralPath $packagePath | ConvertFrom-Json
            try {
                $semanticVersion = [version]$package.version
            }
            catch {
                return
            }

            [pscustomobject]@{
                Path = $_.FullName
                Version = [string]$package.version
                SemanticVersion = $semanticVersion
            }
        } |
        Sort-Object SemanticVersion -Descending

    $current = $candidates | Select-Object -First 1
    if (-not $current) { return $null }

    $declaredMainline = $null
    $readmePath = Join-Path $current.Path "README.md"
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $readme = [System.IO.File]::ReadAllText($readmePath)
        if ($readme -match "mainline-([0-9]+(?:\.[0-9]+)+)-") {
            $declaredMainline = $Matches[1]
        }
    }

    return [pscustomobject]@{
        Path = $current.Path
        Version = $current.Version
        DeclaredMainline = $declaredMainline
    }
}

function Get-SourceInfo {
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        return $null
    }

    $gitMarker = Join-Path $sourceRoot ".git"
    if (-not (Test-Path -LiteralPath $gitMarker)) {
        throw "API source path exists but is not a Git checkout: $sourceRoot"
    }

    $versionPath = Join-Path $sourceRoot "version.txt"
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "API source checkout has no version.txt: $sourceRoot"
    }

    $commit = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $sourceRoot, "rev-parse", "HEAD"))[0]
    $commitDate = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $sourceRoot, "log", "-1", "--format=%cI"))[0]
    $version = [System.IO.File]::ReadAllText($versionPath).Trim()
    $sourceInterface = Convert-WowVersionToInterface -Version $version
    $tocInterfaces = @(Get-TocInterfaces)

    return [pscustomobject]@{
        Path = $sourceRoot
        Version = $version
        Interface = $sourceInterface
        TocInterfaces = $tocInterfaces
        InterfaceMatchesToc = $tocInterfaces -contains $sourceInterface
        Commit = $commit
        CommitDate = $commitDate
    }
}

function Write-SyncState {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Ketho,
        [Parameter(Mandatory = $true)]$Source
    )

    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot | Out-Null
    }

    $state = [ordered]@{
        schemaVersion = 1
        refreshedAtUtc = [DateTime]::UtcNow.ToString("o")
        channel = $Channel
        sourceVersion = $Source.Version
        sourceInterface = $Source.Interface
        sourceCommit = $Source.Commit
        sourceCommitDate = $Source.CommitDate
        tocInterfaces = @($Source.TocInterfaces)
        kethoVersion = if ($Ketho) { $Ketho.Version } else { $null }
        kethoDeclaredMainline = if ($Ketho) { $Ketho.DeclaredMainline } else { $null }
    }
    $json = $state | ConvertTo-Json -Depth 3
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($statePath, $json + "`n", $utf8NoBom)
}

function Write-ReferenceStatus {
    $ketho = Get-KethoInfo
    $source = Get-SourceInfo
    $state = Get-SyncState
    $refreshUtc = if ($state -and $state.refreshedAtUtc -is [DateTime]) {
        $state.refreshedAtUtc.ToUniversalTime().ToString("o")
    }
    elseif ($state) {
        [string]$state.refreshedAtUtc
    }
    else {
        $null
    }

    if ($CompactStatus) {
        $kethoSummary = if ($ketho) { "$($ketho.Version)/$($ketho.DeclaredMainline)" } else { "missing" }
        if ($source) {
            $match = if ($source.InterfaceMatchesToc) { "toc-match" } else { "TOC-MISMATCH" }
            $receipt = if ($state) { $refreshUtc } else { "missing-receipt" }
            Write-Output "WoW API reference: $Channel $($source.Version) $($source.Commit.Substring(0, 8)) $match; refreshed=$receipt; Ketho=$kethoSummary"
            if ($state -and $state.sourceCommit -ne $source.Commit) {
                Write-Warning "The source checkout commit differs from its last successful refresh receipt."
            }
        }
        else {
            Write-Output "WoW API reference: $Channel source missing; Ketho=$kethoSummary"
        }
        return
    }

    Write-Output "Ketho annotations"
    if ($ketho) {
        $declared = if ($ketho.DeclaredMainline) { $ketho.DeclaredMainline } else { "unknown" }
        Write-Output "  Extension: $($ketho.Version)"
        Write-Output "  Declared mainline: $declared"
        Write-Output "  Path: $($ketho.Path)"
    }
    else {
        Write-Output "  Missing"
    }

    Write-Output ""
    Write-Output "WoW UI source ($Channel)"
    if ($source) {
        Write-Output "  Client: $($source.Version)"
        $tocMatch = if ($source.InterfaceMatchesToc) { "match" } else { "MISMATCH" }
        Write-Output "  Interface: $($source.Interface) ($tocMatch; TOC: $($source.TocInterfaces -join ', '))"
        Write-Output "  Commit: $($source.Commit)"
        Write-Output "  Commit date: $($source.CommitDate)"
        Write-Output "  Path: $($source.Path)"
    }
    else {
        Write-Output "  Missing: run this script without -StatusOnly to create it."
    }

    Write-Output ""
    Write-Output "Refresh receipt"
    if ($state) {
        Write-Output "  Last success: $refreshUtc"
        Write-Output "  Recorded commit: $($state.sourceCommit)"
        if ($source -and $state.sourceCommit -ne $source.Commit) {
            Write-Warning "The source checkout commit differs from its last successful refresh receipt."
        }
    }
    else {
        Write-Output "  Missing"
    }

    if ($source -and -not $source.InterfaceMatchesToc) {
        Write-Warning "The $Channel source interface $($source.Interface) is not declared in LsTweeks.toc ($($source.TocInterfaces -join ', '))."
    }

    if ($ketho -and $source -and $ketho.DeclaredMainline) {
        $sourcePatch = (($source.Version -split "\.")[0..2] -join ".")
        if ($ketho.DeclaredMainline -ne $sourcePatch) {
            Write-Warning "Ketho declares $($ketho.DeclaredMainline), but the $Channel source is $sourcePatch. Treat Ketho as a typing aid only for patch-sensitive APIs."
        }
    }
}

if ($StatusOnly) {
    Write-ReferenceStatus
    exit 0
}

if (-not $SkipKethoUpdate) {
    $codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    }
    if (-not $codeCommand) {
        throw "VS Code CLI was not found. Rerun with -SkipKethoUpdate to refresh only the WoW UI source."
    }

    Write-Output "==> Refreshing the published Ketho extension"
    Invoke-NativeVisible -Command $codeCommand.Source -Arguments @("--install-extension", "ketho.wow-api", "--force")
}

if (Test-Path -LiteralPath $sourceRoot) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot ".git"))) {
        throw "Refusing to replace non-Git API source path: $sourceRoot"
    }

    $origin = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $sourceRoot, "remote", "get-url", "origin"))[0]
    $originNormalized = $origin.TrimEnd("/")
    $sourceRepoWithoutSuffix = $sourceRepo -replace "\.git$", ""
    if ($originNormalized -notin @($sourceRepo, $sourceRepoWithoutSuffix)) {
        throw "Unexpected API source origin '$origin' at $sourceRoot"
    }

    $branch = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $sourceRoot, "branch", "--show-current"))[0]
    if ($branch -ne $Channel) {
        throw "API source checkout is on '$branch', expected '$Channel': $sourceRoot"
    }

    $dirty = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $sourceRoot, "status", "--porcelain"))
    if ($dirty.Count -gt 0) {
        throw "API source checkout has local changes; refusing to update: $sourceRoot"
    }

    Write-Output "==> Fast-forwarding WoW UI source channel '$Channel'"
    Invoke-NativeVisible -Command "git" -Arguments @("-C", $sourceRoot, "pull", "--ff-only", "origin", $Channel)
}
else {
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot | Out-Null
    }

    Write-Output "==> Cloning WoW UI source channel '$Channel'"
    Invoke-NativeVisible -Command "git" -Arguments @(
        "clone",
        "--depth", "1",
        "--single-branch",
        "--branch", $Channel,
        $sourceRepo,
        $sourceRoot
    )
}

$refreshedSource = Get-SourceInfo
if (-not $refreshedSource.InterfaceMatchesToc -and -not $AllowInterfaceMismatch) {
    throw "The $Channel source interface $($refreshedSource.Interface) is not declared in LsTweeks.toc ($($refreshedSource.TocInterfaces -join ', ')). Use -AllowInterfaceMismatch only for intentional future-channel research."
}
Write-SyncState -Ketho (Get-KethoInfo) -Source $refreshedSource

Write-Output ""
Write-ReferenceStatus
Write-Output ""
Write-Output "Search current API docs and FrameXML with:"
Write-Output "  rg -n '<API-or-symbol>' '$sourceRoot\Interface'"
