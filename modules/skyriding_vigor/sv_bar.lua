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
local NODE_FRAME_ATLAS = "dragonriding_vigor_frame"
local NODE_BACKGROUND_ATLAS = "dragonriding_vigor_background"
local NODE_FILL_ATLAS = "dragonriding_vigor_fill"
local NODE_FILL_FULL_ATLAS = "dragonriding_vigor_fillfull"
local GRID_SIZE = 20

local SCALE_RANGE = { min = 0.5, max = 2, step = 0.05 }
local SPACING_RANGE = { min = 0, max = 25, step = 0.5 }
local FADE_ALPHA_RANGE = { min = 0.05, max = 1, step = 0.05 }
local POSITION_RANGE = { min = -1000, max = 1000, step = 1 }

local BACKGROUND_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_BACKGROUND_LAYER = true
local DRAW_BACKGROUND_IN_FRONT_OF_FRAME = false

local FILL_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_FILL_LAYER = true
local DRAW_FILL_IN_FRONT_OF_FRAME = false

local FRAME_LAYOUT = {
    scale_x = 1.00,
    scale_y = 1.00,
    offset_x = 0.00,
    offset_y = 0.00,
    visible_edge_inset_x = 11.00,
}
local SHOW_FRAME_LAYER = true

local WING_LAYOUT = {
    scale_x = 1,
    scale_y = 1,
    node_gap_x = -20.0,
    offset_y = -15.0,
}

M.MAX_SLOTS = MAX_SLOTS
M.SETTING_SPECS = {
    fade_alpha = FADE_ALPHA_RANGE,
    scale = SCALE_RANGE,
    spacing = SPACING_RANGE,
    x_position = POSITION_RANGE,
    y_position = POSITION_RANGE,
}
M.SLIDER_KEYS = { "fade_alpha", "spacing", "scale" }
M.LAYOUT_SETTING_KEYS = {
    scale = true,
    spacing = true,
}

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

local function get_atlas_size(atlas)
    if C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            return info.width, info.height
        end
    end
    error(addon_name .. ": missing atlas metadata for " .. tostring(atlas), 2)
end

local function get_node_size()
    if not M._node_width or not M._node_height then
        M._node_width, M._node_height = get_atlas_size(NODE_FRAME_ATLAS)
    end
    return M._node_width, M._node_height
end

local function get_fill_size()
    local width, height = get_node_size()
    return max(1, width * FILL_LAYOUT.scale_x), max(1, height * FILL_LAYOUT.scale_y)
end

local function get_background_size()
    local width, height = get_node_size()
    return max(1, width * BACKGROUND_LAYOUT.scale_x), max(1, height * BACKGROUND_LAYOUT.scale_y)
end

local function get_frame_size()
    local width, height = get_node_size()
    return max(1, width * FRAME_LAYOUT.scale_x), max(1, height * FRAME_LAYOUT.scale_y)
end

local function get_frame_left_in_slot(node_width, frame_width)
    return ((node_width - frame_width) / 2) + FRAME_LAYOUT.offset_x
end

local function get_frame_edge_inset_x(frame_width)
    return min(max(0, FRAME_LAYOUT.visible_edge_inset_x or 0), max(0, (frame_width - 1) / 2))
end

local function get_frame_edge_width(frame_width)
    local edge_inset_x = get_frame_edge_inset_x(frame_width)
    return max(1, frame_width - (edge_inset_x * 2))
end

local function get_spacing_pixels(db)
    local defaults = get_defaults()
    local default_spacing = defaults.spacing or 5
    local spacing_setting = db and db.spacing
    if spacing_setting == nil then
        spacing_setting = default_spacing
    end
    return spacing_setting
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

local function set_atlas_sized(texture, atlas, width, height)
    if not texture then return end
    texture:SetAtlas(atlas, false)
    texture:SetSize(width, height)
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function set_bar_atlas(slot, atlas)
    local fill_width, fill_height = get_fill_size()
    slot.bar:SetStatusBarTexture(atlas)
    local texture = slot.bar:GetStatusBarTexture()
    if texture then
        set_atlas_sized(texture, atlas, fill_width, fill_height)
    end
end

local function set_slot_progress(slot, progress)
    progress = max(0, min(progress or 0, 1))

    if slot._bar_texture ~= NODE_FILL_ATLAS then
        set_bar_atlas(slot, NODE_FILL_ATLAS)
        slot._bar_texture = NODE_FILL_ATLAS
    end
    slot.bar:SetValue(progress)
end

local function set_slot_fill_bounds(slot)
    if slot._fill_bounds_set then return end
    local fill_width, fill_height = get_fill_size()

    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetMinMaxValues(0, 1)
    slot._fill_bounds_set = true
end

local function create_slot(parent, index)
    local width, height = get_node_size()
    local fill_width, fill_height = get_fill_size()
    local bg_width, bg_height = get_background_size()
    local frame_width, frame_height = get_frame_size()
    local slot = CreateFrame("Frame", addon_name .. "SkyridingVigorSlot" .. index, parent)
    slot:SetSize(width, height)

    local base_level = slot:GetFrameLevel()
    local frame_level = base_level + 3
    local background_level = base_level + 1
    local fill_level = base_level + 2
    if DRAW_BACKGROUND_IN_FRONT_OF_FRAME then
        frame_level = base_level + 1
        background_level = base_level + 2
        fill_level = base_level + 3
    elseif DRAW_FILL_IN_FRONT_OF_FRAME then
        background_level = base_level + 1
        frame_level = base_level + 2
        fill_level = base_level + 3
    end

    slot.background_frame = CreateFrame("Frame", nil, slot)
    slot.background_frame:ClearAllPoints()
    slot.background_frame:SetAllPoints(slot)
    slot.background_frame:SetFrameLevel(background_level)

    slot.background = slot.background_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    slot.background:ClearAllPoints()
    slot.background:SetPoint("CENTER", slot, "CENTER", BACKGROUND_LAYOUT.offset_x, BACKGROUND_LAYOUT.offset_y)
    set_atlas_sized(slot.background, NODE_BACKGROUND_ATLAS, bg_width, bg_height)
    slot.background:SetShown(SHOW_BACKGROUND_LAYER)

    slot.bar = CreateFrame("StatusBar", nil, slot)
    slot.bar:SetOrientation("VERTICAL")
    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetFrameLevel(fill_level)
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(0)
    set_bar_atlas(slot, NODE_FILL_ATLAS)
    slot.bar:SetShown(SHOW_FILL_LAYER)
    slot._bar_texture = NODE_FILL_ATLAS
    slot._fill_bounds_set = true

    slot.cover_frame = CreateFrame("Frame", nil, slot)
    slot.cover_frame:ClearAllPoints()
    slot.cover_frame:SetAllPoints(slot)
    slot.cover_frame:SetFrameLevel(frame_level)

    slot.cover = slot.cover_frame:CreateTexture(nil, "OVERLAY", nil, 3)
    slot.cover:ClearAllPoints()
    slot.cover:SetPoint("CENTER", slot, "CENTER", FRAME_LAYOUT.offset_x, FRAME_LAYOUT.offset_y)
    slot.cover:SetDrawLayer("OVERLAY", 7)
    set_atlas_sized(slot.cover, NODE_FRAME_ATLAS, frame_width, frame_height)
    slot.cover:SetShown(SHOW_FRAME_LAYER)

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
        if slot._bar_texture ~= NODE_FILL_FULL_ATLAS then
            set_bar_atlas(slot, NODE_FILL_FULL_ATLAS)
            slot._bar_texture = NODE_FILL_FULL_ATLAS
        end
        slot.bar:SetValue(effective_progress)
    elseif state == "filling" then
        set_slot_progress(slot, effective_progress)
    else
        if slot._bar_texture ~= NODE_FILL_ATLAS then
            set_bar_atlas(slot, NODE_FILL_ATLAS)
            slot._bar_texture = NODE_FILL_ATLAS
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
    if M.decor_left_frame and M.decor_right_frame and M.decor_left and M.decor_right then return end

    M.decor_left_frame = CreateFrame("Frame", nil, parent)
    M.decor_right_frame = CreateFrame("Frame", nil, parent)

    M.decor_left = M.decor_left_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_left:SetAllPoints(M.decor_left_frame)
    M.decor_left:SetAtlas("dragonriding_vigor_decor", true)
    M.decor_left:SetTexCoord(1, 0, 0, 1)

    M.decor_right = M.decor_right_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_right:SetAllPoints(M.decor_right_frame)
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

    if values.node_gap_x ~= nil then WING_LAYOUT.node_gap_x = values.node_gap_x end
    if values.scale_x ~= nil then WING_LAYOUT.scale_x = values.scale_x end
    if values.scale_y ~= nil then WING_LAYOUT.scale_y = values.scale_y end
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
    local width, height = get_node_size()
    local frame_width, frame_height = get_frame_size()
    local decor_width = M.decor_left and M.decor_left:GetWidth() or 64
    local decor_height = M.decor_left and M.decor_left:GetHeight() or 64
    local wing_width = decor_width * WING_LAYOUT.scale_x
    local wing_height = decor_height * WING_LAYOUT.scale_y
    local frame_edge_inset_x = get_frame_edge_inset_x(frame_width)
    local frame_edge_width = get_frame_edge_width(frame_width)
    local nodes_width = (frame_edge_width * MAX_SLOTS) + (spacing * (MAX_SLOTS - 1))
    local first_frame_edge_x = wing_width + WING_LAYOUT.node_gap_x
    local frame_edge_left_in_slot = get_frame_left_in_slot(width, frame_width) + frame_edge_inset_x
    local first_slot_x = first_frame_edge_x - frame_edge_left_in_slot
    local node_step = frame_edge_width + spacing
    local right_decor_x = first_frame_edge_x + nodes_width + WING_LAYOUT.node_gap_x
    local total_width = right_decor_x + wing_width
    local total_height = max(height, frame_height, wing_height)
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
        .. first_slot_x .. ":" .. first_frame_edge_x .. ":" .. right_decor_x .. ":"
        .. node_step .. ":" .. frame_width .. ":" .. frame_height .. ":" .. frame_edge_width .. ":"
        .. frame_edge_inset_x .. ":" .. WING_LAYOUT.node_gap_x .. ":"
        .. WING_LAYOUT.scale_x .. ":" .. WING_LAYOUT.scale_y .. ":"
        .. WING_LAYOUT.offset_y
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
        slot:SetPoint("LEFT", visual_frame or frame, "LEFT", first_slot_x + (node_step * (i - 1)), 0)
    end

    if M.decor_left_frame and M.decor_right_frame and M.slots[1] and M.slots[MAX_SLOTS] then
        M.decor_left_frame:ClearAllPoints()
        M.decor_right_frame:ClearAllPoints()
        M.decor_left_frame:SetSize(wing_width, wing_height)
        M.decor_right_frame:SetSize(wing_width, wing_height)
        M.decor_left_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            wing_width / 2,
            WING_LAYOUT.offset_y
        )
        M.decor_right_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            right_decor_x + (wing_width / 2),
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
