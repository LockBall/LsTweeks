-- Default DB values for the Skyriding Vigor module.
-- Consumed by addon.apply_defaults() on first load and after reset.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local SV = addon.skyriding_vigor
local M = {}

M.defaults = {
    skyriding_vigor = {
        enabled = true,
        fade_when_full = true,
        fade_alpha = 0.25,
        move_mode = false,
        snap_to_grid = true,
        spacing = 5,
        scale = 1.0,
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
    },
}

SV.SETTING_SPECS = {
    fade_alpha = { min = 0.05, max = 1, step = 0.05 },
    scale = { min = 0.5, max = 2, step = 0.05 },
    spacing = { min = 0, max = 10, step = 0.5 },
    x_position = { min = -1000, max = 1000, step = 1 },
    y_position = { min = -1000, max = 1000, step = 1 },
}

SV.SLIDER_KEYS = { "fade_alpha", "spacing", "scale" }
SV.LAYOUT_SETTING_KEYS = {
    scale = true,
    spacing = true,
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sv = M.defaults

return M
