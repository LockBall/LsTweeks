-- Aura frame configuration schema and mode-aware value resolution.
-- Owns profile field lists plus Icon/Bar growth keys, defaults, and reads so
-- GUI, profiles, and runtime layout do not repeat frame configuration rules.

local _, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region PROFILE SCHEMA ======================================================

M.PRESENTATION_PROFILE_CATEGORY_PREFIXES = {
    "show", "move", "timer", "timer_swipe", "tooltip", "bg", "scale", "spacing", "width", "bar_mode",
    "color", "bar_bg_color", "fade_ooc", "ooc_alpha", "fade_delay", "fade_length", "bg_color",
    "growth_icon", "growth_bar", "sort", "test_aura", "bar_text_color", "timer_number_font",
    "timer_number_font_size", "timer_number_font_bold", "timer_number_font_outline", "timer_color", "cooldown_mode", "hide_blizz_cdm",
    "stack_number_font", "stack_number_font_size", "stack_number_font_bold", "stack_number_font_outline", "stack_color",
    "sync_bar_bg", "sync_bar_color", "sync_text_color",
}

M.CUSTOM_PRESENTATION_PROFILE_KEYS = {
    "show", "move", "timer", "timer_swipe", "tooltip", "bg", "scale", "spacing", "width", "bar_mode",
    "color", "bar_bg_color", "fade_ooc", "ooc_alpha", "fade_delay", "fade_length", "bg_color",
    "growth_icon", "growth_bar", "test_aura", "bar_text_color", "timer_number_font", "timer_number_font_size",
    "timer_number_font_bold", "timer_number_font_outline", "timer_color", "sync_bar_bg", "sync_bar_color", "sync_text_color",
    "stack_number_font", "stack_number_font_size", "stack_number_font_bold", "stack_number_font_outline", "stack_color",
}

--#endregion PROFILE SCHEMA ===================================================

--#region GROWTH SETTINGS =====================================================

function M.apply_presentation_growth_defaults(defaults, frame_defs)
    if not defaults then return end
    for _, frame_def in ipairs(frame_defs or {}) do
        local growth = frame_def.growth or {}
        defaults["growth_icon_" .. frame_def.key] = growth.icon or "DOWN"
        defaults["growth_bar_" .. frame_def.key] = growth.bar or "DOWN"
    end
end

function M.apply_custom_presentation_growth_defaults(template)
    if not template then return end
    template.growth_icon = "DOWN"
    template.growth_bar = "DOWN"
end

function M.get_growth_logical_key(bar_mode)
    return bar_mode and "growth_bar" or "growth_icon"
end

local function normalize_bar_growth(growth)
    local direction = addon.GetGrowthDirection(growth)
    return direction.vertical and direction.value or "DOWN"
end

function M.get_mode_growth(cfg_db, category, bar_mode)
    local mode_key = M.get_growth_logical_key(bar_mode)
    local fallback = cfg_db and cfg_db ~= M.db
        and M.CUSTOM_FRAME_TEMPLATE and M.CUSTOM_FRAME_TEMPLATE[mode_key]
        or M.defaults and M.defaults[mode_key .. "_" .. category]
        or "DOWN"
    local growth = M.get_setting(cfg_db, category, mode_key, fallback)
    if bar_mode then return normalize_bar_growth(growth) end
    return addon.GetGrowthDirection(growth).value
end

--#endregion GROWTH SETTINGS ==================================================
