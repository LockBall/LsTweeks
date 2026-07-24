-- Background Colors module lifecycle, settings registration, resets, and status.


local addon_name, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync


--#region MODULE LIFECYCLE =====================================================

function M.on_reset_complete()
    M.normalize_db()
    if M.rebuild_general_tab then
        M.rebuild_general_tab()
    elseif M.sync_controls then
        M.sync_controls()
    end
    M.refresh_consumers()
    if M.refresh_profiles_tab then
        M.refresh_profiles_tab()
    end
end

function M.set_module_enabled(enabled)
    if enabled then
        M.normalize_db()
    end
    M.refresh_consumers()
end

--#endregion MODULE LIFECYCLE ==================================================


--#region STATUS ===============================================================

if addon.register_module_status then
    addon.register_module_status(M.MODULE_KEY, function()
        local db = M.get_db() or {}
        local fields = {
            "global=" .. tostring(db.global_enabled == true),
        }
        for _, consumer in ipairs(M.get_registered_consumers()) do
            local consumer_db = M.ensure_consumer_db(consumer.key)
            local selected = 0
            for _, target in ipairs(M.get_registered_targets(consumer.key)) do
                if M.get_target_enabled(consumer.key, target.key) then
                    selected = selected + 1
                end
            end
            fields[#fields + 1] = consumer.key .. "_global=" .. tostring(consumer_db.global_enabled == true)
            fields[#fields + 1] = consumer.key .. "_targets=" .. tostring(selected)
                .. "/" .. tostring(#M.get_registered_targets(consumer.key))
        end
        return fields
    end)
end

--#endregion STATUS ============================================================


--#region EVENT BOOTSTRAP ======================================================

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= addon_name then return end

    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    addon.apply_defaults(M.defaults, Ls_Tweeks_DB)
    M.normalize_db()
    if addon.register_category then
        addon.register_category(M.CATEGORY_NAME, M.BuildSettings, {
            order = 700,
            module_key = M.MODULE_KEY,
        })
    end

    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)
end)

--#endregion EVENT BOOTSTRAP ===================================================
