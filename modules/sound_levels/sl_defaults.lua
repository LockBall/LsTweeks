-- Sound Levels module defaults and target metadata.
-- Defines known sound targets and preset replacement paths; runtime code mutes originals
-- and optionally plays addon-owned quieter files when they exist.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.REPLACEMENT_FILE_MIN_LEVEL = 0
M.REPLACEMENT_FILE_MAX_LEVEL = 19

M.SOUND_ASSETS = {
    achievmentsound1 = {
        folder = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\achievmentsound1\\",
        filename = "achievmentsound1",
    },
    levelup2 = {
        folder = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\levelup2\\",
        filename = "levelup2",
    },
}

local function build_numbered_replacement_paths(asset_key, min_level, max_level)
    local asset = M.SOUND_ASSETS and M.SOUND_ASSETS[asset_key]
    if not asset then return {} end

    local paths = {}
    for level = min_level, max_level do
        paths[tostring(level)] = asset.folder .. asset.filename .. "_" .. level .. ".ogg"
    end
    return paths
end

local function apply_replacement_paths(targets)
    for _, target in pairs(targets or {}) do
        if target.replacement_asset and not target.replacement_paths then
            target.replacement_paths = build_numbered_replacement_paths(
                target.replacement_asset,
                M.REPLACEMENT_FILE_MIN_LEVEL,
                M.REPLACEMENT_FILE_MAX_LEVEL
            )
        end
    end
end

M.PRESET_OPTIONS = {}
for position = 0, 20 do
    local file_level = 20 - position
    M.PRESET_OPTIONS[#M.PRESET_OPTIONS + 1] = {
        value = tostring(file_level),
        percent = position * 5,
        slider_value = position + 1,
    }
end

M.SOUND_TARGETS = {
    test_sound = {
        label = "Achievement",
        order = 1,
        description = "",
        default_preset = "0",
        replacement_asset = "achievmentsound1",
        original_file_ids = {
            569143,
        },
        events = {},
    },
    ready_check = {
        label = "Ready Check",
        order = 10,
        description = "",
        default_preset = "10",
        preview_soundkit = "READY_CHECK",
        replacement_asset = "levelup2",
        original_file_ids = {
            567478,
        },
        events = {
            "READY_CHECK",
            "LFG_PROPOSAL_SHOW",
        },
    },
}
apply_replacement_paths(M.SOUND_TARGETS)

M.defaults = {
    sound_levels = {
        last_tab_index = 1,
        last_sound_key = "ready_check",
        targets = {
            test_sound = {
                preset = "0",
                use_original = false,
                sound_off = false,
                play_on_adjust = true,
            },
            ready_check = {
                preset = "10",
                use_original = false,
                sound_off = false,
                play_on_adjust = false,
            },
        },
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sound_levels = M.defaults
