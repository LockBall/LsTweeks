# Isolated regression checks for development-folder exclusion and builder failure propagation.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$fixtureRoot = Join-Path $repoRoot ('internal_dev/local_artifacts/test_runs/packaging-test-' + [guid]::NewGuid().ToString('N'))
$fixtureTools = Join-Path $fixtureRoot 'internal_dev/tests_tools/packaging'
$fixtureAddon = Join-Path $fixtureRoot 'LsTweeks'
New-Item -ItemType Directory -Path $fixtureTools -Force | Out-Null
try {
    foreach ($name in @('package.ps1', 'verify-package.ps1', 'package-policy.json')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $fixtureTools
    }
    foreach ($name in @('.agents', '.claude', 'core', 'functions', 'libs', 'media', 'modules')) {
        $directory = Join-Path $fixtureAddon $name
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'fixture.txt'), "fixture`n")
    }
    foreach ($name in @('ADDON_GUIDE.md', 'CHANGELOG.md', 'LICENSE', 'sources.md')) {
        [IO.File]::WriteAllText((Join-Path $fixtureAddon $name), "fixture`n")
    }
    [IO.File]::WriteAllText((Join-Path $fixtureAddon 'LsTweeks.toc'), "## Version: fixture`n")
    # Workspace-only content is outside the package coverage inventory.
    [IO.File]::WriteAllText((Join-Path $fixtureRoot 'development-only.txt'), "private fixture`n")
    & git -C $fixtureRoot init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Fixture git initialization failed.' }
    $builder = Join-Path $fixtureTools 'package.ps1'
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0) { throw 'Valid fixture package failed.' }

    # Public package output cannot be redirected into private development files.
    & pwsh.exe -NoProfile -File $builder -OutputDir internal_dev/private-output
    if ($LASTEXITCODE -eq 0) { throw 'Builder accepted output outside releases.' }
    if (Test-Path -LiteralPath (Join-Path $fixtureRoot 'internal_dev/private-output')) {
        throw 'Rejected output created private-directory artifacts.'
    }

    $currentZip = Join-Path $fixtureRoot 'releases/LsTweeks-fixture.zip'
    $oldZip = Join-Path $fixtureRoot 'releases/LsTweeks-older.zip'
    $archiveZip = Join-Path $fixtureRoot 'internal_dev/local_artifacts/release_history/LsTweeks-older.zip'
    Copy-Item -LiteralPath $currentZip -Destination $oldZip
    $oldHash = (Get-FileHash -LiteralPath $oldZip).Hash
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0) { throw 'Build with older package failed.' }
    if (Test-Path -LiteralPath $oldZip) { throw 'Historical package remained in public output.' }
    if ((Get-FileHash -LiteralPath $archiveZip).Hash -ne $oldHash) { throw 'Archived package contents changed.' }

    # An identical historical archive is reused without changing its contents.
    Copy-Item -LiteralPath $archiveZip -Destination $oldZip
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $oldZip)) { throw 'Identical historical package was not reused.' }
    if ((Get-FileHash -LiteralPath $archiveZip).Hash -ne $oldHash) { throw 'Identical archive changed.' }

    # A junction inside releases must not redirect build writes into private data.
    $privateTarget = Join-Path $fixtureRoot 'internal_dev/private-target'
    $linkedOutput = Join-Path $fixtureRoot 'releases/linked-output'
    New-Item -ItemType Directory -Path $privateTarget | Out-Null
    New-Item -ItemType Junction -Path $linkedOutput -Target $privateTarget | Out-Null
    try {
        & pwsh.exe -NoProfile -File $builder -OutputDir releases/linked-output
        if ($LASTEXITCODE -eq 0) { throw 'Linked output was accepted.' }
        if (@(Get-ChildItem -LiteralPath $privateTarget -Force).Count) { throw 'Rejected linked output wrote private files.' }
    } finally {
        if ((Get-Item -LiteralPath $linkedOutput).LinkType -ne 'Junction') { throw 'Unexpected link cleanup target.' }
        [IO.Directory]::Delete($linkedOutput)
    }
    if (-not (Test-Path -LiteralPath $privateTarget)) { throw 'Link cleanup removed its target.' }
    # Same-name, different-content history must never be overwritten.
    [IO.File]::WriteAllText($oldZip, 'different historical contents')
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -eq 0) { throw 'Builder overwrote conflicting history.' }
    if ((Get-FileHash -LiteralPath $archiveZip).Hash -ne $oldHash) { throw 'Archive collision changed history.' }
    Remove-Item -LiteralPath $oldZip

    # Failed verification must leave historical packages where they were.
    Copy-Item -LiteralPath $currentZip -Destination $oldZip
    $currentHash = (Get-FileHash -LiteralPath $currentZip).Hash
    # A failing verifier must also make the builder process fail.
    [IO.File]::WriteAllText((Join-Path $fixtureTools 'verify-package.ps1'), "exit 1`n")
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -eq 0) { throw 'Builder hid a verifier failure.' }
    if (-not (Test-Path -LiteralPath $oldZip)) { throw 'Verification failure archived historical output.' }
    if ((Get-FileHash -LiteralPath $currentZip).Hash -ne $currentHash) { throw 'Failed candidate replaced the current package.' }
    Write-Host 'Packaging regression checks passed.'
} finally {
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'internal_dev/local_artifacts/test_runs')) + [IO.Path]::DirectorySeparatorChar
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing fixture cleanup outside private test runs: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
