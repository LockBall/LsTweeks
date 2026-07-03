-- General tab UI for the Audio Volumes module.
local _, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes
local UI = M.GUI_LAYOUT

--#region GENERAL TAB ==========================================================

function M.BuildGeneralTab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y)
    title:SetText("General")

    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.audio_volumes, {
        after_reset = M.on_reset_complete,
    })
    reset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
end

--#endregion GENERAL TAB =======================================================
