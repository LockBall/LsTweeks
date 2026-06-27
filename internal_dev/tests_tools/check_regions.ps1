param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,
    [switch]$Outline
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Get-RelativePath {
    param([string]$FullName)

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $FullName)
    return ($relative -replace "\\", "/")
}

function Get-LuaFiles {
    if ($Path -and $Path.Count -gt 0) {
        foreach ($item in $Path) {
            $resolved = Resolve-Path -LiteralPath $item -ErrorAction Stop
            foreach ($path_info in $resolved) {
                $full_name = $path_info.Path
                if ((Get-Item -LiteralPath $full_name).PSIsContainer) {
                    Get-ChildItem -LiteralPath $full_name -Recurse -File -Filter "*.lua"
                } else {
                    Get-Item -LiteralPath $full_name
                }
            }
        }
        return
    }

    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter "*.lua" |
        Where-Object {
                $relative = Get-RelativePath $_.FullName
                -not (
                    $relative -like "libs/*" -or
                    $relative -like "internal_dev/tests_tools/lua_checks/*" -or
                    $relative -eq "internal_dev/working_docs/SoundKitConstants.lua"
                )
        }
}

function Get-RegionName {
    param([string]$Line)

    $name = $Line -replace "^--#(?:end)?region\s*", ""
    $name = $name -replace "\s*=+\s*$", ""
    return $name.Trim()
}

function Read-Regions {
    param([System.IO.FileInfo]$File)

    $lines = [System.IO.File]::ReadAllLines($File.FullName)
    $stack = New-Object System.Collections.Generic.List[object]
    $regions = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line_number = $i + 1
        $line = $lines[$i]

        if ($line -match "^--#region\b") {
            $name = Get-RegionName $line
            if ($name -eq "") {
                $errors.Add("${line_number}: empty region name")
            }
            $stack.Add([pscustomobject]@{
                Name = $name
                StartLine = $line_number
            })
            continue
        }

        if ($line -match "^--#endregion\b") {
            $name = Get-RegionName $line
            if ($stack.Count -eq 0) {
                $errors.Add("${line_number}: unexpected endregion '$name'")
                continue
            }

            $start = $stack[$stack.Count - 1]
            $stack.RemoveAt($stack.Count - 1)
            if ($start.Name -ne $name) {
                $errors.Add("${line_number}: endregion '$name' does not match region '$($start.Name)' from line $($start.StartLine)")
            }

            $regions.Add([pscustomobject]@{
                Name = $start.Name
                StartLine = $start.StartLine
                EndLine = $line_number
            })
        }
    }

    for ($i = $stack.Count - 1; $i -ge 0; $i--) {
        $start = $stack[$i]
        $errors.Add("$($start.StartLine): unclosed region '$($start.Name)'")
    }

    if ($regions.Count -eq 0) {
        $errors.Add("missing region markers")
    }

    return [pscustomobject]@{
        Regions = @($regions | Sort-Object StartLine)
        Errors = @($errors)
    }
}

Push-Location $repoRoot
try {
    $files = @(Get-LuaFiles | Sort-Object FullName)
    if ($files.Count -eq 0) {
        throw "No Lua files found."
    }

    $failed = $false
    foreach ($file in $files) {
        $relative = Get-RelativePath $file.FullName
        $result = Read-Regions $file

        if ($Outline) {
            Write-Host $relative
            foreach ($region in $result.Regions) {
                "{0,6}-{1,-6} {2}" -f $region.StartLine, $region.EndLine, $region.Name
            }
        }

        foreach ($error_text in $result.Errors) {
            $failed = $true
            Write-Error "${relative}: $error_text" -ErrorAction Continue
        }
    }

    if ($failed) {
        throw "Region validation failed."
    }

    if (-not $Outline) {
        Write-Host "Region checks passed."
    }
} finally {
    Pop-Location
}
