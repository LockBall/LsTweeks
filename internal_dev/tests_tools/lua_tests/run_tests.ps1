# Headless Lua test runner: selects all, named, filtered, or changed-file-impacted suites and
# executes each in its own Lua 5.1 process so addon global state never leaks between suites.

[CmdletBinding()]
param(
    # Optional substring filter, e.g. ./run_tests.ps1 pf_fade
    [string]$Filter,
    # One or more exact/substring suite names, e.g. -Suite af_ranges,tooltip
    [string[]]$Suite,
    # Select suites impacted by staged, unstaged, and untracked files.
    [switch]$Changed,
    # Print selected suite files without executing them.
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

$selectionModes = @($Filter, ($Suite.Count -gt 0), $Changed.IsPresent) | Where-Object { $_ }
if ($selectionModes.Count -gt 1) {
    throw "Use only one test selection mode: -Filter, -Suite, or -Changed."
}

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
$allTestFiles = @(Get-ChildItem -Path $testDir -Filter 'test_*.lua' | Sort-Object Name)
$testFiles = $allTestFiles

function Get-SuiteName {
    param([System.IO.FileInfo]$File)
    $File.BaseName -replace '^test_', ''
}

function Get-ChangedPaths {
    $paths = @(
        git diff --name-only --diff-filter=ACMRTUXB
        git diff --cached --name-only --diff-filter=ACMRTUXB
        git ls-files --others --exclude-standard
    )
    @($paths |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ -replace '\\', '/' } |
        Sort-Object -Unique)
}

function Get-ChangedStubMethods {
    param([string]$Path)

    $diffLines = @(
        git diff --unified=0 -- $Path
        git diff --cached --unified=0 -- $Path
    )
    $methods = foreach ($line in $diffLines) {
        if ($line -match '^[+-]function\s+frame_methods:([A-Za-z_][A-Za-z0-9_]*)') {
            $Matches[1]
        }
    }
    @($methods | Sort-Object -Unique)
}

function Get-ImpactedSuiteNames {
    param([string[]]$Paths)

    $selected = @{}
    $add = {
        param([string[]]$Names)
        foreach ($name in $Names) {
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $selected[$name] = $true
            }
        }
    }
    $addAll = {
        foreach ($file in $allTestFiles) {
            & $add (Get-SuiteName $file)
        }
    }

    foreach ($path in $Paths) {
        if ($path -match '^internal_dev/tests_tools/lua_tests/tests/test_(.+)\.lua$') {
            & $add $Matches[1]
            continue
        }
        if ($path -eq 'internal_dev/tests_tools/lua_tests/harness.lua') {
            & $addAll
            continue
        }
        if ($path -eq 'internal_dev/tests_tools/lua_tests/wow_stub.lua') {
            $methods = @(Get-ChangedStubMethods $path)
            if ($methods.Count -eq 0) {
                & $addAll
                continue
            }
            $matchedSuite = $false
            foreach ($file in $allTestFiles) {
                $content = Get-Content -LiteralPath $file.FullName -Raw
                foreach ($method in $methods) {
                    if ($content.Contains($method)) {
                        & $add (Get-SuiteName $file)
                        $matchedSuite = $true
                        break
                    }
                }
            }
            if (-not $matchedSuite) {
                & $addAll
            }
            continue
        }

        switch -Regex ($path) {
            '^modules/aura_frames/af_logic_native_visibility\.lua$' { & $add 'af_native_visibility'; continue }
            '^modules/aura_frames/af_profiles\.lua$' { & $add @('profiles', 'af_ranges'); continue }
            '^modules/aura_frames/' { & $add 'af_ranges'; continue }
            '^modules/audio_volumes/' { & $add 'av_situations'; continue }
            '^modules/objectives/ob_auto_collapse\.lua$' { & $add 'ob_auto_collapse'; continue }
            '^modules/objectives/ob_(background|functions|main)\.lua$' { & $add @('ob_background', 'ob_auto_collapse'); continue }
            '^modules/objectives/ob_section_count\.lua$' { & $add 'ob_section_count'; continue }
            '^modules/objectives/' { & $add @('ob_auto_collapse', 'ob_background', 'ob_section_count'); continue }
            '^modules/player_frame/' { & $add 'pf_fade'; continue }
            '^modules/skyriding_vigor/' { & $add 'sv_state'; continue }
            '^functions/tooltip\.lua$' { & $add @('tooltip', 'af_ranges'); continue }
            '^functions/table_utils\.lua$' { & $add @('table_utils', 'profiles'); continue }
            '^functions/(buttons|checkbox|dropdown|slider)\.lua$' { & $add 'control_factories'; continue }
            '^functions/profiles\.lua$' { & $add 'profiles'; continue }
            '^(core/|LsTweeks\.toc$)' { & $add 'smoke_load_all'; continue }
            '^(functions|modules)/.*\.lua$' { & $add 'smoke_load_all'; continue }
        }
    }

    @($selected.Keys | Sort-Object)
}

if ($Filter) {
    $testFiles = $testFiles | Where-Object { $_.Name -like "*$Filter*" }
} elseif ($Suite.Count -gt 0) {
    $testFiles = $testFiles | Where-Object {
        $name = Get-SuiteName $_
        @($Suite | Where-Object { $name -like "*$_*" -or $name -eq $_ }).Count -gt 0
    }
} elseif ($Changed) {
    $changedPaths = @(Get-ChangedPaths)
    $impactedNames = @(Get-ImpactedSuiteNames $changedPaths)
    $testFiles = @($testFiles | Where-Object { $impactedNames -contains (Get-SuiteName $_) })
    if ($testFiles.Count -eq 0) {
        Write-Host "No headless Lua suites impacted by current changes."
        exit 0
    }
    Write-Host "Impacted suites: $((@($testFiles | ForEach-Object { Get-SuiteName $_ })) -join ', ')"
}
if (-not $testFiles) {
    Write-Error "No test files matched the requested selection in $testDir"
    exit 2
}

if ($ListOnly) {
    $testFiles | ForEach-Object { Write-Host $_.Name }
    exit 0
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
