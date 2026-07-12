-- Aura Frames profile schema and runtime application.
-- Shared profile storage and CRUD live in functions/profiles.lua.

local _, addon = ...

--#region PROFILE SCHEMA =======================================================

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local PROFILE_GLOBAL_KEYS = {
    "enable_blizz_buffs", "enable_blizz_debuffs", "cancel_modifier", "short_threshold", "aura_visible_icon_tick",
    "timer_number_font", "timer_number_font_size", "timer_number_font_bold",
}
local PROFILE_CATEGORY_PREFIXES = {
    "show", "move", "timer", "timer_swipe", "tooltip", "bg", "scale", "spacing", "width", "bar_mode", "color",
    "bar_bg_color", "fade_ooc", "ooc_alpha", "fade_delay", "fade_length", "bg_color", "max_icons", "growth", "sort",
    "test_aura", "bar_text_color", "timer_number_font", "timer_number_font_size", "timer_number_font_bold", "timer_color",
    "cooldown_mode", "hide_blizz_cdm",
}
local CUSTOM_PROFILE_KEYS = {
    "id", "name", "aura_base_filter", "aura_modifier", "show", "move", "timer", "timer_swipe", "tooltip", "bg",
    "scale", "spacing", "width", "bar_mode", "color", "bar_bg_color", "fade_ooc", "ooc_alpha", "fade_delay",
    "fade_length", "bg_color", "max_icons", "growth", "test_aura", "bar_text_color", "timer_number_font",
    "timer_number_font_size", "timer_number_font_bold", "timer_color", "position",
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function copy_keys(source, dest, keys)
    for _, key in ipairs(keys) do
        if source[key] ~= nil then dest[key] = copy(source[key]) end
    end
end
local function apply_keys(source, dest, keys)
    for _, key in ipairs(keys) do dest[key] = source[key] ~= nil and copy(source[key]) or nil end
end

function M.export_aura_frame_profile_data()
    if not M.db then return nil end
    local data = {}
    copy_keys(M.db, data, PROFILE_GLOBAL_KEYS)
    for _, category in ipairs(M.CATEGORIES or {}) do
        for _, prefix in ipairs(PROFILE_CATEGORY_PREFIXES) do
            local key = prefix .. "_" .. category
            if M.db[key] ~= nil then data[key] = copy(M.db[key]) end
        end
    end
    data.positions = copy(M.db.positions or {})
    data.custom_frames = {}
    for _, entry in ipairs(M.db.custom_frames or {}) do
        local entry_copy = {}
        copy_keys(entry, entry_copy, CUSTOM_PROFILE_KEYS)
        data.custom_frames[#data.custom_frames + 1] = entry_copy
    end
    return data
end

function M.apply_aura_frame_profile_data(data)
    if not (M.db and data) then return false, "Profile data is missing." end
    apply_keys(data, M.db, PROFILE_GLOBAL_KEYS)
    for _, category in ipairs(M.CATEGORIES or {}) do
        for _, prefix in ipairs(PROFILE_CATEGORY_PREFIXES) do
            local key = prefix .. "_" .. category
            if data[key] ~= nil then
                M.db[key] = copy(data[key])
            elseif M.defaults[key] ~= nil then
                M.db[key] = copy(M.defaults[key])
            else
                M.db[key] = nil
            end
        end
    end
    if M.migrate_legacy_cdm_fade_settings then M.migrate_legacy_cdm_fade_settings(M.db, data) end
    M.db.positions = copy(data.positions or {})
    M.db.custom_frames = copy(data.custom_frames or {})
    addon.apply_defaults(M.defaults, M.db)
    if M.normalize_saved_colors then M.normalize_saved_colors(M.db) end
    if M.create_custom_frame then
        for _, entry in ipairs(M.db.custom_frames) do
            local show_key = entry.id and ("show_" .. entry.id)
            if show_key and M.frames and not M.frames[show_key] then M.create_custom_frame(entry) end
        end
    end
    if M.on_reset_complete then M.on_reset_complete() end
    return true, "Loaded profile."
end

M.profile_manager = addon.CreateProfileManager({
    label = "Aura Frames",
    schema_version = 1,
    get_db = function() return M.db end,
    export_data = M.export_aura_frame_profile_data,
    apply_data = M.apply_aura_frame_profile_data,
})

function M.get_aura_frame_profiles() return M.profile_manager:get_profiles() end
function M.find_aura_frame_profile(name) return M.profile_manager:find(name) end
function M.save_aura_frame_profile(name, overwrite) return M.profile_manager:save(name, overwrite) end
function M.delete_aura_frame_profile(name) return M.profile_manager:delete(name) end
function M.rename_aura_frame_profile(old_name, new_name) return M.profile_manager:rename(old_name, new_name) end
function M.load_aura_frame_profile(name) return M.profile_manager:load(name) end

--#endregion PROFILE SCHEMA ====================================================
