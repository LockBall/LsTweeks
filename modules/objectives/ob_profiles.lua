-- Objectives profile schema and runtime application.
local _, addon = ...
addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region PROFILE SCHEMA =======================================================

local PROFILE_KEYS = {
    "collapse_campaign", "collapse_quests", "collapse_achievements",
    "show_auto_collapse_activation_tooltip",
    "show_quest_log_count", "show_quest_log_count_on_hover",
    "show_tracked_achievement_count", "show_tracked_achievement_count_on_hover",
    "customize_background", "background_color_enabled", "objective_tracker_border",
    "background_color", "background_alpha",
    "objective_tracker_move_mode", "objective_tracker_snap_to_grid",
    "objective_tracker_offset_x", "objective_tracker_offset_y",
}
local copy = addon.deep_copy
function M.export_objectives_profile_data()
    local data, db = {}, M.get_db()
    for _, key in ipairs(PROFILE_KEYS) do data[key] = copy(db[key]) end
    return data
end
function M.apply_objectives_profile_data(data)
    if not data then return false, "Profile data is missing." end
    local db, defaults = M.get_db(), M.defaults.objectives
    for _, key in ipairs(PROFILE_KEYS) do
        if data[key] ~= nil then
            db[key] = copy(data[key])
        else
            db[key] = copy(defaults[key])
        end
    end
    if M.on_reset_complete then M.on_reset_complete() end
    return true, "Loaded profile."
end
M.profile_manager = addon.CreateProfileManager({ label = "Objectives", get_db = M.get_db, export_data = M.export_objectives_profile_data, apply_data = M.apply_objectives_profile_data })
--#endregion PROFILE SCHEMA ====================================================
