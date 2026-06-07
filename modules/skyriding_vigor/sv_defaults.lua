-- Default DB values for the Skyriding Vigor module.
-- Consumed by addon.apply_defaults() on first load and after reset.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local defs = {}

defs.defaults = {
    skyriding_vigor = {
        enabled = true,
        fade_when_full = true,
        fade_alpha = 0.25,
        fade_length = 3,
        move_mode = false,
        snap_to_grid = true,
        style = "default",
        decor_style = "default",
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

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.sv = defs.defaults

return defs
