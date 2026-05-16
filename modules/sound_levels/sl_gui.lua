-- Settings UI for the Sound Levels module: General and Sounds tabs,
-- target list, per-sound level slider, and preview controls.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local STRINGS = {
    use_original_label = "Original",
    play_on_adjust_label = "Play Sound on Adjust",
    status_waiting = "Waiting for Blizzard FileDataID and replacement sound files.",
    help_text =
        "This module uses premade files at specific volumes because WoW does not support per-sound volume controls."
        .. "\n\nOriginal is the unmodified WoW volume."
        .. "\n\nUse the Original checkbox to compare Blizzard's sound against replacement volume 0-100%."
        .. "\n\nThey suppress the original file and play replacement files from " .. M.SOUND_ASSET_PATHS.levelup2,
}

local UI = {
    pad_x = 20,
    pad_y = -18,
    tab_width = 92,
    tab_height = 24,
    tab_gap = 8,
    content_top = -58,
    panel_width = 590,
    list_width = 190,
    list_row_height = 26,
    detail_x = 230,
    sound_panel_y = -18,
    detail_width = 560,
    detail_height = 230,
    level_slider_width = 432,
    level_button_size = 22,
    level_control_width = 500,
}

local function apply_box_backdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.28)
    frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
end

local function create_play_button(parent, target_key, anchor)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    button:SetPoint("TOP", anchor, "BOTTOM", -70, -64)

    local button_ring = button:CreateTexture(nil, "BORDER")
    button_ring:SetAllPoints()
    button_ring:SetTexture("Interface\\Artifacts\\ArtifactRelic-Slot")
    button_ring:SetDesaturated(true)
    button_ring:SetVertexColor(0.55, 0.55, 0.55, 0.85)

    local play_icon = button:CreateTexture(nil, "OVERLAY")
    play_icon:SetSize(18, 22)
    play_icon:SetPoint("CENTER", button, "CENTER", 1, 0)
    play_icon:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    play_icon:SetTexCoord(0.18, 0.82, 0.16, 0.84)
    play_icon:SetVertexColor(0.9, 0.9, 0.9, 1)

    button:SetScript("OnEnter", function()
        button_ring:SetVertexColor(0.75, 0.75, 0.75, 0.95)
        play_icon:SetVertexColor(1, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function()
        button_ring:SetVertexColor(0.55, 0.55, 0.55, 0.85)
        play_icon:SetVertexColor(0.9, 0.9, 0.9, 1)
        play_icon:SetPoint("CENTER", button, "CENTER", 1, 0)
    end)
    button:SetScript("OnMouseDown", function()
        button_ring:SetVertexColor(0.4, 0.4, 0.4, 0.85)
        play_icon:SetPoint("CENTER", button, "CENTER", 2, -1)
    end)
    button:SetScript("OnMouseUp", function()
        button_ring:SetVertexColor(0.75, 0.75, 0.75, 0.95)
        play_icon:SetPoint("CENTER", button, "CENTER", 1, 0)
    end)
    button:SetScript("OnClick", function()
        M.play_replacement(target_key)
    end)

    return button
end

local function format_percent(option)
    local percent = option and option.percent or 0
    return tostring(math.floor(percent + 0.5)) .. "%"
end

local function create_slider_arrow_button(parent, anchor, point, relative_point, x_offset, is_increment)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(UI.level_button_size, UI.level_button_size)
    button:SetPoint(point, anchor, relative_point, x_offset, 0)
    button:SetNormalTexture(is_increment and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    button:SetPushedTexture(is_increment and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down" or "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    button:SetDisabledTexture(is_increment and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled" or "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")

    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexCoord(0.18, 0.82, 0.16, 0.84)
        normal:SetVertexColor(0.88, 0.88, 0.88, 0.95)
    end
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetTexCoord(0.18, 0.82, 0.16, 0.84)
        pushed:SetVertexColor(0.72, 0.72, 0.72, 0.95)
    end
    local disabled = button:GetDisabledTexture()
    if disabled then
        disabled:SetTexCoord(0.18, 0.82, 0.16, 0.84)
        disabled:SetVertexColor(0.45, 0.45, 0.45, 0.75)
    end

    return button
end

local function build_sound_detail_panel(parent, target_key, target)
    local target_db = M.get_target_db(target_key)

    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(UI.detail_width, UI.detail_height)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.detail_x, UI.sound_panel_y)
    apply_box_backdrop(box)

    local desc = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -16)
    desc:SetWidth(UI.detail_width - 32)
    desc:SetJustifyH("LEFT")
    desc:SetText((target.description ~= "" and target.description) or " ")

    local level_label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    level_label:SetPoint("TOP", desc, "BOTTOM", 0, -18)
    level_label:SetText("Level")

    local percent_label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    percent_label:SetPoint("TOP", level_label, "BOTTOM", 0, -4)

    local current_preset = M.get_preset_by_value(target_db.preset)
    local preset_options = M.PRESET_OPTIONS or {}
    local preset_count = math.max(#preset_options, 1)
    local initial_slider_value = target_db.sound_off == true and 1 or (current_preset and current_preset.slider_value or preset_count)
    local initial_option = M.get_preset_by_slider_value(initial_slider_value)
    percent_label:SetText(format_percent(initial_option))

    local level_control = CreateFrame("Frame", nil, box)
    level_control:SetSize(UI.level_control_width, UI.level_button_size)
    level_control:SetPoint("TOP", percent_label, "BOTTOM", 0, -8)

    local slider = CreateFrame("Slider", addon_name .. target_key .. "SoundLevelSlider", box, "MinimalSliderTemplate")
    slider:SetSize(UI.level_slider_width, 18)
    slider:SetPoint("CENTER", level_control, "CENTER", 0, 0)
    slider:SetMinMaxValues(1, preset_count)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initial_slider_value)

    local decrement_button = create_slider_arrow_button(level_control, slider, "RIGHT", "LEFT", -10, false)
    local increment_button = create_slider_arrow_button(level_control, slider, "LEFT", "RIGHT", 10, true)
    local original_cb = nil
    local suppress_original_clear = false

    local function set_slider_inactive(inactive)
        local alpha = inactive and 0.45 or 1
        slider:SetAlpha(alpha)
        decrement_button:SetAlpha(alpha)
        increment_button:SetAlpha(alpha)
        if inactive then
            percent_label:SetTextColor(0.55, 0.55, 0.55, 1)
        else
            percent_label:SetTextColor(1, 1, 1, 1)
        end
    end

    local function update_slider_buttons(slider_value)
        decrement_button:SetEnabled(slider_value > 1)
        increment_button:SetEnabled(slider_value < preset_count)
    end

    local function sync_original_inactive_state()
        set_slider_inactive(target_db.use_original == true)
    end

    local function clear_original_from_slider_interaction()
        if target_db.use_original ~= true then return end
        target_db.use_original = false
        if original_cb and original_cb.SetChecked then
            original_cb:SetChecked(false)
        end
        sync_original_inactive_state()
    end

    update_slider_buttons(initial_slider_value)
    sync_original_inactive_state()

    slider:SetScript("OnValueChanged", function(self, value)
        local option = M.get_preset_by_slider_value(value)
        local slider_value = option and option.slider_value or preset_count
        if self:GetValue() ~= slider_value then
            self:SetValue(slider_value)
            return
        end

        percent_label:SetText(format_percent(option))
        update_slider_buttons(slider_value)
        if suppress_original_clear then
            return
        end
        clear_original_from_slider_interaction()

        local new_preset = (option and option.value) or target.default_preset or "0"
        local is_off = slider_value == 1
        local changed = target_db.preset ~= new_preset or target_db.sound_off ~= is_off
        target_db.sound_off = is_off
        if target_db.preset == new_preset then
            if changed then
                M.stop_preview_sound()
                M.apply_sound_levels()
            end
            return
        end

        target_db.preset = new_preset
        M.apply_sound_levels()
    end)
    slider:SetScript("OnMouseUp", function()
        if target_db.play_on_adjust == true then
            M.queue_adjust_preview(target_key)
        end
    end)
    decrement_button:SetScript("OnClick", function()
        slider:SetValue(math.max(1, slider:GetValue() - 1))
        if target_db.play_on_adjust == true then
            M.queue_adjust_preview(target_key)
        end
    end)
    increment_button:SetScript("OnClick", function()
        slider:SetValue(math.min(preset_count, slider:GetValue() + 1))
        if target_db.play_on_adjust == true then
            M.queue_adjust_preview(target_key)
        end
    end)
    M.controls[target_key .. "_preset"] = slider
    slider._lstweeks_set_sound_level_value = function(_, value)
        suppress_original_clear = true
        slider:SetValue(value)
        suppress_original_clear = false
        sync_original_inactive_state()
    end
    slider._lstweeks_sync_original_state = sync_original_inactive_state

    local play_button = create_play_button(box, target_key, slider)

    local original_container
    original_container, original_cb = addon.CreateCheckbox(
        box,
        STRINGS.use_original_label,
        target_db.use_original == true,
        function(is_checked)
            target_db.use_original = is_checked == true
            if is_checked == true then
                target_db.sound_off = false
            else
                target_db.sound_off = slider:GetValue() == 1
            end
            sync_original_inactive_state()
            M.stop_preview_sound()
            M.apply_sound_levels()
        end
    )
    sync_original_inactive_state()
    original_container:SetPoint("TOPLEFT", level_control, "BOTTOMLEFT", 0, -28)
    M.controls[target_key .. "_use_original"] = original_cb

    local adjust_container, adjust_cb = addon.CreateCheckbox(
        box,
        STRINGS.play_on_adjust_label,
        target_db.play_on_adjust == true,
        function(is_checked)
            target_db.play_on_adjust = is_checked == true
        end
    )
    adjust_container:SetPoint("LEFT", play_button, "RIGHT", 18, 0)
    M.controls[target_key .. "_play_on_adjust"] = adjust_cb

    if #(target.original_file_ids or {}) == 0 and not target.preview_soundkit then
        local status = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 16, 14)
        status:SetWidth(UI.detail_width - 32)
        status:SetJustifyH("LEFT")
        status:SetText(STRINGS.status_waiting)
    end

    return box
end

local function build_general_tab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y)
    title:SetText("General")

    local panel, text = addon.CreateRivetedPanel(
        parent,
        UI.panel_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        title,
        "TOPLEFT",
        0,
        -34
    )
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -22)
    text:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetText(STRINGS.help_text)
    panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, text:GetHeight() + 44))

    local reset = addon.CreateGlobalReset(parent, M.get_db(), M.defaults.sound_levels)
    reset:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -20)
end

local function build_sounds_tab(parent)
    M.get_db()
    local targets = M.get_ordered_sound_targets()
    local selected_key = targets[1] and targets[1].key
    local rows = {}
    local detail_panels = {}

    local list_box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list_box:SetSize(UI.list_width, 260)
    list_box:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.sound_panel_y)
    apply_box_backdrop(list_box)

    local function select_sound(target_key)
        selected_key = target_key
        for _, row in ipairs(rows) do
            local selected = row.target_key == selected_key
            row.bg:SetShown(selected)
            row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
        end
        for _, panel in pairs(detail_panels) do
            panel:Hide()
        end
        local target = M.SOUND_TARGETS and M.SOUND_TARGETS[selected_key]
        if target then
            if not detail_panels[selected_key] then
                detail_panels[selected_key] = build_sound_detail_panel(parent, selected_key, target)
            end
            detail_panels[selected_key]:Show()
        end
    end

    for i, entry in ipairs(targets) do
        local row = CreateFrame("Button", nil, list_box)
        row:SetSize(UI.list_width - 18, UI.list_row_height)
        row:SetPoint("TOPLEFT", list_box, "TOPLEFT", 9, -(10 + ((i - 1) * UI.list_row_height)))
        row.target_key = entry.key

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
        row.bg:Hide()

        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.08)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetText(entry.label)
        row:SetScript("OnClick", function()
            select_sound(entry.key)
        end)

        rows[#rows + 1] = row
    end

    if selected_key then
        select_sound(selected_key)
    end
end

function M.BuildSettings(parent)
    local tabs = {}
    local panels = {}
    local selected_index = 1

    local tab_defs = {
        { label = "General", builder = build_general_tab },
        { label = "Sounds", builder = build_sounds_tab },
    }

    local function select_tab(index)
        selected_index = index
        for i, button in ipairs(tabs) do
            if i == selected_index then
                PanelTemplates_SelectTab(button)
                panels[i]:Show()
            else
                PanelTemplates_DeselectTab(button)
                panels[i]:Hide()
            end
        end
    end

    for i, def in ipairs(tab_defs) do
        local tab = CreateFrame("Button", addon_name .. "SoundLevelsTab" .. i, parent, "PanelTabButtonTemplate")
        tab:SetText(def.label)
        tab:SetID(i)
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i-1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and UI.pad_x or 5, i == 1 and UI.pad_y or 0)
        PanelTemplates_TabResize(tab, 0)
        tabs[i] = tab

        local panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, UI.content_top)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        panel:Hide()
        panels[i] = panel

        def.builder(panel)
        tab:SetScript("OnClick", function(self)
            select_tab(self:GetID())
        end)
    end

    PanelTemplates_SetNumTabs(parent, #tab_defs)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end
