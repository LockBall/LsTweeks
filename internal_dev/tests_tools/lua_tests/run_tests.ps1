# Headless Lua test runner: executes every tests/test_*.lua file in its own Lua 5.1 process
# so addon global state never leaks between suites; exits nonzero if any suite fails.

[CmdletBinding()]
param(
    # Optional substring filter, e.g. ./run_tests.ps1 pf_fade
    [string]$Filter
)

$ErrorActionPreference = 'Stop'

$luaCandidates = @(
    'C:\Program Files (x86)\Lua\5.1\lua.exe',
    'lua5.1', 'lua51', 'lua', 'luajit'
)
$lua = $null
foreach ($candidate in $luaCandidates) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $lua = $cmd.Source; break }
}
if (-not $lua) {
    Write-Error 'No Lua interpreter found. Install Lua 5.1 or add it to PATH.'
    exit 2
}

$testDir = Join-Path $PSScriptRoot 'tests'
$testFiles = Get-ChildItem -Path $testDir -Filter 'test_*.lua' | Sort-Object Name
if ($Filter) {
    $testFiles = $testFiles | Where-Object { $_.Name -like "*$Filter*" }
}
if (-not $testFiles) {
    Write-Error "No test files matched filter '$Filter' in $testDir"
    exit 2
}

$failed = 0
foreach ($file in $testFiles) {
    Write-Host "== $($file.Name) ==" -ForegroundColor Cyan
    & $lua $file.FullName
    if ($LASTEXITCODE -ne 0) { $failed++ }
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "$failed suite(s) FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "All $($testFiles.Count) suite(s) passed" -ForegroundColor Green
exit 0
