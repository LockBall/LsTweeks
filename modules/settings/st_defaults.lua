-- Default DB values for the Settings module: interface_alpha, minimap visibility, and open_on_reload.
-- Consumed by addon.apply_defaults() when settings defaults need to be applied.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local M = {}

M.defaults = {
    minimap = { hide = false },
    open_on_reload = false,
    interface_alpha = 0.65,
    modules = {
        player_frame = true,
        objectives = true,
        background_color_sync = true,
        aura_frames = true,
        audio_volumes = true,
        skyriding_vigor = true,
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.st = M.defaults

return M

--#endregion FILE CONTENTS ===================================================
