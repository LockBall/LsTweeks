-- Audio Volumes module defaults and target metadata.
-- Defines known sound targets and preset replacement paths; runtime code mutes originals
-- and optionally plays addon-owned quieter files when they exist.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

M.REPLACEMENT_FILE_MIN_LEVEL = 0
M.REPLACEMENT_FILE_MAX_LEVEL = 19

M.SOUND_ASSETS = {
    achievmentsound1 = {
        folder = "Interface\\AddOns\\LsTweeks\\modules\\audio_volumes\\sounds\\achievmentsound1\\",
        filename = "achievmentsound1",
    },
    levelup2 = {
        folder = "Interface\\AddOns\\LsTweeks\\modules\\audio_volumes\\sounds\\levelup2\\",
        filename = "levelup2",
    },
}

local function build_numbered_replacement_paths(asset_key, min_level, max_level)
    local asset = M.SOUND_ASSETS[asset_key]
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
M.PRESET_OPTIONS_BY_VALUE = {}
M.PRESET_OPTIONS_BY_SLIDER_VALUE = {}
for position = 0, 20 do
    local file_level = 20 - position
    local option = {
        value = position == 0 and nil or tostring(file_level),
        percent = position * 5,
        slider_value = position,
        sound_off = position == 0,
    }
    M.PRESET_OPTIONS[#M.PRESET_OPTIONS + 1] = option
    if option.value then
        M.PRESET_OPTIONS_BY_VALUE[option.value] = option
    end
    M.PRESET_OPTIONS_BY_SLIDER_VALUE[option.slider_value] = option
end

M.SOUND_TARGETS = {
    achievement = {
        label = "Achievement",
        order = 1,
        description = "Used as test sound to preview new volume.",
        default_preset = "0",
        channel = "SFX",
        replacement_asset = "achievmentsound1",
        original_file_ids = {
            569143,
        },
        events = {},
    },
    ready_check = {
        label = "Ready Check",
        order = 10,
        description = "Party, raid, and LFG proposal ready sounds.",
        default_preset = "10",
        channel = "SFX",
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

M.SOUND_EVENT_TARGETS = {}
for target_key, target in pairs(M.SOUND_TARGETS) do
    for _, event_name in ipairs(target.events or {}) do
        local event_targets = M.SOUND_EVENT_TARGETS[event_name]
        if not event_targets then
            event_targets = {}
            M.SOUND_EVENT_TARGETS[event_name] = event_targets
        end
        event_targets[#event_targets + 1] = target_key
    end
end

M.defaults = {
    audio_volumes = {
        last_tab_index = 1,
        last_sound_key = "ready_check",
        fishing_focus = {
            enabled = false,
        },
        combat_volumes = {
            enabled = false,
            test_sound = "bloodlust",
        },
        quiet_custom = {
            enabled = false,
            test_sound = "bloodlust",
        },
        custom_situations = {},
        last_situation_key = "fishing",
        last_quick_pick_key = "quiet_custom",
        next_custom_situation_id = 1,
        targets = {
            achievement = {
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
addon.module_defaults.audio_volumes = M.defaults

--#endregion FILE CONTENTS ===================================================
