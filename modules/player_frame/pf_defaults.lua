-- Default DB values for the Player Frame module.


--#region FILE CONTENTS ======================================================

local _, addon = ...

local M = addon.player_frame or {}
addon.player_frame = M

M.controls = M.controls or {}
M.frames = M.frames or {}
M.MODULE_KEY = "player_frame"

M.FADE_DEFAULTS = {
    fade_alpha = 0.5,
    fade_delay = 2.0,
    fade_length = 5.0,
    health_visible_threshold = 80,
    health_release_speed = 75,
}

M.defaults = {
    player_frame = {
        hide_portrait_combat_text = false,
        fade_out_of_combat = false,
        fade_alpha = M.FADE_DEFAULTS.fade_alpha,
        fade_delay = M.FADE_DEFAULTS.fade_delay,
        fade_length = M.FADE_DEFAULTS.fade_length,
        health_visible_threshold = M.FADE_DEFAULTS.health_visible_threshold,
        health_release_speed = M.FADE_DEFAULTS.health_release_speed,
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.pf = M.defaults

return M

--#endregion FILE CONTENTS ===================================================
