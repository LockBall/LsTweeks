-- Aura Frames settings grid helper.
-- Owns the shared row/column placement used by preset and custom frame panels.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function place_settings_grid_control(grid, control, row, column, slot, place_opts)
    if not control then return end
    place_opts = place_opts or {}
    local align = place_opts.align or grid.col_align[column] or "left"
    local x = grid[column]
    local y = grid.row_start
    for i = 1, (row - 1) do
        y = y - (grid.row_heights[i] or grid.row_heights[#grid.row_heights])
    end
    if place_opts.valign == "bottom" then
        y = y - (grid.row_heights[row] or grid.row_heights[#grid.row_heights])
    end
    local y_offset = grid.offsets[slot or "default"] or 0
    if place_opts.y_offset then y_offset = y_offset + place_opts.y_offset end
    local width = place_opts.width or (control.GetWidth and control:GetWidth() or 0)
    if align == "center" then
        x = x + math.floor((grid.col_width - width) / 2)
    elseif align == "right" then
        x = x + grid.col_width - width
    end
    control:SetPoint("TOPLEFT", grid.parent, "TOPLEFT", x, y + y_offset)
end

local function add_settings_grid_row_separator(grid, row)
    local parent = grid.parent
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(2)
    local y = grid.row_start
    for i = 1, row do
        y = y - (grid.row_heights[i] or grid.row_heights[#grid.row_heights])
    end
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y + math.floor(grid.row_gap / 2))
    line:SetWidth(grid[4] + grid.col_width - 12)
end

function M.create_settings_grid(parent, opts)
    opts = opts or {}
    local col_gap    = opts.col_gap or 150
    local col_width  = opts.col_width or 190
    local col_offset = opts.col_offset or -20
    local row_gap    = opts.row_gap or 20
    local grid = {
        [1] = col_offset,
        [2] = col_gap + col_offset,
        [3] = col_gap * 2 + col_offset,
        [4] = col_gap * 3 + col_offset,
        parent = parent,
        col_width = col_width,
        col_align = opts.col_align or { "center", "center", "center", "center" },
        row_start = opts.row_start or 10,
        row_gap = row_gap,
        row_heights = opts.row_heights or { 115, 105, 115, 90, 250 },
        reset_btn_width = opts.reset_btn_width or 110,
        offsets = opts.offsets or { default = 0, dropdown = 8, picker = 4 },
        content_rows = opts.content_rows or 5,
    }

    grid.place_at = place_settings_grid_control
    grid.add_row_separator = add_settings_grid_row_separator

    return grid
end
