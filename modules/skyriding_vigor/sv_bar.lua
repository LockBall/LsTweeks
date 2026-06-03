-- Visual bar implementation for the Skyriding Vigor module.
-- Game-state detection and event routing live in sv_main.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local abs = math.abs
local max = math.max
local min = math.min

local MAX_SLOTS = 6
local DEFAULT_NODE_WIDTH = 42
local DEFAULT_NODE_HEIGHT = 45
local FILL_INSET_X = 4
local FILL_INSET_Y = 4
local GRID_SIZE = 20
local WING_LAYOUT = {
    overlap_x = 19,
    offset_x = 0,
    offset_y = -14,
}

M.MAX_SLOTS = MAX_SLOTS
M.WING_LAYOUT = WING_LAYOUT

local function get_db()
    return M.get_db and M.get_db()
end

local function get_defaults()
    return M.DEFAULTS or {}
end

local function snap_value(value)
    return math.floor(((value or 0) / GRID_SIZE) + 0.5) * GRID_SIZE
end

local function set_center_position(frame, x, y)
    if not frame then return end
    x = x or 0
    y = y or 0
    if frame._center_x == x and frame._center_y == y then
        return
    end
    frame._center_x = x
    frame._center_y = y
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", frame._center_x, frame._center_y)
end

local function get_saved_center(db)
    local defaults = get_defaults()
    local pos = db and db.position or defaults.position or {}
    return pos.x or 0, pos.y or 0
end

local function get_spacing_pixels(db)
    local defaults = get_defaults()
    local default_spacing = defaults.spacing or 5
    local spacing_setting = db and db.spacing
    if spacing_setting == nil then
        spacing_setting = default_spacing
    end
    return spacing_setting - default_spacing
end

local function get_cursor_position()
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

function M.snap_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    local xOfs = frame._center_x
    local yOfs = frame._center_y
    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = get_saved_center(db)
    end
    set_center_position(frame, snap_value(xOfs), snap_value(yOfs))
end

function M.save_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    if db.snap_to_grid then
        M.snap_position()
    end

    local xOfs = frame._center_x
    local yOfs = frame._center_y
    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = get_saved_center(db)
    end
    db.position = db.position or {}
    db.position.point = "CENTER"
    db.position.relativePoint = "CENTER"
    db.position.x = xOfs or 0
    db.position.y = yOfs or 0
    if M.sync_position_controls then
        M.sync_position_controls(db)
    end
end

function M.apply_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    local xOfs, yOfs = get_saved_center(db)
    set_center_position(frame, xOfs, yOfs)
end

local function set_atlas_native(texture, atlas)
    if not texture then return end
    texture:SetAtlas(atlas, true)
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function hide_region(region)
    if region and region.Hide then
        region:Hide()
    end
end

local function set_slot_progress(slot, progress)
    progress = max(0, min(progress or 0, 1))

    if slot._bar_texture ~= "dragonriding_vigor_fill" then
        slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")
        slot._bar_texture = "dragonriding_vigor_fill"
    end
    slot.bar:SetValue(progress)
end

local function set_slot_fill_bounds(slot)
    if slot._fill_bounds_set then return end

    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.bar:SetSize(DEFAULT_NODE_WIDTH - (FILL_INSET_X * 2), DEFAULT_NODE_HEIGHT - (FILL_INSET_Y * 2))
    slot.bar:SetMinMaxValues(0, 1)
    slot._fill_bounds_set = true
end

local function create_slot(parent, index)
    local ok, slot = pcall(CreateFrame, "Frame", addon_name .. "SkyridingVigorSlot" .. index, parent, "UIWidgetFillUpFrameTemplate")
    if not ok or not slot then
        slot = CreateFrame("Frame", addon_name .. "SkyridingVigorSlot" .. index, parent)
    end
    slot:SetSize(DEFAULT_NODE_WIDTH, DEFAULT_NODE_HEIGHT)

    slot.background = slot.BG or slot:CreateTexture(nil, "BACKGROUND", nil, 0)
    slot.background:ClearAllPoints()
    slot.background:SetPoint("CENTER", slot, "CENTER", 0, 0)
    set_atlas_native(slot.background, "dragonriding_vigor_background")

    slot.bar = slot.Bar or CreateFrame("StatusBar", nil, slot)
    slot.bar:SetOrientation("VERTICAL")
    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.bar:SetSize(DEFAULT_NODE_WIDTH - (FILL_INSET_X * 2), DEFAULT_NODE_HEIGHT - (FILL_INSET_Y * 2))
    slot.bar:SetFrameLevel(slot:GetFrameLevel() + 1)
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(0)
    slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")
    slot._bar_texture = "dragonriding_vigor_fill"
    slot._fill_bounds_set = true

    slot.cover_frame = slot.cover_frame or CreateFrame("Frame", nil, slot)
    slot.cover_frame:ClearAllPoints()
    slot.cover_frame:SetAllPoints(slot)
    slot.cover_frame:SetFrameLevel(slot.bar:GetFrameLevel() + 2)

    slot.cover = slot.Frame or slot.cover_frame:CreateTexture(nil, "OVERLAY", nil, 3)
    slot.cover:ClearAllPoints()
    slot.cover:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.cover:SetDrawLayer("OVERLAY", 7)
    set_atlas_native(slot.cover, "dragonriding_vigor_frame")

    hide_region(slot.Spark)
    hide_region(slot.SparkMask)
    hide_region(slot.Flash)
    hide_region(slot.Flipbook)
    hide_region(slot.BurstFlipbook)
    hide_region(slot.FilledFlipbook)
    if slot.bar then
        hide_region(slot.bar.Spark)
        hide_region(slot.bar.SparkMask)
        hide_region(slot.bar.Flipbook)
        hide_region(slot.bar.FlipbookMask)
        hide_region(slot.bar.BurstFlipbook)
        hide_region(slot.bar.FilledFlipbook)
    end

    return slot
end

function M.set_slot_state(index, state, progress)
    local slot = M.slots[index]
    if not slot then return end

    local effective_progress
    if state == "full" then
        effective_progress = 1
    elseif state == "filling" then
        effective_progress = max(0, min(progress or 0, 1))
    else
        effective_progress = 0
    end

    if slot._state == state and abs((slot._progress or -1) - effective_progress) < 0.001 then
        return
    end

    set_slot_fill_bounds(slot)
    if state == "full" then
        if slot._bar_texture ~= "dragonriding_vigor_fillfull" then
            slot.bar:SetStatusBarTexture("dragonriding_vigor_fillfull")
            slot._bar_texture = "dragonriding_vigor_fillfull"
        end
        slot.bar:SetValue(effective_progress)
    elseif state == "filling" then
        set_slot_progress(slot, effective_progress)
    else
        if slot._bar_texture ~= "dragonriding_vigor_fill" then
            slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")
            slot._bar_texture = "dragonriding_vigor_fill"
        end
        slot.bar:SetValue(effective_progress)
    end
    slot._state = state
    slot._progress = effective_progress
end

function M.set_slot_visible(index, visible)
    local slot = M.slots[index]
    if not slot then return end

    if visible then
        if not slot:IsShown() then
            slot:Show()
        end
    else
        if slot:IsShown() then
            slot:Hide()
        end
    end
end

local function ensure_decor(parent)
    if M.decor_left and M.decor_right then return end

    M.decor_left = parent:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_left:SetAtlas("dragonriding_vigor_decor", true)
    M.decor_left:SetTexCoord(1, 0, 0, 1)

    M.decor_right = parent:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_right:SetAtlas("dragonriding_vigor_decor", true)
end

function M.ensure_frame()
    if M.frame then return M.frame end

    local frame = CreateFrame("Frame", addon_name .. "SkyridingVigor", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    local visual_frame = CreateFrame("Frame", nil, frame)
    visual_frame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    M.visual_frame = visual_frame
    ensure_decor(visual_frame)

    frame:SetScript("OnDragStart", function(self)
        local db = get_db()
        if not db or not db.move_mode or InCombatLockdown() then return end
        local cursor_x, cursor_y = get_cursor_position()
        local center_x = self._center_x
        local center_y = self._center_y
        if center_x == nil or center_y == nil then
            center_x, center_y = get_saved_center(db)
        end
        self._drag_start_cursor_x = cursor_x
        self._drag_start_cursor_y = cursor_y
        self._drag_start_center_x = center_x
        self._drag_start_center_y = center_y
        self:SetScript("OnUpdate", function(drag_frame)
            local current_x, current_y = get_cursor_position()
            set_center_position(
                drag_frame,
                drag_frame._drag_start_center_x + current_x - drag_frame._drag_start_cursor_x,
                drag_frame._drag_start_center_y + current_y - drag_frame._drag_start_cursor_y
            )
        end)
    end)

    frame:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self._drag_start_cursor_x = nil
        self._drag_start_cursor_y = nil
        self._drag_start_center_x = nil
        self._drag_start_center_y = nil
        M.save_position()
    end)

    M.frame = frame
    M.invalidate_layout()
    for i = 1, MAX_SLOTS do
        M.slots[i] = create_slot(visual_frame, i)
    end

    M.apply_position()
    return frame
end

function M.set_wing_layout(values)
    if not values then return end

    if values.overlap_x ~= nil then WING_LAYOUT.overlap_x = values.overlap_x end
    if values.offset_x ~= nil then WING_LAYOUT.offset_x = values.offset_x end
    if values.offset_y ~= nil then WING_LAYOUT.offset_y = values.offset_y end

    M.invalidate_layout()
    if M.frame and M.refresh then
        M.refresh()
    end
end

function M.invalidate_layout()
    M._layout_signature = nil
end

function M.apply_layout()
    local db = get_db()
    local frame = M.ensure_frame()
    if not db or not frame then return end

    local defaults = get_defaults()
    local spacing = get_spacing_pixels(db)
    local scale = db.scale or defaults.scale or 1
    local width = DEFAULT_NODE_WIDTH
    local height = DEFAULT_NODE_HEIGHT
    local decor_width = M.decor_left and M.decor_left:GetWidth() or 64
    local decor_height = M.decor_left and M.decor_left:GetHeight() or 64
    local nodes_width = (width * MAX_SLOTS) + (spacing * (MAX_SLOTS - 1))
    local first_slot_x = decor_width - WING_LAYOUT.overlap_x
    local right_decor_x = first_slot_x + nodes_width - WING_LAYOUT.overlap_x
    local total_width = right_decor_x + decor_width
    local total_height = max(height, decor_height)
    local visual_frame = M.visual_frame
    local center_x = frame._center_x
    local center_y = frame._center_y
    if center_x == nil or center_y == nil then
        center_x, center_y = get_saved_center(db)
    end
    if frame._center_x == nil or frame._center_y == nil then
        set_center_position(frame, center_x, center_y)
    end

    local layout_signature = spacing .. ":" .. scale .. ":" .. total_width .. ":" .. total_height .. ":"
        .. first_slot_x .. ":" .. right_decor_x .. ":" .. WING_LAYOUT.overlap_x .. ":"
        .. WING_LAYOUT.offset_x .. ":" .. WING_LAYOUT.offset_y
    if M._layout_signature == layout_signature then
        return
    end
    M._layout_signature = layout_signature

    frame:SetSize(total_width * scale, total_height * scale)
    frame:SetScale(1)
    if visual_frame then
        visual_frame:SetSize(total_width, total_height)
        visual_frame:SetScale(scale)
        visual_frame:ClearAllPoints()
        visual_frame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    set_center_position(frame, center_x, center_y)

    for i = 1, MAX_SLOTS do
        local slot = M.slots[i]
        slot:ClearAllPoints()
        slot:SetSize(width, height)
        slot:SetPoint("LEFT", visual_frame or frame, "LEFT", first_slot_x + ((width + spacing) * (i - 1)), 0)
    end

    if M.decor_left and M.decor_right and M.slots[1] and M.slots[MAX_SLOTS] then
        M.decor_left:ClearAllPoints()
        M.decor_right:ClearAllPoints()
        M.decor_left:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            (decor_width / 2) - WING_LAYOUT.offset_x,
            WING_LAYOUT.offset_y
        )
        M.decor_right:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            right_decor_x + (decor_width / 2) + WING_LAYOUT.offset_x,
            WING_LAYOUT.offset_y
        )
    end
end

function M.set_move_mode(enabled)
    local frame = M.ensure_frame()
    local mouse_enabled = enabled and true or false
    if frame._mouse_enabled ~= mouse_enabled then
        frame:EnableMouse(mouse_enabled)
        frame._mouse_enabled = mouse_enabled
    end
    if enabled then
        if frame._sv_alpha ~= 1 then
            frame:SetAlpha(1)
            frame._sv_alpha = 1
        end
        if not frame:IsShown() then
            frame:Show()
        end
    end
end
