-- Generic registered-consumer profile schema for Background Colors.


local _, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync


--#region PROFILE SCHEMA =======================================================

local PROFILE_KEYS = {
    "global_enabled",
    "global_enable_all_backgrounds",
    "global_color",
    "consumers",
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do
        out[key] = copy(child)
    end
    return out
end

function M.export_profile_data()
    local data = {}
    local db = M.get_db()
    if not db then return data end
    for _, key in ipairs(PROFILE_KEYS) do
        data[key] = copy(db[key])
    end
    return data
end

function M.apply_profile_data(data)
    if type(data) ~= "table" then
        return false, "Profile data is missing."
    end

    local db = M.get_db()
    local defaults = M.defaults.background_color_sync
    for _, key in ipairs(PROFILE_KEYS) do
        if data[key] ~= nil then
            db[key] = copy(data[key])
        else
            db[key] = copy(defaults[key])
        end
    end
    M.normalize_db()
    if M.on_reset_complete then
        M.on_reset_complete()
    else
        M.refresh_consumers()
    end
    return true, "Loaded profile."
end

M.profile_manager = addon.CreateProfileManager({
    label = "Background Colors",
    get_db = M.get_db,
    export_data = M.export_profile_data,
    apply_data = M.apply_profile_data,
})

--#endregion PROFILE SCHEMA ====================================================

