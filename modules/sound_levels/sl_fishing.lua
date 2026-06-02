-- Fishing-specific Sound Levels behavior: temporary channel profile while
-- the player is channeling Fishing.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local FISHING_CHANNEL_SPELL_ID = 131476

M.FISHING_FOCUS_CHANNELS = {
    { key = "master", label = "Master", cvar = "Sound_MasterVolume" },
    { key = "sfx", label = "Effects", cvar = "Sound_SFXVolume" },
    { key = "music", label = "Music", cvar = "Sound_MusicVolume" },
    { key = "ambience", label = "Ambience", cvar = "Sound_AmbienceVolume" },
    { key = "dialog", label = "Dialog", cvar = "Sound_DialogVolume" },
}

local function get_cvar(cvar_name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(cvar_name)
    end
    if GetCVar then
        return GetCVar(cvar_name)
    end
    return nil
end

local function set_cvar(cvar_name, value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(cvar_name, value)
        return
    end
    if SetCVar then
        SetCVar(cvar_name, value)
    end
end

local function read_channel_percent(channel)
    if not channel then return 0 end
    local raw_value = M._fishing_focus_active and M._fishing_focus_cached and M._fishing_focus_cached[channel.cvar]
    if raw_value == nil then
        raw_value = get_cvar(channel.cvar)
    end
    local value = tonumber(raw_value)
    if not value then return 0 end
    return math.max(0, math.min(100, math.floor((value * 100) + 0.5)))
end

function M.get_fishing_focus_db()
    local db = M.get_db()
    db.fishing_focus = db.fishing_focus or {}
    local defaults = M.defaults and M.defaults.sound_levels and M.defaults.sound_levels.fishing_focus
    if defaults then
        addon.apply_defaults(defaults, db.fishing_focus)
    end
    if db.fishing_focus.initialized_from_current ~= true then
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            db.fishing_focus[channel.key] = read_channel_percent(channel)
        end
        db.fishing_focus.initialized_from_current = true
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local value = tonumber(db.fishing_focus[channel.key])
        if not value then
            value = read_channel_percent(channel)
        end
        db.fishing_focus[channel.key] = math.max(0, math.min(100, value))
    end
    db.fishing_focus.enabled = db.fishing_focus.enabled == true
    return db.fishing_focus
end

function M.get_current_sound_channel_percent(channel)
    return read_channel_percent(channel)
end

function M.apply_fishing_focus()
    local focus_db = M.get_fishing_focus_db()
    if focus_db.enabled ~= true then return end

    M._fishing_focus_active = true
    M._fishing_focus_cached = M._fishing_focus_cached or {}

    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        if M._fishing_focus_cached[channel.cvar] == nil then
            M._fishing_focus_cached[channel.cvar] = get_cvar(channel.cvar)
        end
        set_cvar(channel.cvar, tostring((tonumber(focus_db[channel.key]) or 0) / 100))
    end
end

function M.restore_fishing_focus()
    if not M._fishing_focus_active then return end

    for cvar_name, value in pairs(M._fishing_focus_cached or {}) do
        if value ~= nil then
            set_cvar(cvar_name, value)
        end
    end
    M._fishing_focus_cached = nil
    M._fishing_focus_active = false
end

function M.resync_fishing_focus()
    if M._fishing_focus_active then
        M.apply_fishing_focus()
    end
end

local function handle_fishing_focus_event(_, event, unit, _, spell_id)
    if unit ~= "player" or spell_id ~= FISHING_CHANNEL_SPELL_ID then return end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        M.apply_fishing_focus()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        M.restore_fishing_focus()
    end
end

function M.sync_fishing_focus_events()
    local focus_db = M.get_fishing_focus_db()
    if not M.fishing_focus_frame then
        M.fishing_focus_frame = CreateFrame("Frame")
        M.fishing_focus_frame:SetScript("OnEvent", handle_fishing_focus_event)
    end

    if focus_db.enabled == true then
        if not M._fishing_focus_events_registered then
            M.fishing_focus_frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
            M.fishing_focus_frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
            M._fishing_focus_events_registered = true
        end
    else
        M.restore_fishing_focus()
        if M._fishing_focus_events_registered then
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            M._fishing_focus_events_registered = false
        end
    end
end
