-- Objectives Profiles tab UI.
local _, addon = ...
addon.objectives = addon.objectives or {}
local M = addon.objectives
--#region PROFILES TAB =========================================================
function M.BuildProfilesTab(parent)
    M.refresh_profiles_tab = addon.BuildProfilesTab(parent, M.profile_manager, { label = "Objectives", note = "Profiles save Objective Tracker position, background, collapse, and count settings for use on another character." })
end
--#endregion PROFILES TAB ======================================================
