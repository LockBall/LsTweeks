$ErrorActionPreference = "Stop"

$syncScript = Join-Path $PSScriptRoot "sync_wow_api_reference.ps1"
$tempBase = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".wow-api-test"))
$testRoot = Join-Path $tempBase ("lstweaks-wow-api-reference-" + [guid]::NewGuid().ToString("N"))
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$passed = 0

function Write-TestFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Invoke-TestGit {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = & git -C $Repository @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git failed in '$Repository': $($output -join [Environment]::NewLine)"
    }
    return @($output)
}

function New-TestOrigin {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Channel,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $origin = Join-Path $testRoot "origins\$Name"
    New-Item -ItemType Directory -Path $origin | Out-Null
    $initOutput = & git init --initial-branch=$Channel $origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git init failed: $($initOutput -join [Environment]::NewLine)"
    }
    Write-TestFile -Path (Join-Path $origin "version.txt") -Text "$Version`n"
    Invoke-TestGit -Repository $origin -Arguments @("add", "version.txt") | Out-Null
    Invoke-TestGit -Repository $origin -Arguments @(
        "-c", "user.name=LsTweeks Test",
        "-c", "user.email=lstweaks@example.invalid",
        "commit", "-m", "initial"
    ) | Out-Null
    return ([System.Uri]$origin).AbsoluteUri
}

function New-TestToc {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Interfaces
    )

    $tocPath = Join-Path $testRoot "tocs\$Name.toc"
    Write-TestFile -Path $tocPath -Text "## Interface: $($Interfaces -join ', ')`n"
    return $tocPath
}

function Invoke-TestSync {
    param(
        [Parameter(Mandatory = $true)][string]$Channel,
        [Parameter(Mandatory = $true)][string]$Origin,
        [Parameter(Mandatory = $true)][string]$Cache,
        [Parameter(Mandatory = $true)][string]$Toc,
        [int]$ExpectedExitCode = 0,
        [string[]]$ExtraArguments = @()
    )

    $extensions = Join-Path $testRoot "empty-extensions"
    if (-not (Test-Path -LiteralPath $extensions)) {
        New-Item -ItemType Directory -Path $extensions | Out-Null
    }
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $syncScript,
        "-Channel", $Channel,
        "-SkipKethoUpdate",
        "-SourceRepository", $Origin,
        "-CacheDirectory", $Cache,
        "-TocFile", $Toc,
        "-ExtensionsDirectory", $extensions
    ) + $ExtraArguments

    $output = & pwsh.exe @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($exitCode -ne $ExpectedExitCode) {
        throw "sync exit $exitCode, expected ${ExpectedExitCode}:`n$text"
    }
    return $text
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Text -notmatch $Pattern) {
        throw "$Label did not match '$Pattern':`n$Text"
    }
}

function Pass {
    param([Parameter(Mandatory = $true)][string]$Label)
    $script:passed++
    Write-Output "PASS: $Label"
}

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $toc120100 = New-TestToc -Name "retail" -Interfaces @("120100")

    $liveOrigin = New-TestOrigin -Name "live" -Channel "live" -Version "12.1.0.70000"
    $liveCache = Join-Path $testRoot "cache-live"
    $initial = Invoke-TestSync -Channel "live" -Origin $liveOrigin -Cache $liveCache -Toc $toc120100
    Assert-Contains -Text $initial -Pattern "Interface: 120100 \(match" -Label "initial clone"
    if (-not (Test-Path -LiteralPath (Join-Path $liveCache "sync-state-live.json") -PathType Leaf)) {
        throw "initial clone did not write a refresh receipt"
    }
    Pass "matching initial clone writes receipt"

    $repeat = Invoke-TestSync -Channel "live" -Origin $liveOrigin -Cache $liveCache -Toc $toc120100
    Assert-Contains -Text $repeat -Pattern "Already up to date" -Label "repeat refresh"
    Pass "repeat refresh is a fast-forward no-op"

    $ptrOrigin = New-TestOrigin -Name "ptr" -Channel "ptr" -Version "12.1.0.70001"
    $ptrCache = Join-Path $testRoot "cache-ptr"
    $ptr = Invoke-TestSync -Channel "ptr" -Origin $ptrOrigin -Cache $ptrCache -Toc $toc120100
    Assert-Contains -Text $ptr -Pattern "WoW UI source \(ptr\)" -Label "alternate channel"
    Pass "alternate channel uses isolated cache"

    $betaOrigin = New-TestOrigin -Name "beta" -Channel "beta" -Version "13.0.0.70002"
    $betaCache = Join-Path $testRoot "cache-beta"
    $mismatch = Invoke-TestSync -Channel "beta" -Origin $betaOrigin -Cache $betaCache -Toc $toc120100 -ExpectedExitCode 1
    Assert-Contains -Text $mismatch -Pattern "is not declared in LsTweeks\.toc" -Label "interface mismatch"
    $allowed = Invoke-TestSync -Channel "beta" -Origin $betaOrigin -Cache $betaCache -Toc $toc120100 -ExtraArguments @("-AllowInterfaceMismatch")
    Assert-Contains -Text $allowed -Pattern "MISMATCH" -Label "allowed interface mismatch"
    Pass "interface mismatch fails unless explicitly allowed"

    $dirtyOrigin = New-TestOrigin -Name "dirty" -Channel "live" -Version "12.1.0.70003"
    $dirtyCache = Join-Path $testRoot "cache-dirty"
    Invoke-TestSync -Channel "live" -Origin $dirtyOrigin -Cache $dirtyCache -Toc $toc120100 | Out-Null
    Write-TestFile -Path (Join-Path $dirtyCache "live\local-change.txt") -Text "do not overwrite`n"
    $dirty = Invoke-TestSync -Channel "live" -Origin $dirtyOrigin -Cache $dirtyCache -Toc $toc120100 -ExpectedExitCode 1
    Assert-Contains -Text $dirty -Pattern "has local changes; refusing to update" -Label "dirty cache"
    Pass "dirty cache fails closed"

    $remoteOrigin = New-TestOrigin -Name "remote" -Channel "live" -Version "12.1.0.70004"
    $remoteCache = Join-Path $testRoot "cache-remote"
    Invoke-TestSync -Channel "live" -Origin $remoteOrigin -Cache $remoteCache -Toc $toc120100 | Out-Null
    Invoke-TestGit -Repository (Join-Path $remoteCache "live") -Arguments @("remote", "set-url", "origin", (Join-Path $testRoot "unexpected-origin")) | Out-Null
    $remote = Invoke-TestSync -Channel "live" -Origin $remoteOrigin -Cache $remoteCache -Toc $toc120100 -ExpectedExitCode 1
    Assert-Contains -Text $remote -Pattern "Unexpected API source origin" -Label "unexpected remote"
    Pass "unexpected remote fails closed"

    $branchOrigin = New-TestOrigin -Name "branch" -Channel "live" -Version "12.1.0.70005"
    $branchCache = Join-Path $testRoot "cache-branch"
    Invoke-TestSync -Channel "live" -Origin $branchOrigin -Cache $branchCache -Toc $toc120100 | Out-Null
    Invoke-TestGit -Repository (Join-Path $branchCache "live") -Arguments @("checkout", "-b", "other") | Out-Null
    $branch = Invoke-TestSync -Channel "live" -Origin $branchOrigin -Cache $branchCache -Toc $toc120100 -ExpectedExitCode 1
    Assert-Contains -Text $branch -Pattern "is on 'other', expected 'live'" -Label "wrong branch"
    Pass "wrong branch fails closed"

    Write-Output "$passed updater tests passed."
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedRoot = [System.IO.Path]::GetFullPath($testRoot)
        $requiredPrefix = $tempBase.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
        if (-not $resolvedRoot.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove test path outside the managed test directory: $resolvedRoot"
        }
        $reparsePoints = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop |
            Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint })
        if ($reparsePoints.Count -gt 0) {
            throw "Refusing to remove test tree containing reparse points: $($reparsePoints.FullName -join ', ')"
        }
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop
    }
}
