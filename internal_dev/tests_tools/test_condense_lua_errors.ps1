# Focused regression checks for condense_lua_errors.ps1 using compact synthetic WoW Lua error data.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tool = Join-Path $PSScriptRoot "condense_lua_errors.ps1"
$fixturePath = Join-Path ([System.IO.Path]::GetTempPath()) ("lstweeks-lua-errors-" + [guid]::NewGuid().ToString("N") + ".txt")
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lstweeks-lua-errors-" + [guid]::NewGuid().ToString("N") + ".md")

$fixture = @'
Message: Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua:491: secret value (execution tainted by 'LsTweeks')
Time: First
Count: 3
Stack:
[Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua]:491: in function 'Layout'
[Interface/AddOns/LsTweeks/modules/example.lua]:20: in function 'Apply'
[Interface/AddOns/OtherAddon/caller.lua]:5: in function 'One'
Locals:
large=<table>{
 value=1
}

Message: Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua:491: secret value (execution tainted by 'LsTweeks')
Time: Second
Count: 2
Stack:
[Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua]:491: in function 'Layout'
[Interface/AddOns/LsTweeks/modules/example.lua]:20: in function 'Apply'
[Interface/AddOns/AnotherAddon/caller.lua]:9: in function 'Two'
Locals:
large=<table>{
 value=2
}

Message: Interface/AddOns/LsTweeks/core/example.lua:7: separate failure
Time: Third
Count: 1
Stack:
[Interface/AddOns/LsTweeks/core/example.lua]:7: in function 'Fail'
Locals:
value=nil
'@

function Assert-Contains {
    param([string] $Text, [string] $Expected)
    if (-not $Text.Contains($Expected)) { throw "Expected report to contain: $Expected" }
}

try {
    [System.IO.File]::WriteAllText($fixturePath, ($fixture -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))

    $markdown = (& $tool -Path $fixturePath) | Out-String
    Assert-Contains $markdown "- Parsed records: 3"
    Assert-Contains $markdown "- Reported occurrences: 6"
    Assert-Contains $markdown "- Unique messages: 2"
    Assert-Contains $markdown "- Distinct stack variants: 3"
    Assert-Contains $markdown "- Explicit taint attribution: LsTweeks"
    Assert-Contains $markdown "[Interface/AddOns/LsTweeks/modules/example.lua]:20: in function 'Apply'"
    Assert-Contains $markdown "Variant 1: 3x; First"
    if ($markdown.Contains("large=<table>")) { throw "Locals must be omitted by default." }

    $withLocals = (& $tool -Path $fixturePath -IncludeLocals -MaxLocalLines 2) | Out-String
    Assert-Contains $withLocals "Representative locals:"
    Assert-Contains $withLocals "large=<table>{"
    Assert-Contains $withLocals "more line(s) omitted"

    & $tool -Path $fixturePath -OutputPath $outputPath | Out-Null
    if (-not (Test-Path -LiteralPath $outputPath)) { throw "Expected output file was not created." }
    $bytes = [System.IO.File]::ReadAllBytes($outputPath)
    if ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "Output must be UTF-8 without BOM."
    }
    $written = [System.IO.File]::ReadAllText($outputPath)
    if ($written.Contains("`r")) { throw "Output must use LF line endings." }

    $json = (& $tool -Path $fixturePath -Format Json) | Out-String | ConvertFrom-Json
    if ($json.parsed_records -ne 3 -or $json.reported_occurrences -ne 6 -or $json.unique_messages -ne 2) {
        throw "JSON summary counts are incorrect."
    }

    Write-Output "condense_lua_errors tests passed."
} finally {
    Remove-Item -LiteralPath $fixturePath, $outputPath -Force -ErrorAction SilentlyContinue
}
