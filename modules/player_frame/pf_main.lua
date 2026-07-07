-- Player Frame main controller: portrait combat text, lifecycle, and events.
-- Registers the "Player Frame" settings category and applies changes immediately.
local addon_name, addon = ...
addon.player_frame = addon.player_frame or {
    controls = {},
    frames = {}
}

local M = addon.player_frame

local math_min = math.min
local math_max = math.max
local MODULE_KEY = M.MODULE_KEY

--#region SETTINGS AND DEFAULTS ================================================

local defaults = M.defaults
local FADE_DEFAULTS = M.FADE_DEFAULTS
local FADE_SETTING_RANGES = M.FADE_SETTING_RANGES

--#endregion SETTINGS AND DEFAULTS =============================================

--#region RUNTIME STATE ========================================================

local hitIndicatorFrame = nil
local hookApplied = false
local hidePortraitText = false
local fadeEventsRegistered = false
local loader = nil

--#endregion RUNTIME STATE =====================================================

--#region DATABASE HELPERS =====================================================

local function get_player_frame_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.player_frame = Ls_Tweeks_DB.player_frame or {}
    return Ls_Tweeks_DB.player_frame
end

M.get_db = get_player_frame_db

function M.get_clamped_fade_value(db, key, min_value, max_value)
    local range = FADE_SETTING_RANGES[key]
    min_value = min_value or (range and range.min)
    max_value = max_value or (range and range.max)
    local value = tonumber(db and db[key]) or FADE_DEFAULTS[key]
    return math_max(min_value, math_min(max_value, value))
end

--#endregion DATABASE HELPERS ==================================================

--#region RUNTIME LOGIC ========================================================

local function is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(MODULE_KEY)
end

local function get_hit_indicator()
    if hitIndicatorFrame then return hitIndicatorFrame end

    if PlayerFrame and PlayerFrame.PlayerFrameContent then
        local content = PlayerFrame.PlayerFrameContent
        local main = content.PlayerFrameContentMain
        if main and main.HitIndicator then
            hitIndicatorFrame = main.HitIndicator
            return hitIndicatorFrame
        end
    end

    return nil
end

local function setup_on_show_hook(frame)
    if hookApplied or not frame then return end

    frame:HookScript("OnShow", function(self)
        self:SetAlpha(hidePortraitText and 0 or 1)
    end)
    hookApplied = true
end

local function sync_fade_events(db)
    if not loader then return end

    local should_register = db and db.fade_out_of_combat
    if should_register == fadeEventsRegistered then return end

    if should_register then
        loader:RegisterEvent("PLAYER_REGEN_DISABLED")
        loader:RegisterEvent("PLAYER_REGEN_ENABLED")
        loader:RegisterUnitEvent("UNIT_HEALTH", "player")
        loader:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    else
        loader:UnregisterEvent("PLAYER_REGEN_DISABLED")
        loader:UnregisterEvent("PLAYER_REGEN_ENABLED")
        loader:UnregisterEvent("UNIT_HEALTH")
        loader:UnregisterEvent("UNIT_MAXHEALTH")
    end

    fadeEventsRegistered = should_register and true or false
end

local function set_portrait_combat_text_hidden(disable)
    hidePortraitText = disable == true

    local h = get_hit_indicator()
    if not h then return end

    if hidePortraitText then
        h:SetAlpha(0)
        setup_on_show_hook(h)
    else
        h:SetAlpha(1)
    end
end

local function set_player_frame_setting(key, value)
    local db = get_player_frame_db()
    if not db then return end
    if db[key] == value then return end

    db[key] = value
    if key == "health_visible_threshold" and is_runtime_enabled() then
        M.fade.on_threshold_changed(db)
    end
    M.update_player_frame()
end

M.set_player_frame_setting = set_player_frame_setting

local function on_fade_slider_changed(key)
    if is_runtime_enabled() and M.fade.on_fade_setting_changed then
        M.fade.on_fade_setting_changed(get_player_frame_db(), key)
    end
    M.update_player_frame()
end

M.on_fade_slider_changed = on_fade_slider_changed

local function stop_runtime()
    sync_fade_events(nil)
    if hidePortraitText then
        set_portrait_combat_text_hidden(false)
    end
    M.fade.stop_transition()
    if PlayerFrame then
        PlayerFrame:SetAlpha(1)
    end
end

local function start_runtime(db)
    if not db then return end
    sync_fade_events(db)
    set_portrait_combat_text_hidden(db.hide_portrait_combat_text)
    M.fade.apply(db)
end

local function handle_runtime_event(event)
    if not is_runtime_enabled() then
        stop_runtime()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        M.fade.on_enter_combat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        M.fade.on_leave_combat(get_player_frame_db())
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        M.fade.queue_health_update(get_player_frame_db)
    end
end

--#endregion RUNTIME LOGIC =====================================================

--#region PUBLIC MODULE HOOKS ==================================================

function M.update_player_frame()
    if not is_runtime_enabled() then
        stop_runtime()
        return
    end

    local db = get_player_frame_db()
    start_runtime(db)
end

function M.set_module_enabled(enabled)
    if enabled then
        M.update_player_frame()
        return
    end

    stop_runtime()
end

if addon.register_module_status then
    addon.register_module_status(MODULE_KEY, function()
        local fade_status = M.fade and M.fade.get_runtime_status and M.fade.get_runtime_status()
        local fields = {
            "fade_events=" .. tostring(fadeEventsRegistered == true),
            "loader_event_script=" .. tostring(loader and loader:GetScript("OnEvent") ~= nil),
            "hide_portrait_text=" .. tostring(hidePortraitText == true),
        }
        if fade_status then
            fields[#fields + 1] = "fade_state=" .. tostring(fade_status.state)
            fields[#fields + 1] = "fade_delay_timer=" .. tostring(fade_status.fade_delay_timer == true)
            fields[#fields + 1] = "fade_ticker=" .. tostring(fade_status.fade_ticker == true)
            fields[#fields + 1] = "queued_health_timer=" .. tostring(fade_status.queued_health_timer == true)
        end
        return fields
    end)
end

--#endregion PUBLIC MODULE HOOKS ===============================================

--#region EVENT ROUTING ========================================================

loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

local function init_complete(self)
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end

        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        addon.apply_defaults(defaults, Ls_Tweeks_DB)

        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.build_options_panel, { module_key = MODULE_KEY })
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.update_player_frame()
        init_complete(self)
    elseif event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED"
        or event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH"
    then
        handle_runtime_event(event)
    end
end)

--#endregion EVENT ROUTING =====================================================
