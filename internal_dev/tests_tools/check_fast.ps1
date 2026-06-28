param(
    [switch]$Package
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

if (-not (Test-Path -LiteralPath $luac)) {
    throw "Missing Lua 5.1 compiler: $luac"
}

Push-Location $repoRoot
try {
    $luaFiles = @(
        "core/init.lua",
        "core/main_frame.lua",
        "core/minimap_button.lua",
        "functions/checkbox.lua",
        "functions/color_picker.lua",
        "functions/dropdown.lua",
        "functions/layout_grid.lua",
        "functions/module_reset.lua",
        "functions/panel_riveted.lua",
        "functions/slider_with_box.lua",
        "functions/table_utils.lua",
        "functions/ui_helpers.lua",
        "functions/buttons.lua",
        "modules/about.lua",
        "modules/settings/st_defaults.lua",
        "modules/settings/st_main.lua",
        "modules/player_frame/pf_fade.lua",
        "modules/player_frame/pf_main.lua",
        "modules/objectives/ob_defaults.lua",
        "modules/objectives/ob_auto_collapse.lua",
        "modules/objectives/ob_section_count.lua",
        "modules/objectives/ob_background.lua",
        "modules/objectives/ob_main.lua",
        "modules/sound_levels/sl_defaults.lua",
        "modules/sound_levels/sl_functions.lua",
        "modules/sound_levels/sl_fishing.lua",
        "modules/sound_levels/sl_core.lua",
        "modules/sound_levels/sl_gui.lua",
        "modules/sound_levels/sl_main.lua",
        "modules/skyriding_vigor/sv_defaults.lua",
        "modules/skyriding_vigor/sv_styles.lua",
        "modules/skyriding_vigor/sv_bar.lua",
        "modules/skyriding_vigor/sv_fade.lua",
        "modules/skyriding_vigor/sv_state.lua",
        "modules/skyriding_vigor/sv_gui.lua",
        "modules/skyriding_vigor/sv_main.lua",
        "modules/aura_frames/af_defaults.lua",
        "modules/aura_frames/af_functions.lua",
        "modules/aura_frames/af_debug_outlines.lua",
        "modules/aura_frames/af_screen_grid.lua",
        "modules/aura_frames/af_scan.lua",
        "modules/aura_frames/af_render.lua",
        "modules/aura_frames/af_icon_layout.lua",
        "modules/aura_frames/af_core.lua",
        "modules/aura_frames/af_gui_tree.lua",
        "modules/aura_frames/af_gui_frame_builders.lua",
        "modules/aura_frames/af_gui.lua",
        "modules/aura_frames/af_profiles.lua",
        "modules/aura_frames/af_test_aura.lua",
        "modules/aura_frames/af_main.lua"
    )

    $missing = @($luaFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missing.Count -gt 0) {
        throw "Missing Lua file(s): $($missing -join ', ')"
    }

    Invoke-Step "Lua syntax" {
        & $luac -p @luaFiles
    }

    Invoke-Step "Lua regions" {
        pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "internal_dev/tests_tools/check_regions.ps1"
    }

    Invoke-Step "Whitespace diff check" {
        git diff --check
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
