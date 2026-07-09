-- Objectives Position: All Objectives tracker offsets, move mode, snap-to-grid, and Position settings.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults
local POSITION_RANGE = { min = -500, max = 500, step = 1 }
local SNAP_GRID_SIZE = 20
local SLIDER_WITH_BOX_SIZE = addon.SLIDER_WITH_BOX_SIZE

local UI_CONFIG = {
    group_offset_x = 20,
    group_padding_x = 12,
    position_group_offset_y = -20,
    position_group_width = 1,
    position_group_height = 150,
    grid_offset_x = 12,
    grid_offset_y = -37,
    grid_col_width = SLIDER_WITH_BOX_SIZE.width,
    grid_column_gap_x = 18,
    slider_row_height = SLIDER_WITH_BOX_SIZE.height + 5,
}

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local objective_move_hooks_installed = false
local objective_move_original_mouse_enabled = nil
local objective_header_original_color
local objective_position_state = "unavailable"
local objective_position_base
local objective_drag_state = setmetatable({}, { __mode = "k" })

--#endregion RUNTIME STATE =====================================================


--#region OBJECTIVE TRACKER HELPERS ============================================

local get_objective_tracker = M.get_objective_tracker

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
    if x_slider and x_slider.SetValueSilently then
        x_slider:SetValueSilently(get_objective_offset("x"))
    end

    local y_slider = M.controls and M.controls.objective_tracker_offset_y_slider
    if y_slider and y_slider.SetValueSilently then
        y_slider:SetValueSilently(get_objective_offset("y"))
    end
end
M.sync_objective_position_sliders = sync_objective_position_sliders

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
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        objective_position_state = "combat_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

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
M.apply_objective_position = apply_objective_position

local function restore_objective_position()
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        objective_position_state = "combat_restore_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    local tracker = get_objective_tracker()
    local base = objective_position_base
    if not tracker or not base then return end

    if tracker.ClearAllPoints and tracker.SetPoint then
        tracker:ClearAllPoints()
        tracker:SetPoint(base.point, base.relative_to, base.relative_point, base.offset_x, base.offset_y)
        objective_position_state = "restored"
    end
end
M.restore_objective_position = restore_objective_position

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
        if InCombatLockdown() then
            objective_drag_state[self] = nil
            return
        end

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
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    local tracker = get_objective_tracker()
    if not tracker then return end

    capture_objective_position_base(tracker)
    ensure_objective_move_hooks(tracker)
    if tracker.EnableMouse then
        tracker:EnableMouse(is_objective_move_mode_enabled() or objective_move_original_mouse_enabled == true)
    end
    sync_objective_move_header_highlight()
end
M.apply_objective_move_mode = apply_objective_move_mode

local function restore_objective_move_mode()
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    local tracker = get_objective_tracker()
    if not tracker then return end

    objective_drag_state[tracker] = nil
    if tracker.EnableMouse and objective_move_original_mouse_enabled ~= nil then
        tracker:EnableMouse(objective_move_original_mouse_enabled == true)
    end
    sync_objective_move_header_highlight()
end
M.restore_objective_move_mode = restore_objective_move_mode

function M.append_objective_position_status(fields)
    fields[#fields + 1] = "objective_move_mode=" .. tostring(is_objective_move_mode_enabled() == true)
    fields[#fields + 1] = "objective_move_header_highlight=" .. tostring(objective_header_original_color ~= nil)
    fields[#fields + 1] = "objective_snap_to_grid=" .. tostring(is_objective_snap_to_grid_enabled() == true)
    fields[#fields + 1] = "objective_position_state=" .. tostring(objective_position_state)
    fields[#fields + 1] = "objective_offset_x=" .. tostring(get_objective_offset("x"))
    fields[#fields + 1] = "objective_offset_y=" .. tostring(get_objective_offset("y"))
end

--#endregion POSITION ==========================================================


--#region GUI ==================================================================

local function set_objective_position()
    save_objective_offset("x", get_objective_offset("x"))
    save_objective_offset("y", get_objective_offset("y"))
    apply_objective_position()
    sync_objective_position_sliders()
end

local function reset_objective_position()
    local db = M.get_db()
    if not db then return end

    if M.is_background_border_enabled and M.is_background_border_enabled() then
        if M.set_background_border_position_offsets then
            M.set_background_border_position_offsets()
        end
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

local function get_objective_position_default(key)
    if M.get_background_aware_position_default then
        return M.get_background_aware_position_default(key)
    end
    return DEFAULTS.objectives[key]
end

function M.BuildPositionSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db()
    if not db then return end

    local position_group = addon.CreateSettingsGroup(
        parent,
        "Position",
        cfg.position_group_width,
        cfg.position_group_height,
        cfg.group_offset_x,
        cfg.position_group_offset_y
    )

    local position_grid = addon.CreateSettingsGrid(position_group, {
        column_count = 3,
        col_offset = cfg.grid_offset_x,
        row_start = cfg.grid_offset_y,
        col_width = cfg.grid_col_width,
        column_gap_x = cfg.grid_column_gap_x,
        row_heights = { cfg.slider_row_height },
        col_align = { "left", "left", "left" },
        offsets = { default = 0 },
    })

    local move_mode_container, move_mode_cb, move_mode_label = addon.CreateCheckbox(
        position_group,
        "Move Mode",
        db.objective_tracker_move_mode == true,
        set_objective_move_mode
    )
    M.controls.objective_tracker_move_mode_checkbox = move_mode_container
    position_grid:place_at(move_mode_container, 1, 1)
    addon.AttachTooltip(move_mode_label, nil, "Allows dragging the All Objectives tracker and saves the result to the X/Y offset sliders.")

    local snap_container, snap_cb, snap_label = addon.CreateCheckbox(
        position_group,
        "Snap to Grid",
        db.objective_tracker_snap_to_grid == true,
        set_objective_snap_to_grid
    )
    M.controls.objective_tracker_snap_to_grid_checkbox = snap_container
    position_grid:stack_below(snap_container, move_mode_container, { y = -2 })
    addon.AttachTooltip(snap_label, nil, "Rounds Objective Tracker offsets to a 20 pixel grid when moving or adjusting position.")

    local reset_move_button = addon.CreateMoveResetButton(position_group, snap_container, {
        on_click = reset_objective_position,
    })
    M.controls.objective_tracker_reset_move_button = reset_move_button
    addon.AttachTooltip(reset_move_button, nil, "Restores the All Objectives tracker X/Y offsets to their defaults.")

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesPositionX",
        position_group,
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
    position_grid:place_at(x_slider, 1, 2)

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesPositionY",
        position_group,
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
    position_grid:place_at(y_slider, 1, 3)

    local position_width = position_grid[3] - cfg.grid_offset_x + (y_slider:GetWidth() or cfg.grid_col_width)
    position_group:SetWidth(math.ceil(position_width + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================
