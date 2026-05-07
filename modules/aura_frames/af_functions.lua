-- Shared helper functions for the aura frames module.
-- Defines small cross-file utilities for CDM viewer lookup, frame positioning,
-- custom frame setup, and frame/category setting fallback resolution.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

function M.get_cdm_viewer_frame(category)
    local frame_name = M.CDM_VIEWER_FRAMES and M.CDM_VIEWER_FRAMES[category]
    return frame_name and _G[frame_name] or nil
end

function M.apply_frame_position(frame, pos, scale)
    if not (frame and pos) then return end
    scale = scale or (frame.GetScale and frame:GetScale()) or 1
    if scale == 0 then scale = 1 end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "CENTER", (pos.x or 0) / scale, (pos.y or 0) / scale)
end

function M.read_frame_position(frame)
    if not frame then return nil, nil end
    local left = frame:GetLeft()
    local top  = frame:GetTop()
    if not (left and top) then return nil, nil end

    local parent_scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frame_scale  = frame.GetEffectiveScale and frame:GetEffectiveScale() or frame:GetScale() or 1
    if parent_scale == 0 then parent_scale = 1 end
    local scale = frame_scale / parent_scale
    local ucx, ucy = UIParent:GetCenter()
    local x = (left * scale) - ucx
    local y = (top  * scale) - ucy
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

function M.sync_frame_position_to_db(frame, pos_table)
    if not (frame and pos_table and M.read_frame_position) then return nil, nil end
    local x, y = M.read_frame_position(frame)
    if not (x and y) then return nil, nil end
    pos_table.point = "TOPLEFT"
    pos_table.x = x
    pos_table.y = y
    return x, y
end

function M.get_setting(cfg_db, category, key, fallback)
    if cfg_db and cfg_db ~= M.db and cfg_db[key] ~= nil then return cfg_db[key] end
    if category and M.db and M.db[key .. "_" .. category] ~= nil then
        return M.db[key .. "_" .. category]
    end
    if cfg_db and cfg_db[key] ~= nil then return cfg_db[key] end
    if M.db and M.db[key] ~= nil then return M.db[key] end
    return fallback
end

-- Frame-specific value -> category-specific value -> global value -> default global value.
function M.get_timer_number_font_size(category, cfg_db)
    local db = cfg_db or M.db or {}
    local defaults = M.defaults or {}

    if cfg_db then
        local custom_size = tonumber(db.timer_number_font_size)
        if custom_size then return custom_size end
    end

    if category then
        local category_size = tonumber(db["timer_number_font_size_"..category])
        if category_size then return category_size end
    end

    local global_size = tonumber(db.timer_number_font_size)
    if global_size then return global_size end

    return tonumber(defaults.timer_number_font_size) or 10
end

-- Returns the next available auto-name ("Custom 1" .. "Custom N").
local function next_custom_name()
    local used = {}
    if M.db and M.db.custom_frames then
        for _, entry in ipairs(M.db.custom_frames) do
            used[entry.name] = true
        end
    end
    for n = 1, M.MAX_CUSTOM_FRAMES do
        local candidate = "Custom " .. n
        if not used[candidate] then return candidate end
    end
    return "Custom"
end

-- Returns the next available stable id ("custom_1" .. "custom_N").
local function next_custom_id()
    local used = {}
    if M.db and M.db.custom_frames then
        for _, entry in ipairs(M.db.custom_frames) do
            used[entry.id] = true
        end
    end
    for n = 1, M.MAX_CUSTOM_FRAMES do
        local candidate = "custom_" .. n
        if not used[candidate] then return candidate end
    end
    return "custom_x"
end

-- Creates a new custom frame entry table from the template.
function M.new_custom_entry(id, name)
    local entry = {}
    for k, v in pairs(M.CUSTOM_FRAME_TEMPLATE) do
        if type(v) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            entry[k] = t
        else
            entry[k] = v
        end
    end
    entry.id   = id   or next_custom_id()
    entry.name = name or next_custom_name()
    return entry
end

function M.get_custom_aura_filter(entry)
    if not entry then return "HELPFUL" end
    local base = entry.aura_base_filter
    if base ~= "HARMFUL" then base = "HELPFUL" end
    local modifier = entry.aura_modifier
    if not modifier or modifier == "" or modifier == "NONE" then
        return base
    end
    local def = M.get_custom_modifier_def and M.get_custom_modifier_def(modifier)
    if def and def.force_base then
        base = def.force_base
        entry.aura_base_filter = base
    end
    return base .. "|" .. modifier
end

function M.get_custom_modifier_def(value)
    value = value or "NONE"
    for _, def in ipairs(M.CUSTOM_AURA_MODIFIERS or {}) do
        if def.value == value then return def end
    end
    return (M.CUSTOM_AURA_MODIFIERS and M.CUSTOM_AURA_MODIFIERS[1]) or { value = "NONE", text = "NONE" }
end
