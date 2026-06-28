-- Objectives Background: background sizing, color/opacity, and tracker position controls.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults
local FORCE_EXPAND_GRACE_SECONDS = 2
local DEFAULT_BACKGROUND_COLOR = DEFAULTS.objectives.background_color
local COLOR_RANGE = { min = 0, max = 1 }
local POSITION_RANGE = { min = -500, max = 500, step = 1 }
local SNAP_GRID_SIZE = 20
local COLOR_BLOCK_PADDING_LEFT = -4
local COLOR_BLOCK_PADDING_RIGHT = -12
local COLOR_BLOCK_PADDING_TOP = -10
local COLOR_BLOCK_PADDING_BOTTOM = -8
local OBJECTIVE_BORDER_PADDING_LEFT = 0
local OBJECTIVE_BORDER_PADDING_RIGHT = -10
local OBJECTIVE_BORDER_PADDING_TOP = -8
local OBJECTIVE_BORDER_PADDING_BOTTOM = -6
local OBJECTIVE_BORDER_OFFSET_X = -12
local OBJECTIVE_BORDER_OFFSET_Y = -5
local OBJECTIVE_BORDER_STYLE = {
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local OBJECTIVE_BORDER_COLOR = { r = 1, g = 1, b = 1, a = 0.9 }

local UI_CONFIG = {
    background_group_offset_x = 20,
    background_group_offset_y = -194,
    background_group_height = 150,
    background_group_width = 673,
    background_grid_offset_x = 12,
    background_grid_offset_y = -37,
    background_grid_col_width = 130,
    background_grid_col_gap = 133,
}

local BACKGROUND_ALPHA_REGION_KEYS = {
    "TopLeftCorner",
    "TopRightCorner",
    "BottomLeftCorner",
    "BottomRightCorner",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
    "Center",
}

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local background_hooks_installed = false
local background_sync_queued = false
local background_adjustments = 0
local background_last_reason = "none"
local background_last_state = "unavailable"
local background_last_anchor = "none"
local background_last_force_expand = "none"
local background_last_blocked_anchor = "none"
local background_last_container_collapse_time = nil
local background_hooked_frame
local background_adjusting = false
local background_color_last_signature = "none"
local background_color_state = "unavailable"
local background_regions_reset = false
local background_last_applied_alpha = nil
local background_color_overlay_anchor = nil
local background_color_reset_pending = false
local background_color_auto_enabled_border = false
local objective_move_hooks_installed = false
local objective_move_original_mouse_enabled = nil
local objective_header_original_color
local objective_border_frame
local objective_position_state = "unavailable"
local objective_position_base
local objective_drag_state = setmetatable({}, { __mode = "k" })

--#endregion RUNTIME STATE =====================================================


--#region OBJECTIVE TRACKER HELPERS ============================================

local get_background_bottom_anchor
local background_points_to_header
local set_background_bottom_to_header

local function get_objective_tracker()
    local tracker = ObjectiveTrackerFrame
    if tracker and tracker.NineSlice then
        return tracker
    end
    return nil
end

local function get_frame_name(frame, fallback)
    if frame and frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then
            return name
        end
    end
    return fallback
end

local function get_bool_state(frame, method_name)
    local method = frame and frame[method_name]
    if method then
        return method(frame) == true
    end
    return nil
end

local function is_tracker_collapsed(tracker)
    if not tracker then return false end
    if tracker.IsCollapsed and tracker:IsCollapsed() then return true end
    return tracker.isCollapsed == true or tracker.collapsed == true
end

get_background_bottom_anchor = function(background)
    if not background or not background.GetNumPoints or not background.GetPoint then return nil end

    for index = 1, background:GetNumPoints() do
        local point, relative_to = background:GetPoint(index)
        if point == "BOTTOM" then
            return relative_to
        end
    end

    return nil
end

background_points_to_header = function(tracker, background)
    return get_background_bottom_anchor(background) == (tracker and tracker.Header)
end

set_background_bottom_to_header = function(tracker, background)
    background_adjusting = true
    if background.ClearPoint then
        background:ClearPoint("BOTTOM")
    end
    background:SetPoint("BOTTOM", tracker.Header, "BOTTOM", 0, -(tracker.bottomModulePadding or 10))
    background_adjusting = false
end

local function is_in_force_expand_grace()
    if not background_last_container_collapse_time then return false end
    return (GetTime() - background_last_container_collapse_time) < FORCE_EXPAND_GRACE_SECONDS
end

--#endregion OBJECTIVE TRACKER HELPERS =========================================


--#region POSITION =============================================================

local function get_objective_offset(axis)
    local db = M.get_db()
    local key = axis == "x" and "objective_tracker_offset_x" or "objective_tracker_offset_y"
    return addon.clamp_number(db and db[key], DEFAULTS.objectives[key] or 0, POSITION_RANGE)
end

local function is_objective_move_mode_enabled()
    local db = M.get_db()
    return M.is_runtime_enabled() and db and db.objective_tracker_move_mode == true
end

local function is_objective_snap_to_grid_enabled()
    local db = M.get_db()
    return M.is_runtime_enabled() and db and db.objective_tracker_snap_to_grid == true
end

local function is_background_color_default(color)
    if type(color) ~= "table" then return true end

    return (color.r or DEFAULT_BACKGROUND_COLOR.r) == DEFAULT_BACKGROUND_COLOR.r
        and (color.g or DEFAULT_BACKGROUND_COLOR.g) == DEFAULT_BACKGROUND_COLOR.g
        and (color.b or DEFAULT_BACKGROUND_COLOR.b) == DEFAULT_BACKGROUND_COLOR.b
        and (color.a or DEFAULT_BACKGROUND_COLOR.a or 1) == (DEFAULT_BACKGROUND_COLOR.a or 1)
end

local function is_objective_border_enabled()
    local db = M.get_db()
    if not M.is_runtime_enabled() or not db then return false end
    if db.objective_tracker_border ~= nil then
        return db.objective_tracker_border == true
    end

    local color = db.background_color
    return not is_background_color_default(color)
end

local function snap_objective_offset(value)
    return addon.clamp_number(math.floor(((value or 0) / SNAP_GRID_SIZE) + 0.5) * SNAP_GRID_SIZE, 0, POSITION_RANGE)
end

local function normalize_objective_offset(value)
    if is_objective_snap_to_grid_enabled() then
        return snap_objective_offset(value)
    end
    return addon.clamp_number(value, 0, POSITION_RANGE)
end

local function save_objective_offset(axis, value)
    local db = M.get_db()
    if not db then return end

    local key = axis == "x" and "objective_tracker_offset_x" or "objective_tracker_offset_y"
    db[key] = normalize_objective_offset(value)
end

local function sync_objective_position_sliders()
    local x_slider = M.controls and M.controls.objective_tracker_offset_x_slider
    if x_slider and x_slider.slider and x_slider.slider.SetValue then
        x_slider._suppress_callback = true
        x_slider.slider:SetValue(get_objective_offset("x"))
        x_slider._suppress_callback = false
    end

    local y_slider = M.controls and M.controls.objective_tracker_offset_y_slider
    if y_slider and y_slider.slider and y_slider.slider.SetValue then
        y_slider._suppress_callback = true
        y_slider.slider:SetValue(get_objective_offset("y"))
        y_slider._suppress_callback = false
    end
end

local function capture_objective_position_base(tracker)
    if objective_position_base or not tracker or not tracker.GetPoint then return end

    local point, relative_to, relative_point, offset_x, offset_y = tracker:GetPoint(1)
    local center_x, center_y
    if tracker.GetCenter then
        center_x, center_y = tracker:GetCenter()
    end
    local ui_center_x, ui_center_y = UIParent:GetCenter()
    objective_position_base = {
        point = point or "TOPRIGHT",
        relative_to = relative_to or UIParent,
        relative_point = relative_point or "TOPRIGHT",
        offset_x = offset_x or 0,
        offset_y = offset_y or 0,
        left = tracker.GetLeft and tracker:GetLeft() or nil,
        top = tracker.GetTop and tracker:GetTop() or nil,
        center_x = center_x and ui_center_x and (center_x - ui_center_x) or 0,
        center_y = center_y and ui_center_y and (center_y - ui_center_y) or 0,
    }
end

local function set_objective_center_position(tracker, offset_x, offset_y)
    local base = objective_position_base
    if not tracker or not base or not tracker.ClearAllPoints or not tracker.SetPoint then return end

    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER", base.center_x + (offset_x or 0), base.center_y + (offset_y or 0))
end

local function apply_objective_position()
    local tracker = get_objective_tracker()
    if not tracker then
        objective_position_state = "unavailable"
        return
    end

    capture_objective_position_base(tracker)
    local base = objective_position_base
    if not base then
        objective_position_state = "no_base"
        return
    end

    if tracker.ClearAllPoints and tracker.SetPoint then
        set_objective_center_position(tracker, get_objective_offset("x"), get_objective_offset("y"))
        objective_position_state = "applied"
    end
end

local function restore_objective_position()
    local tracker = get_objective_tracker()
    local base = objective_position_base
    if not tracker or not base then return end

    if tracker.ClearAllPoints and tracker.SetPoint then
        tracker:ClearAllPoints()
        tracker:SetPoint(base.point, base.relative_to, base.relative_point, base.offset_x, base.offset_y)
        objective_position_state = "restored"
    end
end

local function save_objective_position_from_tracker()
    local tracker = get_objective_tracker()
    local db = M.get_db()
    local base = objective_position_base
    if not tracker or not db or not base or not tracker.GetPoint then return end

    local left = tracker.GetLeft and tracker:GetLeft() or nil
    local top = tracker.GetTop and tracker:GetTop() or nil
    local center_x, center_y
    if tracker.GetCenter then
        center_x, center_y = tracker:GetCenter()
    end
    local ui_center_x, ui_center_y = UIParent:GetCenter()
    if center_x and center_y and ui_center_x and ui_center_y then
        save_objective_offset("x", center_x - ui_center_x - base.center_x)
        save_objective_offset("y", center_y - ui_center_y - base.center_y)
    elseif left and top and base.left and base.top then
        save_objective_offset("x", left - base.left)
        save_objective_offset("y", top - base.top)
    else
        local _, _, _, offset_x, offset_y = tracker:GetPoint(1)
        save_objective_offset("x", (offset_x or base.offset_x) - base.offset_x)
        save_objective_offset("y", (offset_y or base.offset_y) - base.offset_y)
    end
    apply_objective_position()
    sync_objective_position_sliders()
end

local function get_cursor_position()
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

local function anchor_to_objective_background(tracker, frame, left, right, top, bottom)
    if not tracker or not frame then return end

    local background = tracker.NineSlice
    local anchor = background or tracker
    left = left or 0
    right = right or 0
    top = top or 0
    bottom = bottom or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, -top)
    frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -right, bottom)
end

local function sync_objective_move_header_highlight()
    local tracker = get_objective_tracker()
    if not tracker then return end

    local text = tracker.Header and tracker.Header.Text
    if not text or not text.SetTextColor then return end

    if is_objective_move_mode_enabled() then
        if not objective_header_original_color and text.GetTextColor then
            local r, g, b, a = text:GetTextColor()
            objective_header_original_color = { r = r, g = g, b = b, a = a }
        end
        text:SetTextColor(1, 1, 1, 1)
    else
        local color = objective_header_original_color
        if color then
            text:SetTextColor(color.r or 1, color.g or 0.82, color.b or 0, color.a or 1)
        end
        objective_header_original_color = nil
    end
end

local function ensure_objective_border(tracker)
    if objective_border_frame or not tracker then return objective_border_frame end

    local border = CreateFrame("Frame", nil, tracker, "BackdropTemplate")
    border:SetFrameStrata(tracker:GetFrameStrata())
    border:SetFrameLevel((tracker:GetFrameLevel() or 1) + 10)
    border:SetBackdrop(OBJECTIVE_BORDER_STYLE)
    border:SetBackdropBorderColor(
        OBJECTIVE_BORDER_COLOR.r,
        OBJECTIVE_BORDER_COLOR.g,
        OBJECTIVE_BORDER_COLOR.b,
        OBJECTIVE_BORDER_COLOR.a
    )
    border:SetBackdropColor(0, 0, 0, 0)
    border:EnableMouse(false)
    border:Hide()

    objective_border_frame = border
    return border
end

local function sync_objective_border()
    local tracker = get_objective_tracker()
    if not tracker then return end

    local border = ensure_objective_border(tracker)
    if not border then return end
    anchor_to_objective_background(
        tracker,
        border,
        OBJECTIVE_BORDER_PADDING_LEFT,
        OBJECTIVE_BORDER_PADDING_RIGHT,
        OBJECTIVE_BORDER_PADDING_TOP,
        OBJECTIVE_BORDER_PADDING_BOTTOM
    )

    if is_objective_border_enabled() then
        border:Show()
    else
        border:Hide()
    end
end

local function set_objective_border_offsets()
    local db = M.get_db()
    if not db then return end

    db.objective_tracker_offset_x = OBJECTIVE_BORDER_OFFSET_X
    db.objective_tracker_offset_y = OBJECTIVE_BORDER_OFFSET_Y
end

local function get_objective_position_default(key)
    if is_objective_border_enabled() then
        if key == "objective_tracker_offset_x" then return OBJECTIVE_BORDER_OFFSET_X end
        if key == "objective_tracker_offset_y" then return OBJECTIVE_BORDER_OFFSET_Y end
    end
    return DEFAULTS.objectives[key]
end

local function ensure_objective_move_hooks(tracker)
    if objective_move_hooks_installed or not tracker then return end

    if tracker.IsMouseEnabled then
        objective_move_original_mouse_enabled = tracker:IsMouseEnabled()
    end
    if tracker.SetMovable then
        tracker:SetMovable(true)
    end
    if tracker.SetClampedToScreen then
        tracker:SetClampedToScreen(true)
    end
    if tracker.RegisterForDrag then
        tracker:RegisterForDrag("LeftButton")
    end

    tracker:HookScript("OnDragStart", function(self)
        if not is_objective_move_mode_enabled() or InCombatLockdown() then return end
        local state = objective_drag_state[self]
        if state and state.dragging then return end

        local cursor_x, cursor_y = get_cursor_position()
        objective_drag_state[self] = {
            dragging = true,
            start_cursor_x = cursor_x,
            start_cursor_y = cursor_y,
            start_offset_x = get_objective_offset("x"),
            start_offset_y = get_objective_offset("y"),
        }
    end)

    tracker:HookScript("OnUpdate", function(self)
        local state = objective_drag_state[self]
        if not state or not state.dragging then return end
        local current_x, current_y = get_cursor_position()
        save_objective_offset("x", state.start_offset_x + current_x - state.start_cursor_x)
        save_objective_offset("y", state.start_offset_y + current_y - state.start_cursor_y)
        apply_objective_position()
    end)

    tracker:HookScript("OnDragStop", function(self)
        local state = objective_drag_state[self]
        if not state or not state.dragging then return end
        objective_drag_state[self] = nil
        save_objective_position_from_tracker()
    end)

    objective_move_hooks_installed = true
end

local function apply_objective_move_mode()
    local tracker = get_objective_tracker()
    if not tracker then return end

    capture_objective_position_base(tracker)
    ensure_objective_move_hooks(tracker)
    if tracker.EnableMouse then
        tracker:EnableMouse(is_objective_move_mode_enabled() or objective_move_original_mouse_enabled == true)
    end
    sync_objective_move_header_highlight()
end

local function restore_objective_move_mode()
    local tracker = get_objective_tracker()
    if not tracker then return end

    objective_drag_state[tracker] = nil
    if tracker.EnableMouse and objective_move_original_mouse_enabled ~= nil then
        tracker:EnableMouse(objective_move_original_mouse_enabled == true)
    end
    sync_objective_move_header_highlight()
end

--#endregion POSITION ==========================================================


--#region COLOR AND OPACITY ====================================================

local function get_background_color_alpha()
    local db = M.get_db()
    local color = db and db.background_color
    return addon.clamp_number(type(color) == "table" and color.a, DEFAULT_BACKGROUND_COLOR.a or 0.5, COLOR_RANGE)
end

local function get_background_color()
    local db = M.get_db()
    local color = db and db.background_color or DEFAULT_BACKGROUND_COLOR
    if type(color) ~= "table" then
        color = DEFAULT_BACKGROUND_COLOR
    end

    return {
        r = addon.clamp_number(color.r, DEFAULT_BACKGROUND_COLOR.r, COLOR_RANGE),
        g = addon.clamp_number(color.g, DEFAULT_BACKGROUND_COLOR.g, COLOR_RANGE),
        b = addon.clamp_number(color.b, DEFAULT_BACKGROUND_COLOR.b, COLOR_RANGE),
        a = get_background_color_alpha(),
    }
end

local function get_background_opacity()
    local db = M.get_db()
    return addon.clamp_number(db and db.background_alpha, DEFAULTS.objectives.background_alpha or 0.5, COLOR_RANGE)
end

local function ensure_background_color()
    local db = M.get_db()
    if not db then return end
    if type(db.background_color) ~= "table" then
        db.background_color = {
            r = DEFAULT_BACKGROUND_COLOR.r,
            g = DEFAULT_BACKGROUND_COLOR.g,
            b = DEFAULT_BACKGROUND_COLOR.b,
            a = DEFAULT_BACKGROUND_COLOR.a or 0.5,
        }
    elseif db.background_color.a == nil then
        db.background_color.a = DEFAULT_BACKGROUND_COLOR.a or 0.5
    end
end

local function should_customize_background()
    local db = M.get_db()
    return M.is_runtime_enabled() and db and db.customize_background == true
end

local function get_color_signature(color)
    return table.concat({
        tostring(color.r),
        tostring(color.g),
        tostring(color.b),
        tostring(color.a),
    }, ":")
end

local function get_background_signature(color, opacity)
    return get_color_signature(color) .. ":bg_alpha=" .. tostring(opacity) .. ":color_alpha=" .. tostring(get_background_color_alpha())
end

local function hide_background_color_frame(background)
    local overlay = background and background._lstweeks_color_overlay
    if overlay then
        overlay:Hide()
        overlay:ClearAllPoints()
        background._lstweeks_color_overlay = nil
    end

    local overlays = background and background._lstweeks_color_overlays
    if overlays then
        for _, entry in ipairs(overlays) do
            if entry.overlay then
                entry.overlay:Hide()
                entry.overlay:ClearAllPoints()
            end
            if entry.mask then
                entry.mask:Hide()
                entry.mask:ClearAllPoints()
            end
        end
    end

    local corner_overlays = background and background._lstweeks_corner_color_overlays
    if corner_overlays then
        for _, entry in ipairs(corner_overlays) do
            if entry.overlay then
                entry.overlay:Hide()
                entry.overlay:ClearAllPoints()
            end
        end
    end

    local color_frame = background and background._lstweeks_color_frame
    if color_frame then
        color_frame:Hide()
        color_frame:ClearAllPoints()
    end
end

local function apply_color_to_region(region)
    if region and region.SetVertexColor then
        if region.SetDesaturated then
            region:SetDesaturated(false)
        end
        if region.SetBlendMode then
            region:SetBlendMode("BLEND")
        end
        region:SetVertexColor(1, 1, 1, 1)
        return true
    end
    return false
end

local function apply_center_color_overlay(background, color, enabled)
    local overlay = background and background._lstweeks_center_color_overlay
    if not enabled then
        if overlay then
            overlay:Hide()
        end
        background_color_overlay_anchor = nil
        return false
    end

    if not overlay then
        local owner = background.GetParent and background:GetParent() or background
        overlay = owner:CreateTexture(nil, "BORDER")
        overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
        overlay:SetVertexColor(1, 1, 1, 1)
        background._lstweeks_center_color_overlay = overlay
        background_color_overlay_anchor = nil
    end

    local anchor = background.Center or background
    if background_color_overlay_anchor ~= anchor then
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", COLOR_BLOCK_PADDING_LEFT, -COLOR_BLOCK_PADDING_TOP)
        overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -COLOR_BLOCK_PADDING_RIGHT, COLOR_BLOCK_PADDING_BOTTOM)
        background_color_overlay_anchor = anchor
    end

    overlay:SetVertexColor(color.r, color.g, color.b, get_background_color_alpha())
    overlay:Show()
    return true
end

local function apply_background_color(color, force, opacity_override, show_color_overlay)
    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not background then
        background_color_state = "unavailable"
        return
    end

    local opacity = opacity_override
    if opacity == nil then
        opacity = get_background_opacity()
    end
    local signature = get_background_signature(color, opacity) .. ":overlay=" .. tostring(show_color_overlay == true)
    if not force and background_color_last_signature == signature then
        return
    end

    if background.SetAlpha and (force or background_last_applied_alpha ~= opacity) then
        background:SetAlpha(opacity)
        background_last_applied_alpha = opacity
    end

    local applied = 0
    if force or not background_regions_reset then
        hide_background_color_frame(background)
        for _, key in ipairs(BACKGROUND_ALPHA_REGION_KEYS) do
            if apply_color_to_region(background[key]) then
                applied = applied + 1
            end
        end
        background_regions_reset = true
    end
    local overlay_applied = apply_center_color_overlay(background, color, show_color_overlay == true)

    background_color_last_signature = signature
    background_color_state = overlay_applied
        and ("center_overlay:bg_alpha=" .. tostring(opacity) .. ":color_alpha=" .. tostring(get_background_color_alpha()) .. ":reset_regions=" .. tostring(applied))
        or "no_regions"
end

local function apply_configured_background_color(force)
    if not M.is_runtime_enabled() then return end
    if should_customize_background() then
        apply_background_color(get_background_color(), force, nil, true)
    else
        apply_background_color(DEFAULT_BACKGROUND_COLOR, force, 0, false)
    end
end

local function restore_background_color()
    background_regions_reset = false
    apply_background_color(DEFAULT_BACKGROUND_COLOR, true, 1, false)
end

--#endregion COLOR AND OPACITY =================================================


--#region BACKGROUND SIZING ====================================================

local function show_background_to_header(tracker, background, state)
    local header = tracker and tracker.Header
    if header and header.IsShown and header:IsShown() then
        local changed = not background_points_to_header(tracker, background)
            or not (background.IsShown and background:IsShown())
        if not background_points_to_header(tracker, background) then
            set_background_bottom_to_header(tracker, background)
        end
        if background.Show and not (background.IsShown and background:IsShown()) then
            background:Show()
        end
        background_last_state = state or "shown_header_only"
        background_last_anchor = header.GetName and header:GetName() or "tracker_header"
        if changed then
            background_adjustments = background_adjustments + 1
        end
    else
        local changed = background.IsShown and background:IsShown()
        if background.Hide then
            background:Hide()
        end
        background_last_state = "hidden_no_visible_header"
        background_last_anchor = "none"
        if changed then
            background_adjustments = background_adjustments + 1
        end
    end
end

local function get_priority_module_for_anchor(tracker, anchor)
    if not tracker or not anchor then return nil end

    local priority_modules = {}
    for _, module in ipairs(tracker.modules or {}) do
        if module.hasDisplayPriority == true then
            priority_modules[module] = true
        end
    end

    local frame = anchor
    while frame do
        if priority_modules[frame] then
            return frame
        end
        if not frame.GetParent then
            return nil
        end
        frame = frame:GetParent()
    end

    return nil
end

local function force_expand_for_background_anchor(tracker, anchor)
    local priority_module = get_priority_module_for_anchor(tracker, anchor)
    if not priority_module then
        background_last_blocked_anchor = get_frame_name(anchor, "unknown")
        return false
    end

    background_last_force_expand = "background:" .. get_frame_name(priority_module, "priority_module")
    background_last_blocked_anchor = "none"
    background_last_state = "force_expand_background_anchor"
    background_last_anchor = "blizzard"

    if tracker.ForceExpand then
        tracker:ForceExpand()
    elseif tracker.SetCollapsed then
        tracker:SetCollapsed(false)
    end

    return true
end

local function check_collapsed_background_anchor(reason)
    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not tracker or not background or not M.is_runtime_enabled() then return end
    if not is_tracker_collapsed(tracker) then return end

    local anchor = get_background_bottom_anchor(background)
    if anchor and anchor ~= tracker.Header then
        background_last_reason = reason or "background anchor changed"
        if not is_in_force_expand_grace() then
            if force_expand_for_background_anchor(tracker, anchor) then
                return
            end
        end
        show_background_to_header(tracker, background, "shown_container_collapsed_blocked_anchor")
        sync_objective_border()
    end
end

local function sync_objective_background(reason)
    background_sync_queued = false
    background_last_reason = reason or "unknown"

    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not tracker or not background then
        background_last_state = "unavailable"
        return
    end

    if not M.is_runtime_enabled() then
        background_last_state = "module_disabled"
        return
    end

    apply_configured_background_color()

    if is_tracker_collapsed(tracker) then
        if not background_points_to_header(tracker, background) and not is_in_force_expand_grace() then
            if force_expand_for_background_anchor(tracker, get_background_bottom_anchor(background)) then
                return
            end
            show_background_to_header(tracker, background, "shown_container_collapsed_blocked_anchor")
            sync_objective_border()
            return
        end

        show_background_to_header(tracker, background, "shown_container_collapsed")
        sync_objective_border()
        return
    end

    background_last_state = "blizzard_owned_expanded"
    background_last_anchor = "blizzard"
    background_last_force_expand = "none"
    background_last_blocked_anchor = "none"
    sync_objective_border()
end

local function queue_background_sync(reason)
    if background_sync_queued then return end
    background_sync_queued = true
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.next_frame or 0
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function queue_background_followup(reason)
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.fifth_sec or 0.2
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function ensure_background_hooks()
    if background_hooks_installed then return end
    if not M.is_runtime_enabled() then return end

    local tracker = get_objective_tracker()
    if not tracker then return end
    local background = tracker.NineSlice

    hooksecurefunc(tracker, "Update", function()
        if not M.is_runtime_enabled() then return end
        queue_background_sync("tracker update")
    end)
    hooksecurefunc(tracker, "SetCollapsed", function(_, collapsed)
        if not M.is_runtime_enabled() then return end
        if collapsed then
            background_last_container_collapse_time = GetTime()
        end
        queue_background_sync("tracker collapsed")
        queue_background_followup("tracker collapsed followup")
    end)
    if tracker.SetBackgroundAlpha then
        hooksecurefunc(tracker, "SetBackgroundAlpha", function()
            if not M.is_runtime_enabled() then return end
            apply_configured_background_color(true)
        end)
    end
    if background and background.SetPoint then
        background_hooked_frame = background
        hooksecurefunc(background, "SetPoint", function()
            if not M.is_runtime_enabled() then return end
            if background_adjusting then return end
            check_collapsed_background_anchor("background SetPoint")
        end)
    end

    background_hooks_installed = true
    queue_background_sync("hooks installed")
end

--#endregion BACKGROUND SIZING =================================================


--#region STATUS ===============================================================

local function append_background_module_status(fields)
    local tracker = get_objective_tracker()
    if not tracker then
        fields[#fields + 1] = "bg_modules=unavailable"
        return
    end

    fields[#fields + 1] = "bg_modules=" .. tostring(#(tracker.modules or {}))
    for index, module in ipairs(tracker.modules or {}) do
        local prefix = "bg_module_" .. tostring(index) .. "_"
        local last_block = module.GetLastBlock and module:GetLastBlock() or nil
        local contents_height = module.GetContentsHeight and module:GetContentsHeight() or nil
        local module_height = module.GetHeight and module:GetHeight() or nil
        local last_block_height = last_block and last_block.GetHeight and last_block:GetHeight() or nil

        fields[#fields + 1] = prefix .. "name=" .. get_frame_name(module, "unnamed")
        fields[#fields + 1] = prefix .. "priority=" .. tostring(module.hasDisplayPriority == true)
        fields[#fields + 1] = prefix .. "shown=" .. tostring(get_bool_state(module, "IsShown"))
        fields[#fields + 1] = prefix .. "collapsed=" .. tostring(get_bool_state(module, "IsCollapsed"))
        fields[#fields + 1] = prefix .. "displayable=" .. tostring(get_bool_state(module, "IsDisplayable"))
        fields[#fields + 1] = prefix .. "height=" .. tostring(module_height)
        fields[#fields + 1] = prefix .. "contents_height=" .. tostring(contents_height)
        fields[#fields + 1] = prefix .. "raw_contents_height=" .. tostring(module.contentsHeight)
        fields[#fields + 1] = prefix .. "has_contents=" .. tostring(module.hasContents == true)
        fields[#fields + 1] = prefix .. "has_tried_blocks=" .. tostring(module.hasTriedBlocks == true)
        fields[#fields + 1] = prefix .. "has_skipped_blocks=" .. tostring(module.hasSkippedBlocks == true)
        fields[#fields + 1] = prefix .. "state=" .. tostring(module.state)
        fields[#fields + 1] = prefix .. "last_block=" .. get_frame_name(last_block, "none")
        fields[#fields + 1] = prefix .. "last_block_shown=" .. tostring(get_bool_state(last_block, "IsShown"))
        fields[#fields + 1] = prefix .. "last_block_height=" .. tostring(last_block_height)
    end
end

local function append_background_region_status(fields)
    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not background or not background.GetRegions then
        fields[#fields + 1] = "bg_regions=unavailable"
        return
    end

    local regions = { background:GetRegions() }
    fields[#fields + 1] = "bg_regions=" .. tostring(#regions)
    for index, region in ipairs(regions) do
        local prefix = "bg_region_" .. tostring(index) .. "_"
        local object_type = region.GetObjectType and region:GetObjectType() or "unknown"
        local draw_layer, sub_level
        if region.GetDrawLayer then
            draw_layer, sub_level = region:GetDrawLayer()
        end
        local width = region.GetWidth and region:GetWidth() or nil
        local height = region.GetHeight and region:GetHeight() or nil
        local alpha = region.GetAlpha and region:GetAlpha() or nil
        local vertex_r, vertex_g, vertex_b, vertex_a
        if region.GetVertexColor then
            vertex_r, vertex_g, vertex_b, vertex_a = region:GetVertexColor()
        end
        local get_blend_mode = region["GetBlendMode"]
        local is_desaturated = region["IsDesaturated"]
        local get_texture = region["GetTexture"]
        local get_atlas = region["GetAtlas"]
        local blend_mode = get_blend_mode and get_blend_mode(region) or nil
        local desaturated = is_desaturated and is_desaturated(region) or nil
        local texture = get_texture and get_texture(region) or nil
        local atlas = get_atlas and get_atlas(region) or nil

        fields[#fields + 1] = prefix .. "name=" .. get_frame_name(region, "unnamed")
        fields[#fields + 1] = prefix .. "type=" .. tostring(object_type)
        fields[#fields + 1] = prefix .. "shown=" .. tostring(get_bool_state(region, "IsShown"))
        fields[#fields + 1] = prefix .. "layer=" .. tostring(draw_layer) .. ":" .. tostring(sub_level)
        fields[#fields + 1] = prefix .. "size=" .. tostring(width) .. "x" .. tostring(height)
        fields[#fields + 1] = prefix .. "alpha=" .. tostring(alpha)
        fields[#fields + 1] = prefix .. "vertex=" .. tostring(vertex_r) .. ":" .. tostring(vertex_g) .. ":" .. tostring(vertex_b) .. ":" .. tostring(vertex_a)
        fields[#fields + 1] = prefix .. "blend=" .. tostring(blend_mode)
        fields[#fields + 1] = prefix .. "desaturated=" .. tostring(desaturated)
        fields[#fields + 1] = prefix .. "texture=" .. tostring(texture)
        fields[#fields + 1] = prefix .. "atlas=" .. tostring(atlas)
    end
end

function M.get_background_status()
    local fields = {}
    fields[#fields + 1] = "bg_hooks=" .. tostring(background_hooks_installed)
    fields[#fields + 1] = "bg_point_hook=" .. tostring(background_hooked_frame ~= nil)
    fields[#fields + 1] = "bg_state=" .. tostring(background_last_state)
    fields[#fields + 1] = "bg_anchor=" .. tostring(background_last_anchor)
    fields[#fields + 1] = "bg_force_expand=" .. tostring(background_last_force_expand)
    fields[#fields + 1] = "bg_blocked_anchor=" .. tostring(background_last_blocked_anchor)
    fields[#fields + 1] = "bg_force_expand_grace=" .. tostring(is_in_force_expand_grace())
    fields[#fields + 1] = "bg_enabled=" .. tostring(should_customize_background() == true)
    fields[#fields + 1] = "bg_color_state=" .. tostring(background_color_state)
    fields[#fields + 1] = "bg_color_signature=" .. tostring(background_color_last_signature)
    fields[#fields + 1] = "bg_alpha=" .. tostring(get_background_opacity())
    fields[#fields + 1] = "bg_color_alpha=" .. tostring(get_background_color_alpha())
    fields[#fields + 1] = "bg_nineslice_alpha=" .. tostring(get_objective_tracker() and get_objective_tracker().NineSlice and get_objective_tracker().NineSlice:GetAlpha() or nil)
    fields[#fields + 1] = "objective_move_mode=" .. tostring(is_objective_move_mode_enabled() == true)
    fields[#fields + 1] = "objective_move_header_highlight=" .. tostring(objective_header_original_color ~= nil)
    fields[#fields + 1] = "objective_border=" .. tostring(is_objective_border_enabled() == true)
    fields[#fields + 1] = "objective_border_shown=" .. tostring(objective_border_frame and objective_border_frame.IsShown and objective_border_frame:IsShown() or false)
    fields[#fields + 1] = "objective_snap_to_grid=" .. tostring(is_objective_snap_to_grid_enabled() == true)
    fields[#fields + 1] = "objective_position_state=" .. tostring(objective_position_state)
    fields[#fields + 1] = "objective_offset_x=" .. tostring(get_objective_offset("x"))
    fields[#fields + 1] = "objective_offset_y=" .. tostring(get_objective_offset("y"))
    fields[#fields + 1] = "bg_adjustments=" .. tostring(background_adjustments)
    fields[#fields + 1] = "bg_last_reason=" .. tostring(background_last_reason)
    append_background_module_status(fields)
    append_background_region_status(fields)
    return fields
end

--#endregion STATUS ============================================================


--#region PUBLIC API ===========================================================

function M.apply_background()
    ensure_background_hooks()
    apply_objective_position()
    apply_objective_move_mode()
    sync_objective_border()
    apply_configured_background_color()
end

function M.restore_background()
    restore_objective_move_mode()
    restore_objective_position()
    if objective_border_frame then
        objective_border_frame:Hide()
    end
    restore_background_color()
    local tracker = get_objective_tracker()
    if tracker and tracker.Update then
        tracker:Update()
    end
end

--#endregion PUBLIC API ========================================================


--#region GUI ==================================================================

local function set_background_color(reason)
    local db = M.get_db()
    local border_was_enabled = is_objective_border_enabled()
    local border_auto_enabled = false
    if reason == "reset" and db then
        db.objective_tracker_border = nil
        background_color_reset_pending = true
        background_color_auto_enabled_border = false
    elseif reason ~= "cancel" and db and background_color_reset_pending and not is_background_color_default(db.background_color) then
        db.objective_tracker_border = true
        background_color_reset_pending = false
        background_color_auto_enabled_border = true
        border_auto_enabled = true
    elseif reason == "cancel" then
        if db and background_color_auto_enabled_border and is_background_color_default(db.background_color) then
            db.objective_tracker_border = nil
        end
        background_color_reset_pending = false
        background_color_auto_enabled_border = false
    end

    apply_configured_background_color(false)

    local border_is_enabled = is_objective_border_enabled()
    if border_was_enabled ~= border_is_enabled or border_auto_enabled or reason == "reset" then
        if border_auto_enabled then
            set_objective_border_offsets()
            apply_objective_position()
            sync_objective_position_sliders()
        end
        sync_objective_border()
        if M.controls.objective_tracker_border_checkbox and M.controls.objective_tracker_border_checkbox.SetChecked then
            M.controls.objective_tracker_border_checkbox:SetChecked(border_is_enabled)
        end
    end
end

local function set_background_alpha()
    apply_configured_background_color(false)
end

local function sync_background_controls()
    local enabled = should_customize_background()
    if M.controls.background_color_picker and M.controls.background_color_picker.SetEnabled then
        M.controls.background_color_picker:SetEnabled(enabled)
    end
    if M.controls.background_alpha_slider and M.controls.background_alpha_slider.SetEnabled then
        M.controls.background_alpha_slider:SetEnabled(enabled)
    end
end

local function set_customize_background(enabled)
    local db = M.get_db()
    if not db then return end
    db.customize_background = enabled == true
    sync_background_controls()
    apply_configured_background_color(true)
end

local function set_objective_position()
    save_objective_offset("x", get_objective_offset("x"))
    save_objective_offset("y", get_objective_offset("y"))
    apply_objective_position()
    sync_objective_position_sliders()
end

local function reset_objective_position()
    local db = M.get_db()
    if not db then return end

    if is_objective_border_enabled() then
        set_objective_border_offsets()
    else
        db.objective_tracker_offset_x = DEFAULTS.objectives.objective_tracker_offset_x or 0
        db.objective_tracker_offset_y = DEFAULTS.objectives.objective_tracker_offset_y or 0
    end
    apply_objective_position()
    sync_objective_position_sliders()
end

local function set_objective_move_mode(enabled)
    local db = M.get_db()
    if not db then return end
    db.objective_tracker_move_mode = enabled == true
    apply_objective_move_mode()
end

local function set_objective_snap_to_grid(enabled)
    local db = M.get_db()
    if not db then return end
    db.objective_tracker_snap_to_grid = enabled == true
    set_objective_position()
end

local function set_objective_border(enabled)
    local db = M.get_db()
    if not db then return end
    db.objective_tracker_border = enabled == true
    if enabled == true then
        set_objective_border_offsets()
        apply_objective_position()
        sync_objective_position_sliders()
    end
    sync_objective_border()
end

function M.BuildBackgroundSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db()
    if not db then return end
    ensure_background_color()

    local group = addon.CreateSettingsGroup(
        parent,
        "Background",
        cfg.background_group_width,
        cfg.background_group_height,
        cfg.background_group_offset_x,
        cfg.background_group_offset_y
    )

    local grid = addon.CreateSettingsGrid(group, {
        column_count = 5,
        col_offset = cfg.background_grid_offset_x,
        row_start = cfg.background_grid_offset_y,
        col_width = cfg.background_grid_col_width,
        col_gap = cfg.background_grid_col_gap,
        row_heights = { 100 },
        col_align = { "left", "left", "left", "center", "left" },
        offsets = { default = 0 },
    })

    local customize_container, customize_cb, customize_label = addon.CreateCheckbox(
        group,
        "Enable",
        db.customize_background == true,
        set_customize_background
    )
    M.controls.customize_background_checkbox = customize_cb
    grid:place_at(customize_container, 1, 1)
    addon.AttachTooltip(customize_label, nil, "Shows the Objective Tracker background and enables color and opacity controls.")

    local move_mode_container, move_mode_cb, move_mode_label = addon.CreateCheckbox(
        group,
        "Move Mode",
        db.objective_tracker_move_mode == true,
        set_objective_move_mode
    )
    M.controls.objective_tracker_move_mode_checkbox = move_mode_cb
    grid:stack_below(move_mode_container, customize_container, { y = -2 })
    addon.AttachTooltip(move_mode_label, nil, "Allows dragging the All Objectives tracker and saves the result to the X/Y offset sliders.")

    local snap_container, snap_cb, snap_label = addon.CreateCheckbox(
        group,
        "Snap to Grid",
        db.objective_tracker_snap_to_grid == true,
        set_objective_snap_to_grid
    )
    M.controls.objective_tracker_snap_to_grid_checkbox = snap_cb
    grid:stack_below(snap_container, move_mode_container, { y = -2 })
    addon.AttachTooltip(snap_label, nil, "Rounds Objective Tracker offsets to a 20 pixel grid when moving or adjusting position.")

    local reset_move_button = addon.CreateMoveResetButton(group, snap_container, {
        on_click = reset_objective_position,
    })
    M.controls.objective_tracker_reset_move_button = reset_move_button
    addon.AttachTooltip(reset_move_button, nil, "Restores the All Objectives tracker X/Y offsets to their defaults.")

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesPositionX",
        group,
        "X Offset",
        POSITION_RANGE.min,
        POSITION_RANGE.max,
        POSITION_RANGE.step,
        db,
        "objective_tracker_offset_x",
        DEFAULTS.objectives,
        set_objective_position,
        {
            get_default_value = get_objective_position_default,
            tooltip = "Moves the All Objectives tracker horizontally from its original anchor.",
        }
    )
    M.controls.objective_tracker_offset_x_slider = x_slider
    grid:place_at(x_slider, 1, 2)

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesPositionY",
        group,
        "Y Offset",
        POSITION_RANGE.min,
        POSITION_RANGE.max,
        POSITION_RANGE.step,
        db,
        "objective_tracker_offset_y",
        DEFAULTS.objectives,
        set_objective_position,
        {
            get_default_value = get_objective_position_default,
            tooltip = "Moves the All Objectives tracker vertically from its original anchor.",
        }
    )
    M.controls.objective_tracker_offset_y_slider = y_slider
    grid:place_at(y_slider, 1, 3)

    local background_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesBackgroundAlpha",
        group,
        "Alpha",
        0,
        1,
        0.05,
        db,
        "background_alpha",
        DEFAULTS.objectives,
        set_background_alpha,
        {
            display_decimals = 2,
            tooltip = "Controls the actual Blizzard Objective Tracker background alpha.",
        }
    )
    M.controls.background_alpha_slider = background_alpha_slider
    grid:place_at(background_alpha_slider, 1, 4)

    local picker = addon.CreateColorPicker(
        group,
        db,
        "background_color",
        true,
        "Color",
        DEFAULTS.objectives,
        set_background_color
    )
    M.controls.background_color_picker = picker
    grid:place_at(picker, 1, 5, nil, { width = picker:GetWidth(), align = "center" })
    addon.AttachTooltip(picker, nil, "Tints the center color block. The picker alpha controls only that color block.")

    local border_container, border_cb, border_label = addon.CreateCheckbox(
        group,
        "Border",
        is_objective_border_enabled(),
        set_objective_border
    )
    M.controls.objective_tracker_border_checkbox = border_cb
    grid:stack_below(border_container, picker, { y = -2, align = "center", column_width = cfg.background_grid_col_width })
    addon.AttachTooltip(border_label, nil, "Shows the LsTweeks dialog border around the All Objectives tracker.")

    sync_background_controls()
end

--#endregion GUI ===============================================================
