-- Shared helpers for the Sound Levels module: DB access, preset lookup,
-- target ordering, and target activity predicates.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

M.controls = M.controls or {}
M.frames = M.frames or {}

function M.get_db()
    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    local defaults = addon.module_defaults and addon.module_defaults.sound_levels
    if defaults then
        addon.apply_defaults(defaults, Ls_Tweeks_DB)
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
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.value == value then
            return option
        end
    end
    return M.PRESET_OPTIONS and M.PRESET_OPTIONS[1]
end

function M.is_valid_preset_value(value)
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.value == value then
            return true
        end
    end
    return false
end

function M.get_preset_by_slider_value(value)
    local rounded = math.floor((tonumber(value) or 1) + 0.5)
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.slider_value == rounded then
            return option
        end
    end
    return M.PRESET_OPTIONS and M.PRESET_OPTIONS[1]
end

function M.should_mute_original(target_db)
    if target_db and target_db.sound_off == true then
        return true
    end
    return not (target_db and target_db.use_original == true)
end

function M.should_play_replacement(target_db)
    if target_db and target_db.sound_off == true then
        return false
    end
    return not (target_db and target_db.use_original == true)
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
