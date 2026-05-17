-- Runtime behavior for Sound Levels: applies file mutes, plays previews and
-- replacements, and wires WoW events to selected replacement sounds.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local function mute_file(file_id)
    if C_Sound and C_Sound.MuteSoundFile then
        C_Sound.MuteSoundFile(file_id)
    elseif MuteSoundFile then
        MuteSoundFile(file_id)
    end
end

local function unmute_file(file_id)
    if C_Sound and C_Sound.UnmuteSoundFile then
        C_Sound.UnmuteSoundFile(file_id)
    elseif UnmuteSoundFile then
        UnmuteSoundFile(file_id)
    end
end

local function play_preview_soundkit(target)
    local soundkit_key = target and target.preview_soundkit
    local soundkit_id = nil
    if type(soundkit_key) == "number" then
        soundkit_id = soundkit_key
    elseif type(soundkit_key) == "string" and SOUNDKIT then
        soundkit_id = SOUNDKIT[soundkit_key]
    end
    if not soundkit_id then return false end

    M.stop_preview_sound()
    local will_play, sound_handle
    if C_Sound and C_Sound.PlaySound then
        will_play, sound_handle = C_Sound.PlaySound(soundkit_id)
    elseif PlaySound then
        will_play, sound_handle = PlaySound(soundkit_id)
    end
    M._preview_sound_handle = sound_handle
    return will_play ~= false
end

local function play_original_file(target)
    local file_id = target and target.original_file_ids and target.original_file_ids[1]
    if not file_id then
        return play_preview_soundkit(target)
    end

    for _, original_file_id in ipairs(target.original_file_ids or {}) do
        unmute_file(original_file_id)
    end

    M.stop_preview_sound()
    local did_play, sound_handle
    if C_Sound and C_Sound.PlaySoundFile then
        did_play, sound_handle = C_Sound.PlaySoundFile(file_id, "Master")
    elseif PlaySoundFile then
        did_play, sound_handle = PlaySoundFile(file_id, "Master")
    end
    M._preview_sound_handle = sound_handle
    if did_play == false then return play_preview_soundkit(target) end
    return true
end

function M.unmute_all_sound_files()
    for _, target in pairs(M.SOUND_TARGETS or {}) do
        for _, file_id in ipairs(target.original_file_ids or {}) do
            unmute_file(file_id)
        end
    end
end

function M.apply_sound_levels()
    M.get_db()
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
        local target_db = M.get_target_db(target_key)
        local mute = M.should_mute_original(target_db)
        for _, file_id in ipairs(target.original_file_ids or {}) do
            if mute then
                mute_file(file_id)
            else
                unmute_file(file_id)
            end
        end
    end
end

function M.play_replacement(target_key)
    M.get_db()

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

    if not M.should_play_replacement(target_db) then return false end

    local preset = target_db.preset
    local path = target.replacement_paths and target.replacement_paths[preset]
    if not path then return play_preview_soundkit(target) end

    M.stop_preview_sound()
    local did_play, sound_handle
    if C_Sound and C_Sound.PlaySoundFile then
        did_play, sound_handle = C_Sound.PlaySoundFile(path, "Master")
    elseif PlaySoundFile then
        did_play, sound_handle = PlaySoundFile(path, "Master")
    end
    M._preview_sound_handle = sound_handle
    if did_play == false then return play_preview_soundkit(target) end
    return true
end

function M.play_event_replacement(target_key)
    local target_db = M.get_target_db(target_key)
    if not M.should_mute_original(target_db) then
        return false
    end
    return M.play_replacement(target_key)
end

function M.stop_preview_sound()
    local handle = M._preview_sound_handle
    M._preview_sound_handle = nil
    if not handle then return end
    if C_Sound and C_Sound.StopSound then
        C_Sound.StopSound(handle)
    elseif StopSound then
        StopSound(handle)
    end
end

function M.queue_adjust_preview(target_key)
    if M._adjust_preview_timer then
        M._adjust_preview_timer:Cancel()
        M._adjust_preview_timer = nil
    end
    M.stop_preview_sound()
    M._adjust_preview_timer = C_Timer.NewTimer(0.12, function()
        M._adjust_preview_timer = nil
        M.play_replacement(target_key)
    end)
end

local function handle_event(_, event)
    local event_targets = M.SOUND_EVENT_TARGETS and M.SOUND_EVENT_TARGETS[event]
    if not event_targets then return end
    for _, target_key in ipairs(event_targets) do
        if M.play_event_replacement(target_key) then
            return
        end
    end
end

function M.sync_registered_events()
    if not M.event_frame then
        M.event_frame = CreateFrame("Frame")
        M.event_frame:SetScript("OnEvent", handle_event)
    end

    M.event_frame:UnregisterAllEvents()
    M.get_db()

    for event_name in pairs(M.SOUND_EVENT_TARGETS or {}) do
        M.event_frame:RegisterEvent(event_name)
    end
end
