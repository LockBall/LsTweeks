# Offline relocation must retain provenance and reject changed input checkouts.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixtureRoot = Join-Path $repoRoot ('releases/annotation-relocation-test-' + [guid]::NewGuid().ToString('N'))
$tool = Join-Path $PSScriptRoot 'sync_wow_annotations.ps1'
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $commits = @{}
    foreach ($name in @('live', 'ketho-live', 'framexml-annotations-live')) {
        $checkout = Join-Path $fixtureRoot $name
        New-Item -ItemType Directory -Path $checkout | Out-Null
        & git -C $checkout init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Fixture git init failed.' }
        & git -C $checkout -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty --quiet -m Fixture
        if ($LASTEXITCODE -ne 0) { throw 'Fixture git commit failed.' }
        $commits[$name] = (& git -C $checkout rev-parse HEAD)
    }
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'ketho-live/Annotations/Core') -Force | Out-Null
    $receiptPath = Join-Path $fixtureRoot 'annotation-state-live.json'
    $original = [ordered]@{
        schemaVersion = 2; channel = 'live'; generatedAtUtc = '2026-10-30T12:34:27Z'
        sourceCommit = $commits['live']; generatorCommit = $commits['ketho-live']
        frameXmlCommit = $commits['framexml-annotations-live']
        wrapperHash = 'fixture-wrapper'; blizzardResourcesCommit = 'fixture-resources'
        sourceInterfacePath = 'obsolete/source'; corePath = 'obsolete/core'; frameXmlPath = 'obsolete/framexml'
    }
    [IO.File]::WriteAllText($receiptPath, ($original | ConvertTo-Json) + "`n")
    & pwsh.exe -NoProfile -File $tool -Relocate -CacheDirectory $fixtureRoot
    if ($LASTEXITCODE -ne 0) { throw 'Matching receipt relocation failed.' }
    $relocated = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    foreach ($key in $original.Keys | Where-Object { $_ -notin @('sourceInterfacePath', 'corePath', 'frameXmlPath') }) {
        if ($key -eq 'generatedAtUtc') {
            if (([DateTime]$relocated.$key).ToUniversalTime() -ne ([DateTime]$original[$key]).ToUniversalTime()) {
                throw 'Relocation changed the generation timestamp.'
            }
            continue
        }
        if ([string]$relocated.$key -ne [string]$original[$key]) { throw "Relocation changed provenance: $key" }
    }
    if ($relocated.corePath -ne (Join-Path $fixtureRoot 'ketho-live/Annotations/Core')) { throw 'Core path was not rebased.' }
    if ($relocated.sourceInterfacePath -ne (Join-Path $fixtureRoot 'live/Interface')) { throw 'Source path was not rebased.' }
    if ($relocated.frameXmlPath -ne (Join-Path $fixtureRoot 'framexml-annotations-live')) { throw 'FrameXML path was not rebased.' }
    $receiptHash = (Get-FileHash -LiteralPath $receiptPath).Hash
    & git -C (Join-Path $fixtureRoot 'live') -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty --quiet -m Changed
    if ($LASTEXITCODE -ne 0) { throw 'Fixture input mutation failed.' }
    & pwsh.exe -NoProfile -File $tool -Relocate -CacheDirectory $fixtureRoot
    if ($LASTEXITCODE -eq 0) { throw 'Relocation accepted a changed checkout.' }
    if ((Get-FileHash -LiteralPath $receiptPath).Hash -ne $receiptHash) { throw 'Rejected relocation changed the receipt.' }
    Write-Host 'Annotation relocation regression checks passed.'
} finally {
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'releases')) + [IO.Path]::DirectorySeparatorChar
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup outside releases: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
