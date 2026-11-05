# Isolated regression checks for development-folder exclusion and builder failure propagation.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$temporaryRoot = Join-Path $repoRoot 'internal_dev/scratch'
$fixtureRoot = Join-Path $temporaryRoot ('lstweeks-packaging-test-' + [guid]::NewGuid().ToString('N'))
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
    & pwsh.exe -NoProfile -File $builder -KeepStage
    if ($LASTEXITCODE -ne 0) { throw 'Valid fixture package failed.' }
    $scratch = Join-Path $fixtureRoot 'internal_dev/scratch'
    $keptStages = @(Get-ChildItem -LiteralPath $scratch -Directory -Filter 'package-*')
    if ($keptStages.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $keptStages[0].FullName 'LsTweeks/LsTweeks.toc'))) {
        throw 'KeepStage did not retain staged addon under repository scratch.'
    }
    if (@(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'releases') -Directory).Count) {
        throw 'Release output contains temporary staging.'
    }
    $keptStagePath = $keptStages[0].FullName
    if ([IO.Path]::GetDirectoryName($keptStagePath) -ne $scratch -or $keptStages[0].Name -notmatch '^package-[0-9a-f]{32}$') {
        throw 'Unexpected retained-stage cleanup path.'
    }
    Remove-Item -LiteralPath $keptStagePath -Recurse -Force

    # Public package output cannot be redirected into private development files.
    & pwsh.exe -NoProfile -File $builder -OutputDir internal_dev/private-output
    if ($LASTEXITCODE -eq 0) { throw 'Builder accepted output outside releases.' }
    if (Test-Path -LiteralPath (Join-Path $fixtureRoot 'internal_dev/private-output')) {
        throw 'Rejected output created private-directory artifacts.'
    }

    $currentZip = Join-Path $fixtureRoot 'releases/LsTweeks-fixture.zip'
    $oldZip = Join-Path $fixtureRoot 'releases/LsTweeks-older.zip'
    Copy-Item -LiteralPath $currentZip -Destination $oldZip
    $oldHash = (Get-FileHash -LiteralPath $oldZip).Hash
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0) { throw 'Build with another package failed.' }
    $storedZip = Join-Path $fixtureRoot 'releases/previous_versions/LsTweeks-older.zip'
    if (Test-Path -LiteralPath $oldZip) { throw 'Previous version remained beside current output.' }
    if ((Get-FileHash -LiteralPath $storedZip).Hash -ne $oldHash) { throw 'Previous version was not preserved exactly.' }
    # An existing, different archive must never be overwritten.
    [IO.File]::WriteAllText($oldZip, 'collision fixture')
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -eq 0) { throw 'Conflicting previous version was overwritten.' }
    if ((Get-FileHash -LiteralPath $storedZip).Hash -ne $oldHash) { throw 'Collision changed the archive.' }
    Remove-Item -LiteralPath $oldZip
    # Rebuilding the same version keeps its existing history unchanged.
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0) { throw 'Same-version rebuild failed with history present.' }
    if (@(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'internal_dev') -Directory | Where-Object { $_.Name -notin @('tests_tools','scratch') }).Count) {
        throw 'Build created unsolicited private directories.'
    }

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
    $currentHash = (Get-FileHash -LiteralPath $currentZip).Hash
    [IO.File]::WriteAllText((Join-Path $fixtureAddon 'LsTweeks.toc'), "## Version: next`n")
    # A failing verifier must also make the builder process fail.
    [IO.File]::WriteAllText((Join-Path $fixtureTools 'verify-package.ps1'), "exit 1`n")
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -eq 0) { throw 'Builder hid a verifier failure.' }
    if ((Get-FileHash -LiteralPath $storedZip).Hash -ne $oldHash) { throw 'Failed verification changed an archived version.' }
    if ((Get-FileHash -LiteralPath $currentZip).Hash -ne $currentHash) { throw 'Failed candidate replaced the current package.' }
    if (@(Get-ChildItem -LiteralPath $scratch -Force).Count) { throw 'Package run left temporary staging behind.' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'verify-package.ps1') -Destination $fixtureTools -Force
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -ne 0) { throw 'Verified version bump failed.' }
    $previousCurrent = Join-Path $fixtureRoot 'releases/previous_versions/LsTweeks-fixture.zip'
    if (Test-Path -LiteralPath $currentZip) { throw 'Prior current zip was not moved on version bump.' }
    if ((Get-FileHash -LiteralPath $previousCurrent).Hash -ne $currentHash) { throw 'Version bump changed prior release bytes.' }
    if (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot 'releases/LsTweeks-next.zip'))) { throw 'New release missing.' }
    if (@(Get-ChildItem -LiteralPath $scratch -Force).Count) { throw 'Successful version bump retained staging.' }
    Write-Host 'Packaging regression checks passed.'
} finally {
    $allowedRoot = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedFixture) -notmatch '^lstweeks-packaging-test-[0-9a-f]{32}$') {
        throw "Refusing fixture cleanup outside the dedicated temporary fixture: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
