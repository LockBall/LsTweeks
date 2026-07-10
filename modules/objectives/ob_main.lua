-- Objectives module shell: composes Objective feature settings, lifecycle, and status.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

local MODULE_KEY = M.MODULE_KEY
local CATEGORY_NAME = "Objectives"
local objectives_combat_update_pending = false
local loader

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults

--#endregion SETTINGS AND DEFAULTS =============================================


--#region OBJECTIVE TRACKER RUNTIME ============================================

function M.is_objectives_combat_locked()
    return InCombatLockdown and InCombatLockdown()
end

function M.defer_objectives_combat_update()
    objectives_combat_update_pending = true
    if loader then
        loader:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

function M.apply_objectives()
    if not M.is_runtime_enabled() then return end

    if M.apply_background then
        M.apply_background()
    end
    if M.apply_auto_collapse then
        M.apply_auto_collapse()
    end
    if M.apply_section_count then
        M.apply_section_count()
    end
end

--#endregion OBJECTIVE TRACKER RUNTIME =========================================


--#region GUI ==================================================================

--#endregion GUI ===============================================================


--#region PUBLIC MODULE HOOKS ==================================================

function M.on_reset_complete()
    if M.migrate_background_settings then M.migrate_background_settings(M.get_db()) end
    if M.rebuild_tracker_tab then M.rebuild_tracker_tab() end
    M.apply_objectives()
    if M.refresh_profiles_tab then M.refresh_profiles_tab() end
end

function M.set_module_enabled(enabled)
    if enabled then
        M.apply_objectives()
    else
        if M.set_section_count_module_enabled then
            M.set_section_count_module_enabled(false)
        end
        if M.restore_background then
            M.restore_background()
        end
    end
end

if addon.register_module_status then
    addon.register_module_status(MODULE_KEY, function()
        local fields = {}
        if M.get_auto_collapse_status then
            for _, field in ipairs(M.get_auto_collapse_status()) do
                fields[#fields + 1] = field
            end
        end
        if M.get_background_status then
            for _, field in ipairs(M.get_background_status()) do
                fields[#fields + 1] = field
            end
        end
        if M.get_section_count_status then
            for _, field in ipairs(M.get_section_count_status()) do
                fields[#fields + 1] = field
            end
        end
        return fields
    end)
end

--#endregion PUBLIC MODULE HOOKS ===============================================


--#region EVENT BOOTSTRAP ======================================================

loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == addon_name then
            Ls_Tweeks_DB = Ls_Tweeks_DB or {}
            if M.migrate_background_settings then
                M.migrate_background_settings(Ls_Tweeks_DB.objectives)
            end
            addon.apply_defaults(DEFAULTS, Ls_Tweeks_DB)
            if addon.register_category then
                addon.register_category(CATEGORY_NAME, M.BuildSettings, { order = 600, module_key = MODULE_KEY })
            end
        elseif name == "Blizzard_ObjectiveTracker" then
            M.apply_objectives()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.apply_objectives()
        C_Timer.After(addon.UPDATE_INTERVALS.fifth_sec, function()
            M.apply_objectives()
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if not objectives_combat_update_pending then return end

        objectives_combat_update_pending = false
        if M.is_runtime_enabled() then
            M.apply_objectives()
        elseif M.restore_background then
            M.restore_background()
        end
    end
end)

--#endregion EVENT BOOTSTRAP ===================================================
