-- Objectives General tab UI.
local _, addon = ...
addon.objectives = addon.objectives or {}
local M = addon.objectives
--#region GENERAL TAB ==========================================================
function M.BuildGeneralTab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -20)
    title:SetText("Objectives")
    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.objectives, { preserve_label = "Keep Profiles", preserve_default = true, preserve_keys = { "profiles", "last_profile_name" }, after_reset = M.on_reset_complete })
    reset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
end
--#endregion GENERAL TAB =======================================================
