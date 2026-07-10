-- Audio Volumes situations: Fishing Focus, Combat Volumes, Quick Picks,
-- temporary channel CVars, situation previews, and situation event routing.
local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

local FISHING_CHANNEL_SPELL_ID = 131476
local FISHING_BOBBER_SOUNDKIT_ID = 3355
local FISHING_BOBBER_SOUND_CHANNEL = "SFX"
local FISHING_BOBBER_PREVIEW_RESTORE_DELAY = 2.0
local DEFAULT_TEST_SOUND_KEY = "bloodlust"
local CUSTOM_SITUATION_PREFIX = "custom:"
local _PlaySound = (C_Sound and C_Sound.PlaySound) or PlaySound
local _PlaySoundFile = (C_Sound and C_Sound.PlaySoundFile) or PlaySoundFile
local _StopSound = (C_Sound and C_Sound.StopSound) or StopSound

--#region CONFIGURATION ========================================================

M.FISHING_FOCUS_CHANNELS = {
    { key = "master", label = "Master", cvar = "Sound_MasterVolume" },
    { key = "music", label = "Music", cvar = "Sound_MusicVolume" },
    { key = "sfx", label = "Effects", cvar = "Sound_SFXVolume" },
    { key = "ambience", label = "Ambience", cvar = "Sound_AmbienceVolume" },
    { key = "dialog", label = "Dialog", cvar = "Sound_DialogVolume" },
}

M.TEST_SOUND_OPTIONS = {
    { value = "bloodlust", text = "Bloodlust", file_id = 568812, channel = "SFX" }, -- Bloodlust
}

function M.get_test_sound_option(sound_key)
    for _, option in ipairs(M.TEST_SOUND_OPTIONS or {}) do
        if option.value == sound_key then
            return option
        end
    end
    return nil
end

function M.get_valid_test_sound_key(sound_key, fallback)
    if M.get_test_sound_option(sound_key) then
        return sound_key
    end
    fallback = fallback or DEFAULT_TEST_SOUND_KEY
    if M.get_test_sound_option(fallback) then
        return fallback
    end
    return (M.TEST_SOUND_OPTIONS and M.TEST_SOUND_OPTIONS[1] and M.TEST_SOUND_OPTIONS[1].value) or DEFAULT_TEST_SOUND_KEY
end

--#endregion CONFIGURATION =====================================================

--#region CVAR HELPERS =========================================================

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
    if (M._fishing_focus_active or M._combat_volumes_active or M._manual_situation_active_key) and M._temporary_sound_profile_cached then
        raw_value = M._temporary_sound_profile_cached[channel.cvar]
    end
    if raw_value == nil then
        raw_value = get_cvar(channel.cvar)
    end
    local value = tonumber(raw_value)
    if not value then return 0 end
    return math.max(0, math.min(100, math.floor((value * 100) + 0.5)))
end

--#endregion CVAR HELPERS ======================================================

--#region DATABASE =============================================================

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
    local defaults = M.defaults and M.defaults.audio_volumes and M.defaults.audio_volumes.fishing_focus
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

function M.get_combat_volumes_db()
    local db = M.get_db()
    db.combat_volumes = db.combat_volumes or {}
    local defaults = M.defaults and M.defaults.audio_volumes and M.defaults.audio_volumes.combat_volumes
    if defaults then
        addon.apply_defaults(defaults, db.combat_volumes)
    end
    if db.combat_volumes.initialized_from_current ~= true then
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            db.combat_volumes[channel.key] = read_channel_percent(channel)
        end
        db.combat_volumes.initialized_from_current = true
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local value = tonumber(db.combat_volumes[channel.key])
        if not value then
            value = read_channel_percent(channel)
        end
        db.combat_volumes[channel.key] = math.max(0, math.min(100, value))
    end
    db.combat_volumes.enabled = db.combat_volumes.enabled == true
    db.combat_volumes.test_sound = M.get_valid_test_sound_key(db.combat_volumes.test_sound, "bloodlust")
    return db.combat_volumes
end

local function sanitize_custom_situation_name(name, fallback)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then
        return fallback or "Custom Situation"
    end
    return name
end

function M.get_quiet_custom_db()
    local db = M.get_db()
    db.quiet_custom = db.quiet_custom or {}
    local defaults = M.defaults and M.defaults.audio_volumes and M.defaults.audio_volumes.quiet_custom
    if defaults then
        addon.apply_defaults(defaults, db.quiet_custom)
    end
    db.quiet_custom.name = sanitize_custom_situation_name(db.quiet_custom.name, "Quiet Custom")
    db.quiet_custom.enabled = db.quiet_custom.enabled == true
    db.quiet_custom.test_sound = M.get_valid_test_sound_key(db.quiet_custom.test_sound, "bloodlust")
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local value = tonumber(db.quiet_custom[channel.key])
        if not value then
            value = 25
        end
        db.quiet_custom[channel.key] = math.max(0, math.min(100, value))
    end
    return db.quiet_custom
end

function M.get_custom_situations_db()
    local db = M.get_db()
    db.custom_situations = db.custom_situations or {}
    db.next_custom_situation_id = math.max(1, tonumber(db.next_custom_situation_id) or 1)
    return db.custom_situations
end

local function get_custom_situation_id(situation_key)
    if type(situation_key) ~= "string" then return nil end
    return situation_key:match("^" .. CUSTOM_SITUATION_PREFIX .. "(.+)$")
end

function M.get_custom_situation_db(situation_key)
    local situation_id = get_custom_situation_id(situation_key)
    if not situation_id then return nil end
    return M.get_custom_situations_db()[situation_id]
end

local function get_next_custom_situation_id(situations)
    local id = 1
    while situations[tostring(id)] do
        id = id + 1
    end
    return id
end

function M.create_custom_situation(name)
    local db = M.get_db()
    local situations = M.get_custom_situations_db()
    local id_num = get_next_custom_situation_id(situations)
    local id = tostring(id_num)

    local situation = {
        name = sanitize_custom_situation_name(name, "Custom " .. id),
        enabled = false,
        test_sound = "bloodlust",
    }
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        situation[channel.key] = read_channel_percent(channel)
    end
    situations[id] = situation
    db.next_custom_situation_id = get_next_custom_situation_id(situations)
    db.last_situation_key = CUSTOM_SITUATION_PREFIX .. id
    return db.last_situation_key, situation
end

function M.delete_custom_situation(situation_key)
    local situation_id = get_custom_situation_id(situation_key)
    if not situation_id then return false end
    local situations = M.get_custom_situations_db()
    if not situations[situation_id] then return false end
    situations[situation_id] = nil
    local db = M.get_db()
    if db.last_situation_key == situation_key then
        db.last_situation_key = "fishing"
    end
    db.next_custom_situation_id = get_next_custom_situation_id(situations)
    return true
end

function M.rename_custom_situation(situation_key, name)
    local situation = M.get_custom_situation_db(situation_key)
    if not situation then return false end
    situation.name = sanitize_custom_situation_name(name, situation.name)
    return true
end

function M.rename_situation(situation_key, name)
    if situation_key == "quiet_custom" then
        local situation = M.get_quiet_custom_db()
        situation.name = sanitize_custom_situation_name(name, situation.name or "Quiet Custom")
        return true
    end
    return M.rename_custom_situation(situation_key, name)
end

function M.get_situation_profile_db(situation_key)
    if situation_key == "fishing" then
        return M.get_fishing_focus_db()
    end
    if situation_key == "combat" then
        return M.get_combat_volumes_db()
    end
    if situation_key == "quiet_custom" then
        return M.get_quiet_custom_db()
    end
    local situation = M.get_custom_situation_db(situation_key)
    if not situation then return nil end
    situation.enabled = situation.enabled == true
    situation.test_sound = M.get_valid_test_sound_key(situation.test_sound, "bloodlust")
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local value = tonumber(situation[channel.key])
        if not value then
            value = read_channel_percent(channel)
        end
        situation[channel.key] = math.max(0, math.min(100, value))
    end
    return situation
end

local function get_manual_situation_entries()
    local entries = {
        { key = "quiet_custom", db = M.get_quiet_custom_db() },
    }
    local custom_situations = M.get_custom_situations_db()
    local custom_ids = {}
    for situation_id in pairs(custom_situations or {}) do
        custom_ids[#custom_ids + 1] = situation_id
    end
    table.sort(custom_ids, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
    for _, situation_id in ipairs(custom_ids) do
        local situation_key = CUSTOM_SITUATION_PREFIX .. situation_id
        entries[#entries + 1] = {
            key = situation_key,
            db = M.get_situation_profile_db(situation_key),
        }
    end
    return entries
end

local function get_enabled_manual_situation_key()
    for _, entry in ipairs(get_manual_situation_entries()) do
        if entry.db and entry.db.enabled == true then
            return entry.key
        end
    end
    return nil
end

function M.set_manual_situation_enabled(situation_key, enabled)
    local selected_db = M.get_situation_profile_db(situation_key)
    if not selected_db then return false end

    for _, entry in ipairs(get_manual_situation_entries()) do
        if entry.db then
            entry.db.enabled = enabled == true and entry.key == situation_key
        end
    end
    if enabled ~= true then
        selected_db.enabled = false
    end
    M.sync_manual_situation_profile()
    return true
end

function M.get_quick_pick_menu_entries()
    local entries = {}
    local quiet_custom = M.get_quiet_custom_db()
    entries[#entries + 1] = {
        key = "quiet_custom",
        label = quiet_custom.name or "Quiet Custom",
        enabled = quiet_custom.enabled == true,
    }

    local custom_situations = M.get_custom_situations_db()
    local custom_ids = {}
    for situation_id in pairs(custom_situations or {}) do
        custom_ids[#custom_ids + 1] = situation_id
    end
    table.sort(custom_ids, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
    for _, situation_id in ipairs(custom_ids) do
        local situation_key = CUSTOM_SITUATION_PREFIX .. situation_id
        local situation = M.get_situation_profile_db(situation_key)
        if situation then
            entries[#entries + 1] = {
                key = situation_key,
                label = situation.name or ("Custom " .. situation_id),
                enabled = situation.enabled == true,
            }
        end
    end
    return entries
end

function M.set_quick_pick_from_menu(situation_key, enabled)
    if not M.set_manual_situation_enabled(situation_key, enabled) then
        return false
    end
    local db = M.get_db()
    db.last_quick_pick_key = situation_key
    db.last_situation_key = situation_key
    if M.sync_temporary_profile_controls then
        M.sync_temporary_profile_controls()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if M.sync_temporary_profile_controls then
                M.sync_temporary_profile_controls()
            end
        end)
    end
    return true
end

function M.copy_current_sound_channels_to_fishing_focus()
    local focus_db = M.get_fishing_focus_db()
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        focus_db[channel.key] = read_channel_percent(channel)
    end
    return focus_db
end

function M.copy_current_sound_channels_to_situation(situation_key)
    local profile_db = M.get_situation_profile_db(situation_key)
    if not profile_db then return nil end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        profile_db[channel.key] = read_channel_percent(channel)
    end
    return profile_db
end

function M.copy_current_sound_channels_to_combat_volumes()
    local combat_db = M.get_combat_volumes_db()
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        combat_db[channel.key] = read_channel_percent(channel)
    end
    return combat_db
end

function M.get_current_sound_channel_percent(channel)
    return read_channel_percent(channel)
end

function M.set_current_sound_channel_percent(channel, percent)
    if not channel then return end
    local value = math.max(0, math.min(100, tonumber(percent) or 0))
    local cvar_value = tostring(value / 100)
    if (M._fishing_focus_active or M._combat_volumes_active or M._manual_situation_active_key) and M._temporary_sound_profile_cached then
        M._temporary_sound_profile_cached[channel.cvar] = cvar_value
        M._fishing_focus_cached = M._temporary_sound_profile_cached
        return
    end
    set_cvar(channel.cvar, cvar_value)
end

--#endregion DATABASE ==========================================================

--#region PREVIEW PLAYBACK =====================================================

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

    local profile_db = nil
    profile_db = M.get_situation_profile_db(profile_key)

    if not profile_db then
        ---@diagnostic disable-next-line: param-type-mismatch -- Ketho types C_Sound.PlaySound channel as numeric, but current client accepts string channels.
        local did_play, sound_handle = _PlaySound(FISHING_BOBBER_SOUNDKIT_ID, FISHING_BOBBER_SOUND_CHANNEL)
        M._fishing_bobber_preview_handle = sound_handle
        return did_play ~= false
    end

    local cached = {}
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        cached[channel.cvar] = get_cvar(channel.cvar)
        local percent = profile_db[channel.key]
        set_cvar(channel.cvar, tostring((tonumber(percent) or 0) / 100))
    end
    M._fishing_bobber_preview_cached = cached

    ---@diagnostic disable-next-line: param-type-mismatch -- Ketho types C_Sound.PlaySound channel as numeric, but current client accepts string channels.
    local did_play, sound_handle = _PlaySound(FISHING_BOBBER_SOUNDKIT_ID, FISHING_BOBBER_SOUND_CHANNEL)
    M._fishing_bobber_preview_handle = sound_handle
    M._fishing_bobber_preview_timer = C_Timer.NewTimer(FISHING_BOBBER_PREVIEW_RESTORE_DELAY, restore_bobber_preview_profile)
    return did_play ~= false
end

function M.play_situation_preview(profile_key, test_sound_key)
    if profile_key == "fishing" or (profile_key == "current" and not test_sound_key) then
        return M.play_fishing_bobber_preview(profile_key)
    end
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        restore_bobber_preview_profile()
        return false
    end

    restore_bobber_preview_profile()

    local profile_db = M.get_situation_profile_db(profile_key)
    local test_sound = M.get_test_sound_option(test_sound_key)
        or M.get_test_sound_option(profile_db and profile_db.test_sound)
        or M.get_test_sound_option(DEFAULT_TEST_SOUND_KEY)
        or (M.TEST_SOUND_OPTIONS and M.TEST_SOUND_OPTIONS[1])
    if not test_sound then return false end

    if not profile_db then
        local did_play, sound_handle
        if test_sound.file_id then
            did_play, sound_handle = _PlaySoundFile(test_sound.file_id, test_sound.channel or "SFX")
        else
            ---@diagnostic disable-next-line: param-type-mismatch -- Ketho types C_Sound.PlaySound channel as numeric, but current client accepts string channels.
            did_play, sound_handle = _PlaySound(test_sound.soundkit, test_sound.channel or "SFX")
        end
        M._fishing_bobber_preview_handle = sound_handle
        return did_play ~= false
    end

    local cached = {}
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        cached[channel.cvar] = get_cvar(channel.cvar)
        local percent = profile_db[channel.key]
        set_cvar(channel.cvar, tostring((tonumber(percent) or 0) / 100))
    end
    M._fishing_bobber_preview_cached = cached

    local did_play, sound_handle
    if test_sound.file_id then
        did_play, sound_handle = _PlaySoundFile(test_sound.file_id, test_sound.channel or "SFX")
    else
        ---@diagnostic disable-next-line: param-type-mismatch -- Ketho types C_Sound.PlaySound channel as numeric, but current client accepts string channels.
        did_play, sound_handle = _PlaySound(test_sound.soundkit, test_sound.channel or "SFX")
    end
    M._fishing_bobber_preview_handle = sound_handle
    M._fishing_bobber_preview_timer = C_Timer.NewTimer(FISHING_BOBBER_PREVIEW_RESTORE_DELAY, restore_bobber_preview_profile)
    return did_play ~= false
end

--#endregion PREVIEW PLAYBACK ==================================================

--#region TEMPORARY PROFILE RUNTIME ============================================

local function ensure_temporary_sound_profile_cache()
    M._temporary_sound_profile_cached = M._temporary_sound_profile_cached or {}
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        if M._temporary_sound_profile_cached[channel.cvar] == nil then
            M._temporary_sound_profile_cached[channel.cvar] = get_cvar(channel.cvar)
        end
    end
    M._fishing_focus_cached = M._temporary_sound_profile_cached
end

local function apply_channel_profile(profile_db)
    ensure_temporary_sound_profile_cache()
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        set_cvar(channel.cvar, tostring((tonumber(profile_db[channel.key]) or 0) / 100))
    end
end

local function restore_cached_normal_profile()
    for cvar_name, value in pairs(M._temporary_sound_profile_cached or {}) do
        if value ~= nil then
            set_cvar(cvar_name, value)
        end
    end
    M._temporary_sound_profile_cached = nil
    M._fishing_focus_cached = nil
end

function M.apply_active_sound_channel_profile()
    restore_bobber_preview_profile()

    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M._fishing_focus_active = false
        M._combat_volumes_active = false
        M._manual_situation_active_key = nil
        restore_cached_normal_profile()
        return
    end

    if M._combat_volumes_active then
        apply_channel_profile(M.get_combat_volumes_db())
        return
    end
    if M._fishing_focus_active then
        apply_channel_profile(M.get_fishing_focus_db())
        return
    end
    if M._manual_situation_active_key then
        local profile_db = M.get_situation_profile_db(M._manual_situation_active_key)
        if profile_db then
            apply_channel_profile(profile_db)
            return
        end
        M._manual_situation_active_key = nil
    end
    restore_cached_normal_profile()
end

function M.sync_manual_situation_profile()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M._manual_situation_active_key = nil
        M.apply_active_sound_channel_profile()
        return
    end

    M._manual_situation_active_key = get_enabled_manual_situation_key()
    if M._manual_situation_active_key then
        for _, entry in ipairs(get_manual_situation_entries()) do
            if entry.db then
                entry.db.enabled = entry.key == M._manual_situation_active_key
            end
        end
    end
    M.apply_active_sound_channel_profile()
end

function M.restore_manual_situation_profile()
    if not M._manual_situation_active_key then return end

    M._manual_situation_active_key = nil
    M.apply_active_sound_channel_profile()
end

function M.resync_manual_situation_profile()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_manual_situation_profile()
        return
    end

    if M._manual_situation_active_key then
        M.apply_active_sound_channel_profile()
    end
end

function M.apply_fishing_focus()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_fishing_focus()
        return
    end

    local focus_db = M.get_fishing_focus_db()
    if focus_db.enabled ~= true then return end

    M._fishing_focus_active = true
    M.apply_active_sound_channel_profile()
end

function M.restore_fishing_focus()
    if M.stop_fishing_bobber_preview then
        M.stop_fishing_bobber_preview()
    end
    if not M._fishing_focus_active then return end

    M._fishing_focus_active = false
    M.apply_active_sound_channel_profile()
end

function M.resync_fishing_focus()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_fishing_focus()
        return
    end

    if M._fishing_focus_active then
        M.apply_active_sound_channel_profile()
    end
end

function M.apply_combat_volumes()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_combat_volumes()
        return
    end

    local combat_db = M.get_combat_volumes_db()
    if combat_db.enabled ~= true then return end

    M._fishing_focus_active = false
    M._combat_volumes_active = true
    M.apply_active_sound_channel_profile()
end

function M.restore_combat_volumes()
    if not M._combat_volumes_active then return end

    M._combat_volumes_active = false
    M.apply_active_sound_channel_profile()
end

function M.resync_combat_volumes()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_combat_volumes()
        return
    end

    if M._combat_volumes_active then
        M.apply_active_sound_channel_profile()
    end
end

--#endregion TEMPORARY PROFILE RUNTIME =========================================

--#region EVENT ROUTING ========================================================

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

local function handle_combat_volumes_event(_, event)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.sync_combat_volumes_events()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        M.apply_combat_volumes()
    elseif event == "PLAYER_REGEN_ENABLED" then
        M.restore_combat_volumes()
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

function M.sync_combat_volumes_events()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.restore_combat_volumes()
        if M._combat_volumes_events_registered and M.combat_volumes_frame then
            M.combat_volumes_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            M.combat_volumes_frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            M._combat_volumes_events_registered = false
        end
        return
    end

    local db = M.get_db()
    local raw_combat_db = db and db.combat_volumes
    if not (raw_combat_db and raw_combat_db.enabled == true) then
        M.restore_combat_volumes()
        if M._combat_volumes_events_registered and M.combat_volumes_frame then
            M.combat_volumes_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            M.combat_volumes_frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            M._combat_volumes_events_registered = false
        end
        return
    end

    M.get_combat_volumes_db()
    if not M.combat_volumes_frame then
        M.combat_volumes_frame = CreateFrame("Frame")
        M.combat_volumes_frame:SetScript("OnEvent", handle_combat_volumes_event)
    end
    if not M._combat_volumes_events_registered then
        M.combat_volumes_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        M.combat_volumes_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        M._combat_volumes_events_registered = true
    end
    if InCombatLockdown and InCombatLockdown() then
        M.apply_combat_volumes()
    end
end

--#endregion EVENT ROUTING =====================================================
