param(
    [switch]$Package,
    [switch]$Changed
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$luac = "C:\Program Files (x86)\Lua\5.1\luac.exe"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Host "==> $Name"
    & $Action
}

function Get-ProjectTextFiles {
    $extensions = @(".json", ".lua", ".md", ".ps1", ".svg", ".toc")
    $projectRoots = @("core/", "functions/", "internal_dev/", "media/", "modules/")
    $rootFiles = @("LsTweeks.toc", "README.md", "sources.md")
    $gitFiles = @(
        git ls-files
        git ls-files --others --exclude-standard
    )

    foreach ($file in $gitFiles) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        $normalized = $file -replace "\\", "/"
        if (-not (Test-Path -LiteralPath $normalized)) { continue }
        $extension = [System.IO.Path]::GetExtension($normalized)
        if ($extensions -notcontains $extension) { continue }
        if ($rootFiles -contains $normalized) {
            $normalized
            continue
        }
        foreach ($root in $projectRoots) {
            if ($normalized.StartsWith($root)) {
                $normalized
                break
            }
        }
    }
}

function Test-HasCrlf {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
    for ($i = 0; $i -lt ($bytes.Length - 1); $i++) {
        if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) {
            return $true
        }
    }
    return $false
}

function Get-AddonLuaFilesFromToc {
    param([string]$TocPath)

    foreach ($line in Get-Content -LiteralPath $TocPath) {
        $entry = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if ($entry.StartsWith("#")) { continue }

        $normalized = $entry -replace "\\", "/"
        if ($normalized -notmatch "(?i)\.lua$") { continue }
        if ($normalized -match "(?i)^libs/") { continue }

        $normalized
    }
}

function Get-ChangedLuaFiles {
    $paths = @(
        git diff --name-only --diff-filter=ACMRTUXB
        git diff --cached --name-only --diff-filter=ACMRTUXB
        git ls-files --others --exclude-standard
    )

    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $normalized = $path -replace "\\", "/"
        if ([System.IO.Path]::GetExtension($normalized) -ne ".lua") { continue }
        if (-not (Test-Path -LiteralPath $normalized)) { continue }
        $normalized
    }
}

if (-not (Test-Path -LiteralPath $luac)) {
    throw "Missing Lua 5.1 compiler: $luac"
}

Push-Location $repoRoot
try {
    $luaFiles = if ($Changed) {
        @(Get-ChangedLuaFiles | Sort-Object -Unique)
    } else {
        @(Get-AddonLuaFilesFromToc "LsTweeks.toc")
    }

    $missing = @($luaFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missing.Count -gt 0) {
        throw "Missing Lua file(s): $($missing -join ', ')"
    }

    Invoke-Step "Lua syntax" {
        if ($luaFiles.Count -eq 0) {
            Write-Host "No changed Lua files."
        } else {
            & $luac -p @luaFiles
        }
    }

    Invoke-Step "Lua regions" {
        & "internal_dev/tests_tools/check_regions.ps1"
    }

    Invoke-Step "Whitespace diff check" {
        git diff --check
    }

    Invoke-Step "Line endings" {
        $crlfFiles = @(Get-ProjectTextFiles | Sort-Object -Unique | Where-Object { Test-HasCrlf $_ })
        if ($crlfFiles.Count -gt 0) {
            throw "CRLF line endings found; project text files must use LF: $($crlfFiles -join ', ')"
        }
    }

    if ($Package) {
        Invoke-Step "Package build and verification" {
            pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "internal_dev/tests_tools/packaging/package.ps1"
        }
    }

    Write-Host "Fast checks passed."
} finally {
    Pop-Location
}
