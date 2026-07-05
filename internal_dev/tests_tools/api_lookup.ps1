param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ApiName
)

$ErrorActionPreference = "Stop"

$extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
$kethoExtension = Get-ChildItem -Path $extensionsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "ketho.wow-api-*" } |
    Sort-Object Name -Descending |
    Select-Object -First 1

if (-not $kethoExtension) {
    throw "Could not find ketho.wow-api extension under $extensionsRoot"
}

$annotationRoots = @(
    Join-Path $kethoExtension.FullName "Annotations\Core"
    Join-Path $kethoExtension.FullName "Annotations\FrameXML"
)

foreach ($root in $annotationRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        throw "Missing Ketho annotation root: $root"
    }
}

$escapedApi = [System.Text.RegularExpressions.Regex]::Escape($ApiName)
$functionPattern = "^\s*function\s+$escapedApi\s*\("
$results = New-Object System.Collections.Generic.List[object]

foreach ($root in $annotationRoots) {
    Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.lua" | ForEach-Object {
        $file = $_
        $lines = [System.IO.File]::ReadAllLines($file.FullName)

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch $functionPattern) { continue }

            $start = $i
            while ($start -gt 0 -and $lines[$start - 1] -match "^\s*---") {
                $start--
            }

            $block = for ($line = $start; $line -le $i; $line++) {
                $lines[$line]
            }

            $relativePath = $file.FullName.Substring($kethoExtension.FullName.Length).TrimStart("\") -replace "\\", "/"
            $results.Add([pscustomobject]@{
                Path = $relativePath
                Line = $i + 1
                Text = @($block)
            })
        }
    }
}

if ($results.Count -eq 0) {
    throw "No exact Ketho annotation function found for '$ApiName'."
}

Write-Host "Ketho:" $kethoExtension.FullName
Write-Host ""

for ($i = 0; $i -lt $results.Count; $i++) {
    $match = $results[$i]
    Write-Host "$($match.Path):$($match.Line)"
    foreach ($line in $match.Text) {
        $line
    }

    if ($i -lt ($results.Count - 1)) {
        Write-Host ""
    }
}
