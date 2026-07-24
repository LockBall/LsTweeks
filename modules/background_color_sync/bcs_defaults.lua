-- Defaults, preset palette, registry state, and DB access for Background Colors.


local _, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync


--#region MODULE IDENTITY AND DB ==============================================

M.MODULE_KEY = "background_color_sync"
M.CATEGORY_NAME = "Background Colors"
M.consumers = M.consumers or {}
M.consumer_order = M.consumer_order or {}

function M.get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.background_color_sync = Ls_Tweeks_DB.background_color_sync or {}
    return Ls_Tweeks_DB.background_color_sync
end

function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

--#endregion MODULE IDENTITY AND DB ===========================================


--#region COLOR PRESETS ========================================================

M.PRESET_OPTIONS = {
    { value = "red", text = "Red" },
    { value = "orange", text = "Orange" },
    { value = "yellow", text = "Yellow" },
    { value = "green", text = "Green" },
    { value = "blue", text = "Blue" },
    { value = "indigo", text = "Indigo" },
    { value = "violet", text = "Violet" },
    { value = "black", text = "Black" },
    { value = "white", text = "White" },
    { value = "grey", text = "Grey" },
}

M.COLOR_PRESETS = {
    red = { r = 1, g = 0, b = 0 },
    orange = { r = 1, g = 0.5, b = 0 },
    yellow = { r = 1, g = 1, b = 0 },
    green = { r = 0, g = 1, b = 0 },
    blue = { r = 0, g = 0, b = 1 },
    indigo = { r = 0.294, g = 0, b = 0.51 },
    violet = { r = 0.56, g = 0, b = 1 },
    black = { r = 0, g = 0, b = 0 },
    white = { r = 1, g = 1, b = 1 },
    grey = { r = 0.5, g = 0.5, b = 0.5 },
}

--#endregion COLOR PRESETS =====================================================


--#region DEFAULTS =============================================================

M.defaults = {
    background_color_sync = {
        global_enabled = false,
        global_enable_all_backgrounds = false,
        global_color = { r = 0, g = 0, b = 0, a = 0.5 },
        consumers = {},
        last_tab_index = 1,
        last_profile_name = nil,
        profiles = {},
    },
}

--#endregion DEFAULTS ==========================================================

