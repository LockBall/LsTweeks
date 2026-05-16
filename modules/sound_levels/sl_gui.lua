-- Settings UI for the Sound Levels module: General and Sounds tabs,
-- target list, per-sound level slider, and preview controls.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

local TICK_COLOR_R, TICK_COLOR_G, TICK_COLOR_B, TICK_COLOR_A = 0.62, 0.62, 0.62, 0.9

local STRINGS = {
    sound_off_label = "Off",
    use_original_label = "Original",
    play_on_adjust_label = "Play Sound on Adjust",
    status_waiting = "Waiting for Blizzard FileDataID and replacement sound files.",
    help_text =
        "This module uses premade files at specific volumes because WoW does not support per-sound volume controls."
        .. "\n\nOriginal is the unmodified WoW volume."
        .. "\n\nUse the Original checkbox to compare Blizzard's sound against replacement volume 0-100%."
        .. "\n\nThey suppress the original file and play replacement files from media\\sounds\\levelup2.",
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
    level_slider_width = 500,
    -- Visual calibration for tick marks against the usable slider track.
    level_slider_tick_start_x = 10.5,
    level_slider_tick_end_x = 490,
}

local function should_show_slider_label(option)
    return option and (option.major_tick == true or option.midpoint_tick == true)
end

local function get_tick_height(option)
    if not option then return 0 end
    if option.major_tick == true then return 10 end
    if option.midpoint_tick == true then return 7 end
    return 4
end

local function create_tick(parent, slider, height, x)
    local tick = parent:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(TICK_COLOR_R, TICK_COLOR_G, TICK_COLOR_B, TICK_COLOR_A)
    tick:SetSize(1, height)
    tick:SetPoint("TOP", slider, "BOTTOMLEFT", x, -4)
    return tick
end

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

    local current_preset = M.get_preset_by_value(target_db.preset)
    local preset_options = M.PRESET_OPTIONS or {}
    local preset_count = math.max(#preset_options, 1)
    local slider = CreateFrame("Slider", addon_name .. target_key .. "SoundLevelSlider", box, "MinimalSliderTemplate")
    slider:SetSize(UI.level_slider_width, 18)
    slider:SetPoint("TOP", level_label, "BOTTOM", 0, -12)
    slider:SetMinMaxValues(1, preset_count)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(current_preset and current_preset.slider_value or preset_count)

    local tick_start = UI.level_slider_tick_start_x
    local tick_width = UI.level_slider_tick_end_x - UI.level_slider_tick_start_x
    for _, option in ipairs(preset_options) do
        local x = tick_start
        if preset_count > 1 then
            x = tick_start + (((option.slider_value or 1) - 1) * (tick_width / (preset_count - 1)))
        end

        create_tick(box, slider, get_tick_height(option), x)

        if should_show_slider_label(option) then
            local label = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            label:SetPoint("TOP", slider, "BOTTOMLEFT", x, -16)
            label:SetText(option.text .. "%")
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        local option = M.get_preset_by_slider_value(value)
        local slider_value = option and option.slider_value or preset_count
        if self:GetValue() ~= slider_value then
            self:SetValue(slider_value)
            return
        end

        local new_preset = (option and option.value) or target.default_preset or "0"
        if target_db.preset == new_preset then
            return
        end

        target_db.preset = new_preset
        if target_db.use_original == true then
            target_db.use_original = false
            local original_cb = M.controls[target_key .. "_use_original"]
            if original_cb and original_cb.SetChecked then
                original_cb:SetChecked(false)
            end
        end
        M.apply_sound_levels()
    end)
    slider:SetScript("OnMouseUp", function()
        if target_db.play_on_adjust == true then
            M.queue_adjust_preview(target_key)
        end
    end)
    M.controls[target_key .. "_preset"] = slider

    local play_button = create_play_button(box, target_key, slider)

    local off_container, off_cb = addon.CreateCheckbox(
        box,
        STRINGS.sound_off_label,
        target_db.sound_off == true,
        function(is_checked)
            target_db.sound_off = is_checked == true
            M.stop_preview_sound()
            M.apply_sound_levels()
        end
    )
    off_container:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", UI.level_slider_tick_start_x, -36)
    M.controls[target_key .. "_sound_off"] = off_cb

    local original_container, original_cb = addon.CreateCheckbox(
        box,
        STRINGS.use_original_label,
        target_db.use_original == true,
        function(is_checked)
            target_db.use_original = is_checked == true
            M.stop_preview_sound()
            M.apply_sound_levels()
        end
    )
    original_container:SetPoint("TOPRIGHT", slider, "BOTTOMLEFT", UI.level_slider_tick_end_x, -36)
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
