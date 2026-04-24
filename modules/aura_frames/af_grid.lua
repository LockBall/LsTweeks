local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local GRID_SIZE   = 20   -- matches Blizzard Edit Mode grid spacing
local GRID_OFFSET_X = -1.5  -- shift grid center right (positive, no sign) or left (negative, -)
local GRID_OFFSET_Y = -0.5  -- shift grid center up (positive, no sign) or down (negative, -)

function M.build_grid_lines()
    local overlay = M.grid_overlay
    if not overlay then return end

    if M.grid_lines then
        for _, t in ipairs(M.grid_lines) do t:Hide() end
    end
    M.grid_lines = {}

    local w  = UIParent:GetWidth()
    local h  = UIParent:GetHeight()
    local ucx, ucy = UIParent:GetCenter()
    local cx = math.floor(ucx - UIParent:GetLeft() + 0.5) + GRID_OFFSET_X
    local cy = math.floor(UIParent:GetTop() - ucy + 0.5) - GRID_OFFSET_Y

    local lines = M.grid_lines
    local function make_vline(x, alpha)
        local t = overlay:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, alpha)
        t:SetSize(1, h)
        t:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
        lines[#lines + 1] = t
    end
    local function make_hline(y, alpha)
        local t = overlay:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, alpha)
        t:SetSize(w, 1)
        t:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, -y)
        lines[#lines + 1] = t
    end

    make_vline(cx, 0.25)
    make_hline(cy, 0.25)

    local step = GRID_SIZE
    while step <= math.max(cx, w - cx) + GRID_SIZE do
        make_vline(cx + step, 0.10)
        make_vline(cx - step, 0.10)
        step = step + GRID_SIZE
    end
    step = GRID_SIZE
    while step <= math.max(cy, h - cy) + GRID_SIZE do
        make_hline(cy + step, 0.10)
        make_hline(cy - step, 0.10)
        step = step + GRID_SIZE
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
    C_Timer.After(0, function()
        M.build_grid_lines()
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
