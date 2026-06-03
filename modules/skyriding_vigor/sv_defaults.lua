-- Default DB values for the Skyriding Vigor module.
-- Consumed by addon.apply_defaults() on first load and after reset.
local addon_name, addon = ...

local M = {}

M.defaults = {
    skyriding_vigor = {
        enabled = true,
        fade_when_full = true,
        fade_alpha = 0.25,
        move_mode = false,
        snap_to_grid = true,
        spacing = 0,
        scale = 1.0,
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -200,
        },
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sv = M.defaults

return M
