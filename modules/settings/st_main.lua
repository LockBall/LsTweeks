-- General addon settings controller: alpha runtime, reset sync, and category registration.
-- Registered as the "Settings" sidebar category; on_reset_complete() resyncs controls from DB after settings changes.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

-- Initialize module table
addon.st = addon.st or {
    controls = {},
    frames = {}
}

local M = addon.st
M.controls = M.controls or {}
M.frames = M.frames or {}

-- Apply saved interface transparency to the main frame — called on every Show
local function apply_interface_alpha()
    if not addon.main_frame or not Ls_Tweeks_DB then return end
    local a = Ls_Tweeks_DB.interface_alpha
    if not a then return end
    addon.main_frame:SetBackdropColor(0.06, 0.06, 0.06, a)
    if addon.main_frame.title_bar    then addon.main_frame.title_bar:SetBackdropColor(0.12, 0.12, 0.12, a) end
    if addon.main_frame.sidebar      then addon.main_frame.sidebar:SetBackdropColor(0.10, 0.10, 0.10, a) end
    if addon.main_frame.content_area then addon.main_frame.content_area:SetBackdropColor(0.08, 0.08, 0.08, a) end
    if addon.alpha_affected_frames then
        for _, entry in ipairs(addon.alpha_affected_frames) do
            if entry.frame and entry.frame.SetBackdropColor then
                entry.frame:SetBackdropColor(entry.r, entry.g, entry.b, a)
            end
        end
    end
end
addon.apply_interface_alpha = apply_interface_alpha

function M.on_reset_complete()
    if not Ls_Tweeks_DB then return end
    local defaults = addon.module_defaults.st
    addon.apply_defaults(defaults, Ls_Tweeks_DB)
    apply_interface_alpha()

    if M.sync_settings_controls then
        M.sync_settings_controls()
    end
end

-- Module initializer
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        local defaults = addon.module_defaults.st
        addon.apply_defaults(defaults, Ls_Tweeks_DB)
        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.build_settings_page)
        end
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
    end
end)

--#endregion FILE CONTENTS ===================================================
