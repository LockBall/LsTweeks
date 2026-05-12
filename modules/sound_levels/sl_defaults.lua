-- Sound Levels module defaults and target metadata.
-- Defines known sound targets and preset replacement paths; runtime code mutes originals
-- and optionally plays addon-owned quieter files when they exist.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.PRESET_OPTIONS = {
    { value = "original", text = "Original", slider_value = 1 },
    { value = "shush", text = "Shush", slider_value = 2 },
    { value = "shusher", text = "Shusher", slider_value = 3 },
    { value = "shushest", text = "Shushest", slider_value = 4 },
}

M.SOUND_TARGETS = {
    test_sound = {
        label = "Test Sound",
        order = 1,
        description = "",
        default_preset = "original",
        preview_soundkit = "IG_CHARACTER_INFO_TAB",
        replacement_paths = {
            shush = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\test_sound_shush.ogg",
            shusher = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\test_sound_shusher.ogg",
            shushest = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\test_sound_shushest.ogg",
        },
        original_file_ids = {},
        events = {},
    },
    dungeon_ready = {
        label = "Dungeon Ready",
        order = 10,
        description = "Controls the loud dungeon ready / queue-pop alert once the original sound FileDataID is known.",
        default_preset = "original",
        preview_soundkit = "READY_CHECK",
        replacement_paths = {
            shush = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\dungeon_ready_shush.ogg",
            shusher = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\dungeon_ready_shusher.ogg",
            shushest = "Interface\\AddOns\\LsTweeks\\modules\\sound_levels\\sounds\\dungeon_ready_shushest.ogg",
        },
        original_file_ids = {
            567478,
        },
        events = {
            "LFG_PROPOSAL_SHOW",
        },
    },
}

M.defaults = {
    sound_levels = {
        targets = {
            test_sound = {
                preset = "original",
                play_on_adjust = true,
            },
            dungeon_ready = {
                preset = "original",
                play_on_adjust = false,
            },
        },
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sound_levels = M.defaults
