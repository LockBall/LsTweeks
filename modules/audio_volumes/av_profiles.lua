-- Audio Volumes profile schema and runtime application.
-- Shared profile storage and CRUD live in functions/profiles.lua.

local _, addon = ...

--#region PROFILE SCHEMA =======================================================

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

local PROFILE_KEYS = {
    "targets", "fishing_focus", "combat_volumes", "quiet_custom", "custom_situations", "next_custom_situation_id",
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

function M.export_audio_volumes_profile_data()
    local db = M.get_db()
    for target_key in pairs(M.SOUND_TARGETS) do M.get_target_db(target_key) end
    M.get_fishing_focus_db()
    M.get_combat_volumes_db()
    M.get_quiet_custom_db()
    local data = {}
    for _, key in ipairs(PROFILE_KEYS) do data[key] = copy(db[key]) end
    return data
end

function M.apply_audio_volumes_profile_data(data)
    if not data then return false, "Profile data is missing." end
    local db = M.get_db()
    local defaults = M.defaults.audio_volumes
    for _, key in ipairs(PROFILE_KEYS) do
        db[key] = data[key] ~= nil and copy(data[key]) or copy(defaults[key])
    end
    M._defaults_applied = nil
    M._target_defaults_applied = nil
    M.get_db()
    if M.on_reset_complete then M.on_reset_complete() end
    return true, "Loaded profile."
end

M.profile_manager = addon.CreateProfileManager({
    label = "Audio Volumes",
    get_db = M.get_db,
    export_data = M.export_audio_volumes_profile_data,
    apply_data = M.apply_audio_volumes_profile_data,
})

function M.get_audio_volumes_profiles() return M.profile_manager:get_profiles() end
function M.save_audio_volumes_profile(name, overwrite) return M.profile_manager:save(name, overwrite) end
function M.load_audio_volumes_profile(name) return M.profile_manager:load(name) end

--#endregion PROFILE SCHEMA ====================================================
