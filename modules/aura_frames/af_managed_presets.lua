-- Managed preset Aura capabilities (combined Buffs and Debuffs).
-- Owns native icon/bar presentation for the combined HELPFUL Buffs frame and
-- the HARMFUL Debuffs frame without reintroducing Aura data reads.

local addon_name, addon = ...

local M = addon.aura_frames

local ICON_SIZE = 32
local BAR_ROW_HEIGHT = 18
local BAR_FRAME_INSET = 6
local BAR_ICON_GAP = 5
local BAR_STACK_WIDTH = 20
local BAR_TIMER_WIDTH = 36

--#region MANAGED CONTAINER LAYOUT ============================================

local function get_preset_setting(cfg_db, category, name, fallback)
    local value = cfg_db[name .. "_" .. category]
    if value == nil then return fallback end
    return value
end

local function get_flow_direction(flow_direction, direction)
    local enum_key = direction:sub(1, 1) .. direction:sub(2):lower()
    return flow_direction[enum_key]
end

local function configure_preset_layout(container, frame, cfg_db, category, max_frame_count, bar_mode)
    local flow_axis = AnchorUtil.FlowLayoutAxis
    local flow_direction = AnchorUtil.FlowDirection
    local spacing = get_preset_setting(cfg_db, category, "spacing", 1)
    local growth = get_preset_setting(cfg_db, category, "growth", "DOWN")
    local growth_layout = addon.GetGrowthDirection(growth)
    if bar_mode and not growth_layout.vertical then
        growth_layout = addon.GetGrowthDirection("DOWN")
    end
    local anchor = growth_layout.anchor
    local horizontal_direction = get_flow_direction(flow_direction, growth_layout.horizontal)
    local vertical_direction = get_flow_direction(flow_direction, growth_layout.vertical_direction)
    local axis = growth_layout.vertical and flow_axis.Vertical or flow_axis.Horizontal
    local width = get_preset_setting(cfg_db, category, "width", M.DEFAULT_FRAME_WIDTH)

    container:SetFlowLayoutPadding(0, 0, 0, 0)
    container:ClearAllPoints()
    if bar_mode then
        local x_offset = growth_layout.x_sign * BAR_FRAME_INSET
        local y_offset = growth_layout.y_sign * BAR_FRAME_INSET
        container:SetPoint(anchor, frame, anchor, x_offset, y_offset)
    else
        container:SetPoint(anchor, frame, anchor)
    end
    container:SetFlowLayoutAxis(axis)
    container:SetFlowLayoutAnchorPoint(anchor)
    container:SetFlowLayoutGrowthDirection(horizontal_direction, vertical_direction)

    local element_extent = bar_mode and BAR_ROW_HEIGHT or ICON_SIZE
    local line_size = growth_layout.vertical
        and (max_frame_count * (element_extent + spacing))
        or (bar_mode and (max_frame_count * ((width - (BAR_FRAME_INSET * 2)) + spacing)) or width)
    container:SetFlowLayoutMaximumLineSize(line_size)

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

local function initialize_preset_icon(aura_button)
    aura_button:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = aura_button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(aura_button)
    aura_button:SetIcon(icon)
    bind_native_tooltip(aura_button)
end

local function initialize_preset_bar(aura_button, cfg_db, category)
    local row_width = get_preset_setting(cfg_db, category, "width", M.DEFAULT_FRAME_WIDTH)
        - (BAR_FRAME_INSET * 2)
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

    local bar_color = M.resolve_bar_color(category, get_preset_setting(cfg_db, category, "color"))
    duration_bar:SetStatusBarColor(bar_color.r, bar_color.g, bar_color.b, bar_color.a or 1)
    local background_color = M.get_bar_bg_color(cfg_db, category, bar_color)
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
    M.apply_number_font_to_text(duration_text, category)

    local spell_name = text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spell_name:SetPoint("LEFT", stack_text, "RIGHT", 2, 0)
    spell_name:SetPoint("RIGHT", duration_text, "LEFT", -2, 0)
    spell_name:SetJustifyH("LEFT")
    spell_name:SetWordWrap(false)
    if spell_name.SetMaxLines then spell_name:SetMaxLines(1) end

    local text_color = M.resolve_text_color(
        category,
        "bar",
        get_preset_setting(cfg_db, category, "bar_text_color")
    )
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

local function create_preset_initializer(cfg_db, category, bar_mode)
    if bar_mode == true then
        return function(aura_button)
            initialize_preset_bar(aura_button, cfg_db, category)
        end
    end
    return initialize_preset_icon
end

--#endregion MANAGED BUTTON INITIALIZATION =====================================

--#region BACKEND CREATION =====================================================

local function apply_managed_preset_presentation(backend, cfg_db)
    local category = backend.category
    local bar_mode = get_preset_setting(cfg_db, category, "bar_mode", false) == true
    local mode = bar_mode and "bar" or "icon"
    local max_frame_count = get_preset_setting(cfg_db, category, "max_icons", M.DEFAULT_MAX_ICONS)
    local spacing = get_preset_setting(cfg_db, category, "spacing", 1)
    local growth_layout = addon.GetGrowthDirection(
        get_preset_setting(cfg_db, category, "growth", "DOWN")
    )
    if bar_mode and not growth_layout.vertical then
        growth_layout = addon.GetGrowthDirection("DOWN")
    end
    local signature = table.concat({ mode, max_frame_count, spacing, growth_layout.value }, ":")
    if backend.presentation_signature == signature then return end

    local active_key = backend.presentation_group_keys[mode]
    local inactive_key = backend.presentation_group_keys[bar_mode and "icon" or "bar"]
    backend.container:SetAuraGroupMaxFrameCount(inactive_key, 0)
    backend.container:SetAuraGroupMaxFrameCount(active_key, max_frame_count)
    local layout = configure_preset_layout(
        backend.container,
        backend.owner,
        cfg_db,
        category,
        max_frame_count,
        bar_mode
    )
    backend.container:SetAuraGroupLayout(active_key, layout)
    backend.presentation_mode = mode
    backend.presentation_signature = signature
end

local function create_managed_preset_backend(frame, cfg_db, category, group_key, filter_string)
    if not (frame and cfg_db and M.create_managed_aura_backend) then return nil end

    local backend, backend_error = M.create_managed_aura_backend(
        frame,
        "preset:" .. category,
        "player"
    )
    if not backend then return nil, backend_error end

    backend.category = category
    backend.cfg_db = cfg_db
    backend.presentation_group_keys = {
        bar = group_key .. ":bar",
        icon = group_key .. ":icon",
    }

    local max_frame_count = get_preset_setting(cfg_db, category, "max_icons", M.DEFAULT_MAX_ICONS)
    local bar_layout = configure_preset_layout(backend.container, frame, cfg_db, category, max_frame_count, true)
    local bar_group, group_error = M.add_managed_aura_group(
        backend,
        backend.presentation_group_keys.bar,
        filter_string,
        {
            maxFrameCount = max_frame_count,
            initializeFrame = create_preset_initializer(cfg_db, category, true),
        },
        bar_layout
    )
    if not bar_group then
        M.release_managed_aura_backend(backend)
        return nil, group_error
    end

    local icon_layout = configure_preset_layout(backend.container, frame, cfg_db, category, max_frame_count, false)
    local icon_group
    icon_group, group_error = M.add_managed_aura_group(
        backend,
        backend.presentation_group_keys.icon,
        filter_string,
        {
            maxFrameCount = max_frame_count,
            initializeFrame = create_preset_initializer(cfg_db, category, false),
        },
        icon_layout
    )
    if not icon_group then
        M.release_managed_aura_backend(backend)
        return nil, group_error
    end

    frame._managed_aura_backend = backend
    apply_managed_preset_presentation(backend, cfg_db)
    return backend
end

function M.create_managed_debuff_backend(frame, cfg_db)
    return create_managed_preset_backend(frame, cfg_db, "debuff", "debuffs", "HARMFUL")
end

function M.create_managed_combined_buff_backend(frame, cfg_db)
    return create_managed_preset_backend(frame, cfg_db, "combined", "buffs", "HELPFUL")
end

--#endregion BACKEND CREATION ==================================================

--#region SHELL STATE ==========================================================

local function set_shell_controls_shown(frame, shown)
    M.update_aura_frame_move_controls(frame, shown)
end

function M.update_managed_preset_frame(frame, show_key, move_key)
    local backend = frame and frame._managed_aura_backend
    if not backend then return false end

    local activity = M.get_frame_activity_state(frame, show_key, move_key)
    set_shell_controls_shown(frame, activity.enabled and activity.moving == true)
    if not InCombatLockdown or not InCombatLockdown() then
        apply_managed_preset_presentation(backend, backend.cfg_db)
    end
    M.set_managed_aura_backend_enabled(backend, activity.enabled)
    if M.refresh_frame_ooc_fade then
        M.refresh_frame_ooc_fade(frame, activity)
    end

    if not activity.enabled then
        set_shell_controls_shown(frame, false)
        M.set_shown_if_changed(frame, false)
        return true
    end

    -- Managed content supplies the visible Aura presentation. Keep the
    -- addon-owned positioning shell transparent outside Move Mode.
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    M.set_shown_if_changed(frame, true)
    return true
end

function M.refresh_managed_preset_frames()
    for _, frame in ipairs(M.frames_list or {}) do
        local params = frame and frame.update_params
        if frame and frame._managed_aura_backend and params then
            M.update_managed_preset_frame(frame, params.show_key, params.move_key)
        end
    end
end

--#endregion SHELL STATE =======================================================
