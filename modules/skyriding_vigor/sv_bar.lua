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
    frame._center_x = x or 0
    frame._center_y = y or 0
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", frame._center_x, frame._center_y)
end

local function get_saved_center(db)
    local defaults = get_defaults()
    local pos = db and db.position or defaults.position or {}
    return pos.x or 0, pos.y or 0
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

local function set_slot_progress(slot, progress)
    progress = max(0, min(progress or 0, 1))

    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")
    slot.bar:SetSize(DEFAULT_NODE_WIDTH - (FILL_INSET_X * 2), DEFAULT_NODE_HEIGHT - (FILL_INSET_Y * 2))
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(progress)
end

local function set_slot_fill_bounds(slot)
    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.bar:SetSize(DEFAULT_NODE_WIDTH - (FILL_INSET_X * 2), DEFAULT_NODE_HEIGHT - (FILL_INSET_Y * 2))
end

local function create_slot(parent, index)
    local ok, slot = pcall(CreateFrame, "StatusBar", addon_name .. "SkyridingVigorSlot" .. index, parent, "UIWidgetFillUpFrameTemplate")
    if not ok or not slot then
        slot = CreateFrame("Frame", addon_name .. "SkyridingVigorSlot" .. index, parent)
    end
    slot:SetSize(DEFAULT_NODE_WIDTH, DEFAULT_NODE_HEIGHT)

    slot.background = slot.BG or slot:CreateTexture(nil, "BACKGROUND", nil, 0)
    if not slot.background:GetPoint() then
        slot.background:SetPoint("CENTER", slot, "CENTER", 0, 0)
    end
    set_atlas_native(slot.background, "dragonriding_vigor_background")

    slot.bar = slot.Bar or CreateFrame("StatusBar", nil, slot)
    slot.bar:SetOrientation("VERTICAL")
    slot.bar:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.bar:SetSize(DEFAULT_NODE_WIDTH - (FILL_INSET_X * 2), DEFAULT_NODE_HEIGHT - (FILL_INSET_Y * 2))
    slot.bar:SetFrameLevel(slot:GetFrameLevel() + 1)
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(0)
    slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")

    slot.cover_frame = slot.cover_frame or CreateFrame("Frame", nil, slot)
    if not slot.cover_frame:GetPoint() then
        slot.cover_frame:SetAllPoints(slot)
    end
    slot.cover_frame:SetFrameLevel(slot.bar:GetFrameLevel() + 2)

    slot.cover = slot.Frame or slot.cover_frame:CreateTexture(nil, "OVERLAY", nil, 3)
    if not slot.cover:GetPoint() then
        slot.cover:SetPoint("CENTER", slot, "CENTER", 0, 0)
    end
    slot.cover:SetDrawLayer("OVERLAY", 7)
    set_atlas_native(slot.cover, "dragonriding_vigor_frame")

    return slot
end

function M.set_slot_state(index, state, progress)
    local slot = M.slots[index]
    if not slot then return end

    set_slot_fill_bounds(slot)
    if state == "full" then
        slot.bar:SetStatusBarTexture("dragonriding_vigor_fillfull")
        slot.bar:SetValue(1)
    elseif state == "filling" then
        set_slot_progress(slot, progress)
    else
        slot.bar:SetStatusBarTexture("dragonriding_vigor_fill")
        slot.bar:SetValue(0)
    end
end

function M.set_slot_visible(index, visible)
    local slot = M.slots[index]
    if not slot then return end

    if visible then
        slot:Show()
    else
        slot:Hide()
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

    if M.frame and M.refresh then
        M.refresh()
    end
end

function M.apply_layout()
    local db = get_db()
    local frame = M.ensure_frame()
    if not db or not frame then return end

    local defaults = get_defaults()
    local spacing_setting = db.spacing or defaults.spacing or 5
    local spacing = spacing_setting - 5
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
        if i == 1 then
            slot:SetPoint("LEFT", visual_frame or frame, "LEFT", first_slot_x, 0)
        else
            slot:SetPoint("LEFT", M.slots[i - 1], "RIGHT", spacing, 0)
        end
        M.set_slot_state(i, "empty", 0)
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
    frame:EnableMouse(enabled and true or false)
    if enabled then
        frame:SetAlpha(1)
        frame:Show()
    end
end
