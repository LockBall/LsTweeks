-- Sound Levels module defaults and target metadata.
-- Defines known sound targets and preset replacement paths; runtime code mutes originals
-- and optionally plays addon-owned quieter files when they exist.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local SOUND_PATH = "Interface\\AddOns\\LsTweeks\\media\\sounds\\"
local LEVELUP2_PATH = SOUND_PATH .. "levelup2\\"

local function build_numbered_replacement_paths(folder, filename, min_level, max_level)
    local paths = {}
    for level = min_level, max_level do
        paths[tostring(level)] = folder .. filename .. "_" .. level .. ".ogg"
    end
    return paths
end

M.PRESET_OPTIONS = {}
for level = 0, 40 do
    M.PRESET_OPTIONS[#M.PRESET_OPTIONS + 1] = {
        value = tostring(level),
        text = tostring(level),
        slider_value = level + 1,
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
        default_preset = "0",
        preview_soundkit = "READY_CHECK",
        replacement_paths = build_numbered_replacement_paths(LEVELUP2_PATH, "levelup2", 0, 40),
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
        targets = {
            test_sound = {
                preset = "0",
                use_original = true,
                sound_off = false,
                play_on_adjust = true,
            },
            ready_check = {
                preset = "0",
                use_original = true,
                sound_off = false,
                play_on_adjust = false,
            },
        },
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sound_levels = M.defaults
