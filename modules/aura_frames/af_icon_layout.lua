-- Positions and sizes aura icons within each category frame (static/short/long/debuff).
-- i.e. icon placement within a specific frame on screen, not the frames themselves, which are handled by af_main.lua.
-- setup_layout() arranges icons in rows or columns based on growth direction, bar mode, spacing, and frame width from DB.
-- get_bar_layout_params() returns pixel measurements for bar-mode rows (icon, stack count, timer, name slots).
-- set_height_for_growth() resizes a frame while keeping the correct edge anchored so icons grow in the right direction.

local addon_name, addon = ...

local floor          = math.floor
local math_max       = math.max
local math_ceil      = math.ceil
local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local GROWTH_LAYOUT = {
    UP = {
        vertical = true,
        grows_up = true,
        bar_anchor = "BOTTOMLEFT",
        icon_anchor = "BOTTOMLEFT",
    },
    DOWN = {
        vertical = true,
        bar_anchor = "TOPLEFT",
        icon_anchor = "TOPLEFT",
    },
    LEFT = {
        vertical = false,
        bar_anchor = "TOPLEFT",
        icon_anchor = "TOPRIGHT",
        x_sign = -1,
    },
    RIGHT = {
        vertical = false,
        bar_anchor = "TOPLEFT",
        icon_anchor = "TOPLEFT",
        x_sign = 1,
    },
}

local DEFAULT_GROWTH_LAYOUT = GROWTH_LAYOUT.DOWN
local BAR_ROW_HEIGHT = 18
local ICON_SIZE = 32
local FRAME_BOTTOM_PADDING = 12
local TIMER_SLOT_HEIGHT = 12
local TIMER_BOTTOM_PADDING = 2

--#region BAR LAYOUT PARAMS ====================================================

function M.get_bar_layout_params(timer_font_size)
    timer_font_size = tonumber(timer_font_size) or 10
    local min_width = 36
    local scale_factor = 2.7
    local timer_slot_width = math_max(min_width, math_ceil(timer_font_size * scale_factor))

    return {
        frame_inset = 6,
        frame_inner_width_pad = 12,
        row_height = BAR_ROW_HEIGHT,

        icon_size = BAR_ROW_HEIGHT,
        icon_to_bar_gap = 5,
        bar_height = BAR_ROW_HEIGHT,

        stack_slot_left_pad = 2,
        stack_slot_width = 20,
        stack_slot_height = BAR_ROW_HEIGHT,

        timer_slot_width = timer_slot_width,
        timer_slot_right_pad = 2,
        timer_slot_height = BAR_ROW_HEIGHT,

        name_slot_left_gap = 2,
        name_slot_right_gap = 2,
        name_slot_right_no_timer = 4,
        name_slot_height = BAR_ROW_HEIGHT,

        name_text_left_pad = 2,
        name_text_right_pad = 2,
    }
end

--#endregion BAR LAYOUT PARAMS =================================================

--#region FRAME HEIGHT LAYOUT ==================================================

-- Mirrors setup_layout() so update_auras() does not duplicate content dimensions.
function M.get_aura_frame_height(layout, display_count, bar_mode, spacing, layout_show_timer_text)
    local has_layout = layout ~= nil
    layout = layout or {}
    display_count = tonumber(display_count) or 0
    spacing = tonumber(spacing) or layout.spacing or 0

    if bar_mode then
        local row_height = layout.row_height or BAR_ROW_HEIGHT
        if display_count > 0 then
            return display_count * (row_height + spacing) + FRAME_BOTTOM_PADDING
        end
        return row_height + spacing + FRAME_BOTTOM_PADDING
    end

    local icon_size = layout.icon_size or ICON_SIZE
    local timer_height = layout_show_timer_text and TIMER_SLOT_HEIGHT or 0
    local bottom_padding = FRAME_BOTTOM_PADDING + (layout_show_timer_text and TIMER_BOTTOM_PADDING or 0)
    if display_count <= 0 then
        return icon_size + timer_height + bottom_padding
    end

    local row_height = icon_size + spacing + timer_height
    if has_layout and (layout.growth == "DOWN" or layout.growth == "UP") then
        return display_count * row_height - spacing + bottom_padding
    end
    if has_layout and layout.icons_per_row then
        local rows = math_ceil(display_count / layout.icons_per_row)
        return rows * row_height - spacing + bottom_padding
    end
    return display_count * (ICON_SIZE + FRAME_BOTTOM_PADDING)
end

--#endregion FRAME HEIGHT LAYOUT ===============================================

--#region FRAME HEIGHT RESIZE (PRESERVES ANCHOR POINT) =========================

-- Resize self to new_height while keeping the stable edge anchored.
-- DOWN keeps top edge fixed; UP keeps bottom edge fixed.
function M.set_height_for_growth(self, new_height, growth)
    if not self then return end

    local old_height = self:GetHeight()
    if old_height == new_height then return end
    local delta = new_height - old_height

    local point, relative_to, relative_point, x, y = self:GetPoint(1)
    if not point then return end

    self:SetHeight(new_height)

    if relative_to and relative_to ~= UIParent then
        relative_to = UIParent
    end
    relative_point = relative_point or point
    x = x or 0
    y = y or 0

    local p = tostring(point or "")
    local is_top    = p:find("TOP",    1, true) ~= nil
    local is_bottom = p:find("BOTTOM", 1, true) ~= nil
    if growth == "DOWN" then
        if is_bottom then
            y = y - delta
        elseif not is_top then
            y = y - (delta * 0.5)
        end
    elseif growth == "UP" then
        if is_top then
            y = y + delta
        elseif not is_bottom then
            y = y + (delta * 0.5)
        end
    end

    self:ClearAllPoints()
    self:SetPoint(point, relative_to or UIParent, relative_point, x, y)
end

--#endregion FRAME HEIGHT RESIZE (PRESERVES ANCHOR POINT) ======================

--#region LAYOUT ENGINE ========================================================

local function get_growth_layout(growth)
    return GROWTH_LAYOUT[growth] or DEFAULT_GROWTH_LAYOUT
end

local function set_bar_icon_position(obj, frame, layout, index, step, inset)
    if layout.grows_up then
        obj:SetPoint(layout.bar_anchor, frame, layout.bar_anchor, inset, (index - 1) * step + inset)
    else
        obj:SetPoint(layout.bar_anchor, frame, layout.bar_anchor, inset, -((index - 1) * step + inset))
    end
end

local function set_icon_position(obj, frame, layout, col_idx, row_idx, icon_footprint, row_height, up_offset)
    if layout.grows_up then
        obj:SetPoint(layout.icon_anchor, frame, layout.icon_anchor, 6, row_idx * row_height + up_offset)
    elseif layout.vertical then
        obj:SetPoint(layout.icon_anchor, frame, layout.icon_anchor, 6, -(row_idx * row_height + 6))
    else
        obj:SetPoint(layout.icon_anchor, frame, layout.icon_anchor,
            (layout.x_sign or 1) * (col_idx * icon_footprint + 6),
            -(row_idx * row_height + 6))
    end
end

local function get_timer_text_alignment(category, frame)
    return category == "long" and "CENTER" or "RIGHT"
end

function M.setup_layout(self, show_key, spacing_key, bar_mode)
    if not self or not self.icons then return end
    if InCombatLockdown() then return end

    -- Use frame-specific cfg_db for custom frames; fall back to global M.db for presets.
    local db = (self._cfg_db) or M.db
    local category = show_key:sub(6)
    local runtime_config = self._runtime_config_cache
    local frame_width = (runtime_config and runtime_config.frame_width) or db["width_"..category] or db["width"] or M.DEFAULT_FRAME_WIDTH
    local spacing = (runtime_config and runtime_config.spacing) or db[spacing_key] or db["spacing"] or 6
    local growth = (runtime_config and runtime_config.growth) or db["growth_"..category] or db["growth"] or "DOWN"
    local growth_layout = get_growth_layout(growth)

    local show_timer_text = runtime_config and runtime_config.show_timer_text
    if show_timer_text == nil then
        show_timer_text = M.is_timer_text_enabled(db, category, db["timer"] ~= nil and "timer" or nil)
    end
    local cooldown_icon_overlay = runtime_config and runtime_config.cooldown_icon_overlay
    if cooldown_icon_overlay == nil then
        cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, db)
    end
    local layout_show_timer_text = runtime_config and runtime_config.layout_show_timer_text
    if layout_show_timer_text == nil then
        layout_show_timer_text = show_timer_text and not cooldown_icon_overlay
    end
    local timer_font_size = M.get_timer_number_font_size(category, self._cfg_db)
    local bar_layout = M.get_bar_layout_params(timer_font_size)
    local timer_text_align = get_timer_text_alignment(category, self)
    local timer_anchor_point = (timer_text_align == "CENTER") and "CENTER" or "RIGHT"
    local bar_timer_slot_width = bar_layout.timer_slot_width
    local bar_timer_slot_right_pad = bar_layout.timer_slot_right_pad

    local icon_size = ICON_SIZE
    local icon_footprint = icon_size + spacing
    local icons_per_row = growth_layout.vertical
        and 1
        or math_max(1, floor((frame_width - 12 + spacing) / icon_footprint))

    for i = 1, #self.icons do
        local obj = self.icons[i]
        obj:ClearAllPoints()
        obj.texture:ClearAllPoints()

        if bar_mode then
            local bar_h = bar_layout.row_height
            local step  = bar_h + spacing
            obj:SetSize(frame_width - bar_layout.frame_inner_width_pad, bar_h)

            set_bar_icon_position(obj, self, growth_layout, i, step, bar_layout.frame_inset)

            obj.texture:SetSize(bar_layout.icon_size, bar_layout.icon_size)
            obj.texture:SetPoint("LEFT", obj, "LEFT", 0, 0)

            obj.bar:ClearAllPoints()
            obj.bar:SetPoint("LEFT", obj.texture, "RIGHT", bar_layout.icon_to_bar_gap, 0)
            obj.bar:SetPoint("RIGHT", obj, "RIGHT", 0, 0)
            obj.bar:SetHeight(bar_layout.bar_height)

            obj.stack_slot:ClearAllPoints()
            obj.stack_slot:SetPoint("LEFT", obj.bar, "LEFT", bar_layout.stack_slot_left_pad, 0)
            obj.stack_slot:SetSize(bar_layout.stack_slot_width, bar_layout.stack_slot_height)
            obj.stack_slot:Show()

            obj.timer_slot:ClearAllPoints()
            obj.timer_slot:SetPoint("RIGHT", obj.bar, "RIGHT", -bar_timer_slot_right_pad, 0)
            obj.timer_slot:SetSize(bar_timer_slot_width, bar_layout.timer_slot_height)

            obj.name_slot:ClearAllPoints()
            obj.name_slot:SetPoint("LEFT", obj.stack_slot, "RIGHT", bar_layout.name_slot_left_gap, 0)
            if show_timer_text then
                obj.name_slot:SetPoint("RIGHT", obj.timer_slot, "LEFT", -bar_layout.name_slot_right_gap, 0)
            else
                obj.name_slot:SetPoint("RIGHT", obj.bar, "RIGHT", -bar_layout.name_slot_right_no_timer, 0)
            end
            obj.name_slot:SetHeight(bar_layout.name_slot_height)
            obj.name_slot:Show()

            obj.name_text:ClearAllPoints()
            obj.name_text:SetPoint("LEFT", obj.name_slot, "LEFT", bar_layout.name_text_left_pad, 0)
            obj.name_text:SetPoint("RIGHT", obj.name_slot, "RIGHT", -bar_layout.name_text_right_pad, 0)
            obj.name_text:SetJustifyV("MIDDLE")
            obj.name_text:Show()

            obj.time_text:ClearAllPoints()
            obj.time_text:SetJustifyV("MIDDLE")
            obj.time_text:SetPoint(timer_anchor_point, obj.timer_slot, timer_anchor_point, 0, 0)
            obj.time_text:SetWidth(bar_timer_slot_width)
            obj.time_text:SetJustifyH(timer_text_align)
            if show_timer_text then
                obj.timer_slot:Show()
                obj.time_text:Show()
            else
                obj.timer_slot:Hide()
                obj.time_text:Hide()
            end

            obj.count_text:ClearAllPoints()
            obj.count_text:SetPoint("CENTER", obj.stack_slot, "CENTER", 0, 0)
            obj.count_text:Hide()

        else
            obj:SetSize(icon_size, icon_size)
            obj.texture:SetAllPoints(obj)

            local col_idx = (i - 1) % icons_per_row
            local row_idx = floor((i - 1) / icons_per_row)
            local timer_h = layout_show_timer_text and TIMER_SLOT_HEIGHT or 0
            local row_h   = icon_size + spacing + timer_h

            local up_offset = 6 + (timer_h > 0 and (timer_h + 2) or 0)
            set_icon_position(obj, self, growth_layout, col_idx, row_idx, icon_footprint, row_h, up_offset)

            obj.stack_slot:ClearAllPoints()
            obj.stack_slot:Hide()

            obj.name_slot:ClearAllPoints()
            obj.name_slot:Hide()

            obj.name_text:ClearAllPoints()
            obj.name_text:Hide()

            obj.timer_slot:ClearAllPoints()
            obj.timer_slot:SetPoint("TOPRIGHT", obj, "BOTTOMRIGHT", 0, -2)
            obj.timer_slot:SetSize(icon_size, TIMER_SLOT_HEIGHT)

            obj.time_text:ClearAllPoints()
            obj.time_text:SetPoint(timer_anchor_point, obj.timer_slot, timer_anchor_point, 0, 0)
            obj.time_text:SetWidth(icon_size)
            obj.time_text:SetJustifyH(timer_text_align)
            if layout_show_timer_text then
                obj.timer_slot:Show()
                obj.time_text:Show()
            else
                obj.timer_slot:Hide()
                obj.time_text:Hide()
            end

            obj.count_text:ClearAllPoints()
            obj.count_text:SetPoint("BOTTOMRIGHT", obj, "BOTTOMRIGHT", 0, 1)
        end
    end

    self._layout_cache = {
        bar_mode        = bar_mode,
        show_timer_text = show_timer_text,
        layout_show_timer_text = layout_show_timer_text,
        cooldown_icon_overlay = cooldown_icon_overlay,
        icons_per_row   = icons_per_row,
        frame_width     = frame_width,
        spacing         = spacing,
        growth          = growth,
        growth_layout   = growth_layout,
        row_height      = bar_layout.row_height,
        icon_size       = ICON_SIZE,
    }
end

--#endregion LAYOUT ENGINE =====================================================
