-- Shared row/column layout helpers for settings panels.
local addon_name, addon = ...

function addon.GetGridOffset(placement, cfg)
    placement = placement or {}
    cfg = cfg or {}

    local column_width = cfg.column_width or cfg.slider_width or 0
    local col_step_x = cfg.col_step_x or (column_width + (cfg.column_gap_x or cfg.slider_gap_x or 0))
    local row_step_y = cfg.row_step_y or ((cfg.row_height or cfg.slider_row_height or 0) + (cfg.row_gap_y or cfg.slider_row_gap_y or 0))
    local center_offset = placement.center and placement.width and ((column_width - placement.width) / 2) or 0

    return (cfg.origin_x or cfg.title_offset_x or 0) + ((placement.col or 1) - 1) * col_step_x + center_offset + (placement.x or 0),
        (cfg.origin_y or cfg.title_offset_y or 0) - ((placement.row or 1) - 1) * row_step_y + (placement.y or 0)
end

function addon.SetGridPoint(frame, parent, placement, cfg)
    if not frame or not parent then return end
    local x, y = addon.GetGridOffset(placement, cfg)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

function addon.CenterGridControl(frame, parent, placement, cfg)
    if not frame or not parent or not placement then return end
    local centered_placement = {
        row = placement.row,
        col = placement.col,
        x = placement.x,
        y = placement.y,
        width = frame:GetWidth(),
        center = placement.center,
        align = placement.align,
    }
    addon.SetGridPoint(frame, parent, centered_placement, cfg)
end

local function get_settings_grid_y(grid, row)
    local y = grid.row_start
    for i = 1, (row - 1) do
        y = y - (grid.row_heights[i] or grid.row_heights[#grid.row_heights])
    end
    return y
end

local function place_settings_grid_control(grid, control, row, column, slot, place_opts)
    if not control then return end

    place_opts = place_opts or {}
    local align = place_opts.align or grid.col_align[column] or "left"
    local y = get_settings_grid_y(grid, row)
    if place_opts.valign == "bottom" then
        y = y - (grid.row_heights[row] or grid.row_heights[#grid.row_heights])
    end

    local y_offset = grid.offsets[slot or "default"] or 0
    if place_opts.y_offset then y_offset = y_offset + place_opts.y_offset end

    local width = place_opts.width or (control.GetWidth and control:GetWidth() or 0)
    local placement = {
        row = row,
        col = column,
        x = 0,
        y = y - grid.row_start + y_offset,
        width = width,
        center = align == "center",
    }
    if align == "right" then
        placement.x = (grid.col_width or 0) - width
    end

    addon.SetGridPoint(control, grid.parent, placement, {
        origin_x = grid.col_offset,
        origin_y = grid.row_start,
        column_width = grid.col_width,
        column_gap_x = grid.col_gap - grid.col_width,
        row_height = 0,
        row_gap_y = 0,
    })
end

local function get_placement_options(placement, place_opts)
    if not placement then return place_opts end

    local resolved_opts = {}
    if place_opts then
        for key, value in pairs(place_opts) do
            resolved_opts[key] = value
        end
    end
    if resolved_opts.align == nil then
        resolved_opts.align = placement.center and "center" or placement.align
    end
    if resolved_opts.y_offset == nil then
        resolved_opts.y_offset = placement.y
    end
    if resolved_opts.width == nil then
        resolved_opts.width = placement.width
    end

    return resolved_opts
end

local function get_center_options(control, place_opts)
    local resolved_opts = {}
    if place_opts then
        for key, value in pairs(place_opts) do
            resolved_opts[key] = value
        end
    end
    if resolved_opts.width == nil then
        resolved_opts.width = control:GetWidth()
    end

    return resolved_opts
end

local function place_settings_grid_placement(grid, control, placement, slot, place_opts)
    if not placement then return end
    grid:place_at(control, placement.row, placement.col, slot, get_placement_options(placement, place_opts))
end

local function center_settings_grid_control(grid, control, placement, slot, place_opts)
    if not control or not placement then return end
    grid:place(control, placement, slot, get_center_options(control, place_opts))
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

    line:SetPoint("TOPLEFT", parent, "TOPLEFT", grid.separator_left, y + math.floor(grid.row_gap / 2))
    if grid.separator_stretch then
        line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -grid.separator_right_pad, y + math.floor(grid.row_gap / 2))
    else
        line:SetWidth(grid[grid.column_count] + grid.col_width - grid.separator_left - grid.separator_right_pad)
    end
    return line
end

local function add_settings_grid_row_separators(grid, rows, mode)
    if not rows then return end
    mode = mode or "after"

    for _, row in ipairs(rows) do
        if mode == "before" then
            grid:add_row_separator(row - 1)
        else
            grid:add_row_separator(row)
        end
    end
end

function addon.CreateSettingsGrid(parent, opts)
    opts = opts or {}
    local col_gap = opts.col_gap or 150
    local col_width = opts.col_width or 190
    local col_offset = opts.col_offset or -20
    local row_gap = opts.row_gap or 20
    local column_count = opts.column_count or 4
    local grid = {
        parent = parent,
        column_count = column_count,
        col_gap = col_gap,
        col_width = col_width,
        col_offset = col_offset,
        col_align = opts.col_align or { "center", "center", "center", "center" },
        row_start = opts.row_start or 10,
        row_gap = row_gap,
        row_heights = opts.row_heights or { 115, 115, 115, 115, 115, 115 },
        reset_btn_width = opts.reset_btn_width or 110,
        offsets = opts.offsets or { default = 0, dropdown = 8, picker = 4 },
        content_rows = opts.content_rows or 6,
        separator_left = opts.separator_left or 0,
        separator_right_pad = opts.separator_right_pad or 12,
        separator_stretch = opts.separator_stretch or false,
    }

    for i = 1, column_count do
        grid[i] = ((i - 1) * col_gap) + col_offset
    end

    grid.place_at = place_settings_grid_control
    grid.place = place_settings_grid_placement
    grid.center = center_settings_grid_control
    grid.add_row_separator = add_settings_grid_row_separator
    grid.add_row_separators = add_settings_grid_row_separators

    if opts.row_separators then
        grid:add_row_separators(opts.row_separators, opts.row_separator_mode)
    end

    return grid
end
