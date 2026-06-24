-- Shared utility functions used across all modules: addon.deep_copy_into() and addon.apply_defaults().
-- deep_copy_into() does a full recursive overwrite from a source table into a destination; apply_defaults() fills missing DB keys from a defaults table without overwriting existing values.
local addon_name, addon = ...

-- Use after table.wipe(dest) to restore a DB table from defaults.
function addon.deep_copy_into(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = {}
            addon.deep_copy_into(v, dest[k])
        else
            dest[k] = v
        end
    end
end

-- Recursive fill-missing copy: only writes keys that are absent in dest.
-- Use to apply defaults onto an existing DB without overwriting user values.
function addon.apply_defaults(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            addon.apply_defaults(v, dest[k])
        else
            if dest[k] == nil then dest[k] = v end
        end
    end
end

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
    placement.width = frame:GetWidth()
    addon.SetGridPoint(frame, parent, placement, cfg)
end
