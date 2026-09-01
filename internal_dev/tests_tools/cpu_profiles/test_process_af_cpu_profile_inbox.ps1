[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tool = Join-Path $PSScriptRoot "process_af_cpu_profile_inbox.ps1"
$inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lstweeks-af-profile-" + [guid]::NewGuid().ToString("N") + ".txt")
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lstweeks-af-profile-" + [guid]::NewGuid().ToString("N") + ".md")

$fixture = @'
old unrelated text
|cff33ff99== LsTweeks CPU Profile report ==|r
elapsed 96.0s
aura_timer_tick 0.15s
<!-- cpu-profile-run: elapsed=96.0 combat=94.0 timer_tick=0.15 -->
combat 94.0s 97.9% segments=1 active=yes
skyriding_active 0.0s 0.0% segments=0 active=no
|cff33ff99LsTweeks module status|r (aura_frames)
Buffs & Debuffs: enabled=true
  runtime=true
aura_specialization index=3 id=70 name=Retribution
aura_cooldown_modes essential=true utility=false
aura_test_auras global=false paused=false frames=none
aura_custom_frames count=0 entries=none
af.update_auras calls=100 total=25.000ms avg=0.2500ms max=1.000ms cb_msps=0.266 cb_callsps=1.06
af.tick_visible_icons calls=600 total=60.000ms avg=0.1000ms max=0.500ms cb_msps=0.638 cb_callsps=6.38
|cff33ff99== LsTweeks CPU Profile stopped ==|r
'@

try {
    [System.IO.File]::WriteAllText($inputPath, $fixture, [System.Text.UTF8Encoding]::new($false))
    & $tool -InputPath $inputPath -OutputPath $outputPath -Title "2026-08-31, Aura Frames Only, Test"
    $output = [System.IO.File]::ReadAllText($outputPath)

    if ($output -notmatch "### 2026-08-31, Aura Frames Only, Test") {
        throw "Processed output is missing the requested title."
    }
    if ($output -notmatch [regex]::Escape("<!-- cpu-profile-run: elapsed=96.0 combat=94.0 timer_tick=0.15 -->")) {
        throw "Processed output is missing metadata."
    }
    if ($output -notmatch "\| ``af\.update_auras`` \| 100 \| 25\.000 \| 0\.2500 \| 1\.000 \| 0\.266 \| 1\.06 \|") {
        throw "Processed output contains an incorrect metric row."
    }
    if ($output -match "CPU Profile stopped") {
        throw "Processed output should exclude the stop marker."
    }

    Write-Output "process_af_cpu_profile_inbox tests passed."
} finally {
    Remove-Item -LiteralPath $inputPath, $outputPath -Force -ErrorAction SilentlyContinue
}
