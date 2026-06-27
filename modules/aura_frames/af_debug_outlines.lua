-- Debug helper that draws 1px border outlines on aura icon slot frames to visualize layout boundaries.
-- refresh_section_outlines() reads M.db.show_bar_section_outlines and adds or removes outlines accordingly; outlines are tagged ._is_outline for safe cleanup.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...
local M = addon.aura_frames

local function is_outline_enabled()
    return M.db and M.db.show_bar_section_outlines
end

local OUTLINE_DEFS = {
    { points = { {"TOPLEFT", 0, 0}, {"TOPRIGHT", 0, 0} }, size = { "Height", 1 } },
    { points = { {"BOTTOMLEFT", 0, 0}, {"BOTTOMRIGHT", 0, 0} }, size = { "Height", 1 } },
    { points = { {"TOPLEFT", 0, 0}, {"BOTTOMLEFT", 0, 0} }, size = { "Width", 1 } },
    { points = { {"TOPRIGHT", 0, 0}, {"BOTTOMRIGHT", 0, 0} }, size = { "Width", 1 } },
}

local function remove_debug_outlines(frame)
    if not frame then return end
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region._is_outline then
            region:Hide()
            region:SetTexture(nil)
        end
    end
end

local function add_debug_outline(frame, r, g, b, a)
    if not is_outline_enabled() or not frame then return end
    remove_debug_outlines(frame)
    for _, def in ipairs(OUTLINE_DEFS) do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(r, g, b, a)
        tex:SetPoint(def.points[1][1], frame, def.points[1][1], def.points[1][2], def.points[1][3])
        tex:SetPoint(def.points[2][1], frame, def.points[2][1], def.points[2][2], def.points[2][3])
        tex["Set"..def.size[1]](tex, def.size[2])
        tex._is_outline = true
    end
    M._debug_outlines_active = true
end

function M.add_debug_outline(frame, r, g, b, a)
    add_debug_outline(frame, r, g, b, a)
end

function M.refresh_section_outlines()
    local enabled = is_outline_enabled()
    if not enabled and not M._debug_outlines_active then
        return
    end

    local frames_list = M.frames_list
    if not frames_list then return end
    for frame_index = 1, #frames_list do
        local frame = frames_list[frame_index]
        if frame and frame.icons then
            for _, obj in ipairs(frame.icons) do
                if enabled then
                    add_debug_outline(obj.stack_slot, 1, 0.4, 0, 0.9)
                    add_debug_outline(obj.name_slot, 0, 0.6, 1, 0.9)
                    add_debug_outline(obj.timer_slot, 0, 1, 0.3, 0.9)
                else
                    remove_debug_outlines(obj.stack_slot)
                    remove_debug_outlines(obj.name_slot)
                    remove_debug_outlines(obj.timer_slot)
                end
            end
        end
    end

    M._debug_outlines_active = enabled == true
end

--#endregion FILE CONTENTS ===================================================
