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

-- growth direction dropdown
-- Replaces the deprecated UIDropDownMenu API with a custom popup list.
function M.CreateDirectionDropdown(name, parent, labelText, db_key, callback)
    local dir_values = { "RIGHT", "LEFT", "DOWN", "UP" }
    local options = {}
    for _, dir in ipairs(dir_values) do
        options[#options + 1] = { value = dir, text = dir }
    end

    return addon.CreateDropdown(name, parent, labelText, options, {
        width = 106,
        get_value = function()
            return M.db[db_key] or "DOWN"
        end,
        on_select = function(value)
            M.db[db_key] = value
            if callback then callback() end
        end,
    })
end

-- tabs settings controls
function M.BuildSettings(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Buffs & Debuffs Configuration")

    local tabs, panels = {}, {}

    -- Category definitions. Keys follow pattern <prefix>_<cat>.
    -- `opts.key` lets display labels diverge from DB keys (for example "Tracked Buffs" -> tracked_buffs).
    -- prefixes: show, move, timer, bg, scale, spacing
    local function make_cat(name, opts)
        local k = (opts and opts.key) or name:lower()
        return {
            name        = name,
            show_key    = "show_"    .. k,
            move_key    = "move_"    .. k,
            timer_key   = "timer_"   .. k,
            bg_key      = "bg_"      .. k,
            scale_key   = "scale_"   .. k,
            spacing_key = "spacing_" .. k,
            is_debuff   = opts and opts.is_debuff,
        }
    end

    local frames_data = {
        make_cat("Static"),
        make_cat("DeBuff", { is_debuff = true }),
        make_cat("Short"),
        make_cat("Long"),
        make_cat("Essential"),
        make_cat("Utility"),
        make_cat("Tracked Buffs", { key = "tracked_buffs" }),
        make_cat("Tracked Bars", { key = "tracked_bars" }),
    }

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

-- Sync only GUI control states from DB (used after reset flows).
function M.sync_general_controls_from_db()
    if not M.controls or not M.db then return end

    local buffs = M.controls["enable_blizz_buffs"]
    if buffs and buffs.SetChecked then
        buffs:SetChecked(M.db.enable_blizz_buffs)
    end

    local debuffs = M.controls["enable_blizz_debuffs"]
    if debuffs and debuffs.SetChecked then
        debuffs:SetChecked(M.db.enable_blizz_debuffs)
    end

    local snap_cb = M.controls["snap_to_grid_checkbox"]
    if snap_cb and snap_cb.SetChecked then
        snap_cb:SetChecked(M.db.snap_to_grid == true)
    end

    local spell_id_cb = M.controls["show_spell_id_checkbox"]
    if spell_id_cb and spell_id_cb.SetChecked then
        spell_id_cb:SetChecked(M.db.show_spell_id == true)
    end

    local grid_cb = M.controls["show_grid_checkbox"]
    if grid_cb and grid_cb.SetChecked then
        grid_cb:SetChecked(M.db.show_grid == true)
    end

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
            local cb = M.controls[key]
            if cb and cb.SetChecked and M.db[key] ~= nil then
                cb:SetChecked(M.db[key] == true)
            end
        end
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        local font_dropdown = M.controls["timer_number_font_dropdown_"..cat]
        if font_dropdown and font_dropdown.SetValue then
            font_dropdown:SetValue(M.db["timer_number_font_"..cat] or M.db.timer_number_font or "source_code_pro")
        end

        local font_size_slider = M.controls["timer_number_font_size_slider_"..cat]
        if font_size_slider and font_size_slider.slider then
            font_size_slider.slider:SetValue(M.db["timer_number_font_size_"..cat] or M.defaults["timer_number_font_size_"..cat] or 10)
        end
    end

    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        local cat_bold_cb = M.controls["timer_number_font_bold_"..cat]
        if cat_bold_cb and cat_bold_cb.SetChecked then
            cat_bold_cb:SetChecked(M.db["timer_number_font_bold_"..cat] or false)
        end
    end

    local outlines_cb = M.controls["show_bar_section_outlines_checkbox"]
    if outlines_cb and outlines_cb.SetChecked then
        outlines_cb:SetChecked(M.db.show_bar_section_outlines == true)
    end

end
