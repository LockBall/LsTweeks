-- Shared helper functions for the aura frames module.
-- Defines small cross-file utilities for CDM viewer lookup, frame positioning,
-- custom frame setup, and frame/category setting fallback resolution.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local MAIN_FRAME_FALLBACK_HALF_WIDTH = 475
local DEFAULT_POSITION_GAP = 32
local CUSTOM_DEFAULT_POSITION_START_Y = 50
local CUSTOM_DEFAULT_POSITION_STEP_Y = -50
local CDM_DEFAULT_POSITION_Y_OFFSETS = {
    essential = 25,
    utility = -25,
    tracked_buffs = -75,
    tracked_bars = -125,
}
local TIMER_BEHAVIOR = {
    static = { enabled = false, format = "none" },
    short  = { enabled = true,  format = "decimal" },
}

local DEFAULT_TIMER_BEHAVIOR = {
    enabled = true,
    format = "time",
}

local CANCELABLE_AURA_FILTER = "HELPFUL|CANCELABLE"

function M.set_shown_if_changed(frame, shown)
    if not frame then return end
    if shown then
        if not frame:IsShown() then frame:Show() end
    elseif frame:IsShown() then
        frame:Hide()
    end
end

function M.clear_timer_text(font_string)
    if not font_string then return end
    if font_string._last_text ~= "" then
        font_string:SetText("")
        font_string._last_text = ""
    end
end

local function normalize_cancel_modifier(modifier)
    if modifier == "OFF" or modifier == "CTRL" or modifier == "ALT" or modifier == "SHIFT" then
        return modifier
    end
    return "CTRL"
end

local function is_cancel_modifier_down(modifier)
    if modifier == "CTRL" then return IsControlKeyDown and IsControlKeyDown() end
    if modifier == "ALT" then return IsAltKeyDown and IsAltKeyDown() end
    if modifier == "SHIFT" then return IsShiftKeyDown and IsShiftKeyDown() end
    return false
end

local function is_frame_category_cancelable(frame)
    if not frame then return false end
    if frame.is_custom then return true end
    return frame.category == "static" or frame.category == "long"
end

local function refresh_aura_frames_after_cancel()
    if M.mark_aura_scan_dirty then
        M.mark_aura_scan_dirty()
    end

    local function refresh()
        if not M.update_auras then return end
        local frames_list = M.frames_list
        if not frames_list then return end
        for i = 1, #frames_list do
            local frame = frames_list[i]
            local params = frame.update_params
            if params then
                M.update_auras(frame, params.show_key, params.move_key, params.timer_key,
                    params.bg_key, params.scale_key, params.spacing_key, params.aura_filter)
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(M.UPDATE_INTERVALS and M.UPDATE_INTERVALS.next_frame or 0, refresh)
    else
        refresh()
    end
end

local function find_cancelable_buff_index(aura_instance_id)
    if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex and aura_instance_id) then return nil end

    local index = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", index, CANCELABLE_AURA_FILTER)
        if not aura then return nil end
        if aura.auraInstanceID == aura_instance_id then
            return index
        end
        index = index + 1
    end
end

function M.try_cancel_aura_icon(obj, button)
    if button ~= "RightButton" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if not (M.db and obj) then return false end

    local modifier = normalize_cancel_modifier(M.db.cancel_modifier)
    if modifier == "OFF" then return false end
    if not is_cancel_modifier_down(modifier) then return false end

    if obj.is_test_preview or obj.is_spell_cooldown then return false end
    if type(obj.aura_index) ~= "number" then return false end
    if not is_frame_category_cancelable(obj:GetParent()) then return false end
    if type(CancelUnitBuff) ~= "function" then return false end

    local buff_index = find_cancelable_buff_index(obj.aura_index)
    if not buff_index then return false end

    local ok = pcall(CancelUnitBuff, "player", buff_index, CANCELABLE_AURA_FILTER)
    if ok then
        refresh_aura_frames_after_cancel()
    end
    return ok
end

function M.get_cdm_viewer_frame(category)
    local frame_name = M.CDM_VIEWER_FRAMES[category]
    return frame_name and _G[frame_name] or nil
end

local function read_main_frame_reference()
    local main_frame = addon.main_frame
    local ui_center_x, ui_center_y = UIParent:GetCenter()
    if main_frame and ui_center_x and ui_center_y then
        local right = main_frame.GetRight and main_frame:GetRight()
        local center_y
        if main_frame.GetCenter then
            local center_x
            center_x, center_y = main_frame:GetCenter()
        end
        if right and center_y then
            return right - ui_center_x, center_y - ui_center_y
        end
    end
    return MAIN_FRAME_FALLBACK_HALF_WIDTH, 0
end

function M.get_default_cdm_frame_position(category)
    local y_offset = CDM_DEFAULT_POSITION_Y_OFFSETS[category]
    if not y_offset then return nil end
    local main_right_x, main_center_y = read_main_frame_reference()
    return {
        point = "TOPLEFT",
        x = main_right_x + DEFAULT_POSITION_GAP,
        y = main_center_y + y_offset,
    }
end

local function get_custom_position_index(id)
    if type(id) == "string" then
        local n = tonumber(id:match("^custom_(%d+)$"))
        if n then return n end
    end
    return 1
end

function M.get_default_custom_frame_position(id)
    local main_right_x, main_center_y = read_main_frame_reference()
    local index = get_custom_position_index(id)
    return {
        point = "TOPLEFT",
        x = main_right_x + DEFAULT_POSITION_GAP,
        y = main_center_y + CUSTOM_DEFAULT_POSITION_START_Y + ((index - 1) * CUSTOM_DEFAULT_POSITION_STEP_Y),
    }
end

function M.refresh_cdm_default_positions()
    if not (M.defaults and M.defaults.positions) then return end
    for category in pairs(CDM_DEFAULT_POSITION_Y_OFFSETS) do
        local pos = M.get_default_cdm_frame_position(category)
        if pos then
            M.defaults.positions[category] = M.defaults.positions[category] or {}
            M.defaults.positions[category].point = pos.point
            M.defaults.positions[category].x = pos.x
            M.defaults.positions[category].y = pos.y
        end
    end
end

function M.apply_cdm_default_positions_to_db()
    if not (M.db and M.db.positions) then return end
    M.refresh_cdm_default_positions()
    for category in pairs(CDM_DEFAULT_POSITION_Y_OFFSETS) do
        local default_pos = M.defaults and M.defaults.positions and M.defaults.positions[category]
        if default_pos and not M.db.positions[category] then
            M.db.positions[category] = M.db.positions[category] or {}
            M.db.positions[category].point = default_pos.point
            M.db.positions[category].x = default_pos.x
            M.db.positions[category].y = default_pos.y
        end
    end
end

function M.apply_frame_position(frame, pos, scale)
    if not (frame and pos) then return end
    scale = scale or (frame.GetScale and frame:GetScale()) or 1
    if scale == 0 then scale = 1 end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "CENTER", (pos.x or 0) / scale, (pos.y or 0) / scale)
end

function M.get_frame_config_db(frame)
    if frame and frame.is_custom and frame.custom_entry then
        return frame.custom_entry
    end
    return M.db
end

function M.get_frame_position_table(frame)
    if not frame then return nil end
    if frame.is_custom and frame.custom_entry then
        frame.custom_entry.position = frame.custom_entry.position or {}
        return frame.custom_entry.position
    end
    local category = frame.category
    return M.db and M.db.positions and category and M.db.positions[category] or nil
end

function M.get_frame_position_scale(frame, scale_key)
    local cfg_db = M.get_frame_config_db(frame) or M.db
    local category = frame and frame.category
    local scale = 1
    if cfg_db then
        if scale_key and cfg_db[scale_key] ~= nil then
            scale = cfg_db[scale_key]
        elseif category and cfg_db["scale_" .. category] ~= nil then
            scale = cfg_db["scale_" .. category]
        elseif cfg_db.scale ~= nil then
            scale = cfg_db.scale
        end
    end
    if not scale or scale == 0 then scale = 1 end
    return scale
end

function M.apply_saved_frame_position(frame, scale_key, fallback_y, scale)
    if not frame then return end
    local pos = M.get_frame_position_table(frame)
    if pos then
        M.apply_frame_position(frame, pos, scale or M.get_frame_position_scale(frame, scale_key))
    else
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "CENTER", -100, fallback_y or 75)
    end
end

function M.set_saved_frame_position_axis(frame, axis, value, scale_key)
    if not (frame and axis and value ~= nil) then return end
    local pos = M.get_frame_position_table(frame)
    if not pos then return end
    if axis ~= "x" and axis ~= "y" then return end
    pos.point = "TOPLEFT"
    pos[axis] = value
    M.apply_saved_frame_position(frame, scale_key)
end

function M.reset_frame_move_placement(frame, opts)
    if not frame then return end
    opts = opts or {}

    local default_pos = opts.default_position
    local pos = M.get_frame_position_table(frame)
    if pos and default_pos then
        pos.point = default_pos.point or "TOPLEFT"
        pos.x = default_pos.x or 0
        pos.y = default_pos.y or 0
    end

    local default_width = opts.default_width
    if default_width then
        if opts.width_table and opts.width_key then
            opts.width_table[opts.width_key] = default_width
        end
        if frame.SetWidth then
            frame:SetWidth(default_width)
        end
    end

    M.apply_saved_frame_position(frame, opts.scale_key)

    local x_slider = opts.x_slider
    local y_slider = opts.y_slider
    local width_slider = opts.width_slider
    if x_slider and x_slider.slider and pos and pos.x ~= nil then
        x_slider.slider:SetValue(pos.x)
    end
    if y_slider and y_slider.slider and pos and pos.y ~= nil then
        y_slider.slider:SetValue(pos.y)
    end
    if width_slider and width_slider.slider and default_width then
        width_slider.slider:SetValue(default_width)
    end

    if opts.update then
        opts.update()
    end
end

function M.create_move_reset_button(parent, anchor_to, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(opts.width or 110, 22)
    button:SetPoint("TOPLEFT", anchor_to, "BOTTOMLEFT", 0, -6)
    button:SetText("Move Reset")
    button:SetScript("OnClick", function()
        if opts.on_click then
            opts.on_click()
        end
    end)
    return button
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

function M.sync_frame_position_from_drag(frame, scale_key)
    if not frame then return nil, nil end
    local pos = M.get_frame_position_table(frame)
    if not pos then return nil, nil end
    local x, y = M.sync_frame_position_to_db(frame, pos)
    if not (x and y) then return nil, nil end
    if M.db and M.db.snap_to_grid then
        pos.x, pos.y = M.snap_frame_position(pos, frame)
        M.apply_saved_frame_position(frame, scale_key)
    end
    return pos.x, pos.y
end

function M.start_frame_drag(frame)
    if not frame then return end
    frame._is_user_positioning = true
    frame:StartMoving()
end

function M.stop_frame_drag(frame, scale_key)
    if not frame then return nil, nil end
    frame:StopMovingOrSizing()
    local x, y = M.sync_frame_position_from_drag(frame, scale_key)
    frame._is_user_positioning = nil
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

function M.migrate_legacy_cdm_fade_settings(dest, source)
    dest = dest or M.db
    source = source or dest
    if not (dest and source and M.CDM_CATEGORIES) then return end

    local legacy_fade = source.fade_wow_cooldown_ooc
    local legacy_alpha = source.wow_cooldown_ooc_alpha
    if legacy_fade == nil and legacy_alpha == nil then return end

    for _, category in ipairs(M.CDM_CATEGORIES) do
        local fade_key = "fade_ooc_" .. category
        local alpha_key = "ooc_alpha_" .. category
        if source[fade_key] == nil and legacy_fade ~= nil then
            dest[fade_key] = legacy_fade == true
        end
        if source[alpha_key] == nil and legacy_alpha ~= nil then
            dest[alpha_key] = legacy_alpha
        end
    end
end

function M.get_bar_bg_color(cfg_db, category, color)
    color = color or M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    return M.get_setting(cfg_db, category, "bar_bg_color", {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = M.BAR_BG_ALPHA_DEFAULT,
    })
end

function M.normalize_timer_category(category)
    if type(category) == "string" and category:sub(1, 5) == "show_" then
        return category:sub(6)
    end
    return category
end

function M.get_timer_behavior(category)
    category = M.normalize_timer_category(category)
    return TIMER_BEHAVIOR[category] or DEFAULT_TIMER_BEHAVIOR
end

function M.is_timer_text_enabled(db, category, timer_key)
    category = M.normalize_timer_category(category)
    local behavior = M.get_timer_behavior(category)
    if behavior.enabled == false then
        return false
    end

    local value
    if timer_key then
        value = db and db[timer_key]
    elseif category then
        value = db and db["timer_" .. category]
    end

    if value == nil then
        return true
    end
    return value and true or false
end

local function read_frame_bool(cfg_db, key)
    if not (cfg_db and key) then return false end
    return cfg_db[key] == true
end

function M.get_frame_activity_state(frame, show_key, move_key)
    local category = frame and frame.category
    local cfg_db = M.get_frame_config_db(frame)
    local is_custom = frame and frame.is_custom == true
    local is_cdm = category and M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[category] == true
    local enabled_key = is_custom and "show" or show_key
    local moving_key = is_custom and "move" or move_key
    local test_key = is_custom and "test_aura" or (category and ("test_aura_" .. category))
    local enabled = read_frame_bool(cfg_db, enabled_key)

    return {
        enabled = enabled,
        moving = enabled and read_frame_bool(cfg_db, moving_key),
        test_aura = enabled and read_frame_bool(cfg_db, test_key),
        is_custom = is_custom,
        is_cdm = is_cdm,
        needs_shared_scan = enabled and not is_custom,
        needs_custom_scan = enabled and is_custom,
        needs_cdm_viewer = enabled and is_cdm,
        needs_cdm_scan = enabled and is_cdm,
    }
end

function M.cdm_category_needs_viewer(category)
    if not (category and M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[category]) then
        return false
    end
    local keys = M.get_preset_keys(category)
    local frame = M.frames and M.frames[keys.show_key]
    if not frame then
        return M.db and M.db[keys.show_key] == true
    end
    return M.get_frame_activity_state(frame, keys.show_key, keys.move_key).needs_cdm_viewer == true
end

function M.mark_aura_scan_dirty()
    M._aura_scan_dirty = true
    M.clear_custom_aura_scan_cache()
    if M.clear_sorted_aura_ids_cache then
        M.clear_sorted_aura_ids_cache()
    end
end

-- Frame-specific value -> category-specific value -> global value -> default global value.
function M.get_timer_number_font_size(category, cfg_db)
    local defaults = M.defaults or {}
    local value = M.get_setting(cfg_db, category, "timer_number_font_size", defaults.timer_number_font_size or 10)
    return tonumber(value) or 10
end

local function next_custom_slot(field, prefix, fallback)
    local used = {}
    if M.db and M.db.custom_frames then
        for _, entry in ipairs(M.db.custom_frames) do
            local value = entry[field]
            if value ~= nil then
                used[value] = true
            end
        end
    end
    for n = 1, M.MAX_CUSTOM_FRAMES do
        local candidate = prefix .. n
        if not used[candidate] then return candidate end
    end
    return fallback
end

-- Returns the next available auto-name ("Custom 1" .. "Custom N").
local function next_custom_name()
    return next_custom_slot("name", "Custom ", "Custom")
end

-- Returns the next available stable id ("custom_1" .. "custom_N").
local function next_custom_id()
    return next_custom_slot("id", "custom_", "custom_x")
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
    entry.position = M.get_default_custom_frame_position(entry.id) or entry.position
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
    local def = M.get_custom_modifier_def(modifier)
    if def and def.force_base then
        base = def.force_base
        entry.aura_base_filter = base
    end
    return base .. "|" .. modifier
end

function M.get_custom_modifier_def(value)
    value = value or "NONE"
    return M.CUSTOM_AURA_MODIFIERS_BY_VALUE[value] or M.CUSTOM_AURA_MODIFIERS[1]
end

function M.apply_tooltip_panel_backdrop(frame, r, g, b, a, br, bg, bb, ba)
    if not frame then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    if r then frame:SetBackdropColor(r, g, b, a or 1) end
    if br then frame:SetBackdropBorderColor(br, bg, bb, ba or 1) end
end

function M.apply_title_bar_backdrop(frame)
    if not frame then return end
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.2, 0.2, 0.2, 1)
end

function M.apply_thin_border_backdrop(frame, bg_color, border_color)
    if not frame then return end
    frame:SetBackdrop({
        bgFile   = bg_color and "Interface\\Buttons\\WHITE8x8" or nil,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if bg_color then
        frame:SetBackdropColor(bg_color.r or 0, bg_color.g or 0, bg_color.b or 0, bg_color.a or 1)
    end
    if border_color then
        frame:SetBackdropBorderColor(border_color.r or 1, border_color.g or 1, border_color.b or 1, border_color.a or 1)
    end
end
