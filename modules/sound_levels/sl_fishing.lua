-- Fishing-specific Sound Levels behavior: temporary channel profile while
-- the player is channeling Fishing.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local FISHING_CHANNEL_SPELL_ID = 131476
local FISHING_BOBBER_SOUNDKIT_ID = 3355
local FISHING_BOBBER_SOUND_CHANNEL = "SFX"
local FISHING_BOBBER_PREVIEW_RESTORE_DELAY = 2.0
local _PlaySound = (C_Sound and C_Sound.PlaySound) or PlaySound
local _StopSound = (C_Sound and C_Sound.StopSound) or StopSound

M.FISHING_FOCUS_CHANNELS = {
    { key = "master", label = "Master", cvar = "Sound_MasterVolume" },
    { key = "music", label = "Music", cvar = "Sound_MusicVolume" },
    { key = "sfx", label = "Effects", cvar = "Sound_SFXVolume" },
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
    local raw_value = nil
    if M._fishing_focus_active and M._fishing_focus_cached then
        raw_value = M._fishing_focus_cached[channel.cvar]
    end
    if raw_value == nil then
        raw_value = get_cvar(channel.cvar)
    end
    local value = tonumber(raw_value)
    if not value then return 0 end
    return math.max(0, math.min(100, math.floor((value * 100) + 0.5)))
end

function M.get_default_fishing_focus_channel_percent(channel, current_percent)
    current_percent = current_percent or read_channel_percent(channel)
    if channel and channel.key == "sfx" then
        return math.min(100, current_percent + 25)
    end
    return current_percent
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
            db.fishing_focus[channel.key] = M.get_default_fishing_focus_channel_percent(channel)
        end
        db.fishing_focus.initialized_from_current = true
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local value = tonumber(db.fishing_focus[channel.key])
        if not value then
            value = M.get_default_fishing_focus_channel_percent(channel)
        end
        db.fishing_focus[channel.key] = math.max(0, math.min(100, value))
    end
    db.fishing_focus.enabled = db.fishing_focus.enabled == true
    return db.fishing_focus
end

function M.copy_current_sound_channels_to_fishing_focus()
    local focus_db = M.get_fishing_focus_db()
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        focus_db[channel.key] = read_channel_percent(channel)
    end
    return focus_db
end

function M.get_current_sound_channel_percent(channel)
    return read_channel_percent(channel)
end

local function restore_bobber_preview_profile()
    if M._fishing_bobber_preview_timer then
        M._fishing_bobber_preview_timer:Cancel()
        M._fishing_bobber_preview_timer = nil
    end
    if M._fishing_bobber_preview_handle then
        _StopSound(M._fishing_bobber_preview_handle)
        M._fishing_bobber_preview_handle = nil
    end
    for cvar_name, value in pairs(M._fishing_bobber_preview_cached or {}) do
        if value ~= nil then
            set_cvar(cvar_name, value)
        end
    end
    M._fishing_bobber_preview_cached = nil
end

function M.stop_fishing_bobber_preview()
    restore_bobber_preview_profile()
end

function M.play_fishing_bobber_preview(profile_key)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        restore_bobber_preview_profile()
        return false
    end

    restore_bobber_preview_profile()

    if profile_key ~= "fishing" then
        local did_play, sound_handle = _PlaySound(FISHING_BOBBER_SOUNDKIT_ID, FISHING_BOBBER_SOUND_CHANNEL)
        M._fishing_bobber_preview_handle = sound_handle
        return did_play ~= false
    end

    local focus_db = M.get_fishing_focus_db()
    local cached = {}
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        cached[channel.cvar] = get_cvar(channel.cvar)
        local percent = focus_db[channel.key]
        set_cvar(channel.cvar, tostring((tonumber(percent) or 0) / 100))
    end
    M._fishing_bobber_preview_cached = cached

    local did_play, sound_handle = _PlaySound(FISHING_BOBBER_SOUNDKIT_ID, FISHING_BOBBER_SOUND_CHANNEL)
    M._fishing_bobber_preview_handle = sound_handle
    M._fishing_bobber_preview_timer = C_Timer.NewTimer(FISHING_BOBBER_PREVIEW_RESTORE_DELAY, restore_bobber_preview_profile)
    return did_play ~= false
end

function M.apply_fishing_focus()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_fishing_focus()
        return
    end

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
    if M.stop_fishing_bobber_preview then
        M.stop_fishing_bobber_preview()
    end
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
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_fishing_focus()
        return
    end

    if M._fishing_focus_active then
        M.apply_fishing_focus()
    end
end

local function handle_fishing_focus_event(_, event, _, _, spell_id)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.sync_fishing_focus_events()
        return
    end

    if spell_id ~= FISHING_CHANNEL_SPELL_ID then return end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        M.apply_fishing_focus()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        M.restore_fishing_focus()
    end
end

function M.sync_fishing_focus_events()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_fishing_focus()
        if M._fishing_focus_events_registered and M.fishing_focus_frame then
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            M._fishing_focus_events_registered = false
        end
        return
    end

    local db = M.get_db()
    local raw_focus_db = db and db.fishing_focus
    if not (raw_focus_db and raw_focus_db.enabled == true) then
        M.restore_fishing_focus()
        if M._fishing_focus_events_registered and M.fishing_focus_frame then
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
            M.fishing_focus_frame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            M._fishing_focus_events_registered = false
        end
        return
    end

    M.get_fishing_focus_db()
    if not M.fishing_focus_frame then
        M.fishing_focus_frame = CreateFrame("Frame")
        M.fishing_focus_frame:SetScript("OnEvent", handle_fishing_focus_event)
    end
    if not M._fishing_focus_events_registered then
        M.fishing_focus_frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        M.fishing_focus_frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        M._fishing_focus_events_registered = true
    end
end
