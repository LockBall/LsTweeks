[CmdletBinding()]
param(
    [ValidateSet("live", "ptr")]
    [string]$Channel = "live",

    [switch]$StatusOnly,

    [Parameter(DontShow = $true)]
    [string]$CacheDirectory,

    [Parameter(DontShow = $true)]
    [string]$SourceDirectory,

    [Parameter(DontShow = $true)]
    [string]$WslDistribution = "Ubuntu-26.04"
)

$ErrorActionPreference = "Stop"

$cacheRoot = if ($CacheDirectory) { $CacheDirectory } else { Join-Path $PSScriptRoot ".wow-api-source" }
$sourceRoot = if ($SourceDirectory) { $SourceDirectory } else { Join-Path $cacheRoot $Channel }
$generatorRoot = Join-Path $cacheRoot "ketho-$Channel"
$frameXmlRoot = Join-Path $cacheRoot "framexml-annotations-$Channel"
$resourceRoot = Join-Path $cacheRoot "blizzard-interface-resources-$Channel"
$statePath = Join-Path $cacheRoot "annotation-state-$Channel.json"
$wrapperPath = Join-Path $PSScriptRoot "lua_checks\kethos\generate_annotations.lua"

$product = switch ($Channel) {
    "live" { "wow" }
    "ptr" { "wowt" }
}
$frameXmlBranch = $Channel

function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& $Command @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Get-GitCommit {
    param([Parameter(Mandatory = $true)][string]$Path)
    return @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $Path, "rev-parse", "HEAD"))[0]
}

function Sync-CleanCheckout {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Invoke-NativeCapture -Command "git" -Arguments @(
            "clone", "-c", "core.longpaths=true", "--depth", "1", "--single-branch", "--branch", $Branch, $Repository, $Path
        ) | Out-Null
    }
    elseif (-not (Test-Path -LiteralPath (Join-Path $Path ".git"))) {
        throw "Managed annotation path is not a Git checkout: $Path"
    }

    $origin = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $Path, "remote", "get-url", "origin"))[0]
    if (($origin.TrimEnd("/") -replace "\.git$", "") -ne ($Repository.TrimEnd("/") -replace "\.git$", "")) {
        throw "Unexpected annotation origin '$origin' at $Path"
    }

    $currentBranch = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $Path, "branch", "--show-current"))[0]
    if ($currentBranch -ne $Branch) {
        throw "Annotation checkout is on '$currentBranch', expected '$Branch': $Path"
    }

    $dirty = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $Path, "status", "--porcelain"))
    if ($dirty.Count -gt 0) {
        throw "Managed annotation checkout has local changes: $Path"
    }

    Invoke-NativeCapture -Command "git" -Arguments @("-C", $Path, "pull", "--ff-only", "origin", $Branch) | Out-Null
    return Get-GitCommit -Path $Path
}

function Get-RemoteCommit {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    $line = @(Invoke-NativeCapture -Command "git" -Arguments @("ls-remote", $Repository, "refs/heads/$Branch"))[0]
    if ($line -notmatch "^([0-9a-f]{40})\s") {
        throw "Could not resolve $Repository branch '$Branch'."
    }
    return $Matches[1]
}

function Convert-ToWslPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return @(Invoke-NativeCapture -Command "wsl.exe" -Arguments @("-d", $WslDistribution, "--", "wslpath", "-a", $Path))[0]
}

function Quote-Bash {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + $Value.Replace("'", "'`"'`"'") + "'"
}

function Remove-ManagedGeneratorPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $requiredPrefix = [System.IO.Path]::GetFullPath($generatorRoot).TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear generated path outside the Ketho checkout: $resolvedPath"
    }
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Get-AnnotationState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

function Write-AnnotationStatus {
    $state = Get-AnnotationState
    if (-not $state) {
        Write-Output "Generated annotations ($Channel): missing"
        return
    }

    $generatedUtc = if ($state.generatedAtUtc -is [DateTime]) {
        $state.generatedAtUtc.ToUniversalTime().ToString("o")
    } else { [string]$state.generatedAtUtc }
    Write-Output "Generated annotations ($Channel)"
    Write-Output "  Generated: $generatedUtc"
    Write-Output "  WoW source: $($state.sourceCommit)"
    Write-Output "  Ketho generator: $($state.generatorCommit)"
    Write-Output "  Local generator wrapper: $($state.wrapperHash)"
    Write-Output "  BlizzardInterfaceResources: $($state.blizzardResourcesCommit)"
    Write-Output "  FrameXML annotations: $($state.frameXmlCommit)"
    Write-Output "  Core: $($state.corePath)"
    Write-Output "  FrameXML: $($state.frameXmlPath)"
}

if ($StatusOnly) {
    Write-AnnotationStatus
    exit 0
}

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Managed WoW source is missing: $sourceRoot"
}
if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
    throw "Ketho generation wrapper is missing: $wrapperPath"
}
if (-not (Test-Path -LiteralPath $cacheRoot)) {
    New-Item -ItemType Directory -Path $cacheRoot | Out-Null
}

Write-Output "==> Refreshing Ketho generator source"
if (-not (Test-Path -LiteralPath $generatorRoot)) {
    Invoke-NativeCapture -Command "git" -Arguments @(
        "clone", "--filter=blob:none", "--sparse", "--depth", "1", "--single-branch", "--branch", "master",
        "https://github.com/Ketho/vscode-wow-api.git", $generatorRoot
    ) | Out-Null
}
elseif (-not (Test-Path -LiteralPath (Join-Path $generatorRoot ".git"))) {
    throw "Managed Ketho path is not a Git checkout: $generatorRoot"
}
$generatorOrigin = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "remote", "get-url", "origin"))[0]
if (($generatorOrigin.TrimEnd("/") -replace "\.git$", "") -ne "https://github.com/Ketho/vscode-wow-api") {
    throw "Unexpected Ketho generator origin '$generatorOrigin' at $generatorRoot"
}
$generatorBranch = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "branch", "--show-current"))[0]
if ($generatorBranch -ne "master") {
    throw "Ketho generator checkout is on '$generatorBranch', expected 'master': $generatorRoot"
}
Invoke-NativeCapture -Command "git" -Arguments @(
    "-C", $generatorRoot, "sparse-checkout", "set", "--cone", "Annotations/Core", "luasrc", "wowdoc"
) | Out-Null
$generatorChanges = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "status", "--porcelain"))
foreach ($change in $generatorChanges) {
    $path = $change.Substring(3) -replace "\\", "/"
    if ($path -notlike "Annotations/Core/Blizzard_APIDocumentationGenerated/*" -and
        $path -notin @("Annotations/Core/Data/CVar.lua", "Annotations/Core/Data/Enum.lua", "Annotations/Core/Data/Event.lua")) {
        throw "Unexpected local change in the managed Ketho generator checkout: $change"
    }
}
Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "fetch", "origin", "master") | Out-Null
$generatorCommit = @(Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "rev-parse", "origin/master"))[0]

Write-Output "==> Refreshing FrameXML annotations"
$frameXmlCommit = Sync-CleanCheckout -Path $frameXmlRoot -Repository "https://github.com/NumyAddon/FramexmlAnnotations.git" -Branch $frameXmlBranch
$sourceCommit = Get-GitCommit -Path $sourceRoot
$resourcesCommit = Get-RemoteCommit -Repository "https://github.com/Ketho/BlizzardInterfaceResources.git" -Branch $Channel
$wrapperHash = (Get-FileHash -LiteralPath $wrapperPath -Algorithm SHA256).Hash.ToLowerInvariant()

$state = Get-AnnotationState
$corePath = Join-Path $generatorRoot "Annotations\Core"
$frameXmlPath = $frameXmlRoot
$generatedOut = Join-Path $generatorRoot "luasrc\out"
$transientWow = Join-Path $generatorRoot ".wow"
$needsGeneration = -not $state -or
    $state.schemaVersion -ne 2 -or
    $state.sourceCommit -ne $sourceCommit -or
    $state.generatorCommit -ne $generatorCommit -or
    $state.wrapperHash -ne $wrapperHash -or
    $state.blizzardResourcesCommit -ne $resourcesCommit -or
    $state.frameXmlCommit -ne $frameXmlCommit -or
    -not (Test-Path -LiteralPath $corePath -PathType Container)

if (-not $needsGeneration) {
    Remove-ManagedGeneratorPath -Path $generatedOut
    Remove-ManagedGeneratorPath -Path $transientWow
    Write-Output "==> Generated annotations already match all upstream commits"
    Write-Output ""
    Write-AnnotationStatus
    exit 0
}

$toolchainCheck = @(& wsl.exe -d $WslDistribution -- bash -lc "test -x ~/.local/share/lstweeks-ketho/.lua/bin/lua" 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "The WSL Ketho Lua toolchain is missing. Run setup_wow_annotations_wsl.ps1 once."
}

Write-Output "==> Preparing exact BlizzardInterfaceResources inputs"
$resourcesDirectory = Join-Path $resourceRoot "Resources"
New-Item -ItemType Directory -Path $resourcesDirectory -Force | Out-Null
foreach ($fileName in @("LuaEnum.lua", "CVars.lua")) {
    $url = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/$resourcesCommit/Resources/$fileName"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $resourcesDirectory $fileName)
}

Write-Output "==> Generating current LuaLS annotations"
Invoke-NativeCapture -Command "git" -Arguments @("-C", $generatorRoot, "reset", "--hard", $generatorCommit) | Out-Null

$generatedDocs = Join-Path $corePath "Blizzard_APIDocumentationGenerated"
foreach ($target in @($generatedDocs, $generatedOut, $transientWow)) {
    Remove-ManagedGeneratorPath -Path $target
}
New-Item -ItemType Directory -Path $generatedDocs -Force | Out-Null

$sourceLink = Join-Path $generatorRoot "wow-ui-source"
if (Test-Path -LiteralPath $sourceLink) {
    $item = Get-Item -LiteralPath $sourceLink -Force
    if ($item.LinkType -ne "Junction" -or [System.IO.Path]::GetFullPath($item.Target) -ne [System.IO.Path]::GetFullPath($sourceRoot)) {
        throw "Managed Ketho source link has an unexpected target: $sourceLink"
    }
}
else {
    New-Item -ItemType Junction -Path $sourceLink -Target $sourceRoot | Out-Null
}

$generatorWsl = Convert-ToWslPath -Path $generatorRoot
$wrapperWsl = Convert-ToWslPath -Path $wrapperPath
$resourcesWsl = Convert-ToWslPath -Path $resourcesDirectory
$bashCommand = ". ~/.local/share/lstweeks-ketho/.lua/bin/activate; cd $(Quote-Bash $generatorWsl); lua $(Quote-Bash $wrapperWsl) $(Quote-Bash $product) $(Quote-Bash $Channel) $(Quote-Bash $resourcesWsl)"
$generationOutput = @(& wsl.exe -d $WslDistribution -- bash -lc $bashCommand 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Ketho annotation generation failed:`n$($generationOutput -join [Environment]::NewLine)"
}

foreach ($requiredPath in @(
    (Join-Path $corePath "Blizzard_APIDocumentationGenerated\UnitAuraDocumentation.lua"),
    (Join-Path $corePath "Data\Enum.lua"),
    $frameXmlPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Generated annotation output is incomplete: $requiredPath"
    }
}

foreach ($target in @($generatedOut, $transientWow)) {
    Remove-ManagedGeneratorPath -Path $target
}

$annotationState = [ordered]@{
    schemaVersion = 2
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    channel = $Channel
    sourceCommit = $sourceCommit
    generatorCommit = $generatorCommit
    wrapperHash = $wrapperHash
    blizzardResourcesCommit = $resourcesCommit
    frameXmlCommit = $frameXmlCommit
    sourceInterfacePath = (Join-Path $sourceRoot "Interface")
    corePath = $corePath
    frameXmlPath = $frameXmlPath
}
$json = $annotationState | ConvertTo-Json -Depth 3
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($statePath, $json + "`n", $utf8NoBom)

Write-Output ""
Write-AnnotationStatus
