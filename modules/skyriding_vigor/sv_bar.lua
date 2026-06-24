-- Visual bar implementation for the Skyriding Vigor module.
-- Frame construction, atlas sizing, positioning, layout, and slot rendering live here.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_Texture_GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local error = error
local tostring = tostring

--#region BAR LAYOUT DEFINITIONS ===============================================

local MAX_SLOTS = M.MAX_SLOTS or 6
local GRID_SIZE = 20

local BACKGROUND_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_BACKGROUND_LAYER = true

local FILL_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_FILL_LAYER = true

local SPARK_LAYOUT = {
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_SPARK_LAYER = true

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
}

--#endregion BAR LAYOUT DEFINITIONS ============================================

--#region SHARED ACCESSORS =====================================================

local function get_db()
    return M.get_db and M.get_db()
end

local function get_defaults()
    return M.DEFAULTS or {}
end

--#endregion SHARED ACCESSORS ==================================================

--#region POSITION HELPERS =====================================================

local function snap_value(value)
    return floor(((value or 0) / GRID_SIZE) + 0.5) * GRID_SIZE
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

--#endregion POSITION HELPERS ==================================================

--#region ATLAS SIZE HELPERS ===================================================

local function get_atlas_size(atlas)
    if C_Texture_GetAtlasInfo then
        local info = C_Texture_GetAtlasInfo(atlas)
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            return info.width, info.height
        end
    end
    error(addon_name .. ": missing atlas metadata for " .. tostring(atlas), 2)
end

local function get_node_size()
    local _, style = M.get_bar_style(get_db())
    local atlas = style.frame
    if M._node_size_atlas ~= atlas or not M._node_width or not M._node_height then
        M._node_width, M._node_height = get_atlas_size(atlas)
        M._node_size_atlas = atlas
    end
    return M._node_width, M._node_height
end

local function get_decor_size()
    local _, style = M.get_decor_style(get_db())
    local atlas = style.atlas
    if M._decor_size_atlas ~= atlas or not M._decor_width or not M._decor_height then
        M._decor_width, M._decor_height = get_atlas_size(atlas)
        M._decor_size_atlas = atlas
    end
    return M._decor_width, M._decor_height
end

local function get_fill_size()
    local width, height = get_node_size()
    return max(1, width * FILL_LAYOUT.scale_x), max(1, height * FILL_LAYOUT.scale_y)
end

local function get_background_size()
    local width, height = get_node_size()
    local _, style = M.get_bar_style(get_db())
    return max(1, width * (style.background_scale_x or BACKGROUND_LAYOUT.scale_x)),
        max(1, height * (style.background_scale_y or BACKGROUND_LAYOUT.scale_y))
end

local function get_frame_size()
    local width, height = get_node_size()
    return max(1, width * FRAME_LAYOUT.scale_x), max(1, height * FRAME_LAYOUT.scale_y)
end

local function get_frame_left_in_slot(node_width, frame_width)
    return ((node_width - frame_width) / 2) + FRAME_LAYOUT.offset_x
end

local function get_frame_edge_inset_x(frame_width)
    local _, style = M.get_bar_style(get_db())
    local inset = style.visible_edge_inset_x
    if inset == nil then
        inset = FRAME_LAYOUT.visible_edge_inset_x or 0
    end
    return min(max(0, inset), max(0, (frame_width - 1) / 2))
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
    local _, style = M.get_bar_style(db)
    return spacing_setting + (style.spacing_offset or 0)
end

--#endregion ATLAS SIZE HELPERS ================================================

--#region DRAG HELPERS =========================================================

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

--#endregion DRAG HELPERS ======================================================

--#region SLOT RENDERING =======================================================

local function set_atlas_sized(texture, atlas, width, height)
    if not texture then return end
    texture:SetAtlas(atlas, false)
    texture:SetSize(width, height)
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function apply_slot_static_atlases(slot)
    local db = get_db()
    local style_key, style = M.get_bar_style(db)
    local bg_width, bg_height = get_background_size()
    local frame_width, frame_height = get_frame_size()
    local frame_atlas = M.get_frame_atlas(db, style_key, style)

    if slot.background_frame and slot.cover_frame then
        if style.background_above_frame then
            slot.background_frame:SetFrameLevel(slot.cover_frame:GetFrameLevel() + 1)
        else
            slot.background_frame:SetFrameLevel(slot.cover_frame:GetFrameLevel() - 2)
        end
    end

    slot.background:ClearAllPoints()
    slot.background:SetPoint(
        "CENTER",
        slot,
        "CENTER",
        style.background_offset_x or BACKGROUND_LAYOUT.offset_x,
        style.background_offset_y or BACKGROUND_LAYOUT.offset_y
    )
    set_atlas_sized(slot.background, style.background, bg_width, bg_height)
    set_atlas_sized(slot.cover, frame_atlas, frame_width, frame_height)
    slot._static_style = style
    slot._frame_atlas = frame_atlas
end

local function set_bar_atlas(slot, atlas)
    local fill_width, fill_height = get_fill_size()
    slot.bar:SetStatusBarTexture(atlas)
    local texture = slot.bar:GetStatusBarTexture()
    local boost_texture
    if slot.fill_boost then
        slot.fill_boost:SetStatusBarTexture(atlas)
        boost_texture = slot.fill_boost:GetStatusBarTexture()
    end
    if texture then
        set_atlas_sized(texture, atlas, fill_width, fill_height)
        local color = M.get_style_fill_color_value(get_db())
        M.apply_fill_texture_color(texture, color)
        if boost_texture then
            set_atlas_sized(boost_texture, atlas, fill_width, fill_height)
            M.apply_fill_boost_texture_color(boost_texture, color)
            slot.fill_boost:SetShown(SHOW_FILL_LAYER and M.fill_color_is_custom(color) and M.get_style_fill_add_alpha() > 0)
        end
    end
end

local function set_spark_atlas(slot, atlas)
    if not slot or not slot.spark or not atlas then return end

    local fill_width, fill_height = get_fill_size()
    local atlas_width, atlas_height = get_atlas_size(atlas)
    local spark_size = M.get_spark_size and M.get_spark_size(get_db()) or 1
    local spark_height = max(1, min(fill_height * 2, atlas_height * (fill_width / max(1, atlas_width)) * spark_size))

    slot.spark:SetAtlas(atlas, false)
    slot.spark:SetSize(fill_width, spark_height)
    slot.spark:SetBlendMode("ADD")
    local color = M.get_spark_color and M.get_spark_color(get_db()) or { r = 1, g = 1, b = 1, a = 1 }
    slot.spark:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    slot._spark_atlas = atlas
end

local function set_slot_spark_clip_bounds(slot)
    if not slot or not slot.spark_frame then return end
    if slot._spark_clip_bounds_set then return end

    local fill_width, fill_height = get_fill_size()
    local _, style = M.get_bar_style(get_db())
    local frame_width = get_frame_size()
    local inset_x = max(0, style.spark_clip_inset_x or 0)
    local inset_y = max(0, style.spark_clip_inset_y or 0)
    slot.spark_frame:ClearAllPoints()
    slot.spark_frame:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.spark_frame:SetSize(
        max(1, min(fill_width, get_frame_edge_width(frame_width)) - (inset_x * 2)),
        max(1, fill_height - (inset_y * 2))
    )
    slot._spark_clip_bounds_set = true
end

local function update_slot_spark(slot, state, progress, style_key, style)
    if not slot or not slot.spark then return end

    local db = get_db()
    local spark_atlas = M.get_spark_atlas and M.get_spark_atlas(db, style_key, style)
    local show_spark = SHOW_SPARK_LAYER and db and db.show_spark and state == "filling"
        and progress and progress > 0 and progress < 1 and spark_atlas
    if not show_spark then
        slot.spark:Hide()
        slot._spark_shown = false
        return
    end

    set_slot_spark_clip_bounds(slot)
    if slot._spark_atlas ~= spark_atlas or not slot._spark_bounds_set then
        set_spark_atlas(slot, spark_atlas)
        slot._spark_bounds_set = true
    else
        local color = M.get_spark_color and M.get_spark_color(db) or { r = 1, g = 1, b = 1, a = 1 }
        slot.spark:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end

    local _, fill_height = get_fill_size()
    local spark_x = style.spark_offset_x or SPARK_LAYOUT.offset_x
    local spark_y = FILL_LAYOUT.offset_y - (fill_height / 2) + (fill_height * progress)
        + (style.spark_offset_y or SPARK_LAYOUT.offset_y)
    slot.spark:ClearAllPoints()
    slot.spark:SetPoint("CENTER", slot.spark_frame, "CENTER", spark_x, spark_y - FILL_LAYOUT.offset_y)
    slot.spark:Show()
    slot._spark_shown = true
end

function M.apply_spark_settings()
    for i = 1, MAX_SLOTS do
        local slot = M.slots[i]
        if slot then
            slot._spark_bounds_set = false
            slot._spark_enabled = nil
        end
    end
    if M.refresh then
        M.refresh()
    end
end

function M.apply_fill_color()
    local color = M.get_style_fill_color_value(get_db())
    for i = 1, MAX_SLOTS do
        local slot = M.slots[i]
        local texture = slot and slot.bar and slot.bar:GetStatusBarTexture()
        if texture then
            M.apply_fill_texture_color(texture, color)
        end
        local boost_texture = slot and slot.fill_boost and slot.fill_boost:GetStatusBarTexture()
        if boost_texture then
            M.apply_fill_boost_texture_color(boost_texture, color)
            slot.fill_boost:SetShown(SHOW_FILL_LAYER and M.fill_color_is_custom(color) and M.get_style_fill_add_alpha() > 0)
        end
    end
end

function M.update_filling_slot_progress(index, progress)
    local slot = M.slots[index]
    if not slot then return end

    progress = max(0, min(progress or 0, 1))
    if slot._state ~= "filling" then
        M.set_slot_state(index, "filling", progress)
        return
    end

    if abs((slot._progress or -1) - progress) < 0.0001 then
        return
    end

    slot.bar:SetValue(progress)
    if slot.fill_boost then
        slot.fill_boost:SetValue(progress)
    end

    local db = get_db()
    local style_key, style = M.get_bar_style(db)
    update_slot_spark(slot, "filling", progress, style_key, style)
    slot._progress = progress
end

local function set_slot_progress(slot, progress)
    progress = max(0, min(progress or 0, 1))

    local _, style = M.get_bar_style(get_db())
    if slot._bar_texture ~= style.fill then
        set_bar_atlas(slot, style.fill)
        slot._bar_texture = style.fill
    end
    slot.bar:SetValue(progress)
    if slot.fill_boost then
        slot.fill_boost:SetValue(progress)
    end
end

local function set_slot_fill_bounds(slot)
    if slot._fill_bounds_set then return end
    local fill_width, fill_height = get_fill_size()

    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetMinMaxValues(0, 1)
    if slot.fill_boost then
        slot.fill_boost:ClearAllPoints()
        slot.fill_boost:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
        slot.fill_boost:SetSize(fill_width, fill_height)
        slot.fill_boost:SetMinMaxValues(0, 1)
    end
    if slot.spark then
        slot._spark_bounds_set = false
        slot._spark_clip_bounds_set = false
    end
    slot._fill_bounds_set = true
end

local function create_slot(parent, index)
    local width, height = get_node_size()
    local fill_width, fill_height = get_fill_size()
    local slot = CreateFrame("Frame", addon_name .. "SkyridingVigorSlot" .. index, parent)
    slot:SetSize(width, height)

    local base_level = slot:GetFrameLevel()
    local background_level = base_level + 1
    local fill_level = base_level + 2
    local spark_level = base_level + 3
    local frame_level = base_level + 4

    slot.background_frame = CreateFrame("Frame", nil, slot)
    slot.background_frame:ClearAllPoints()
    slot.background_frame:SetAllPoints(slot)
    slot.background_frame:SetFrameLevel(background_level)

    slot.background = slot.background_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    slot.background:ClearAllPoints()
    slot.background:SetPoint("CENTER", slot, "CENTER", BACKGROUND_LAYOUT.offset_x, BACKGROUND_LAYOUT.offset_y)
    slot.background:SetShown(SHOW_BACKGROUND_LAYER)

    slot.bar = CreateFrame("StatusBar", nil, slot)
    slot.bar:SetOrientation("VERTICAL")
    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetFrameLevel(fill_level)
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(0)
    slot.bar:SetShown(SHOW_FILL_LAYER)
    slot._fill_bounds_set = true

    slot.fill_boost = CreateFrame("StatusBar", nil, slot)
    slot.fill_boost:SetOrientation("VERTICAL")
    slot.fill_boost:ClearAllPoints()
    slot.fill_boost:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.fill_boost:SetSize(fill_width, fill_height)
    slot.fill_boost:SetFrameLevel(fill_level)
    slot.fill_boost:SetMinMaxValues(0, 1)
    slot.fill_boost:SetValue(0)
    slot.fill_boost:Hide()

    slot.spark_frame = CreateFrame("Frame", nil, slot)
    slot.spark_frame:ClearAllPoints()
    slot.spark_frame:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    local _, style = M.get_bar_style(get_db())
    local frame_width = get_frame_size()
    local inset_x = max(0, style.spark_clip_inset_x or 0)
    local inset_y = max(0, style.spark_clip_inset_y or 0)
    slot.spark_frame:SetSize(
        max(1, min(fill_width, get_frame_edge_width(frame_width)) - (inset_x * 2)),
        max(1, fill_height - (inset_y * 2))
    )
    slot.spark_frame:SetFrameLevel(spark_level)
    if slot.spark_frame.SetClipsChildren then
        slot.spark_frame:SetClipsChildren(true)
    end

    slot.spark = slot.spark_frame:CreateTexture(nil, "OVERLAY", nil, 2)
    slot.spark:ClearAllPoints()
    slot.spark:SetPoint("CENTER", slot.spark_frame, "CENTER", 0, 0)
    slot.spark:Hide()

    slot.cover_frame = CreateFrame("Frame", nil, slot)
    slot.cover_frame:ClearAllPoints()
    slot.cover_frame:SetAllPoints(slot)
    slot.cover_frame:SetFrameLevel(frame_level)

    slot.cover = slot.cover_frame:CreateTexture(nil, "OVERLAY", nil, 3)
    slot.cover:ClearAllPoints()
    slot.cover:SetPoint("CENTER", slot, "CENTER", FRAME_LAYOUT.offset_x, FRAME_LAYOUT.offset_y)
    slot.cover:SetDrawLayer("OVERLAY", 7)
    slot.cover:SetShown(SHOW_FRAME_LAYER)
    apply_slot_static_atlases(slot)
    local _, style = M.get_bar_style(get_db())
    set_bar_atlas(slot, style.fill)
    slot._bar_texture = style.fill

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

    local db = get_db()
    local style_key, style = M.get_bar_style(db)
    local frame_atlas = M.get_frame_atlas(db, style_key, style)
    local spark_atlas = M.get_spark_atlas and M.get_spark_atlas(db, style_key, style)
    local show_spark = db and db.show_spark and state == "filling" and effective_progress > 0
        and effective_progress < 1 and spark_atlas
    if slot._state == state and slot._static_style == style and slot._frame_atlas == frame_atlas
        and slot._spark_enabled == show_spark and (not show_spark or slot._spark_atlas == spark_atlas)
        and abs((slot._progress or -1) - effective_progress) < 0.0001
    then
        update_slot_spark(slot, state, effective_progress, style_key, style)
        return
    end

    if slot._static_style ~= style or slot._frame_atlas ~= frame_atlas then
        apply_slot_static_atlases(slot)
        slot._bar_texture = nil
        slot._fill_bounds_set = false
        slot._spark_bounds_set = false
        slot._spark_clip_bounds_set = false
    end

    set_slot_fill_bounds(slot)
    if state == "full" then
        if slot._bar_texture ~= style.fill_full then
            set_bar_atlas(slot, style.fill_full)
            slot._bar_texture = style.fill_full
        end
        slot.bar:SetValue(effective_progress)
        slot.fill_boost:SetValue(effective_progress)
    elseif state == "filling" then
        set_slot_progress(slot, effective_progress)
    else
        if slot._bar_texture ~= style.fill then
            set_bar_atlas(slot, style.fill)
            slot._bar_texture = style.fill
        end
        slot.bar:SetValue(effective_progress)
        slot.fill_boost:SetValue(effective_progress)
    end
    update_slot_spark(slot, state, effective_progress, style_key, style)
    slot._state = state
    slot._progress = effective_progress
    slot._spark_enabled = show_spark
end

--#endregion SLOT RENDERING ====================================================

--#region FRAME AND SLOT API ===================================================

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
    M.decor_left:SetTexCoord(1, 0, 0, 1)

    M.decor_right = M.decor_right_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_right:SetAllPoints(M.decor_right_frame)
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
        if self._is_dragging then return end
        self._is_dragging = true
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
        self._is_dragging = false
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
    M.apply_fill_color()

    M.apply_position()
    return frame
end

--#endregion FRAME AND SLOT API ================================================

--#region LAYOUT ===============================================================

function M.set_wing_layout(values)
    if not values then return end

    if values.scale_x ~= nil then WING_LAYOUT.scale_x = values.scale_x end
    if values.scale_y ~= nil then WING_LAYOUT.scale_y = values.scale_y end

    M.invalidate_layout()
    if M.frame and M.refresh then
        M.refresh()
    end
end

function M.invalidate_layout()
    M._layout_signature = nil
    M._layout_dirty = true
end

function M.apply_layout()
    if not M._layout_dirty and M._layout_signature then
        return
    end

    local db = get_db()
    local frame = M.ensure_frame()
    if not db or not frame then return end

    local defaults = get_defaults()
    local spacing = get_spacing_pixels(db)
    local style_key = M.get_bar_style(db)
    local scale = M.get_style_layout_number(db, style_key, "scale") or defaults.scale or 1
    local width, height = get_node_size()
    local frame_width, frame_height = get_frame_size()
    local decor_style_key, decor_style = M.get_decor_style(db)
    local decor_disabled = decor_style and decor_style.disabled
    local decor_width, decor_height = get_decor_size()
    local decor_color = M.get_decor_color()
    local decor_atlas = M.get_decor_atlas(db, decor_style_key, decor_style)
    local decor_scale = M.get_decor_layout_number(db, decor_style_key, "scale") or 1
    local wing_scale_x = decor_scale * (decor_style.scale_x or WING_LAYOUT.scale_x)
    local wing_scale_y = decor_scale * (decor_style.scale_y or WING_LAYOUT.scale_y)
    local wing_node_gap_x = M.get_decor_layout_number(db, decor_style_key, "decor_node_gap_x")
    if wing_node_gap_x == nil then wing_node_gap_x = 0 end
    local wing_offset_y = M.get_decor_layout_number(db, decor_style_key, "offset_y")
    if wing_offset_y == nil then wing_offset_y = 0 end
    local wing_width = decor_width * wing_scale_x
    local wing_height = decor_height * wing_scale_y
    local frame_edge_inset_x = get_frame_edge_inset_x(frame_width)
    local frame_edge_width = get_frame_edge_width(frame_width)
    local nodes_width = (frame_edge_width * MAX_SLOTS) + (spacing * (MAX_SLOTS - 1))
    local first_frame_edge_x = wing_width + wing_node_gap_x
    local frame_edge_left_in_slot = get_frame_left_in_slot(width, frame_width) + frame_edge_inset_x
    local first_slot_x = first_frame_edge_x - frame_edge_left_in_slot
    local node_step = frame_edge_width + spacing
    local right_decor_x = first_frame_edge_x + nodes_width + wing_node_gap_x
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

    local node_color = M.get_node_color()
    local layout_signature = spacing .. ":" .. scale .. ":" .. total_width .. ":" .. total_height .. ":"
        .. first_slot_x .. ":" .. first_frame_edge_x .. ":" .. right_decor_x .. ":"
        .. node_step .. ":" .. frame_width .. ":" .. frame_height .. ":" .. frame_edge_width .. ":"
        .. frame_edge_inset_x .. ":" .. wing_node_gap_x .. ":"
        .. wing_scale_x .. ":" .. wing_scale_y .. ":"
        .. wing_offset_y .. ":" .. style_key .. ":" .. node_color .. ":" .. decor_style_key .. ":" .. decor_color
    if M._layout_signature == layout_signature then
        M._layout_dirty = false
        return
    end
    M._layout_signature = layout_signature
    M._layout_dirty = false

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
        M.decor_left_frame:Show()
        M.decor_right_frame:Show()
        M.decor_left_frame:SetAlpha(decor_disabled and 0 or 1)
        M.decor_right_frame:SetAlpha(decor_disabled and 0 or 1)
        if M.decor_left and M._decor_left_atlas ~= decor_atlas then
            M.decor_left:SetAtlas(decor_atlas, false)
            M._decor_left_atlas = decor_atlas
        end
        if M.decor_right and M._decor_right_atlas ~= decor_atlas then
            M.decor_right:SetAtlas(decor_atlas, false)
            M._decor_right_atlas = decor_atlas
        end
        M.decor_left_frame:ClearAllPoints()
        M.decor_right_frame:ClearAllPoints()
        M.decor_left_frame:SetSize(wing_width, wing_height)
        M.decor_right_frame:SetSize(wing_width, wing_height)
        M.decor_left_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            wing_width / 2,
            wing_offset_y
        )
        M.decor_right_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            right_decor_x + (wing_width / 2),
            wing_offset_y
        )
    end
end

--#endregion LAYOUT ============================================================

--#region INTERACTION STATE ====================================================

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

--#endregion INTERACTION STATE =================================================
