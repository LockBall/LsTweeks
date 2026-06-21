-- Default DB values for the Skyriding Vigor module.
-- Consumed by addon.apply_defaults() on first load and after reset.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local defs = {}
local default_progress_interval = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.skyriding_vigor_progress or 0.05

defs.defaults = {
    skyriding_vigor = {
        enabled = true,
        fade_when_full = true,
        fade_alpha = 0.25,
        fade_length = 3,
        show_spark = false,
        spark_color = { r = 1, g = 1, b = 1, a = 1 },
        spark_size = 5.00,
        move_mode = false,
        snap_to_grid = true,
        style = "default",
        decor_style = "default",
        spacing = 5,
        scale = 1.0,
        progress_update_hz = 1 / default_progress_interval,
        style_layouts = {
            default = {
                fill_color = { r = 1, g = 1, b = 1, a = 1 },
                fill_add_alpha = 0.18,
            },
            storm_race = {
                fill_color = { r = 1, g = 1, b = 1, a = 1 },
                fill_add_alpha = 0.18,
            },
        },
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
