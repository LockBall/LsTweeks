-- Shared helpers for the Audio Volumes module: DB access, preset lookup,
-- target ordering, and target activity predicates.
local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

--#region MODULE STATE =========================================================

M.MODULE_KEY = "audio_volumes"
M.controls = M.controls or {}

function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

--#endregion MODULE STATE ======================================================

--#region DATABASE =============================================================

function M.get_db()
    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    if not M._defaults_applied then
        local defaults = addon.module_defaults.audio_volumes
        if defaults then
            addon.apply_defaults(defaults, Ls_Tweeks_DB)
        end
        M._defaults_applied = true
    end
    Ls_Tweeks_DB.audio_volumes = Ls_Tweeks_DB.audio_volumes or {}
    Ls_Tweeks_DB.audio_volumes.targets = Ls_Tweeks_DB.audio_volumes.targets or {}
    return Ls_Tweeks_DB.audio_volumes
end

function M.get_target_db(target_key)
    local db = M.get_db()
    db.targets[target_key] = db.targets[target_key] or {}
    local target = M.SOUND_TARGETS[target_key]
    local defaults = M.defaults
        and M.defaults.audio_volumes
        and M.defaults.audio_volumes.targets
        and M.defaults.audio_volumes.targets[target_key]
    M._target_defaults_applied = M._target_defaults_applied or {}
    if defaults and not M._target_defaults_applied[target_key] then
        addon.apply_defaults(defaults, db.targets[target_key])
        M._target_defaults_applied[target_key] = true
    end
    if not M.is_valid_preset_value(db.targets[target_key].preset) then
        db.targets[target_key].preset = target and target.default_preset or "0"
    end
    if target and not target.preview_soundkit and #(target.original_file_ids or {}) == 0 then
        db.targets[target_key].use_original = false
    end
    return db.targets[target_key]
end

--#endregion DATABASE ==========================================================

--#region PRESET AND TARGET HELPERS ============================================

function M.get_preset_by_value(value)
    local option = M.PRESET_OPTIONS_BY_VALUE[value]
    if option then return option end
    return M.PRESET_OPTIONS_BY_VALUE["0"]
end

function M.is_valid_preset_value(value)
    return M.PRESET_OPTIONS_BY_VALUE[value] ~= nil
end

function M.get_preset_by_slider_value(value)
    local rounded = math.floor((tonumber(value) or 0) + 0.5)
    local option = M.PRESET_OPTIONS_BY_SLIDER_VALUE[rounded]
    if option then return option end
    return M.PRESET_OPTIONS_BY_SLIDER_VALUE[0]
end

function M.should_mute_original(target_db)
    if target_db and target_db.sound_off == true then
        return true
    end
    return not (target_db and target_db.use_original == true)
end

function M.resolve_soundkit_id(soundkit_key)
    if type(soundkit_key) == "number" then
        return soundkit_key
    end
    if type(soundkit_key) == "string" and SOUNDKIT then
        return SOUNDKIT[soundkit_key]
    end
    return nil
end

function M.get_replacement_path_for_preset(target, preset)
    if not target then return nil end
    return target.replacement_paths and target.replacement_paths[preset]
end

function M.get_ordered_sound_targets()
    local targets = {}
    for target_key, target in pairs(M.SOUND_TARGETS) do
        targets[#targets + 1] = {
            key = target_key,
            target = target,
            order = target.order or 100,
            label = target.label or target_key,
        }
    end
    table.sort(targets, function(a, b)
        if a.order == b.order then
            return a.label < b.label
        end
        return a.order < b.order
    end)
    return targets
end

--#endregion PRESET AND TARGET HELPERS =========================================

--#region EVENT CACHE ==========================================================

-- Builds a flat, pre-resolved cache of event -> slot list used by handle_event.
-- Called once after apply_audio_volumes(); each slot contains only what the hot
-- path needs, so the event handler touches no DB or defaults machinery at all.
function M.rebuild_event_cache()
    local cache = {}
    for event_name, target_keys in pairs(M.SOUND_EVENT_TARGETS) do
        local slots = {}
        for _, target_key in ipairs(target_keys) do
            local target = M.SOUND_TARGETS[target_key]
            if target then
                local target_db = M.get_target_db(target_key)
                local muted = M.should_mute_original(target_db)
                local path = nil
                local use_soundkit = false
                local soundkit_id = M.resolve_soundkit_id(target.preview_soundkit)

                if muted and target_db.sound_off ~= true then
                    local preset = target_db.preset
                    path = M.get_replacement_path_for_preset(target, preset)
                    if not path then
                        -- fall back to soundkit preview
                        use_soundkit = soundkit_id ~= nil
                    end
                end

                if path or (use_soundkit and soundkit_id) then
                    slots[#slots + 1] = {
                        path         = path,
                        use_soundkit = use_soundkit,
                        soundkit_id  = soundkit_id,
                        channel      = target.channel or "Master",
                    }
                end
            end
        end
        if #slots > 0 then
            cache[event_name] = slots
        end
    end
    M._event_cache = cache
end

--#endregion EVENT CACHE =======================================================
