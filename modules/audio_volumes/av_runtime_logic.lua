-- Runtime behavior for Audio Volumes: applies file mutes, plays previews and
-- replacements, and wires WoW events to selected replacement sounds.
local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

local _PlaySoundFile   = (C_Sound and C_Sound.PlaySoundFile)   or PlaySoundFile
local _PlaySound       = (C_Sound and C_Sound.PlaySound)       or PlaySound
local _StopSound       = (C_Sound and C_Sound.StopSound)       or StopSound
local _MuteSoundFile   = (C_Sound and C_Sound.MuteSoundFile)   or MuteSoundFile
local _UnmuteSoundFile = (C_Sound and C_Sound.UnmuteSoundFile) or UnmuteSoundFile

--#region RUNTIME LIFECYCLE ====================================================

function M.stop_runtime()
    if M.stop_all_previews then
        M.stop_all_previews()
    end
    if M.restore_fishing_focus then
        M.restore_fishing_focus()
    end
    if M.restore_combat_volumes then
        M.restore_combat_volumes()
    end
    if M.restore_manual_situation_profile then
        M.restore_manual_situation_profile()
    end
    M.unmute_all_sound_files()
    M._event_cache = {}
    M.sync_registered_events()
    if M.sync_fishing_focus_events then
        M.sync_fishing_focus_events()
    end
    if M.sync_combat_volumes_events then
        M.sync_combat_volumes_events()
    end
end

--#endregion RUNTIME LIFECYCLE =================================================

--#region PLAYBACK HELPERS =====================================================

local function play_preview_soundkit(target)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then return false end

    local soundkit_id = M.resolve_soundkit_id(target and target.preview_soundkit)
    if not soundkit_id then return false end

    M.stop_preview_sound()
    local channel = target.channel or "Master"
    local will_play, sound_handle = _PlaySound(soundkit_id, channel)
    M._preview_sound_handle = sound_handle
    return will_play ~= false
end

local function play_original_file(target)
    if target and target.preview_soundkit then
        -- Prefer the SoundKit for Original previews when available; it matches
        -- Blizzard's normal playback path while the file-level mute is active.
        return play_preview_soundkit(target)
    end

    local original_file_ids = target and target.original_file_ids
    local file_count = original_file_ids and #original_file_ids or 0
    local file_id = file_count > 0 and original_file_ids[1]
    if not file_id then
        return play_preview_soundkit(target)
    end

    for _, original_file_id in ipairs(original_file_ids or {}) do
        _UnmuteSoundFile(original_file_id)
    end

    M.stop_preview_sound()
    local channel = target.channel or "Master"
    local did_play, sound_handle = _PlaySoundFile(file_id, channel)
    M._preview_sound_handle = sound_handle
    if did_play == false then return play_preview_soundkit(target) end
    return true
end

--#endregion PLAYBACK HELPERS ==================================================

--#region MUTES AND RUNTIME APPLY ==============================================

function M.unmute_all_sound_files()
    for _, target in pairs(M.SOUND_TARGETS or {}) do
        for _, file_id in ipairs(target.original_file_ids or {}) do
            _UnmuteSoundFile(file_id)
        end
    end
end

function M.apply_audio_volumes()
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.stop_runtime()
        return
    end

    M.get_db()
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
        local target_db = M.get_target_db(target_key)
        local mute = M.should_mute_original(target_db)
        for _, file_id in ipairs(target.original_file_ids or {}) do
            if mute then
                _MuteSoundFile(file_id)
            else
                _UnmuteSoundFile(file_id)
            end
        end
    end
    M.rebuild_event_cache()
    M.sync_registered_events()
end

--#endregion MUTES AND RUNTIME APPLY ===========================================

--#region PREVIEWS =============================================================

function M.play_replacement(target_key)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.stop_all_previews()
        return false
    end

    local target = M.SOUND_TARGETS and M.SOUND_TARGETS[target_key]
    if not target then return false end

    local target_db = M.get_target_db(target_key)
    if target_db.sound_off == true then
        M.stop_preview_sound()
        return false
    end

    if target_db.use_original == true then
        return play_original_file(target)
    end

    local preset = target_db.preset
    local path = M.get_replacement_path_for_preset(target, preset)
    if not path then return play_preview_soundkit(target) end

    M.stop_preview_sound()
    local channel = target.channel or "Master"
    local did_play, sound_handle = _PlaySoundFile(path, channel)
    M._preview_sound_handle = sound_handle
    if did_play == false then return play_preview_soundkit(target) end
    return true
end

function M.stop_preview_sound()
    local handle = M._preview_sound_handle
    M._preview_sound_handle = nil
    if not handle then return end
    _StopSound(handle)
end

function M.cancel_adjust_preview()
    if M._adjust_preview_timer then
        M._adjust_preview_timer:Cancel()
        M._adjust_preview_timer = nil
    end
end

function M.stop_all_previews()
    M.cancel_adjust_preview()
    M.stop_preview_sound()
    if M.stop_fishing_bobber_preview then
        M.stop_fishing_bobber_preview()
    end
end

function M.queue_adjust_preview(target_key)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.stop_all_previews()
        return
    end

    M.cancel_adjust_preview()
    M.stop_preview_sound()
    M._adjust_preview_timer = C_Timer.NewTimer(0.12, function()
        M._adjust_preview_timer = nil
        M.play_replacement(target_key)
    end)
end

--#endregion PREVIEWS ==========================================================

--#region EVENT ROUTING ========================================================

local function handle_event(_, event)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        M.stop_runtime()
        return
    end

    local slots = M._event_cache and M._event_cache[event]
    if not slots then return end
    for i = 1, #slots do
        local slot = slots[i]
        if slot.path then
            local did_play = _PlaySoundFile(slot.path, slot.channel)
            if did_play == false and slot.soundkit_id then
                _PlaySound(slot.soundkit_id, slot.channel)
            end
            return
        end
        if slot.use_soundkit and slot.soundkit_id then
            _PlaySound(slot.soundkit_id, slot.channel)
            return
        end
    end
end

function M.sync_registered_events()
    local registered = M._registered_events or {}
    M._registered_events = registered
    local desired = (M.is_runtime_enabled and not M.is_runtime_enabled()) and {} or (M._event_cache or {})

    if not M.event_frame and next(desired) == nil then
        return
    end

    if not M.event_frame then
        M.event_frame = CreateFrame("Frame")
        M.event_frame:SetScript("OnEvent", handle_event)
    end

    for event_name in pairs(registered) do
        if not desired[event_name] then
            M.event_frame:UnregisterEvent(event_name)
            registered[event_name] = nil
        end
    end

    for event_name in pairs(desired) do
        if not registered[event_name] then
            M.event_frame:RegisterEvent(event_name)
            registered[event_name] = true
        end
    end
end

--#endregion EVENT ROUTING =====================================================
