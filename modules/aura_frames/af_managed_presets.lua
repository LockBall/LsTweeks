-- Managed preset Aura capabilities (Short, learned Static / Long, Timed Buffs, and Debuffs).
-- Owns native icon/bar presentation, frame backgrounds, and move outlines for
-- HELPFUL Buffs and HARMFUL Debuffs without reintroducing Aura data reads.

local addon_name, addon = ...

local M = addon.aura_frames

local ICON_SIZE = 32
local ICON_TIMER_HEIGHT = 12
local ICON_TIMER_GAP = 2
local ICON_CELL_HEIGHT = ICON_SIZE + ICON_TIMER_GAP + ICON_TIMER_HEIGHT
local BAR_ROW_HEIGHT = 18
local BAR_FRAME_INSET = 6
local BAR_ICON_GAP = 5
local BAR_STACK_WIDTH = 20
local BAR_TIMER_WIDTH = 36
local MOVE_OUTLINE_OVERLAP = 1
local MOVE_HANDLE_EDGE_THICKNESS = 3
local MOVE_OUTLINE_PASSIVE_ALPHA = 0.45
local NO_BACKGROUND_INSETS = { left = 0, right = 0, top = 0, bottom = 0 }
local managed_duration_fonts = {}
local managed_stack_fonts = {}
local TIMED_BUFF_CANDIDATE_FILTERS = { maxDuration = math.huge }

--#region MANAGED CONTAINER LAYOUT ============================================

local function get_short_max_duration(cfg_db)
    local duration = tonumber(cfg_db and cfg_db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD
    return math.max(0, duration)
end

local function get_preset_setting(cfg_db, category, name, fallback)
    local value = cfg_db[name .. "_" .. category]
    if value == nil then return fallback end
    return value
end

local function get_flow_direction(flow_direction, direction)
    local enum_key = direction:sub(1, 1) .. direction:sub(2):lower()
    return flow_direction[enum_key]
end

local function configure_preset_layout(container, frame, cfg_db, category, max_frame_count, bar_mode, show_timer_text)
    local flow_axis = AnchorUtil.FlowLayoutAxis
    local flow_direction = AnchorUtil.FlowDirection
    local spacing = get_preset_setting(cfg_db, category, "spacing", 1)
    local growth = M.get_mode_growth(cfg_db, category, bar_mode)
    local growth_layout = addon.GetGrowthDirection(growth)
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

    local icon_cell_height = show_timer_text and ICON_CELL_HEIGHT or ICON_SIZE
    local element_extent = bar_mode and BAR_ROW_HEIGHT or icon_cell_height
    local line_size = growth_layout.vertical
        and (max_frame_count * (element_extent + spacing))
        or (bar_mode and (max_frame_count * ((width - (BAR_FRAME_INSET * 2)) + spacing)) or width)
    container:SetFlowLayoutMaximumLineSize(line_size)

    return {
        elementSpacing = spacing,
        lineSpacing = spacing,
        layoutIndex = 1,
        elementHeight = (not bar_mode) and icon_cell_height or nil,
    }
end

--#endregion MANAGED CONTAINER LAYOUT =========================================

--#region MANAGED BUTTON INITIALIZATION ========================================

local function bind_native_tooltip(aura_button)
    -- AuraButton owns this tooltip path and can identify its secret Aura
    -- without addon AuraData reads or addon-owned hover scripts, including
    -- while Aura access is restricted in combat.
    aura_button:SetMouseMotionEnabled(true)
    aura_button:SetHideTooltipInCombat(false)
end

local function apply_duration_font(duration_text, duration_font, category)
    if duration_font then
        duration_text:SetFontObject(duration_font)
    else
        M.apply_number_font_to_text(duration_text, category)
    end
end

local function get_preset_bar_color(cfg_db, category)
    return M.resolve_bar_color(category, get_preset_setting(cfg_db, category, "color"))
end

local function set_managed_bar_color(duration_bar, color)
    if not (duration_bar and color) then return end
    local r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
    if duration_bar._lstweeks_color_r == r
        and duration_bar._lstweeks_color_g == g
        and duration_bar._lstweeks_color_b == b
        and duration_bar._lstweeks_color_a == a
    then
        return
    end
    duration_bar._lstweeks_color_r = r
    duration_bar._lstweeks_color_g = g
    duration_bar._lstweeks_color_b = b
    duration_bar._lstweeks_color_a = a
    duration_bar:SetStatusBarColor(r, g, b, a)
end

local function set_managed_bar_width(aura_button, width)
    if not aura_button or aura_button._lstweeks_width == width then return end
    aura_button._lstweeks_width = width
    aura_button:SetWidth(width)
end

local function register_frame_background_row(backend, aura_button, mode, index)
    local background = addon.CreateBackgroundRegion(aura_button)
    backend.frame_background_rows[aura_button] = {
        aura_button = aura_button,
        background = background,
        mode = mode,
        index = index,
    }
end

local function initialize_preset_icon(
    aura_button,
    cfg_db,
    category,
    duration_font,
    stack_font,
    backend,
    index
)
    aura_button:SetSize(ICON_SIZE, ICON_CELL_HEIGHT)
    register_frame_background_row(backend, aura_button, "icon", index)

    local icon = aura_button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOP", aura_button, "TOP")
    aura_button:SetIcon(icon)

    local duration_text = aura_button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    duration_text:SetPoint("TOP", icon, "BOTTOM", 0, -ICON_TIMER_GAP)
    duration_text:SetWidth(ICON_SIZE)
    duration_text:SetHeight(ICON_TIMER_HEIGHT)
    duration_text:SetJustifyH("CENTER")
    apply_duration_font(duration_text, duration_font, category)

    local stack_text = aura_button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    stack_text:SetPoint(
        "BOTTOMRIGHT",
        icon,
        "BOTTOMRIGHT",
        -M.ICON_STACK_INSET.right,
        M.ICON_STACK_INSET.bottom
    )
    if stack_font then
        stack_text:SetFontObject(stack_font)
    else
        M.apply_stack_font_style(stack_text, category, cfg_db)
    end

    aura_button:SetDurationText(duration_text, {})
    aura_button:SetApplicationCount(stack_text, {})
    bind_native_tooltip(aura_button)
end

local function initialize_preset_bar(
    aura_button,
    cfg_db,
    category,
    duration_font,
    stack_font,
    bar_regions,
    backend,
    index
)
    local row_width = get_preset_setting(cfg_db, category, "width", M.DEFAULT_FRAME_WIDTH)
        - (BAR_FRAME_INSET * 2)
    aura_button:SetSize(row_width, BAR_ROW_HEIGHT)
    aura_button._lstweeks_width = row_width
    register_frame_background_row(backend, aura_button, "bar", index)

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

    local bar_color = get_preset_bar_color(cfg_db, category)
    set_managed_bar_color(duration_bar, bar_color)
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
    if stack_font then
        stack_text:SetFontObject(stack_font)
    else
        M.apply_stack_font_style(stack_text, category, cfg_db)
    end

    local duration_text = text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    duration_text:SetPoint("RIGHT", duration_bar, "RIGHT", -2, 0)
    duration_text:SetWidth(BAR_TIMER_WIDTH)
    duration_text:SetJustifyH("RIGHT")
    apply_duration_font(duration_text, duration_font, category)

    local spell_name = text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spell_name:SetPoint("LEFT", stack_text, "RIGHT", 2, 0)
    spell_name:SetPoint("RIGHT", duration_text, "LEFT", -2, 0)
    spell_name:SetJustifyH("LEFT")
    spell_name:SetWordWrap(false)
    if spell_name.SetMaxLines then spell_name:SetMaxLines(1) end

    local bar_text_color = M.resolve_text_color(
        category,
        "bar",
        get_preset_setting(cfg_db, category, "bar_text_color")
    )
    -- Duration text inherits the category-owned FontObject so Timer Text color
    -- changes continue to propagate after the immutable native binding.
    spell_name:SetTextColor(bar_text_color.r, bar_text_color.g, bar_text_color.b, 1)

    aura_button:SetSpellName(spell_name)
    aura_button:SetDurationText(duration_text, {})
    aura_button:SetApplicationCount(stack_text, {})
    aura_button:SetDurationBar(duration_bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime,
    })
    bar_regions[aura_button] = duration_bar

    bind_native_tooltip(aura_button)
end

local function create_preset_initializer(
    cfg_db,
    category,
    bar_mode,
    duration_font,
    stack_font,
    bar_regions,
    backend
)
    if bar_mode == true then
        return function(aura_button, index)
            initialize_preset_bar(
                aura_button,
                cfg_db,
                category,
                duration_font,
                stack_font,
                bar_regions,
                backend,
                index
            )
        end
    end
    return function(aura_button, index)
        initialize_preset_icon(
            aura_button,
            cfg_db,
            category,
            duration_font,
            stack_font,
            backend,
            index
        )
    end
end

--#endregion MANAGED BUTTON INITIALIZATION =====================================

--#region MANAGED MOVE OUTLINE CREATION ========================================

local function create_container_move_outline(container)
    local outline = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = container:CreateTexture(nil, "OVERLAY")
        local color = M.MOVE_BORDER_COLOR
        edge:SetColorTexture(color.r, color.g, color.b, color.a)
        if side == "TOP" then
            edge:SetPoint("BOTTOMLEFT", container, "TOPLEFT", -1, 0)
            edge:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 1, 0)
            edge:SetHeight(1)
        elseif side == "BOTTOM" then
            edge:SetPoint("TOPLEFT", container, "BOTTOMLEFT", -1, 0)
            edge:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", 1, 0)
            edge:SetHeight(1)
        elseif side == "LEFT" then
            edge:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, 1)
            edge:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT", 0, -1)
            edge:SetWidth(1)
        else
            edge:SetPoint("TOPLEFT", container, "TOPRIGHT", 0, 1)
            edge:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", 0, -1)
            edge:SetWidth(1)
        end
        edge:Hide()
        outline[side] = edge
    end
    return outline
end

--#endregion MANAGED MOVE OUTLINE CREATION =====================================


--#region MANAGED FRAME BACKGROUNDS ============================================

local function configure_managed_frame_background(
    backend,
    bar_mode,
    width,
    spacing,
    show_timer_text,
    growth_layout
)
    local mode = bar_mode and "bar" or "icon"
    local cell_height = show_timer_text and ICON_CELL_HEIGHT or ICON_SIZE
    local signature = table.concat({
        mode,
        width,
        spacing,
        cell_height,
        growth_layout.value,
    }, ":")
    if backend.frame_background_signature == signature then return end
    backend.frame_background_signature = signature

    local minimum_height = bar_mode and (BAR_ROW_HEIGHT + (BAR_FRAME_INSET * 2)) or cell_height
    local anchor = backend.frame_background_anchor
    anchor:ClearAllPoints()
    anchor:SetPoint(growth_layout.anchor, backend.owner, growth_layout.anchor)
    anchor:SetSize(width, minimum_height)

    local icons_per_row = growth_layout.vertical and 1
        or math.max(1, math.floor((width + spacing) / (ICON_SIZE + spacing)))
    local grows_up = growth_layout.vertical_direction == "UP"
    local grows_left = growth_layout.horizontal == "LEFT"
    for _, record in pairs(backend.frame_background_rows) do
        local texture = record.background.texture
        record.extends_background = false
        texture:ClearAllPoints()
        if record.mode == mode then
            if bar_mode and record.index > 1 then
                record.extends_background = true
                texture:SetSize(width, BAR_ROW_HEIGHT + spacing)
                if grows_up then
                    texture:SetPoint(
                        "BOTTOMLEFT",
                        record.aura_button,
                        "BOTTOMLEFT",
                        -BAR_FRAME_INSET,
                        BAR_FRAME_INSET - spacing
                    )
                else
                    texture:SetPoint(
                        "TOPLEFT",
                        record.aura_button,
                        "TOPLEFT",
                        -BAR_FRAME_INSET,
                        spacing - BAR_FRAME_INSET
                    )
                end
            elseif not bar_mode
                and record.index > icons_per_row
                and ((record.index - 1) % icons_per_row) == 0
            then
                record.extends_background = true
                texture:SetSize(width, cell_height + spacing)
                local point
                if grows_up then
                    point = grows_left and "BOTTOMRIGHT" or "BOTTOMLEFT"
                    texture:SetPoint(point, record.aura_button, point, 0, -spacing)
                else
                    point = grows_left and "TOPRIGHT" or "TOPLEFT"
                    texture:SetPoint(point, record.aura_button, point, 0, spacing)
                end
            end
        end
    end
end

local function apply_managed_frame_background(
    backend,
    cfg_db,
    bar_mode,
    width,
    spacing,
    show_timer_text,
    growth_layout
)
    local background = backend and backend.frame_background
    if not (background and M.resolve_frame_background) then return end

    configure_managed_frame_background(
        backend,
        bar_mode,
        width,
        spacing,
        show_timer_text,
        growth_layout
    )
    local enabled, color = M.resolve_frame_background(cfg_db, backend.category)
    background:Apply(enabled, color, NO_BACKGROUND_INSETS)
    for _, record in pairs(backend.frame_background_rows) do
        record.background:SetColor(color)
        record.background:SetShown(enabled and record.extends_background)
    end
end

--#endregion MANAGED FRAME BACKGROUNDS =========================================


--#region MANAGED MOVE OUTLINE =================================================

local function position_container_move_outline(backend, width, bar_mode, growth_layout)
    local outline = backend.move_outline
    if not outline then return end

    for _, edge in pairs(outline) do
        edge:ClearAllPoints()
    end

    local container = backend.container
    local owner = backend.owner
    local inset = bar_mode and BAR_FRAME_INSET or 0
    local grows_up = growth_layout.vertical_direction == "UP"
    local grows_left = growth_layout.horizontal == "LEFT"
    backend.move_outline_bar_mode = bar_mode
    backend.move_outline_growth_layout = growth_layout
    owner._managed_mover_edge = grows_up and "BOTTOM" or "TOP"
    outline.TOP:SetHeight(grows_up and 1 or MOVE_HANDLE_EDGE_THICKNESS)
    outline.BOTTOM:SetHeight(grows_up and MOVE_HANDLE_EDGE_THICKNESS or 1)
    local active_side = grows_up and "BOTTOM" or "TOP"
    local color = M.MOVE_BORDER_COLOR
    for side, edge in pairs(outline) do
        local alpha = side == active_side and color.a or MOVE_OUTLINE_PASSIVE_ALPHA
        edge:SetColorTexture(color.r, color.g, color.b, alpha)
    end

    if grows_up then
        outline.TOP:SetPoint("BOTTOMLEFT", container, "TOPLEFT", -inset, inset)
        outline.TOP:SetPoint("BOTTOMRIGHT", container, "TOPLEFT", width - inset, inset)
        outline.BOTTOM:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -MOVE_OUTLINE_OVERLAP, 0)
        outline.BOTTOM:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", MOVE_OUTLINE_OVERLAP, 0)
        outline.LEFT:SetPoint("TOPRIGHT", container, "TOPLEFT", -inset, inset + MOVE_OUTLINE_OVERLAP)
        outline.LEFT:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", 0, -MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("TOPLEFT", container, "TOPLEFT", width - inset, inset + MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 0, -MOVE_OUTLINE_OVERLAP)
    elseif grows_left then
        outline.TOP:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -MOVE_OUTLINE_OVERLAP, 0)
        outline.TOP:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", MOVE_OUTLINE_OVERLAP, 0)
        outline.BOTTOM:SetPoint("TOPLEFT", container, "BOTTOMRIGHT", -width - MOVE_OUTLINE_OVERLAP, 0)
        outline.BOTTOM:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", MOVE_OUTLINE_OVERLAP, 0)
        outline.LEFT:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, MOVE_OUTLINE_OVERLAP)
        outline.LEFT:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -width, -MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", 0, -MOVE_OUTLINE_OVERLAP)
    else
        outline.TOP:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -MOVE_OUTLINE_OVERLAP, 0)
        outline.TOP:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", MOVE_OUTLINE_OVERLAP, 0)
        outline.BOTTOM:SetPoint("TOPLEFT", container, "BOTTOMLEFT",
            -inset - MOVE_OUTLINE_OVERLAP, -inset)
        outline.BOTTOM:SetPoint("TOPRIGHT", container, "BOTTOMLEFT",
            width - inset + MOVE_OUTLINE_OVERLAP, -inset)
        outline.LEFT:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, MOVE_OUTLINE_OVERLAP)
        outline.LEFT:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT",
            -inset, -inset - MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, MOVE_OUTLINE_OVERLAP)
        outline.RIGHT:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT",
            width - inset, -inset - MOVE_OUTLINE_OVERLAP)
    end
end

function M.update_managed_move_outline_width(frame, width)
    local backend = frame and frame._managed_aura_backend
    if not (backend and backend.move_outline_growth_layout) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    position_container_move_outline(
        backend,
        math.max(M.MIN_FRAME_WIDTH, width or frame:GetWidth()),
        backend.move_outline_bar_mode,
        backend.move_outline_growth_layout
    )
    return true
end

--#endregion MANAGED MOVE OUTLINE ==============================================


--#region MANAGED PRESENTATION =================================================

local function apply_managed_preset_presentation(backend, cfg_db)
    local category = backend.category
    if backend.uses_learned_buff_filter then
        local revision = M._learned_buff_revision or 0
        local short_max = tonumber(cfg_db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD
        if backend.learned_filter_revision ~= revision
            or backend.learned_filter_short_max ~= short_max
        then
            local candidate_filters = {
                includeSpellIDs = M.build_learned_long_static_spell_ids(cfg_db),
            }
            backend.container:SetAuraGroupCandidateFilters(
                backend.presentation_group_keys.bar,
                candidate_filters
            )
            backend.container:SetAuraGroupCandidateFilters(
                backend.presentation_group_keys.icon,
                candidate_filters
            )
            backend.learned_filter_revision = revision
            backend.learned_filter_short_max = short_max
        end
        if backend.owner.move_handle then
            local count = M.get_learned_long_static_count(cfg_db)
            backend.owner.move_handle.body = string.format(
                "Shows %d learned Static / Long buffs. Helpful Aura durations are learned only while readable outside combat; Short maximum: %s seconds.",
                count,
                tostring(short_max)
            )
        end
    end
    if category == "short" then
        local max_duration = get_short_max_duration(cfg_db)
        if backend.short_max_duration ~= max_duration then
            local candidate_filters = { maxDuration = max_duration }
            backend.container:SetAuraGroupCandidateFilters(
                backend.presentation_group_keys.bar,
                candidate_filters
            )
            backend.container:SetAuraGroupCandidateFilters(
                backend.presentation_group_keys.icon,
                candidate_filters
            )
            backend.short_max_duration = max_duration
        end
        if backend.owner.move_handle then
            backend.owner.move_handle.body = string.format(
                "Shows helpful auras with a total duration of %s seconds or less.",
                tostring(max_duration)
            )
        end
    end
    local bar_mode = get_preset_setting(cfg_db, category, "bar_mode", false) == true
    local show_timer_text = get_preset_setting(cfg_db, category, "timer", true) ~= false
    local width = math.max(
        M.MIN_FRAME_WIDTH,
        get_preset_setting(cfg_db, category, "width", M.DEFAULT_FRAME_WIDTH)
    )
    if backend.owner:GetWidth() ~= width then
        backend.owner:SetWidth(width)
    end
    if backend.duration_font and M.apply_number_font_style then
        M.apply_number_font_style(backend.duration_font, category, cfg_db, show_timer_text and 1 or 0)
    end
    if backend.stack_font and M.apply_stack_font_style then
        M.apply_stack_font_style(backend.stack_font, category, cfg_db)
    end
    local bar_color = get_preset_bar_color(cfg_db, category)
    local bar_width = width - (BAR_FRAME_INSET * 2)
    M.for_each_accessible_managed_aura_button(backend, function(aura_button, group_key)
        if group_key == backend.presentation_group_keys.bar then
            set_managed_bar_width(aura_button, bar_width)
            set_managed_bar_color(backend.bar_regions[aura_button], bar_color)
        end
    end)
    local mode = bar_mode and "bar" or "icon"
    local max_frame_count = M.AURA_FRAME_LIMIT
    local spacing = get_preset_setting(cfg_db, category, "spacing", 1)
    local growth_layout = addon.GetGrowthDirection(M.get_mode_growth(cfg_db, category, bar_mode))
    position_container_move_outline(backend, width, bar_mode, growth_layout)
    apply_managed_frame_background(
        backend,
        cfg_db,
        bar_mode,
        width,
        spacing,
        show_timer_text,
        growth_layout
    )
    local signature = table.concat({ mode, max_frame_count, spacing, growth_layout.value, width,
        tostring(show_timer_text) }, ":")
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
        bar_mode,
        show_timer_text
    )
    backend.container:SetAuraGroupLayout(active_key, layout)
    backend.presentation_mode = mode
    backend.presentation_signature = signature
end

--#endregion MANAGED PRESENTATION ==============================================


--#region BACKEND CREATION =====================================================

local function create_managed_preset_backend(
    frame,
    cfg_db,
    category,
    group_key,
    filter_string,
    candidate_filters,
    sort_method,
    sort_direction
)
    if not (frame and cfg_db and M.create_managed_aura_backend) then return nil end

    local backend, backend_error = M.create_managed_aura_backend(
        frame,
        "preset:" .. category,
        "player"
    )
    if not backend then return nil, backend_error end

    backend.category = category
    backend.cfg_db = cfg_db
    local duration_font = managed_duration_fonts[category]
    if not duration_font and CreateFont then
        duration_font = CreateFont(addon_name .. "ManagedAuraDurationFont" .. category)
        managed_duration_fonts[category] = duration_font
    end
    backend.duration_font = duration_font
    local stack_font = managed_stack_fonts[category]
    if not stack_font and CreateFont then
        stack_font = CreateFont(addon_name .. "ManagedAuraStackFont" .. category)
        managed_stack_fonts[category] = stack_font
    end
    backend.stack_font = stack_font
    backend.bar_regions = {}
    backend.frame_background_rows = {}
    backend.frame_background_anchor = CreateFrame("Frame", nil, frame)
    backend.frame_background = addon.CreateBackgroundRegion(frame, {
        anchor_to = backend.frame_background_anchor,
    })
    backend.move_outline = create_container_move_outline(backend.container)
    backend.presentation_group_keys = {
        bar = group_key .. ":bar",
        icon = group_key .. ":icon",
    }
    if category == "short" then
        backend.short_max_duration = candidate_filters and candidate_filters.maxDuration
    end

    local max_frame_count = M.AURA_FRAME_LIMIT
    local show_timer_text = get_preset_setting(cfg_db, category, "timer", true) ~= false
    if duration_font and M.apply_number_font_style then
        M.apply_number_font_style(duration_font, category, cfg_db, show_timer_text and 1 or 0)
    end
    if stack_font and M.apply_stack_font_style then
        M.apply_stack_font_style(stack_font, category, cfg_db)
    end
    local bar_layout = configure_preset_layout(
        backend.container, frame, cfg_db, category, max_frame_count, true, show_timer_text)
    local bar_group, group_error = M.add_managed_aura_group(
        backend,
        backend.presentation_group_keys.bar,
        filter_string,
        {
            maxFrameCount = max_frame_count,
            candidateFilters = candidate_filters,
            sortMethod = sort_method,
            sortDirection = sort_direction,
            initializeFrame = create_preset_initializer(
                cfg_db,
                category,
                true,
                duration_font,
                stack_font,
                backend.bar_regions,
                backend
            ),
        },
        bar_layout
    )
    if not bar_group then
        M.release_managed_aura_backend(backend)
        return nil, group_error
    end

    local icon_layout = configure_preset_layout(
        backend.container, frame, cfg_db, category, max_frame_count, false, show_timer_text)
    local icon_group
    icon_group, group_error = M.add_managed_aura_group(
        backend,
        backend.presentation_group_keys.icon,
        filter_string,
        {
            maxFrameCount = max_frame_count,
            candidateFilters = candidate_filters,
            sortMethod = sort_method,
            sortDirection = sort_direction,
            initializeFrame = create_preset_initializer(
                cfg_db,
                category,
                false,
                duration_font,
                stack_font,
                backend.bar_regions,
                backend
            ),
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

function M.create_managed_learned_buff_backend(frame, cfg_db)
    local backend, backend_error = create_managed_preset_backend(
        frame,
        cfg_db,
        "static_long",
        "buffs",
        "HELPFUL",
        { includeSpellIDs = M.build_learned_long_static_spell_ids(cfg_db) }
    )
    if not backend then return nil, backend_error end
    backend.uses_learned_buff_filter = true
    apply_managed_preset_presentation(backend, cfg_db)
    return backend
end

function M.create_managed_short_buff_backend(frame, cfg_db)
    -- Load Blizzard_AuraContainer before resolving its public sort enums;
    -- this Lua file itself can load earlier in the addon startup sequence.
    if M.is_managed_aura_supported then
        M.is_managed_aura_supported()
    end
    local sort_method = rawget(_G, "AuraContainerSortMethod")
    local sort_direction = rawget(_G, "AuraContainerSortDirection")
    return create_managed_preset_backend(
        frame,
        cfg_db,
        "short",
        "short_buffs",
        "HELPFUL",
        { maxDuration = get_short_max_duration(cfg_db) },
        sort_method and sort_method.ExpirationOnly,
        sort_direction and sort_direction.Normal
    )
end

function M.create_managed_timed_buff_backend(frame, cfg_db)
    -- Blizzard evaluates maxDuration inside AuraContainer. Any non-nil
    -- maximum also excludes permanent (duration-zero) auras without exposing
    -- duration or expiration values to addon code.
    return create_managed_preset_backend(
        frame,
        cfg_db,
        "timed",
        "timed_buffs",
        "HELPFUL",
        TIMED_BUFF_CANDIDATE_FILTERS
    )
end

function M.refresh_managed_learned_buff_filters()
    if InCombatLockdown and InCombatLockdown() then return false end
    local backend = M.get_managed_aura_backend
        and M.get_managed_aura_backend("preset:static_long")
    if not backend then return false end
    apply_managed_preset_presentation(backend, backend.cfg_db or M.db)
    return true
end

--#endregion BACKEND CREATION ==================================================

--#region SHELL STATE ==========================================================

local function set_shell_controls_shown(frame, shown)
    M.update_aura_frame_move_controls(frame, shown)
    local backend = frame and frame._managed_aura_backend
    for _, edge in pairs(backend and backend.move_outline or {}) do
        edge:SetShown(shown)
    end
end

function M.update_managed_preset_frame(frame, show_key, move_key)
    local backend = frame and frame._managed_aura_backend
    if not backend then return false end

    local activity = M.get_frame_activity_state(frame, show_key, move_key)
    if not InCombatLockdown or not InCombatLockdown() then
        apply_managed_preset_presentation(backend, backend.cfg_db)
    end
    set_shell_controls_shown(frame, activity.enabled and activity.moving == true)
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
