-- Audio Volumes main controller: applies defaults, starts runtime state,
-- registers the settings category, and resyncs controls after reset.
local addon_name, addon = ...

local M = addon.audio_volumes

local CATEGORY_NAME = "Audio Volumes"

--#region RESET AND MODULE HOOKS ===============================================

function M.on_reset_complete()
    M.stop_all_previews()
    M.restore_combat_volumes()
    M.restore_fishing_focus()
    M._defaults_applied = nil
    M._target_defaults_applied = {}
    local db = M.get_db()
    if not (db.last_sound_key and M.SOUND_TARGETS[db.last_sound_key]) then
        db.last_sound_key = M.defaults.audio_volumes.last_sound_key
    end
    if type(db.last_tab_index) ~= "number" then
        db.last_tab_index = M.defaults.audio_volumes.last_tab_index
    end
    M.apply_audio_volumes()

    for target_key in pairs(M.SOUND_TARGETS) do
        local target_db = M.get_target_db(target_key)
        local preset = M.controls[target_key .. "_preset"]
        if preset then
            local option = M.get_preset_by_value(target_db.preset)
            local slider_value = target_db.sound_off == true and 0 or (option and option.slider_value or 0)
            if preset._lstweeks_set_sound_level_value then
                preset:_lstweeks_set_sound_level_value(slider_value)
            else
                preset:SetValue(slider_value)
            end
        end
        local play_on_adjust = M.controls[target_key .. "_play_on_adjust"]
        if play_on_adjust then
            play_on_adjust:SetCheckedSilently(target_db.play_on_adjust == true)
        end
        local use_original = M.controls[target_key .. "_use_original"]
        if use_original then
            use_original:SetCheckedSilently(target_db.use_original == true)
        end
        if preset then
            preset:_lstweeks_sync_original_state()
        end
    end

    if M.rebuild_situations_tab then
        M.rebuild_situations_tab()
    end
    if M.refresh_profiles_tab then
        M.refresh_profiles_tab()
    end
    M.sync_temporary_profile_controls()
    M.sync_fishing_focus_events()
    M.sync_combat_volumes_events()
    M.sync_manual_situation_profile()
end

function M.set_module_enabled(enabled)
    if enabled then
        M.get_db()
        M.apply_audio_volumes()
        M.sync_fishing_focus_events()
        M.sync_combat_volumes_events()
        M.sync_manual_situation_profile()
        return
    end

    M.stop_runtime()
end

local function count_pairs(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

addon.register_module_status(M.MODULE_KEY, function()
    return {
        "registered_events=" .. tostring(count_pairs(M._registered_events)),
        "event_cache=" .. tostring(count_pairs(M._event_cache)),
        "preview_handle=" .. tostring(M._preview_sound_handle ~= nil),
        "adjust_preview_timer=" .. tostring(M._adjust_preview_timer ~= nil),
        "fishing_events=" .. tostring(M._fishing_focus_events_registered == true),
        "fishing_active=" .. tostring(M._fishing_focus_active == true),
        "combat_volume_events=" .. tostring(M._combat_volumes_events_registered == true),
        "combat_volume_active=" .. tostring(M._combat_volumes_active == true),
        "bobber_preview_timer=" .. tostring(M._fishing_bobber_preview_timer ~= nil),
        "bobber_preview_handle=" .. tostring(M._fishing_bobber_preview_handle ~= nil),
    }
end)

--#endregion RESET AND MODULE HOOKS ============================================

--#region EVENT BOOTSTRAP ======================================================

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        M.get_db()
        M.apply_audio_volumes()
        M.sync_fishing_focus_events()
        M.sync_combat_volumes_events()
        M.sync_manual_situation_profile()
        addon.register_category(CATEGORY_NAME, M.BuildSettings, { order = 400, module_key = M.MODULE_KEY })
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        M.stop_runtime()
    end
end)

--#endregion EVENT BOOTSTRAP ===================================================
