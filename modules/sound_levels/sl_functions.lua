-- Shared helpers for the Sound Levels module: DB access, preset lookup,
-- target ordering, and target activity predicates.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.controls = M.controls or {}

function M.get_db()
    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    if not M._defaults_applied then
        local defaults = addon.module_defaults and addon.module_defaults.sound_levels
        if defaults then
            addon.apply_defaults(defaults, Ls_Tweeks_DB)
        end
        M._defaults_applied = true
    end
    Ls_Tweeks_DB.sound_levels = Ls_Tweeks_DB.sound_levels or {}
    Ls_Tweeks_DB.sound_levels.targets = Ls_Tweeks_DB.sound_levels.targets or {}
    return Ls_Tweeks_DB.sound_levels
end

function M.get_target_db(target_key)
    local db = M.get_db()
    db.targets[target_key] = db.targets[target_key] or {}
    local target = M.SOUND_TARGETS and M.SOUND_TARGETS[target_key]
    local defaults = M.defaults
        and M.defaults.sound_levels
        and M.defaults.sound_levels.targets
        and M.defaults.sound_levels.targets[target_key]
    if defaults then
        addon.apply_defaults(defaults, db.targets[target_key])
    end
    if not M.is_valid_preset_value(db.targets[target_key].preset) then
        db.targets[target_key].preset = target and target.default_preset or "0"
    end
    if target and not target.preview_soundkit and #(target.original_file_ids or {}) == 0 then
        db.targets[target_key].use_original = false
    end
    return db.targets[target_key]
end

function M.get_preset_by_value(value)
    local option = M.PRESET_OPTIONS_BY_VALUE and M.PRESET_OPTIONS_BY_VALUE[value]
    if option then return option end
    return M.PRESET_OPTIONS_BY_VALUE and M.PRESET_OPTIONS_BY_VALUE["0"]
end

function M.is_valid_preset_value(value)
    return M.PRESET_OPTIONS_BY_VALUE and M.PRESET_OPTIONS_BY_VALUE[value] ~= nil
end

function M.get_preset_by_slider_value(value)
    local rounded = math.floor((tonumber(value) or 0) + 0.5)
    local option = M.PRESET_OPTIONS_BY_SLIDER_VALUE and M.PRESET_OPTIONS_BY_SLIDER_VALUE[rounded]
    if option then return option end
    return M.PRESET_OPTIONS_BY_SLIDER_VALUE and M.PRESET_OPTIONS_BY_SLIDER_VALUE[0]
end

function M.should_mute_original(target_db)
    if target_db and target_db.sound_off == true then
        return true
    end
    return not (target_db and target_db.use_original == true)
end

function M.get_replacement_paths_for_preset(target, preset)
    if not target then return nil end
    local path = target.replacement_paths and target.replacement_paths[preset]
    if path then
        return { path }
    end
    return nil
end

function M.get_next_replacement_path(target, preset)
    local paths = M.get_replacement_paths_for_preset(target, preset)
    if not paths then return nil end
    return paths[1]
end

function M.get_ordered_sound_targets()
    local targets = {}
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
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

-- Builds a flat, pre-resolved cache of event → slot list used by handle_event.
-- Called once after apply_sound_levels(); each slot contains only what the hot
-- path needs, including one or more resolved paths, so the event handler
-- touches no DB or defaults machinery at all.
function M.rebuild_event_cache()
    local cache = {}
    for event_name, target_keys in pairs(M.SOUND_EVENT_TARGETS or {}) do
        local slots = {}
        for _, target_key in ipairs(target_keys) do
            local target = M.SOUND_TARGETS and M.SOUND_TARGETS[target_key]
            if target then
                local target_db = M.get_target_db(target_key)
                local muted = M.should_mute_original(target_db)
                local paths = nil
                local use_soundkit = false
                local soundkit_id = nil

                if muted and target_db.sound_off ~= true then
                    local preset = target_db.preset
                    paths = M.get_replacement_paths_for_preset(target, preset)
                    if not paths then
                        -- fall back to soundkit preview
                        local sk = target.preview_soundkit
                        if type(sk) == "number" then
                            soundkit_id = sk
                            use_soundkit = true
                        elseif type(sk) == "string" and SOUNDKIT then
                            soundkit_id = SOUNDKIT[sk]
                            use_soundkit = soundkit_id ~= nil
                        end
                    end
                end

                if paths or (use_soundkit and soundkit_id) then
                    slots[#slots + 1] = {
                        paths        = paths,
                        use_soundkit = use_soundkit,
                        soundkit_id  = soundkit_id,
                        channel      = target.channel or "Master",
                        next_index   = 1,
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
