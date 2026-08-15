-- AF12-05 managed Debuff capability.
-- Owns the HARMFUL AuraGroup and its native icon/bar presentation. Later
-- Debuff capability increments extend this file without reintroducing Aura data reads.

local addon_name, addon = ...

local M = addon.aura_frames

local ICON_SIZE = 32
local BAR_ROW_HEIGHT = 18
local BAR_FRAME_INSET = 6
local BAR_ICON_GAP = 5
local BAR_STACK_WIDTH = 20
local BAR_TIMER_WIDTH = 36
local GROUP_KEY = "debuffs"

--#region MANAGED CONTAINER LAYOUT ============================================

local function configure_debuff_layout(container, frame, cfg_db, max_frame_count)
    local flow_axis = AnchorUtil.FlowLayoutAxis
    local flow_direction = AnchorUtil.FlowDirection
    local spacing = cfg_db.spacing_debuff or 1

    container:SetFlowLayoutPadding(0, 0, 0, 0)

    if cfg_db.bar_mode_debuff == true then
        local grows_up = cfg_db.growth_debuff == "UP"
        local anchor = grows_up and "BOTTOMLEFT" or "TOPLEFT"
        local y_offset = grows_up and BAR_FRAME_INSET or -BAR_FRAME_INSET
        container:ClearAllPoints()
        container:SetPoint(anchor, frame, anchor, BAR_FRAME_INSET, y_offset)
        container:SetFlowLayoutAxis(flow_axis.Vertical)
        container:SetFlowLayoutAnchorPoint(anchor)
        container:SetFlowLayoutGrowthDirection(
            flow_direction.Right,
            grows_up and flow_direction.Up or flow_direction.Down
        )
        container:SetFlowLayoutMaximumLineSize(max_frame_count * (BAR_ROW_HEIGHT + spacing))
    else
        local line_size = cfg_db.width_debuff or M.DEFAULT_FRAME_WIDTH
        container:SetFlowLayoutAxis(flow_axis.Horizontal)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(flow_direction.Right, flow_direction.Down)
        container:SetFlowLayoutMaximumLineSize(line_size)
    end

    return {
        elementSpacing = spacing,
        lineSpacing = spacing,
        layoutIndex = 1,
    }
end

--#endregion MANAGED CONTAINER LAYOUT =========================================

--#region MANAGED BUTTON INITIALIZATION ========================================

local function bind_native_tooltip(aura_button)
    -- AuraButton owns this tooltip path and can identify its secret Aura
    -- without addon AuraData reads or addon-owned hover scripts.
    aura_button:SetMouseMotionEnabled(true)
    aura_button:SetHideTooltipInCombat(true)
end

local function initialize_debuff_icon(aura_button)
    aura_button:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = aura_button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(aura_button)
    aura_button:SetIcon(icon)
    bind_native_tooltip(aura_button)
end

local function initialize_debuff_bar(aura_button, cfg_db)
    local row_width = (cfg_db.width_debuff or M.DEFAULT_FRAME_WIDTH) - (BAR_FRAME_INSET * 2)
    aura_button:SetSize(row_width, BAR_ROW_HEIGHT)

    local icon = aura_button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BAR_ROW_HEIGHT, BAR_ROW_HEIGHT)
    icon:SetPoint("LEFT", aura_button, "LEFT")
    aura_button:SetIcon(icon)

    local duration_bar = CreateFrame("StatusBar", nil, aura_button)
    duration_bar:SetPoint("LEFT", icon, "RIGHT", BAR_ICON_GAP, 0)
    duration_bar:SetPoint("RIGHT", aura_button, "RIGHT")
    duration_bar:SetHeight(BAR_ROW_HEIGHT)
    duration_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    duration_bar:SetMinMaxValues(0, 1)

    local bar_color = M.resolve_bar_color("debuff", cfg_db.color_debuff)
    duration_bar:SetStatusBarColor(bar_color.r, bar_color.g, bar_color.b, bar_color.a or 1)
    local background_color = M.get_bar_bg_color(cfg_db, "debuff", bar_color)
    local background = duration_bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(duration_bar)
    background:SetColorTexture(
        background_color.r,
        background_color.g,
        background_color.b,
        background_color.a or M.BAR_BG_ALPHA_DEFAULT
    )

    local text_overlay = CreateFrame("Frame", nil, aura_button)
    text_overlay:SetAllPoints(aura_button)
    text_overlay:SetFrameLevel(duration_bar:GetFrameLevel() + 1)

    local stack_text = text_overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    stack_text:SetPoint("LEFT", duration_bar, "LEFT", 2, 0)
    stack_text:SetWidth(BAR_STACK_WIDTH)
    stack_text:SetJustifyH("CENTER")

    local duration_text = text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    duration_text:SetPoint("RIGHT", duration_bar, "RIGHT", -2, 0)
    duration_text:SetWidth(BAR_TIMER_WIDTH)
    duration_text:SetJustifyH("RIGHT")
    M.apply_number_font_to_text(duration_text, "debuff")

    local spell_name = text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spell_name:SetPoint("LEFT", stack_text, "RIGHT", 2, 0)
    spell_name:SetPoint("RIGHT", duration_text, "LEFT", -2, 0)
    spell_name:SetJustifyH("LEFT")
    spell_name:SetWordWrap(false)
    if spell_name.SetMaxLines then spell_name:SetMaxLines(1) end

    local text_color = M.resolve_text_color("debuff", "bar", cfg_db.bar_text_color_debuff)
    stack_text:SetTextColor(text_color.r, text_color.g, text_color.b, 1)
    duration_text:SetTextColor(text_color.r, text_color.g, text_color.b, 1)
    spell_name:SetTextColor(text_color.r, text_color.g, text_color.b, 1)

    aura_button:SetSpellName(spell_name)
    aura_button:SetDurationText(duration_text, {})
    aura_button:SetApplicationCount(stack_text, {})
    aura_button:SetDurationBar(duration_bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime,
    })

    bind_native_tooltip(aura_button)
end

local function create_debuff_initializer(cfg_db)
    if cfg_db.bar_mode_debuff == true then
        return function(aura_button)
            initialize_debuff_bar(aura_button, cfg_db)
        end
    end
    return initialize_debuff_icon
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

    local max_frame_count = cfg_db.max_icons_debuff or M.DEFAULT_MAX_ICONS
    local layout = configure_debuff_layout(backend.container, frame, cfg_db, max_frame_count)
    local group, group_error = M.add_managed_aura_group(backend, GROUP_KEY, "HARMFUL", {
        maxFrameCount = max_frame_count,
        initializeFrame = create_debuff_initializer(cfg_db),
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
    if M.refresh_frame_ooc_fade then
        M.refresh_frame_ooc_fade(frame, activity)
    end

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
