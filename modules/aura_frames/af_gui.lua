-- Settings UI for the Aura Frames module, registered as a sidebar category in the main window.
-- BuildSettings() creates three tabs:
-- 1) General (global toggles and thresholds)
-- 2) Frames (a tree sidebar listing preset, CDM-backed, and custom frames with settings grids).
-- 3) Spell ID (tooltip spell ID toggle).

local addon_name, addon = ...

-- Ensure the unified module table is used
addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

-- GUI COMPONENT BUILDERS

-- Shared dropdown mechanics live in functions/dropdown.lua via addon.CreateDropdown.

function M.CreateListDropdown(name, parent, labelText, options, get_value, on_select, width)
    local function get_option_text(option)
        return option.text or tostring(option.value or "")
    end

    local function apply_button_style(btn_text, option)
        if not btn_text then return end
        if option.font_path then
            btn_text:SetFont(option.font_path, option.font_size or 9, option.font_flags or "")
        else
            btn_text:SetFontObject(GameFontHighlightSmall)
        end
    end

    local function apply_row_style(row_text, option)
        if option.font_path then
            row_text:SetFont(option.font_path, option.font_size or 9, option.font_flags or "")
        end
    end

    return addon.CreateDropdown(name, parent, labelText, options, {
        width = width or 180,
        get_value = get_value,
        on_select = function(value)
            if on_select then on_select(value) end
        end,
        get_option_text = get_option_text,
        apply_button_style = apply_button_style,
        apply_row_style = apply_row_style,
    })
end

-- tabs settings controls
function M.BuildSettings(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Buffs & Debuffs Configuration")

    local tabs, panels = {}, {}

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

    local tab_data = {
        { name = "General", is_general  = true },
        { name = "Frames",  is_frames   = true },
        { name = "Spell ID", is_aura_id  = true },
    }


    for i, data in ipairs(tab_data) do
        local tab = CreateFrame("Button", addon_name.."Tab"..i, parent, "PanelTabButtonTemplate")
        tab:SetText(data.name)
        tab:SetID(i)
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
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and title or tabs[i-1], i == 1 and "BOTTOMLEFT" or "RIGHT", i == 1 and 0 or 5, i == 1 and -15 or 0)
        PanelTemplates_TabResize(tab, 0)

        local p = CreateFrame("Frame", nil, parent)
        p:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -80)
        p:SetSize(741, 50)  -- tab content panel: 925 frame - 12 B.l - 140 sidebar - 12 B.r - 20 margin
        p:Hide()

        if data.is_general then
            M.build_general_tab(p)
        elseif data.is_frames then
            M.build_frames_tab(p, frames_data)
        elseif data.is_aura_id then
            M.build_aura_id_tab(p)
        end

        tabs[i], panels[i] = tab, p
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
        if control and control.SetChecked then
            control:SetChecked(value == true)
        end
    end

    set_checked("enable_blizz_buffs", M.db.enable_blizz_buffs)
    set_checked("enable_blizz_debuffs", M.db.enable_blizz_debuffs)
    set_checked("snap_to_grid_checkbox", M.db.snap_to_grid)
    set_checked("show_spell_id_checkbox", M.db.show_spell_id)
    set_checked("show_grid_checkbox", M.db.show_grid)

    for _, cat in ipairs(M.CATEGORIES or {}) do
        local keys = {
            "show_" .. cat,
            "move_" .. cat,
            "timer_" .. cat,
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
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        local font_dropdown = M.controls["timer_number_font_dropdown_"..cat]
        if font_dropdown and font_dropdown.SetValue then
            font_dropdown:SetValue(M.db["timer_number_font_"..cat] or M.db.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY)
        end

        local font_size_slider = M.controls["timer_number_font_size_slider_"..cat]
        if font_size_slider and font_size_slider.slider then
            font_size_slider.slider:SetValue(M.db["timer_number_font_size_"..cat] or M.defaults["timer_number_font_size_"..cat] or 10)
        end
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        set_checked("timer_number_font_bold_"..cat, M.db["timer_number_font_bold_"..cat])
    end

    set_checked("show_bar_section_outlines_checkbox", M.db.show_bar_section_outlines)

end
