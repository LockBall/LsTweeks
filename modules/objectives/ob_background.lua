-- Objectives Background: background sizing, color/opacity, owned border, and Background settings.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults
local FORCE_EXPAND_GRACE_SECONDS = 2
local DEFAULT_BACKGROUND_COLOR = {
    r = DEFAULTS.objectives.background_color.r,
    g = DEFAULTS.objectives.background_color.g,
    b = DEFAULTS.objectives.background_color.b,
    a = DEFAULTS.objectives.background_color.a,
}
local COLOR_RANGE = { min = 0, max = 1 }
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
local SLIDER_WITH_BOX_SIZE = addon.SLIDER_WITH_BOX_SIZE

local UI_CONFIG = {
    group_width = 673,
    group_offset_x = 20,
    group_padding_x = 12,
    background_group_offset_y = -180,
    background_group_height = 150,
    grid_offset_x = 12,
    grid_offset_y = -37,
    grid_col_width = SLIDER_WITH_BOX_SIZE.width,
    grid_column_gap_x = 18,
    slider_row_height = SLIDER_WITH_BOX_SIZE.height + 5,
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
local background_last_color_r = nil
local background_last_color_g = nil
local background_last_color_b = nil
local background_last_color_a = nil
local background_last_overlay_enabled = nil
local background_alpha_applying = false
local background_edit_mode_state = "unavailable"
local background_color_overlay_anchor = nil
local background_color_auto_enabled_border = false
local objective_border_frame
local objective_border_anchor_signature = nil
local objective_border_shown = nil

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

local function get_method_value(frame, method_name)
    local method = frame and frame[method_name]
    if method then
        return method(frame)
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


--#region BACKGROUND STATE HELPERS =============================================

local function is_background_color_default(color)
    if type(color) ~= "table" then return true end

    return (color.r or DEFAULT_BACKGROUND_COLOR.r) == DEFAULT_BACKGROUND_COLOR.r
        and (color.g or DEFAULT_BACKGROUND_COLOR.g) == DEFAULT_BACKGROUND_COLOR.g
        and (color.b or DEFAULT_BACKGROUND_COLOR.b) == DEFAULT_BACKGROUND_COLOR.b
        and (color.a or DEFAULT_BACKGROUND_COLOR.a or 1) == (DEFAULT_BACKGROUND_COLOR.a or 1)
end

local function is_background_color_enabled(db)
    if not db then return false end
    if db.background_color_enabled ~= nil then
        return db.background_color_enabled == true
    end

    return db.customize_background == true and not is_background_color_default(db.background_color)
end

local function is_background_border_enabled()
    local db = M.get_db()
    if not M.is_runtime_enabled() or not db then return false end
    if db.objective_tracker_border ~= nil then
        return db.objective_tracker_border == true
    end

    local color = db.background_color
    return not is_background_color_default(color)
end
M.is_background_border_enabled = is_background_border_enabled

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
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    local tracker = get_objective_tracker()
    if not tracker then return end

    local border = ensure_objective_border(tracker)
    if not border then return end
    local anchor = tracker.NineSlice or tracker
    local anchor_signature = table.concat({
        tostring(anchor),
        tostring(OBJECTIVE_BORDER_PADDING_LEFT),
        tostring(OBJECTIVE_BORDER_PADDING_RIGHT),
        tostring(OBJECTIVE_BORDER_PADDING_TOP),
        tostring(OBJECTIVE_BORDER_PADDING_BOTTOM),
    }, ":")
    if objective_border_anchor_signature ~= anchor_signature then
        anchor_to_objective_background(
            tracker,
            border,
            OBJECTIVE_BORDER_PADDING_LEFT,
            OBJECTIVE_BORDER_PADDING_RIGHT,
            OBJECTIVE_BORDER_PADDING_TOP,
            OBJECTIVE_BORDER_PADDING_BOTTOM
        )
        objective_border_anchor_signature = anchor_signature
    end

    local show_border = is_background_border_enabled() == true
    if objective_border_shown ~= show_border then
        if show_border then
            border:Show()
        else
            border:Hide()
        end
        objective_border_shown = show_border
    end
end

local function set_background_border_position_offsets()
    local db = M.get_db()
    if not db then return end

    db.objective_tracker_offset_x = OBJECTIVE_BORDER_OFFSET_X
    db.objective_tracker_offset_y = OBJECTIVE_BORDER_OFFSET_Y
end
M.set_background_border_position_offsets = set_background_border_position_offsets

local function get_background_aware_position_default(key)
    if is_background_border_enabled() then
        if key == "objective_tracker_offset_x" then return OBJECTIVE_BORDER_OFFSET_X end
        if key == "objective_tracker_offset_y" then return OBJECTIVE_BORDER_OFFSET_Y end
    end
    return DEFAULTS.objectives[key]
end
M.get_background_aware_position_default = get_background_aware_position_default

--#endregion BACKGROUND STATE HELPERS ==========================================


--#region COLOR AND OPACITY ====================================================

local function get_background_color_alpha()
    local db = M.get_db()
    local color = db and db.background_color
    return addon.clamp_number(type(color) == "table" and color.a, DEFAULT_BACKGROUND_COLOR.a or 0.5, COLOR_RANGE)
end

local function get_background_color_values()
    local db = M.get_db()
    local color = db and db.background_color or DEFAULT_BACKGROUND_COLOR
    if type(color) ~= "table" then
        color = DEFAULT_BACKGROUND_COLOR
    end

    return addon.clamp_number(color.r, DEFAULT_BACKGROUND_COLOR.r, COLOR_RANGE),
        addon.clamp_number(color.g, DEFAULT_BACKGROUND_COLOR.g, COLOR_RANGE),
        addon.clamp_number(color.b, DEFAULT_BACKGROUND_COLOR.b, COLOR_RANGE),
        get_background_color_alpha()
end

local function get_background_opacity()
    local db = M.get_db()
    return addon.clamp_number(db and db.background_alpha, DEFAULTS.objectives.background_alpha or 0.5, COLOR_RANGE)
end

local function get_edit_mode_objective_opacity_setting()
    return Enum
        and Enum.EditModeObjectiveTrackerSetting
        and Enum.EditModeObjectiveTrackerSetting.Opacity
        or nil
end

local function set_wow_background_opacity(opacity, update_edit_mode)
    local alpha = addon.clamp_number(opacity, DEFAULTS.objectives.background_alpha or 0.5, COLOR_RANGE)
    local percent = math.floor((alpha * 100) + 0.5)
    local tracker = get_objective_tracker()
    local setting = get_edit_mode_objective_opacity_setting()

    if update_edit_mode ~= false and tracker and setting ~= nil and tracker.HasSetting and tracker:HasSetting(setting) then
        local manager = EditModeManagerFrame
        if manager and manager.OnSystemSettingChange then
            background_alpha_applying = true
            local ok = pcall(manager.OnSystemSettingChange, manager, tracker, setting, percent)
            background_alpha_applying = false
            if ok then
                if ObjectiveTrackerManager and ObjectiveTrackerManager.SetOpacity then
                    background_alpha_applying = true
                    ObjectiveTrackerManager:SetOpacity(percent)
                    background_alpha_applying = false
                end
                background_edit_mode_state = "edit_mode:" .. tostring(percent)
                return true
            end
        end

        if tracker.UpdateSystemSettingValue then
            background_alpha_applying = true
            local ok = pcall(tracker.UpdateSystemSettingValue, tracker, setting, percent)
            background_alpha_applying = false
            if ok then
                if ObjectiveTrackerManager and ObjectiveTrackerManager.SetOpacity then
                    background_alpha_applying = true
                    ObjectiveTrackerManager:SetOpacity(percent)
                    background_alpha_applying = false
                end
                background_edit_mode_state = "system_frame:" .. tostring(percent)
                return true
            end
        end
    end

    if ObjectiveTrackerManager and ObjectiveTrackerManager.SetOpacity then
        background_alpha_applying = true
        ObjectiveTrackerManager:SetOpacity(percent)
        background_alpha_applying = false
        background_edit_mode_state = "manager:" .. tostring(percent)
        return true
    end

    if tracker and tracker.SetBackgroundAlpha then
        background_alpha_applying = true
        tracker:SetBackgroundAlpha(alpha)
        background_alpha_applying = false
        background_edit_mode_state = "tracker_alpha:" .. tostring(alpha)
        return true
    end

    local background = tracker and tracker.NineSlice
    if background and background.SetAlpha then
        background:SetAlpha(alpha)
        background_edit_mode_state = "nineslice_alpha:" .. tostring(alpha)
        return true
    end

    background_edit_mode_state = "unavailable"
    return false
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

local function should_show_background_color()
    local db = M.get_db()
    return M.is_runtime_enabled() and is_background_color_enabled(db)
end

function M.migrate_background_settings(db)
    if not db then return end
    if db.background_color_enabled ~= nil then return end
    if db.customize_background == true and not is_background_color_default(db.background_color) then
        db.background_color_enabled = true
    end
end

local function get_color_signature(r, g, b, a)
    return tostring(r) .. ":" .. tostring(g) .. ":" .. tostring(b) .. ":" .. tostring(a)
end

local function get_background_signature(r, g, b, a, opacity, overlay_enabled)
    return get_color_signature(r, g, b, a)
        .. ":bg_alpha=" .. tostring(opacity)
        .. ":color_alpha=" .. tostring(a)
        .. ":overlay=" .. tostring(overlay_enabled)
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

local function reset_background_regions(background)
    local applied = 0
    for _, key in ipairs(BACKGROUND_ALPHA_REGION_KEYS) do
        if apply_color_to_region(background[key]) then
            applied = applied + 1
        end
    end
    return applied
end

local function apply_center_color_overlay(background, r, g, b, a, enabled)
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

    overlay:SetVertexColor(r, g, b, a)
    overlay:Show()
    return true
end

local function apply_background_color(r, g, b, a, force, opacity_override, show_color_overlay, update_edit_mode)
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
    local overlay_enabled = show_color_overlay == true
    if not force
        and background_last_applied_alpha == opacity
        and background_last_color_r == r
        and background_last_color_g == g
        and background_last_color_b == b
        and background_last_color_a == a
        and background_last_overlay_enabled == overlay_enabled
    then
        return
    end

    if force or background_last_applied_alpha ~= opacity then
        if update_edit_mode == nil then
            update_edit_mode = opacity_override == nil or opacity == 0
        end
        set_wow_background_opacity(opacity, update_edit_mode)
        background_last_applied_alpha = opacity
    end
    local applied = 0
    if force or not background_regions_reset then
        applied = reset_background_regions(background)
        background_regions_reset = true
    end
    local overlay_applied = apply_center_color_overlay(background, r, g, b, a, overlay_enabled)

    background_last_color_r = r
    background_last_color_g = g
    background_last_color_b = b
    background_last_color_a = a
    background_last_overlay_enabled = overlay_enabled
    background_color_last_signature = get_background_signature(r, g, b, a, opacity, overlay_enabled)
    background_color_state = overlay_applied
        and ("center_overlay:bg_alpha=" .. tostring(opacity) .. ":color_alpha=" .. tostring(a) .. ":reset_regions=" .. tostring(applied))
        or "no_regions"
end

local function apply_configured_background_color(force)
    if not M.is_runtime_enabled() then return end
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_color_state = "combat_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    local show_blizzard_background = should_customize_background()
    local show_color_background = should_show_background_color()
    local opacity
    if not show_blizzard_background then
        opacity = 0
    end
    local r = DEFAULT_BACKGROUND_COLOR.r
    local g = DEFAULT_BACKGROUND_COLOR.g
    local b = DEFAULT_BACKGROUND_COLOR.b
    local a = DEFAULT_BACKGROUND_COLOR.a
    if show_color_background then
        r, g, b, a = get_background_color_values()
    end
    apply_background_color(r, g, b, a, force, opacity, show_color_background)
end

local function restore_background_color()
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_color_state = "combat_restore_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    background_regions_reset = false
    apply_background_color(
        DEFAULT_BACKGROUND_COLOR.r,
        DEFAULT_BACKGROUND_COLOR.g,
        DEFAULT_BACKGROUND_COLOR.b,
        DEFAULT_BACKGROUND_COLOR.a,
        true,
        1,
        false,
        true
    )
end

--#endregion COLOR AND OPACITY =================================================


--#region BACKGROUND SIZING ====================================================

local function show_background_to_header(tracker, background, state)
    local header = tracker and tracker.Header
    if header and header.IsShown and header:IsShown() then
        local points_to_header = background_points_to_header(tracker, background)
        local changed = not points_to_header
            or not (background.IsShown and background:IsShown())
        if not points_to_header then
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

local function is_priority_module(tracker, frame)
    for _, module in ipairs(tracker.modules or {}) do
        if module == frame and module.hasDisplayPriority == true then
            return true
        end
    end
    return false
end

local function get_priority_module_for_anchor(tracker, anchor)
    if not tracker or not anchor then return nil end

    local frame = anchor
    while frame do
        if is_priority_module(tracker, frame) then
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
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_last_state = "combat_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end
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

    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_last_state = "combat_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

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
    local delay = addon.UPDATE_INTERVALS.next_frame
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function queue_background_followup(reason)
    local delay = addon.UPDATE_INTERVALS.fifth_sec
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
            if background_alpha_applying then return end
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
        local blend_mode = get_method_value(region, "GetBlendMode")
        local desaturated = get_method_value(region, "IsDesaturated")
        local texture = get_method_value(region, "GetTexture")
        local atlas = get_method_value(region, "GetAtlas")

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
    fields[#fields + 1] = "bg_enabled=" .. tostring(should_customize_background() == true or should_show_background_color() == true)
    fields[#fields + 1] = "bg_wow_enabled=" .. tostring(should_customize_background() == true)
    fields[#fields + 1] = "bg_color_enabled=" .. tostring(should_show_background_color() == true)
    fields[#fields + 1] = "bg_color_state=" .. tostring(background_color_state)
    fields[#fields + 1] = "bg_edit_mode_state=" .. tostring(background_edit_mode_state)
    fields[#fields + 1] = "bg_color_signature=" .. tostring(background_color_last_signature)
    fields[#fields + 1] = "bg_alpha=" .. tostring(get_background_opacity())
    fields[#fields + 1] = "bg_color_alpha=" .. tostring(get_background_color_alpha())
    fields[#fields + 1] = "bg_nineslice_alpha=" .. tostring(get_objective_tracker() and get_objective_tracker().NineSlice and get_objective_tracker().NineSlice:GetAlpha() or nil)
    fields[#fields + 1] = "objective_border=" .. tostring(is_background_border_enabled() == true)
    fields[#fields + 1] = "objective_border_shown=" .. tostring(objective_border_frame and objective_border_frame.IsShown and objective_border_frame:IsShown() or false)
    if M.append_objective_position_status then
        M.append_objective_position_status(fields)
    end
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
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_last_state = "combat_deferred"
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    if M.apply_objective_position then
        M.apply_objective_position()
    end
    if M.apply_objective_move_mode then
        M.apply_objective_move_mode()
    end
    sync_objective_border()
    apply_configured_background_color()
end

function M.restore_background()
    local tracker = get_objective_tracker()
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        background_last_state = "combat_restore_deferred"
        if M.restore_objective_move_mode then
            M.restore_objective_move_mode()
        end
        if M.restore_objective_position then
            M.restore_objective_position()
        end
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
        return
    end

    if M.restore_objective_move_mode then
        M.restore_objective_move_mode()
    end
    if M.restore_objective_position then
        M.restore_objective_position()
    end
    if objective_border_frame then
        objective_border_frame:Hide()
    end
    objective_border_anchor_signature = nil
    objective_border_shown = nil
    restore_background_color()
    if tracker and tracker.Update then
        tracker:Update()
    end
end

--#endregion PUBLIC API ========================================================


--#region GUI ==================================================================

local function set_background_color(reason)
    local db = M.get_db()
    local border_was_enabled = is_background_border_enabled()
    local border_auto_enabled = false
    if reason == "reset" and db then
        db.objective_tracker_border = true
        background_color_auto_enabled_border = true
        border_auto_enabled = true
    elseif reason == "open" then
        background_color_auto_enabled_border = false
    elseif reason == "cancel" then
        if db and background_color_auto_enabled_border and is_background_color_default(db.background_color) then
            db.objective_tracker_border = nil
        end
        background_color_auto_enabled_border = false
    end

    apply_configured_background_color(false)

    local border_is_enabled = is_background_border_enabled()
    if border_was_enabled ~= border_is_enabled or border_auto_enabled or reason == "reset" then
        if border_auto_enabled then
            set_background_border_position_offsets()
            if M.apply_objective_position then
                M.apply_objective_position()
            end
            if M.sync_objective_position_sliders then
                M.sync_objective_position_sliders()
            end
        end
        sync_objective_border()
        if M.controls.objective_tracker_border_checkbox and M.controls.objective_tracker_border_checkbox.SetCheckedSilently then
            M.controls.objective_tracker_border_checkbox:SetCheckedSilently(border_is_enabled)
        end
    end
end

local function set_background_alpha()
    apply_configured_background_color(false)
end

local function sync_background_controls()
    local wow_enabled = should_customize_background()
    local color_enabled = should_show_background_color()
    if M.controls.background_color_picker and M.controls.background_color_picker.SetEnabled then
        M.controls.background_color_picker:SetEnabled(color_enabled)
    end
    if M.controls.background_alpha_slider and M.controls.background_alpha_slider.SetEnabled then
        M.controls.background_alpha_slider:SetEnabled(wow_enabled)
    end
end

local function set_customize_background(enabled)
    local db = M.get_db()
    if not db then return end
    db.customize_background = enabled == true
    sync_background_controls()
    apply_configured_background_color(true)
    local tracker = get_objective_tracker()
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        if M.defer_objectives_combat_update then
            M.defer_objectives_combat_update()
        end
    elseif tracker and tracker.Update then
        tracker:Update()
    end
    queue_background_sync("background setting changed")
end

local function set_background_color_enabled(enabled)
    local db = M.get_db()
    if not db then return end

    db.background_color_enabled = enabled == true
    sync_background_controls()
    apply_configured_background_color(true)
end

local function set_objective_border(enabled)
    local db = M.get_db()
    if not db then return end
    db.objective_tracker_border = enabled == true
    if enabled == true then
        set_background_border_position_offsets()
        if M.apply_objective_position then
            M.apply_objective_position()
        end
        if M.sync_objective_position_sliders then
            M.sync_objective_position_sliders()
        end
    end
    sync_objective_border()
end

function M.BuildBackgroundSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db()
    if not db then return end
    ensure_background_color()

    local background_group = addon.CreateSettingsGroup(
        parent,
        "Background",
        cfg.group_width,
        cfg.background_group_height,
        cfg.group_offset_x,
        cfg.background_group_offset_y
    )

    local background_grid = addon.CreateSettingsGrid(background_group, {
        column_count = 3,
        col_offset = cfg.grid_offset_x,
        row_start = cfg.grid_offset_y,
        col_width = cfg.grid_col_width,
        column_gap_x = cfg.grid_column_gap_x,
        row_heights = { cfg.slider_row_height },
        col_align = { "left", "left", "left" },
        offsets = { default = 0 },
    })

    local customize_container, customize_cb, customize_label = addon.CreateCheckbox(
        background_group,
        "WoW BG",
        db.customize_background == true,
        set_customize_background
    )
    M.controls.customize_background_checkbox = customize_container
    background_grid:place_at(customize_container, 1, 1)
    addon.AttachTooltip(customize_label, nil, "Sets Blizzard's Objective Tracker Edit Mode opacity to the saved WoW BG Alpha value, or 0 when unchecked.")

    local color_enabled_container, color_enabled_cb, color_enabled_label = addon.CreateCheckbox(
        background_group,
        "Custom BG",
        is_background_color_enabled(db),
        set_background_color_enabled
    )
    M.controls.background_color_enabled_checkbox = color_enabled_container
    background_grid:place_at(color_enabled_container, 1, 3)
    addon.AttachTooltip(color_enabled_label, nil, "Shows the LsTweeks center color block and enables the color picker and border.")

    local background_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "ObjectivesBackgroundAlpha",
        background_group,
        "WoW BG Alpha",
        0,
        1,
        0.05,
        db,
        "background_alpha",
        DEFAULTS.objectives,
        set_background_alpha,
        {
            display_decimals = 2,
            tooltip = "Controls Blizzard's Objective Tracker Edit Mode opacity without opening Edit Mode.",
        }
    )
    background_alpha_slider:HookValueChanged(function()
        apply_configured_background_color(false)
    end)
    M.controls.background_alpha_slider = background_alpha_slider
    background_grid:place_at(background_alpha_slider, 1, 2)

    local picker = addon.CreateColorPicker(
        background_group,
        db,
        "background_color",
        true,
        "Custom Color",
        DEFAULTS.objectives,
        set_background_color
    )
    M.controls.background_color_picker = picker
    background_grid:stack_below(picker, color_enabled_container, { y = -2 })
    addon.AttachTooltip(picker, nil, "Tints the center color block. The picker alpha controls only that color block.")

    local border_container, border_cb, border_label = addon.CreateCheckbox(
        background_group,
        "Border",
        is_background_border_enabled(),
        set_objective_border
    )
    M.controls.objective_tracker_border_checkbox = border_container
    background_grid:stack_below(border_container, picker, { y = -2 })
    addon.AttachTooltip(border_label, nil, "Shows the LsTweeks dialog border around the All Objectives tracker.")

    local background_width = background_grid[3] - cfg.grid_offset_x + cfg.grid_col_width
    background_group:SetWidth(math.ceil(background_width + cfg.group_padding_x * 2))

    sync_background_controls()
end

--#endregion GUI ===============================================================
