-- Sound Levels module bootstrap: applies defaults, starts runtime state,
-- registers the settings category, and resyncs controls after reset.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.controls = M.controls or {}
M.frames = M.frames or {}

local CATEGORY_NAME = "Sound Levels"

function M.on_reset_complete()
    local db = M.get_db()
    addon.apply_defaults(M.defaults.sound_levels, db)
    M.apply_sound_levels()
    M.sync_registered_events()

    for target_key in pairs(M.SOUND_TARGETS or {}) do
        local target_db = M.get_target_db(target_key)
        local preset = M.controls[target_key .. "_preset"]
        if preset and preset.SetValue then
            local option = M.get_preset_by_value(target_db.preset)
            preset:SetValue(option and option.slider_value or 1)
        end
        local play_on_adjust = M.controls[target_key .. "_play_on_adjust"]
        if play_on_adjust and play_on_adjust.SetChecked then
            play_on_adjust:SetChecked(target_db.play_on_adjust == true)
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
        if M.unmute_all_sound_files then
            M.unmute_all_sound_files()
        end
    end
end)

