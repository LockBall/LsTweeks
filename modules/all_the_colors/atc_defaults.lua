-- Defaults, preset palette, registry state, and DB access for Shared Colors.


local _, addon = ...

addon.all_the_colors = addon.all_the_colors or {}
local M = addon.all_the_colors


--#region MODULE IDENTITY AND DB ==============================================

M.MODULE_KEY = "all_the_colors"
M.CATEGORY_NAME = "All the Colors"
M.consumers = M.consumers or {}
M.consumer_order = M.consumer_order or {}

function M.get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.all_the_colors = Ls_Tweeks_DB.all_the_colors or {}
    return Ls_Tweeks_DB.all_the_colors
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

local function copy_color(color)
    return { r = color.r, g = color.g, b = color.b, a = color.a }
end

M.AURA_COLOR_DEFS = {
    {
        key = "aura_bar_bg_color",
        label = "Bar BG",
        has_alpha = true,
        row = 3,
        column = 2,
        default = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 },
    },
    {
        key = "aura_buff_bar_color",
        label = "Buff Bar",
        has_alpha = true,
        row = 2,
        column = 3,
        default = addon.AURA_BAR_COLOR_DEFAULTS.buff,
    },
    {
        key = "aura_debuff_bar_color",
        label = "Debuff Bar",
        has_alpha = true,
        row = 3,
        column = 3,
        default = addon.AURA_BAR_COLOR_DEFAULTS.debuff,
    },
    {
        key = "aura_timer_text_color",
        label = "Timer Text",
        has_alpha = false,
        row = 3,
        column = 4,
        default = { r = 1, g = 1, b = 1, a = 1 },
    },
    {
        key = "aura_bar_text_color",
        label = "Bar Text",
        has_alpha = false,
        row = 2,
        column = 4,
        default = { r = 1, g = 1, b = 1, a = 1 },
    },
}

local defaults = {
    global_enabled = false,
    global_enable_all_backgrounds = false,
    global_enable_test_auras = false,
    global_disable_ooc_fade = false,
    global_color = { r = 0, g = 0, b = 0, a = 0.5 },
    consumers = {},
    last_tab_index = 1,
    last_profile_name = nil,
    profiles = {},
}
for _, color_def in ipairs(M.AURA_COLOR_DEFS) do
    defaults[color_def.key] = copy_color(color_def.default)
end

M.defaults = { all_the_colors = defaults }

--#endregion DEFAULTS ==========================================================
