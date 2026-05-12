-- Settings UI for the Aura Frames module, registered as a sidebar category in the main window.
-- BuildSettings() creates three tabs:
-- 1) General (global toggles and thresholds)
-- 2) Frames (a tree sidebar listing preset, CDM-backed, and custom frames with settings grids).
-- 3) Profiles (save/load complete Aura Frames setups across characters).

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

local function create_profile_button(parent, text, width, on_click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, 22)
    button:SetText(text)
    button:SetScript("OnClick", on_click)
    return button
end

function M.build_profiles_tab(parent)
    local selected_name = M.db and M.db.last_profile_name
    local rows = {}

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -12)
    title:SetText("Aura Frame Profiles")

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    note:SetWidth(600)
    note:SetJustifyH("LEFT")
    note:SetText("Profiles save the complete Aura Frames setup for use on another character.")

    local name_label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name_label:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -28)
    name_label:SetText("Profile Name")

    local name_box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    name_box:SetSize(220, 22)
    name_box:SetPoint("TOPLEFT", name_label, "BOTTOMLEFT", 0, -4)
    name_box:SetAutoFocus(false)
    name_box:SetMaxLetters(32)
    name_box:SetText(selected_name or "")

    local status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", name_box, "BOTTOMLEFT", 0, -12)
    status:SetWidth(450)
    status:SetJustifyH("LEFT")
    status:SetText("")

    local list_title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    list_title:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, -70)
    list_title:SetText("Saved Profiles")

    local list_box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list_box:SetPoint("TOPLEFT", list_title, "BOTTOMLEFT", 0, -8)
    list_box:SetSize(260, 260)
    M.apply_thin_border_backdrop(list_box, { r = 0.06, g = 0.06, b = 0.06, a = 0.88 }, { r = 0.42, g = 0.42, b = 0.42, a = 0.85 })

    local list_area = CreateFrame("Frame", nil, list_box)
    list_area:SetPoint("TOPLEFT", list_box, "TOPLEFT", 8, -8)
    list_area:SetPoint("BOTTOMRIGHT", list_box, "BOTTOMRIGHT", -8, 8)

    local function set_status(ok, message)
        status:SetText(message or "")
        status:SetTextColor(ok and 0.2 or 1, ok and 1 or 0.25, ok and 0.2 or 0.25)
    end

    local function get_name()
        return (name_box:GetText() or ""):match("^%s*(.-)%s*$")
    end

    local function select_profile(name)
        selected_name = name
        name_box:SetText(name or "")
        if M.db then M.db.last_profile_name = name end
        for _, row in ipairs(rows) do
            if row._profile_name then
                local selected = row._profile_name == selected_name
                row.bg:SetShown(selected)
                row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
            end
        end
    end

    local function clear_rows()
        for _, row in ipairs(rows) do
            row:Hide()
        end
        rows = {}
    end

    local function rebuild_profile_list()
        clear_rows()
        local profiles = M.get_aura_frame_profiles and M.get_aura_frame_profiles() or {}
        if #profiles == 0 then
            local empty = list_area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetPoint("TOPLEFT", list_area, "TOPLEFT", 4, -4)
            empty:SetText("No saved profiles")
            rows[#rows + 1] = empty
            return
        end

        for index, profile in ipairs(profiles) do
            local row = CreateFrame("Button", nil, list_area)
            row:SetSize(238, 20)
            row:SetPoint("TOPLEFT", list_area, "TOPLEFT", 0, -((index - 1) * 22))
            row._profile_name = profile.name

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
            row.bg:Hide()

            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.08)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetText(profile.name or ("Profile " .. index))
            row:SetScript("OnClick", function()
                select_profile(profile.name)
                set_status(true, "Selected profile: " .. (profile.name or ""))
            end)
            rows[#rows + 1] = row
        end
        select_profile(selected_name)
    end

    M.refresh_profiles_tab = function()
        selected_name = M.db and M.db.last_profile_name
        name_box:SetText(selected_name or "")
        set_status(true, "")
        rebuild_profile_list()
    end

    local function confirm_profile_action(dialog_key, text, button_text, on_accept)
        StaticPopupDialogs[dialog_key] = {
            text = text,
            button1 = button_text,
            button2 = "Cancel",
            OnAccept = on_accept,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show(dialog_key)
    end

    local save_new = create_profile_button(parent, "Save New", 100, function()
        local ok, message = M.save_aura_frame_profile(get_name(), false)
        if ok then select_profile(get_name()); rebuild_profile_list() end
        set_status(ok, message)
    end)
    save_new:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -18)

    local overwrite = create_profile_button(parent, "Overwrite", 100, function()
        local name = get_name()
        if name == "" then
            set_status(false, "Enter a profile name to overwrite.")
            return
        end
        confirm_profile_action(
            "LSTWEEKS_OVERWRITE_AURA_PROFILE",
            'Overwrite aura frame profile "' .. name .. '"?',
            "Overwrite",
            function()
                local ok, message = M.save_aura_frame_profile(name, true)
                if ok then select_profile(name); rebuild_profile_list() end
                set_status(ok, message)
            end
        )
    end)
    overwrite:SetPoint("LEFT", save_new, "RIGHT", 8, 0)

    local load = create_profile_button(parent, "Load", 100, function()
        local name = get_name()
        if name == "" then name = selected_name end
        local ok, message = M.load_aura_frame_profile(name)
        set_status(ok, message)
        rebuild_profile_list()
    end)
    load:SetPoint("TOPLEFT", save_new, "BOTTOMLEFT", 0, -8)

    local rename = create_profile_button(parent, "Rename", 100, function()
        if not selected_name or selected_name == "" then
            set_status(false, "Select a profile to rename.")
            return
        end

        local new_name = get_name()
        if new_name == "" then
            set_status(false, "Enter a new profile name.")
            return
        end

        confirm_profile_action(
            "LSTWEEKS_RENAME_AURA_PROFILE",
            'Rename aura frame profile "' .. selected_name .. '" to "' .. new_name .. '"?',
            "Rename",
            function()
                local ok, message = M.rename_aura_frame_profile(selected_name, new_name)
                if ok then
                    select_profile(new_name)
                    rebuild_profile_list()
                end
                set_status(ok, message)
            end
        )
    end)
    rename:SetPoint("LEFT", load, "RIGHT", 8, 0)

    local delete = create_profile_button(parent, "Delete", 100, function()
        local name = get_name()
        if name == "" then name = selected_name end
        if not name or name == "" then
            set_status(false, "Select a profile to delete.")
            return
        end
        confirm_profile_action(
            "LSTWEEKS_DELETE_AURA_PROFILE",
            'Delete aura frame profile "' .. name .. '"?',
            "Delete",
            function()
                local ok, message = M.delete_aura_frame_profile(name)
                if ok then
                    selected_name = M.db and M.db.last_profile_name
                    name_box:SetText(selected_name or "")
                    rebuild_profile_list()
                end
                set_status(ok, message)
            end
        )
    end)
    delete:SetPoint("TOPLEFT", load, "BOTTOMLEFT", 0, -8)

    rebuild_profile_list()
end

-- tabs settings controls
function M.BuildSettings(parent)
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
        { name = "Profiles", is_profiles = true },
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
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i-1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and 10 or 5, i == 1 and -12 or 0)
        PanelTemplates_TabResize(tab, 0)

        local p = CreateFrame("Frame", nil, parent)
        p:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -78)
        p:SetSize(741, 50)  -- tab content panel: 925 frame - 12 B.l - 140 sidebar - 12 B.r - 20 margin
        p:Hide()

        if data.is_general then
            M.build_general_tab(p)
        elseif data.is_frames then
            M.build_frames_tab(p, frames_data)
        elseif data.is_profiles then
            M.build_profiles_tab(p)
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
    set_checked("show_grid_checkbox", M.db.show_grid)

    for _, cat in ipairs(M.CATEGORIES or {}) do
        local keys = {
            "show_" .. cat,
            "move_" .. cat,
            "timer_" .. cat,
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
