-- Audio Volumes Profiles tab UI.
local _, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

--#region PROFILES TAB =========================================================

function M.BuildProfilesTab(parent)
    M.refresh_profiles_tab = addon.BuildProfilesTab(parent, M.profile_manager, {
        label = "Audio Volumes",
        note = "Profiles save sound replacements and temporary-volume situations for use on another character.",
    })
end

--#endregion PROFILES TAB ======================================================
