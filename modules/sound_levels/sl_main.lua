-- Sound Levels module bootstrap: applies defaults, starts runtime state,
-- registers the settings category, and resyncs controls after reset.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local CATEGORY_NAME = "Sound Levels"

function M.on_reset_complete()
    M._defaults_applied = nil
    local db = M.get_db()
    if not (db.last_sound_key and M.SOUND_TARGETS and M.SOUND_TARGETS[db.last_sound_key]) then
        db.last_sound_key = M.defaults.sound_levels.last_sound_key
    end
    if type(db.last_tab_index) ~= "number" then
        db.last_tab_index = M.defaults.sound_levels.last_tab_index
    end
    M.apply_sound_levels()
    M.sync_registered_events()

    for target_key in pairs(M.SOUND_TARGETS or {}) do
        local target_db = M.get_target_db(target_key)
        local preset = M.controls[target_key .. "_preset"]
        if preset and preset.SetValue then
            local option = M.get_preset_by_value(target_db.preset)
            local slider_value = target_db.sound_off == true and 0 or (option and option.slider_value or 0)
            if preset._lstweeks_set_sound_level_value then
                preset:_lstweeks_set_sound_level_value(slider_value)
            else
                preset:SetValue(slider_value)
            end
        end
        local play_on_adjust = M.controls[target_key .. "_play_on_adjust"]
        if play_on_adjust and play_on_adjust.SetChecked then
            play_on_adjust:SetChecked(target_db.play_on_adjust == true)
        end
        local use_original = M.controls[target_key .. "_use_original"]
        if use_original and use_original.SetChecked then
            use_original:SetChecked(target_db.use_original == true)
        end
        if preset and preset._lstweeks_sync_original_state then
            preset:_lstweeks_sync_original_state()
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        M.get_db()
        M.apply_sound_levels()
        M.sync_registered_events()
        if addon.register_category and M.BuildSettings then
            addon.register_category(CATEGORY_NAME, M.BuildSettings, { order = 900 })
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        M.unmute_all_sound_files()
    end
end)
