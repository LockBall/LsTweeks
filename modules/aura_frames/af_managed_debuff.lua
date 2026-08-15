-- AF12-05 managed Debuff capability.
-- Owns the HARMFUL AuraGroup and its initial icon-only presentation. Later
-- Debuff capability increments extend this file without reintroducing Aura data reads.

local addon_name, addon = ...

local M = addon.aura_frames

local ICON_SIZE = 32
local GROUP_KEY = "debuffs"

--#region MANAGED CONTAINER LAYOUT ============================================

local function configure_debuff_layout(container, cfg_db)
    local flow_axis = AnchorUtil.FlowLayoutAxis
    local flow_direction = AnchorUtil.FlowDirection
    local spacing = cfg_db.spacing_debuff or 1
    local line_size = cfg_db.width_debuff or M.DEFAULT_FRAME_WIDTH

    container:SetFlowLayoutPadding(0, 0, 0, 0)
    container:SetFlowLayoutAxis(flow_axis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(flow_direction.Right, flow_direction.Down)
    container:SetFlowLayoutMaximumLineSize(line_size)

    return {
        elementSpacing = spacing,
        lineSpacing = spacing,
        layoutIndex = 1,
    }
end

--#endregion MANAGED CONTAINER LAYOUT =========================================

--#region MANAGED BUTTON INITIALIZATION ========================================

local function initialize_debuff_button(aura_button)
    aura_button:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = aura_button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(aura_button)
    aura_button:SetIcon(icon)

    -- AuraButton owns this tooltip path and can identify its secret Aura
    -- without addon AuraData reads or addon-owned hover scripts.
    aura_button:SetMouseMotionEnabled(true)
    aura_button:SetHideTooltipInCombat(true)
end

--#endregion MANAGED BUTTON INITIALIZATION =====================================

--#region BACKEND CREATION =====================================================

function M.create_managed_debuff_backend(frame, cfg_db)
    if not (frame and cfg_db and M.create_managed_aura_backend) then return nil end

    local backend, backend_error = M.create_managed_aura_backend(
        frame,
        "preset:debuff",
        "player"
    )
    if not backend then return nil, backend_error end

    local layout = configure_debuff_layout(backend.container, cfg_db)
    local max_frame_count = cfg_db.max_icons_debuff or M.DEFAULT_MAX_ICONS
    local group, group_error = M.add_managed_aura_group(backend, GROUP_KEY, "HARMFUL", {
        maxFrameCount = max_frame_count,
        initializeFrame = initialize_debuff_button,
    }, layout)
    if not group then
        M.release_managed_aura_backend(backend)
        return nil, group_error
    end

    frame._managed_aura_backend = backend
    return backend
end

--#endregion BACKEND CREATION ==================================================

--#region SHELL STATE ==========================================================

local function set_shell_controls_shown(frame, shown)
    M.set_shown_if_changed(frame.title_bar, shown)
    M.set_shown_if_changed(frame.bottom_title_bar, shown)
    M.set_shown_if_changed(frame.resizer, shown)
end

function M.update_managed_debuff_frame(frame, show_key, move_key)
    local backend = frame and frame._managed_aura_backend
    if not backend then return false end

    local activity = M.get_frame_activity_state(frame, show_key, move_key)
    M.set_managed_aura_backend_enabled(backend, activity.enabled)

    if not activity.enabled then
        set_shell_controls_shown(frame, false)
        M.set_shown_if_changed(frame, false)
        return true
    end

    -- AF12-05.1 proves the managed transport without carrying the legacy white
    -- BackdropTemplate shell into the icon-only slice. Appearance follows later.
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    set_shell_controls_shown(frame, activity.moving == true)
    M.set_shown_if_changed(frame, true)
    return true
end

function M.refresh_managed_debuff_frames()
    for _, frame in ipairs(M.frames_list or {}) do
        local params = frame and frame.update_params
        if frame and frame._managed_aura_backend and params then
            M.update_managed_debuff_frame(frame, params.show_key, params.move_key)
        end
    end
end

--#endregion SHELL STATE =======================================================
