# Isolated regression checks for development-folder exclusion and builder failure propagation.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$fixtureRoot = Join-Path $repoRoot ('releases/packaging-test-' + [guid]::NewGuid().ToString('N'))
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

    # A failing verifier must also make the builder process fail.
    [IO.File]::WriteAllText((Join-Path $fixtureTools 'verify-package.ps1'), "exit 1`n")
    & pwsh.exe -NoProfile -File $builder
    if ($LASTEXITCODE -eq 0) { throw 'Builder hid a verifier failure.' }
    Write-Host 'Packaging regression checks passed.'
} finally {
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'releases')) + [IO.Path]::DirectorySeparatorChar
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing fixture cleanup outside releases: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
