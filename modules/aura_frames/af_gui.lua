-- Settings UI for the Aura Frames module, registered as a sidebar category in the main window.
-- BuildSettings() creates three tabs:
-- 1) General (global toggles and thresholds)
-- 2) Frames (a tree sidebar listing preset, CDM-backed, and custom frames with settings grids).
-- 3) Profiles (save/load complete Aura Frames setups across characters).


--#region FILE CONTENTS ======================================================


local addon_name, addon = ...

-- Ensure the unified module table is used
addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function build_profiles_tab(parent)
    M.refresh_profiles_tab = addon.BuildProfilesTab(parent, M.profile_manager, {
        label = "Aura Frames",
        note = "Profiles save the complete Aura Frames setup for use on another character.",
    })
end

local function build_frames_data()
    -- Category controls are derived from FRAME_DEFS so GUI labels, DB keys,
    -- runtime frame creation, and CDM metadata stay in one place.
    local function make_cat(frame_def)
        local keys = M.get_preset_keys(frame_def.key)
        return {
            name        = frame_def.label,
            show_key    = keys.show_key,
            move_key    = keys.move_key,
            timer_key   = keys.timer_key,
            bg_key      = keys.bg_key,
            scale_key   = keys.scale_key,
            spacing_key = keys.spacing_key,
            is_debuff   = frame_def.is_debuff,
        }
    end

    local frame_defs_for_tree = {}
    for _, frame_def in ipairs(M.FRAME_DEFS) do
        frame_defs_for_tree[#frame_defs_for_tree + 1] = frame_def
    end
    table.sort(frame_defs_for_tree, function(a, b)
        return (a.tree_order or 0) < (b.tree_order or 0)
    end)

    local frames_data = {}
    for _, frame_def in ipairs(frame_defs_for_tree) do
        frames_data[#frames_data + 1] = make_cat(frame_def)
    end
    return frames_data
end

local function build_tab_panel(parent, context, data, index)
    local tabs = context.tabs
    local panels = context.panels
    local tab = CreateFrame("Button", addon_name.."Tab"..index, parent, "PanelTabButtonTemplate")
    tab:SetText(data.name)
    tab:SetID(index)
    tab:SetScript("OnClick", function(self)
        for j, p in ipairs(panels) do
            p:SetShown(j == self:GetID())
            if j == self:GetID() then
                PanelTemplates_SelectTab(tabs[j])
            else
                PanelTemplates_DeselectTab(tabs[j])
            end
        end
        if M.db then M.db.last_tab_index = self:GetID() end
    end)
    tab:SetPoint(
        index == 1 and "TOPLEFT" or "LEFT",
        index == 1 and parent or tabs[index - 1],
        index == 1 and "TOPLEFT" or "RIGHT",
        index == 1 and 10 or 5,
        index == 1 and -12 or 0
    )
    PanelTemplates_TabResize(tab, 0)

    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -78)
    p:SetSize(741, context.panel_height) -- width: 925 frame - 12 B.l - 140 sidebar - 12 B.r - 20 margin
    p:Hide()

    if data.is_general then
        M.build_general_tab(p)
    elseif data.is_frames then
        M.build_frames_tab(p, context.frames_data)
    elseif data.is_profiles then
        build_profiles_tab(p)
    end

    tabs[index], panels[index] = tab, p
end

-- tabs settings controls
function M.BuildSettings(parent)
    local tabs, panels = {}, {}
    local main_content_height
    if addon.main_frame and addon.main_frame.GetContentAreaSize then
        local _, height = addon.main_frame:GetContentAreaSize()
        main_content_height = height
    end
    local panel_height = math.max(50, (main_content_height or parent:GetHeight() or 0) - 78)
    local context = {
        tabs = tabs,
        panels = panels,
        panel_height = panel_height,
        frames_data = build_frames_data(),
    }

    local tab_data = {
        { name = "General", is_general  = true },
        { name = "Frames",  is_frames   = true },
        { name = "Profiles", is_profiles = true },
    }

    for i, data in ipairs(tab_data) do
        build_tab_panel(parent, context, data, i)
    end

    PanelTemplates_SetNumTabs(parent, #tab_data)
    local restore_tab = math.min((M.db and M.db.last_tab_index) or 1, #tab_data)
    for i = 1, #tab_data do
        if i == restore_tab then
            panels[i]:Show()
            PanelTemplates_SelectTab(tabs[i])
        else
            panels[i]:Hide()
            PanelTemplates_DeselectTab(tabs[i])
        end
    end
    PanelTemplates_UpdateTabs(parent)
end

-- Sync GUI control states from DB (used after reset flows).
function M.sync_general_controls_from_db()
    if not M.controls or not M.db then return end

    local function set_checked(control_key, value)
        local control = M.controls[control_key]
        if control and control.SetCheckedSilently then
            control:SetCheckedSilently(value == true)
        end
    end

    set_checked("enable_blizz_buffs", M.db.enable_blizz_buffs)
    set_checked("enable_blizz_debuffs", M.db.enable_blizz_debuffs)
    set_checked("snap_to_grid_checkbox", M.db.snap_to_grid)
    set_checked("show_grid_checkbox", M.db.show_grid)

    local cancel_modifier = M.controls.cancel_modifier_dropdown
    if cancel_modifier and cancel_modifier.SetValue then
        local value = M.db.cancel_modifier
        if value ~= "OFF" and value ~= "CTRL" and value ~= "ALT" and value ~= "SHIFT" then
            value = M.defaults.cancel_modifier or "CTRL"
        end
        cancel_modifier:SetValue(value)
    end

    local visible_icon_tick = M.controls.aura_visible_icon_tick_slider
    if visible_icon_tick and visible_icon_tick.SetValueSilently then
        visible_icon_tick:SetValueSilently(M.get_visible_icon_tick_interval and M.get_visible_icon_tick_interval()
            or M.db.aura_visible_icon_tick
            or M.defaults.aura_visible_icon_tick)
    end

    for _, cat in ipairs(M.CATEGORIES or {}) do
        local keys = {
            "show_" .. cat,
            "move_" .. cat,
            "timer_" .. cat,
            "timer_swipe_" .. cat,
            "tooltip_" .. cat,
            "bg_" .. cat,
            "bar_mode_" .. cat,
            "test_aura_" .. cat,
            "cooldown_mode_" .. cat,
            "hide_blizz_cdm_" .. cat,
        }
        for _, key in ipairs(keys) do
            if M.db[key] ~= nil then
                set_checked(key, M.db[key])
            end
        end
        local refresh_timer_swipe = M.controls["timer_swipe_refresh_timer_swipe_" .. cat]
        if refresh_timer_swipe then
            refresh_timer_swipe()
        end
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        local font_dropdown = M.controls["timer_number_font_dropdown_"..cat]
        if font_dropdown and font_dropdown.SetValue then
            font_dropdown:SetValue(M.db["timer_number_font_"..cat] or M.db.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY)
        end

        local font_size_slider = M.controls["timer_number_font_size_slider_"..cat]
        if font_size_slider and font_size_slider.SetValueSilently then
            font_size_slider:SetValueSilently(M.db["timer_number_font_size_"..cat] or M.defaults["timer_number_font_size_"..cat] or M.DEFAULT_TIMER_NUMBER_FONT_SIZE)
        end
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        set_checked("timer_number_font_bold_"..cat, M.db["timer_number_font_bold_"..cat])
    end

    set_checked("show_bar_section_outlines_checkbox", M.db.show_bar_section_outlines)

end

--#endregion FILE CONTENTS ===================================================
