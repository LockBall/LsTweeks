-- Aura frame profile save/load support.
-- Exports a complete Aura Frames setup for reuse across characters while
-- excluding editor-only state such as selected tabs, grid visibility, and debug outlines.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local PROFILE_GLOBAL_KEYS = {
    "enable_blizz_buffs",
    "enable_blizz_debuffs",
    "fade_wow_cooldown_ooc",
    "wow_cooldown_ooc_alpha",
    "short_threshold",
    "timer_number_font",
    "timer_number_font_size",
    "timer_number_font_bold",
}

local PROFILE_CATEGORY_PREFIXES = {
    "show",
    "move",
    "timer",
    "tooltip",
    "bg",
    "scale",
    "spacing",
    "width",
    "bar_mode",
    "color",
    "bar_bg_color",
    "bg_color",
    "max_icons",
    "growth",
    "sort",
    "test_aura",
    "bar_text_color",
    "timer_number_font",
    "timer_number_font_size",
    "timer_number_font_bold",
    "timer_color",
    "cooldown_mode",
    "hide_blizz_cdm",
}

local CUSTOM_PROFILE_KEYS = {
    "id",
    "name",
    "aura_base_filter",
    "aura_modifier",
    "show",
    "move",
    "timer",
    "tooltip",
    "bg",
    "scale",
    "spacing",
    "width",
    "bar_mode",
    "color",
    "bar_bg_color",
    "bg_color",
    "max_icons",
    "growth",
    "test_aura",
    "bar_text_color",
    "timer_number_font",
    "timer_number_font_size",
    "timer_number_font_bold",
    "timer_color",
    "position",
}

local function deep_copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deep_copy(v)
    end
    return copy
end

local function trim_profile_name(name)
    return (name or ""):match("^%s*(.-)%s*$")
end

local function ensure_profile_store()
    if not M.db then return nil end
    M.db.profiles = M.db.profiles or {}
    return M.db.profiles
end

local function copy_keys(src, dest, keys)
    for _, key in ipairs(keys) do
        if src[key] ~= nil then
            dest[key] = deep_copy(src[key])
        end
    end
end

local function export_custom_frames()
    local out = {}
    for _, entry in ipairs(M.db.custom_frames or {}) do
        local copy = {}
        copy_keys(entry, copy, CUSTOM_PROFILE_KEYS)
        out[#out + 1] = copy
    end
    return out
end

local function apply_keys(src, dest, keys)
    for _, key in ipairs(keys) do
        if src[key] ~= nil then
            dest[key] = deep_copy(src[key])
        else
            dest[key] = nil
        end
    end
end

local function apply_category_keys(profile_data)
    for _, category in ipairs(M.CATEGORIES or {}) do
        for _, prefix in ipairs(PROFILE_CATEGORY_PREFIXES) do
            local key = prefix .. "_" .. category
            if profile_data[key] ~= nil then
                M.db[key] = deep_copy(profile_data[key])
            elseif M.defaults and M.defaults[key] ~= nil then
                M.db[key] = deep_copy(M.defaults[key])
            end
        end
    end
end

function M.get_aura_frame_profiles()
    return ensure_profile_store() or {}
end

function M.find_aura_frame_profile(name)
    name = trim_profile_name(name)
    if name == "" then return nil, nil end
    for index, profile in ipairs(M.get_aura_frame_profiles()) do
        if profile.name == name then
            return profile, index
        end
    end
    return nil, nil
end

function M.export_aura_frame_profile_data()
    if not M.db then return nil end
    local data = {}
    copy_keys(M.db, data, PROFILE_GLOBAL_KEYS)

    for _, category in ipairs(M.CATEGORIES or {}) do
        for _, prefix in ipairs(PROFILE_CATEGORY_PREFIXES) do
            local key = prefix .. "_" .. category
            if M.db[key] ~= nil then
                data[key] = deep_copy(M.db[key])
            end
        end
    end

    data.positions = deep_copy(M.db.positions or {})
    data.custom_frames = export_custom_frames()
    return data
end

function M.save_aura_frame_profile(name, overwrite)
    local profiles = ensure_profile_store()
    if not profiles then return false, "Aura frame DB is not ready." end

    name = trim_profile_name(name)
    if name == "" then return false, "Enter a profile name." end

    local existing, index = M.find_aura_frame_profile(name)
    if existing and not overwrite then
        return false, "Profile already exists. Use Overwrite."
    end

    local profile = {
        name = name,
        saved_at = date and date("%Y-%m-%d %H:%M") or nil,
        data = M.export_aura_frame_profile_data(),
    }

    if index then
        profiles[index] = profile
    else
        profiles[#profiles + 1] = profile
    end
    M.db.last_profile_name = name
    return true, "Saved profile: " .. name
end

function M.delete_aura_frame_profile(name)
    local profiles = ensure_profile_store()
    if not profiles then return false, "Aura frame DB is not ready." end

    local _, index = M.find_aura_frame_profile(name)
    if not index then return false, "Profile not found." end
    table.remove(profiles, index)
    if M.db.last_profile_name == name then
        M.db.last_profile_name = profiles[1] and profiles[1].name or nil
    end
    return true, "Deleted profile: " .. name
end

function M.rename_aura_frame_profile(old_name, new_name)
    local profile = M.find_aura_frame_profile(old_name)
    if not profile then return false, "Profile not found." end

    new_name = trim_profile_name(new_name)
    if new_name == "" then return false, "Enter a new profile name." end
    if new_name == profile.name then return true, "Profile name unchanged." end
    if M.find_aura_frame_profile(new_name) then
        return false, "A profile with that name already exists."
    end

    profile.name = new_name
    if M.db then M.db.last_profile_name = new_name end
    return true, "Renamed profile: " .. new_name
end

function M.apply_aura_frame_profile_data(profile_data)
    if not (M.db and profile_data) then return false, "Profile data is missing." end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot load an aura frame profile in combat."
    end

    apply_keys(profile_data, M.db, PROFILE_GLOBAL_KEYS)
    apply_category_keys(profile_data)
    M.db.positions = deep_copy(profile_data.positions or {})
    M.db.custom_frames = deep_copy(profile_data.custom_frames or {})

    if M.defaults then
        addon.apply_defaults(M.defaults, M.db)
    end

    if M.create_custom_frame then
        for _, entry in ipairs(M.db.custom_frames or {}) do
            local show_key = entry.id and ("show_" .. entry.id)
            if show_key and M.frames and not M.frames[show_key] then
                M.create_custom_frame(entry)
            end
        end
    end

    if M.on_reset_complete then
        M.on_reset_complete()
    end
    return true, "Loaded profile."
end

function M.load_aura_frame_profile(name)
    local profile = M.find_aura_frame_profile(name)
    if not profile then return false, "Profile not found." end

    local ok, message = M.apply_aura_frame_profile_data(profile.data)
    if ok then
        M.db.last_profile_name = profile.name
        return true, "Loaded profile: " .. profile.name
    end
    return false, message
end
