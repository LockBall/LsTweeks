# Advisory, offline foundation discovery. Never fetches, copies, or updates review state.
#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [string]$ManifestFile = 'development_manifest.json',
    [string]$LocalConfigFile = 'internal_dev/foundation_checkout.json',
    [ValidateRange(1,50)][int]$MaxPaths = 5,
    [switch]$AsJson
)
$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$result = [ordered]@{
    status = 'unconfigured'; reviewedCommit = $null; availableCommit = $null
    trackingStartCommit = $null; comparisonCommit = $null; checkpointKind = 'none'
    sourceDirty = $false; adoptionSourceDirty = $false
    changedPathCount = 0; paths = @(); message = ''
}
function Resolve-ProjectMetadataPath {
    param([string]$Relative)
    if ([IO.Path]::IsPathRooted($Relative)) { throw 'Metadata path must be project-relative.' }
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    $relativePath = [IO.Path]::GetRelativePath($rootPath,$path)
    if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '^\.\.([\\/]|$)') {
        throw 'Metadata path must remain inside the project.'
    }
    $partPath = $rootPath
    foreach ($part in ($relativePath -split '[\\/]')) {
        $partPath = Join-Path $partPath $part
        if ((Test-Path -LiteralPath $partPath) -and
            ((Get-Item -LiteralPath $partPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Linked metadata paths are not supported.'
        }
    }
    return $path
}
function Read-ProjectJson {
    param([string]$Relative)
    $path = Resolve-ProjectMetadataPath $Relative
    $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [pscustomobject]) { throw 'Project metadata must be a JSON object.' }
    return $parsed
}
function Read-SourceGit {
    param([string[]]$Arguments)
    # Disable optional index refresh and configured fsmonitor execution for read-only discovery.
    $gitOptions = @('--no-optional-locks','-c','core.fsmonitor=false')
    if ($script:trustCheckout) { $gitOptions += @('-c',"safe.directory=$script:checkout") }
    $output = @(& git @gitOptions -C $script:checkout @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect configured foundation Git checkout; check access, ownership, and checkpoint availability.' }
    return $output
}
function Get-Discovery {
    $manifest = Read-ProjectJson $ManifestFile
    $result.adoptionSourceDirty = $manifest.foundationSourceDirty -eq $true
    $result.reviewedCommit = $manifest.foundationReview.lastReviewedCommit
    $result.trackingStartCommit = $manifest.foundationReview.trackingStartCommit
    foreach ($field in @('reviewedCommit','trackingStartCommit')) {
        $commit = $result[$field]
        if ($null -ne $commit -and ($commit -isnot [string] -or $commit -notmatch '^[0-9a-fA-F]{40,64}$')) {
            throw 'Tracking/review checkpoints must be full Git commit ID strings or null.'
        }
    }
    $checkpoint = $null
    if ($result.reviewedCommit) {
        $checkpoint = $result.reviewedCommit; $result.checkpointKind = 'reviewed'
    } elseif ($result.trackingStartCommit) {
        $checkpoint = $result.trackingStartCommit; $result.checkpointKind = 'tracking-start'
    }
    $result.comparisonCommit = $checkpoint
    $configPath = Resolve-ProjectMetadataPath $LocalConfigFile
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        $result.message = "Configure $LocalConfigFile with checkoutPath to enable offline discovery."
        return
    }
    $config = Read-ProjectJson $LocalConfigFile
    if ($null -ne $config.trustCheckout -and $config.trustCheckout -isnot [bool]) {
        throw 'trustCheckout must be a JSON boolean.'
    }
    $script:trustCheckout = $config.trustCheckout -eq $true
    if (-not ($config.checkoutPath -is [string]) -or [string]::IsNullOrWhiteSpace($config.checkoutPath)) {
        throw 'Local foundation configuration requires checkoutPath.'
    }
    $script:checkout = if ([IO.Path]::IsPathRooted($config.checkoutPath)) {
        [IO.Path]::GetFullPath($config.checkoutPath)
    } else { [IO.Path]::GetFullPath((Join-Path $rootPath $config.checkoutPath)) }
    if (-not (Test-Path -LiteralPath $script:checkout -PathType Container)) {
        $result.status = 'unavailable'; $result.message = 'Configured local checkout is missing; no network refresh was attempted.'
        return
    }
    $sourceRelative = [IO.Path]::GetRelativePath($rootPath,$script:checkout)
    if ($sourceRelative -eq '.' -or (-not [IO.Path]::IsPathRooted($sourceRelative) -and $sourceRelative -notmatch '^\.\.([\\/]|$)')) {
        throw 'Foundation discovery requires a separate checkout, not this project or its copied snapshot.'
    }
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Git is unavailable.' }
    $gitRoot = (Read-SourceGit @('rev-parse','--show-toplevel') | Select-Object -First 1).Trim()
    if ([IO.Path]::GetRelativePath($script:checkout,[IO.Path]::GetFullPath($gitRoot)) -ne '.') {
        throw 'Configured foundation directory must be a Git repository root.'
    }
    foreach ($marker in @('development_manifest.json','core_policy/evolution.md','bootstrap/create_project.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:checkout $marker) -PathType Leaf)) { throw 'Configured checkout is not a foundation distribution.' }
    }
    $result.availableCommit = (Read-SourceGit @('rev-parse','HEAD') | Select-Object -First 1).Trim()
    $scopes = @('core_policy','templates','bootstrap/create_project.ps1','bootstrap/foundation_update_status.ps1','development_manifest.json')
    foreach ($package in @($manifest.selectedPackages)) {
        if ($package -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid selected package identifier.' }
        $scopes += "languages/$package"
    }
    foreach ($environment in @($manifest.selectedEnvironments)) {
        if ($environment -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid selected environment identifier.' }
        $scopes += "environments/$environment"
    }
    if ($manifest.personalPreferencesAdopted -eq $true) { $scopes += 'preferences/personal.md' }
    $dirtyPaths = @(Read-SourceGit (@('status','--porcelain','--untracked-files=all','--') + $scopes))
    $result.sourceDirty = $dirtyPaths.Count -gt 0
    if (-not $checkpoint) {
        $result.status = 'unreviewed'
        $result.message = 'Choose an explicit tracking start or record a completed review. Neither requires claiming snapshot adoption.'
        return
    }
    $null = Read-SourceGit @('cat-file','-e',"${checkpoint}^{commit}")
    # Refuse to present unrelated/rebased histories as an ordinary upgrade.
    $null = Read-SourceGit @('merge-base','--is-ancestor',$checkpoint,'HEAD')
    $changed = @(Read-SourceGit (@('diff','--no-ext-diff','--no-textconv','--name-only',$checkpoint,'HEAD','--') + $scopes))
    $result.changedPathCount = $changed.Count
    $result.paths = @($changed | Select-Object -First $MaxPaths)
    if ($result.sourceDirty) {
        $result.status = 'source-dirty'
        $result.message = 'Relevant uncommitted source changes exist. A commit checkpoint cannot acknowledge them; inspect actual files and do not auto-adopt.'
    } elseif ($changed.Count) {
        $result.status = 'review-needed'
        $result.message = 'Review these candidates against project scope and local overrides; no adoption was performed.'
    } elseif ($checkpoint -eq $result.availableCommit) {
        $result.status = 'current'; $result.message = 'No committed changes since the comparison checkpoint.'
    } else {
        $result.status = 'no-applicable-changes'; $result.message = 'Only unselected or foundation-internal paths changed.'
    }
    if ($result.checkpointKind -eq 'tracking-start') {
        $result.message += ' Comparison starts at an explicitly selected commit; this does not claim older guidance was reviewed or adopted.'
    }
    if ($result.adoptionSourceDirty) {
        $result.message += ' Original adoption included dirty source; preserve that provenance and compare copied files when reviewing.'
    }
}
try { Get-Discovery } catch {
    $result.status = 'unavailable'
    $result.message = $_.Exception.Message
}
if ($AsJson) { [pscustomobject]$result | ConvertTo-Json -Depth 5; return }
Write-Output "Foundation update check: $($result.status). $($result.message)"
if ($result.comparisonCommit -and $result.availableCommit) {
    Write-Output "Foundation $($result.checkpointKind) checkpoint $($result.comparisonCommit.Substring(0,8)); available $($result.availableCommit.Substring(0,8))."
}
foreach ($path in $result.paths) { Write-Output "  $path" }
if ($result.changedPathCount -gt $result.paths.Count) { Write-Output "  ... $($result.changedPathCount - $result.paths.Count) more relevant paths; use the review workflow for a scoped diff." }
if ($result.status -in @('review-needed','source-dirty','unreviewed')) {
    Write-Output 'Review route: adopted core_policy/evolution.md, or the configured checkout core_policy/evolution.md for an existing project without a snapshot. Discovery is advisory; continue unrelated authorized work.'
}
