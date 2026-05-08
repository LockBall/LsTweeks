-- Screen snap-grid system for aura frame positioning.
-- Draws the optional screen overlay and snaps frame coordinates to grid lines or flush screen edges.

local _, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames
local UPDATE_INTERVALS = M.UPDATE_INTERVALS

local GRID_SIZE     = 20    -- matches Blizzard Edit Mode grid spacing
local GRID_OFFSET_X = -1.5  -- right (positive, no + sign) or left (negative)
local GRID_OFFSET_Y = -0.5  -- up (positive, no + sign) or down (negative)
local EDGE_SNAP_TOLERANCE = 2

local function build_grid_lines()
    local overlay = M.grid_overlay
    if not overlay then return end

    local w   = UIParent:GetWidth()
    local h   = UIParent:GetHeight()
    local ucx, ucy = UIParent:GetCenter()
    local cx  = math.floor(ucx - UIParent:GetLeft() + 0.5) + GRID_OFFSET_X
    local cy  = math.floor(UIParent:GetTop() - ucy  + 0.5) - GRID_OFFSET_Y

    -- build flat list of line specs
    local specs = {}
    local function vspec(x, a) specs[#specs+1] = { v=true,  pos=x, alpha=a } end
    local function hspec(y, a) specs[#specs+1] = { v=false, pos=y, alpha=a } end

    vspec(cx, 0.25)
    hspec(cy, 0.25)
    local step = GRID_SIZE
    while step <= math.max(cx, w - cx) + GRID_SIZE do
        vspec(cx + step, 0.10)
        vspec(cx - step, 0.10)
        step = step + GRID_SIZE
    end
    step = GRID_SIZE
    while step <= math.max(cy, h - cy) + GRID_SIZE do
        hspec(cy + step, 0.10)
        hspec(cy - step, 0.10)
        step = step + GRID_SIZE
    end

    -- Reuse pooled textures; only allocate when pool is exhausted.
    -- WoW cannot destroy textures, so the pool grows to the high-water mark
    -- and stabilises there — no unbounded accumulation across rebuilds.
    M.grid_lines = M.grid_lines or {}
    local pool = M.grid_lines
    for i, s in ipairs(specs) do
        local t = pool[i]
        if not t then
            t = overlay:CreateTexture(nil, "BACKGROUND")
            pool[i] = t
        else
            t:ClearAllPoints()
        end
        t:SetColorTexture(1, 1, 1, s.alpha)
        if s.v then
            t:SetSize(1, h)
            t:SetPoint("TOPLEFT", overlay, "TOPLEFT", s.pos, 0)
        else
            t:SetSize(w, 1)
            t:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, -s.pos)
        end
        t:Show()
    end
    -- hide pool entries beyond what this layout needs
    for i = #specs + 1, #pool do
        pool[i]:Hide()
    end
end

function M.create_grid_overlay()
    if M.grid_overlay then return end
    local overlay = CreateFrame("Frame", "LsTweaksGridOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("BACKGROUND")
    overlay:SetFrameLevel(0)
    overlay:Hide()
    M.grid_overlay = overlay
    C_Timer.After(UPDATE_INTERVALS.next_frame, function()
        build_grid_lines()
        if M.db and M.db.show_grid then overlay:Show() end
    end)
end

function M.set_grid_visible(show)
    if not M.grid_overlay then M.create_grid_overlay() end
    if show then M.grid_overlay:Show() else M.grid_overlay:Hide() end
end

-- snap a coordinate to the nearest grid line (respects offset)
function M.snap_to_grid(v, is_y)
    local offset = is_y and GRID_OFFSET_Y or GRID_OFFSET_X
    return math.floor((v - offset) / GRID_SIZE + 0.5) * GRID_SIZE + offset
end

local function get_frame_parent_scale_ratio(frame)
    local parent_scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frame_scale  = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or frame and frame:GetScale() or 1
    if parent_scale == 0 then parent_scale = 1 end
    return frame_scale / parent_scale
end

local function snap_edge_or_grid(v, min_edge, max_edge, is_y)
    if math.abs(v - min_edge) <= EDGE_SNAP_TOLERANCE then return min_edge end
    if math.abs(v - max_edge) <= EDGE_SNAP_TOLERANCE then return max_edge end
    return M.snap_to_grid(v, is_y)
end

function M.snap_frame_position(pos, frame)
    if not pos then return nil, nil end
    if not frame then
        return M.snap_to_grid(pos.x or 0, false), M.snap_to_grid(pos.y or 0, true)
    end

    local scale = get_frame_parent_scale_ratio(frame)
    local ucx, ucy = UIParent:GetCenter()
    local parent_width = UIParent:GetWidth()
    local frame_width  = (frame.GetWidth and frame:GetWidth() or 0) * scale
    local frame_height = (frame.GetHeight and frame:GetHeight() or 0) * scale

    local left_edge   = -ucx
    local right_edge  = parent_width - frame_width - ucx
    local bottom_edge = frame_height - ucy
    local top_edge    = ucy

    local x = snap_edge_or_grid(pos.x or 0, left_edge, right_edge, false)
    local y = snap_edge_or_grid(pos.y or 0, bottom_edge, top_edge, true)
    return x, y
end
