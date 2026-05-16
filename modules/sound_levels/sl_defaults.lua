-- Sound Levels module defaults and target metadata.
-- Defines known sound targets and preset replacement paths; runtime code mutes originals
-- and optionally plays addon-owned quieter files when they exist.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.SOUND_ASSET_PATHS = {
    levelup2 = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\levelup2\\",
}

local function build_numbered_replacement_paths(folder, filename, min_level, max_level)
    local paths = {}
    for level = min_level, max_level do
        paths[tostring(level)] = folder .. filename .. "_" .. level .. ".ogg"
    end
    return paths
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
        label = "Test Sound",
        order = 1,
        description = "",
        default_preset = "0",
        preview_soundkit = "IG_CHARACTER_INFO_TAB",
        replacement_paths = {},
        original_file_ids = {},
        events = {},
    },
    ready_check = {
        label = "Ready Check",
        order = 10,
        description = "",
        default_preset = "10",
        preview_soundkit = "READY_CHECK",
        replacement_paths = build_numbered_replacement_paths(M.SOUND_ASSET_PATHS.levelup2, "levelup2", 0, 19),
        original_file_ids = {
            567478,
        },
        events = {
            "READY_CHECK",
            "LFG_PROPOSAL_SHOW",
        },
    },
}

M.defaults = {
    sound_levels = {
        last_tab_index = 1,
        last_sound_key = "ready_check",
        targets = {
            test_sound = {
                preset = "0",
                use_original = true,
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
