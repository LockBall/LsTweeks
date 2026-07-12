-- Objectives profile schema and runtime application.
local _, addon = ...
addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region PROFILE SCHEMA =======================================================

local KEYS = { "collapse_all", "collapse_campaign", "collapse_quests", "collapse_achievements", "show_quest_log_count", "show_quest_log_count_on_hover", "show_tracked_achievement_count", "show_tracked_achievement_count_on_hover", "customize_background", "background_color_enabled", "background_color", "background_alpha", "objective_tracker_move_mode", "objective_tracker_snap_to_grid", "objective_tracker_offset_x", "objective_tracker_offset_y" }
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
end
function M.export_objectives_profile_data()
    local data, db = {}, M.get_db()
    for _, key in ipairs(KEYS) do data[key] = copy(db[key]) end
    return data
end
function M.apply_objectives_profile_data(data)
    if not data then return false, "Profile data is missing." end
    local db, defaults = M.get_db(), M.defaults.objectives
    for _, key in ipairs(KEYS) do
        if data[key] ~= nil then
            db[key] = copy(data[key])
        else
            db[key] = copy(defaults[key])
        end
    end
    if M.migrate_background_settings then M.migrate_background_settings(db) end
    if M.on_reset_complete then M.on_reset_complete() end
    return true, "Loaded profile."
end
M.profile_manager = addon.CreateProfileManager({ label = "Objectives", schema_version = 1, get_db = M.get_db, export_data = M.export_objectives_profile_data, apply_data = M.apply_objectives_profile_data })
function M.get_objectives_profiles() return M.profile_manager:get_profiles() end
function M.save_objectives_profile(name, overwrite) return M.profile_manager:save(name, overwrite) end
function M.load_objectives_profile(name) return M.profile_manager:load(name) end

--#endregion PROFILE SCHEMA ====================================================
