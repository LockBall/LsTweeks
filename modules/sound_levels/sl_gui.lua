-- Settings UI for the Sound Levels module: General and Sounds tabs,
-- target list, per-sound level slider, and preview controls.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {}
local M = addon.sound_levels

--#region CONFIGURATION ========================================================

local STRINGS = {
    use_original_label = "Original",
    play_on_adjust_label = "Play on Adjust",
    fishing_help_text =
        "Fishing Focus temporarily applies a second sound-channel profile while the player is channeling Fishing."
        .. "\n\nWhen the fishing channel ends, the normal channel volumes are restored."
        .. "\n\nThe FishingBobber splash sound plays on the Effects channel. Increase that first. You can also reduce other channels to emphasize the difference.",
    help_text =
        "This module uses premade files at specific volumes because WoW does not support per-sound volume controls."
        .. "\n\nOriginal is the unmodified WoW volume."
        .. "\n\nUse the Original checkbox to compare Blizzard's sound against replacement volume 0-100%."
        .. "\n\nThey suppress the original file and play replacement files from the configured module sound folders.",
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
    slider_panel_x = 230,
    slider_panel_y = -18,
    slider_panel_width = 370,
    slider_panel_pad_x = 16,
    slider_panel_height = 70,
    slider_width = 275,
    slider_height = 20,
    slider_frame_width = 400,
    slider_frame_height = 22,
    fishing_slider_width = 130,
    fishing_slider_gap = 10,
    fishing_volumes_panel_height = 180,
}

--#endregion CONFIGURATION =====================================================

--#region SHARED HELPERS =======================================================

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

--#endregion SHARED HELPERS ====================================================

--#region SOUND TARGET CONTROLS ================================================

local function create_play_button(parent, target_key)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)

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

local function has_original_playback(target)
    return target and (target.preview_soundkit or #(target.original_file_ids or {}) > 0)
end

local function build_slider_panel(parent, target_key, target)
    local target_db = M.get_target_db(target_key)

    local slider_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slider_panel:SetSize(UI.slider_panel_width, UI.slider_panel_height)
    slider_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.slider_panel_x, UI.slider_panel_y)
    apply_box_backdrop(slider_panel)

    local target_note = slider_panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    target_note:SetPoint("TOPLEFT", slider_panel, "TOPLEFT", UI.slider_panel_pad_x, -16)
    target_note:SetWidth(UI.slider_panel_width - (UI.slider_panel_pad_x * 2))
    target_note:SetJustifyH("LEFT")
    target_note:SetText((target.description ~= "" and target.description) or " ")

    local slider_container = CreateFrame("Frame", nil, slider_panel)
    slider_container:SetSize(UI.slider_frame_width, UI.slider_frame_height)
    slider_container:SetPoint("CENTER", slider_panel, "CENTER", 0, 12)

    local current_preset = M.get_preset_by_value(target_db.preset)
    local preset_options = M.PRESET_OPTIONS or {}
    local slider_min = 0
    local slider_max = math.max(#preset_options - 1, 0)
    local slider_steps = slider_max - slider_min
    local initial_slider_value = target_db.sound_off == true and slider_min or (current_preset and current_preset.slider_value or slider_max)

    local slider_widget = CreateFrame("Frame", nil, slider_panel, "MinimalSliderWithSteppersTemplate")
    slider_widget:SetSize(UI.slider_width, UI.slider_height)
    slider_widget:SetPoint("CENTER", slider_container, "CENTER", 0, 0)
    slider_widget:Init(initial_slider_value, slider_min, slider_max, slider_steps, {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return format_percent(M.get_preset_by_slider_value(value))
        end),
    })
    slider_widget.Slider:SetValueStep(1)
    slider_widget.Slider:SetObeyStepOnDrag(true)

    local play_button = create_play_button(slider_panel, target_key)
    play_button:SetPoint("RIGHT", slider_widget, "LEFT", 0, 0)

    local original_checkbox = nil
    local suppress_original_clear = false

    local function set_slider_inactive(inactive)
        local alpha = inactive and 0.45 or 1
        slider_widget:SetAlpha(alpha)
    end

    local function sync_original_inactive_state()
        set_slider_inactive(target_db.use_original == true)
    end

    local function clear_original_from_slider_interaction()
        if target_db.use_original ~= true then return end
        target_db.use_original = false
        if original_checkbox and original_checkbox.SetChecked then
            original_checkbox:SetChecked(false)
        end
        sync_original_inactive_state()
    end

    sync_original_inactive_state()

    slider_widget:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        local option = M.get_preset_by_slider_value(value)
        local slider_value = option and option.slider_value or slider_min
        if slider_widget.Slider:GetValue() ~= slider_value then
            slider_widget:SetValue(slider_value)
            return
        end

        if suppress_original_clear then
            return
        end
        clear_original_from_slider_interaction()
        if target_db.play_on_adjust == true then
            M.queue_adjust_preview(target_key)
        end

        local is_off = slider_value == slider_min
        local new_preset = option and option.value
        local changed = target_db.sound_off ~= is_off or ((not is_off) and target_db.preset ~= new_preset)
        target_db.sound_off = is_off
        if is_off then
            if changed then
                M.stop_preview_sound()
                M.apply_sound_levels()
            end
            return
        end

        new_preset = new_preset or target.default_preset or "0"
        if target_db.preset == new_preset then
            if changed then
                M.apply_sound_levels()
            end
            return
        end

        target_db.preset = new_preset
        M.apply_sound_levels()
    end)
    M.controls[target_key .. "_preset"] = slider_widget
    slider_widget._lstweeks_set_sound_level_value = function(_, value)
        suppress_original_clear = true
        slider_widget:SetValue(value)
        suppress_original_clear = false
        sync_original_inactive_state()
    end
    slider_widget._lstweeks_sync_original_state = sync_original_inactive_state

    local slider_options_row = CreateFrame("Frame", nil, slider_panel)
    slider_options_row:SetSize(UI.slider_width, 24)
    slider_options_row:SetPoint("TOP", slider_widget, "BOTTOM", 0, -6)

    local original_container, original_label
    original_container, original_checkbox, original_label = addon.CreateCheckbox(
        slider_panel,
        STRINGS.use_original_label,
        target_db.use_original == true,
        function(is_checked)
            target_db.use_original = is_checked == true
            if is_checked == true then
                target_db.sound_off = false
            else
                target_db.sound_off = slider_widget.Slider:GetValue() == slider_min
            end
            sync_original_inactive_state()
            M.stop_preview_sound()
            M.apply_sound_levels()
        end
    )
    sync_original_inactive_state()
    if not has_original_playback(target) then
        target_db.use_original = false
        original_checkbox:SetChecked(false)
        original_checkbox:Disable()
        original_label:SetTextColor(0.55, 0.55, 0.55, 1)
        sync_original_inactive_state()
    end
    original_container:SetPoint("RIGHT", slider_options_row, "RIGHT", 0, 0)
    M.controls[target_key .. "_use_original"] = original_checkbox

    local play_on_adjust_frame, play_on_adjust_checkbox = addon.CreateCheckbox(
        slider_panel,
        STRINGS.play_on_adjust_label,
        target_db.play_on_adjust == true,
        function(is_checked)
            target_db.play_on_adjust = is_checked == true
        end
    )
    play_on_adjust_frame:SetPoint("LEFT", slider_options_row, "LEFT", 0, 0)
    M.controls[target_key .. "_play_on_adjust"] = play_on_adjust_checkbox

    return slider_panel
end

--#endregion SOUND TARGET CONTROLS =============================================

--#region GENERAL TAB ==========================================================

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
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetText(STRINGS.help_text)
    local panel_padding = addon.RIVETED_PANEL_STYLE.padding
    panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, text:GetHeight() + (panel_padding * 2)))

    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.sound_levels, {
        after_reset = M.on_reset_complete,
    })
    reset:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -20)
end

--#endregion GENERAL TAB =======================================================

--#region CONTROL SYNCHRONIZATION ==============================================

function M.sync_fishing_focus_controls()
    local focus_db = M.get_fishing_focus_db()
    local focus_enabled = M.controls.fishing_focus_enabled
    if focus_enabled and focus_enabled.SetChecked then
        focus_enabled:SetChecked(focus_db.enabled == true)
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local slider = M.controls["fishing_focus_" .. channel.key]
        if slider and slider.slider and slider.slider.SetValue then
            slider.slider:SetValue(focus_db[channel.key])
        end
    end
    if M.controls.fishing_focus_refresh_current then
        M.controls.fishing_focus_refresh_current()
    end
end

--#endregion CONTROL SYNCHRONIZATION ===========================================

--#region FISHING TAB ==========================================================

local function create_fishing_header_bar(parent, title_text, play_profile_key)
    local title_bar = addon.CreateSettingsGroupTitleBar(parent, title_text)

    local play_button = CreateFrame("Button", nil, title_bar, "UIPanelButtonTemplate")
    play_button:SetSize(54, 20)
    play_button:SetPoint("RIGHT", title_bar, "RIGHT", -8, 0)
    play_button:SetText("Play")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(play_button)
    end
    play_button:SetScript("OnClick", function()
        M.play_fishing_bobber_preview(play_profile_key)
    end)

    return title_bar
end

local function build_fishing_tab(parent)
    local focus_db = M.get_fishing_focus_db()
    local focus_defaults = {}
    local slider_count = #(M.FISHING_FOCUS_CHANNELS or {})
    local sliders_panel_width = math.max(
        UI.panel_width,
        28 + (slider_count * UI.fishing_slider_width) + (math.max(slider_count - 1, 0) * UI.fishing_slider_gap)
    )

    local help_panel, help_text = addon.CreateRivetedPanel(
        parent,
        sliders_panel_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        parent,
        "TOPLEFT",
        UI.pad_x,
        UI.pad_y
    )
    local help_padding = addon.RIVETED_PANEL_STYLE.padding
    help_text:SetFontObject(GameFontHighlight)
    help_text:SetJustifyH("LEFT")
    help_text:SetJustifyV("TOP")
    help_text:SetWordWrap(true)
    help_text:SetText(STRINGS.fishing_help_text)
    help_panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, help_text:GetHeight() + (help_padding * 2)))

    local enable_row, enable_checkbox = addon.CreateCheckbox(
        parent,
        "Enable Fishing Focus",
        focus_db.enabled == true,
        function(is_checked)
            focus_db.enabled = is_checked == true
            M.sync_fishing_focus_events()
        end
    )
    enable_row:SetPoint("TOPLEFT", help_panel, "BOTTOMLEFT", 6, -16)
    M.controls.fishing_focus_enabled = enable_checkbox

    local enable_tooltip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    enable_tooltip:SetFrameStrata("TOOLTIP")
    enable_tooltip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    enable_tooltip:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
    enable_tooltip:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.95)
    enable_tooltip:Hide()

    local enable_tooltip_text = enable_tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enable_tooltip_text:SetPoint("CENTER", enable_tooltip, "CENTER", 0, 0)
    enable_tooltip_text:SetText("Activate Fishing Volumes While Fishing")
    enable_tooltip:SetSize(enable_tooltip_text:GetStringWidth() + 24, enable_tooltip_text:GetStringHeight() + 14)

    local function show_enable_tooltip(owner)
        enable_tooltip:ClearAllPoints()
        enable_tooltip:SetPoint("LEFT", owner, "RIGHT", 8, 0)
        enable_tooltip:Show()
    end
    local function hide_enable_tooltip()
        enable_tooltip:Hide()
    end
    enable_row:EnableMouse(true)
    enable_row:SetScript("OnEnter", function(self)
        show_enable_tooltip(self)
    end)
    enable_row:SetScript("OnLeave", hide_enable_tooltip)

    local current_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    current_panel:SetSize(sliders_panel_width, 70)
    current_panel:SetPoint("TOPLEFT", enable_row, "BOTTOMLEFT", -6, -10)
    addon.ApplySettingsGroupOutline(current_panel)

    create_fishing_header_bar(current_panel, "Normal Volumes", "current")

    local current_labels = {}

    local function refresh_current_values()
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            local current_percent = M.get_current_sound_channel_percent(channel)
            focus_defaults[channel.key] = M.get_default_fishing_focus_channel_percent(channel, current_percent)
            local label = current_labels[channel.key]
            if label then
                label:SetText(tostring(current_percent) .. "%")
            end
        end
    end
    M.controls.fishing_focus_refresh_current = refresh_current_values

    local sliders_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sliders_panel:SetSize(sliders_panel_width, UI.fishing_volumes_panel_height)
    sliders_panel:SetPoint("TOPLEFT", current_panel, "BOTTOMLEFT", 0, -16)
    addon.ApplySettingsGroupOutline(sliders_panel)

    create_fishing_header_bar(sliders_panel, "Fishing Volumes", "fishing")

    for i, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local column_x = 14 + ((i - 1) * (UI.fishing_slider_width + UI.fishing_slider_gap))
        local current_channel_label = current_panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        current_channel_label:SetSize(UI.fishing_slider_width, 16)
        current_channel_label:SetPoint("TOPLEFT", current_panel, "TOPLEFT", column_x, -30)
        current_channel_label:SetJustifyH("CENTER")
        current_channel_label:SetText(channel.label)

        local current_label = current_panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        current_label:SetSize(UI.fishing_slider_width, 16)
        current_label:SetPoint("TOPLEFT", current_panel, "TOPLEFT", column_x, -48)
        current_label:SetJustifyH("CENTER")
        current_labels[channel.key] = current_label

        local slider = addon.CreateSliderWithBox(
            addon_name .. "_FishingFocus_" .. channel.key,
            sliders_panel,
            channel.label,
            0,
            100,
            1,
            focus_db,
            channel.key,
            focus_defaults,
            function()
                M.resync_fishing_focus()
            end
        )
        slider:SetSize(UI.fishing_slider_width, 95)
        slider:SetPoint("TOPLEFT", sliders_panel, "TOPLEFT", column_x, -40)
        M.controls["fishing_focus_" .. channel.key] = slider

        if channel.key == "sfx" then
            local use_current_button = CreateFrame("Button", nil, sliders_panel, "UIPanelButtonTemplate")
            use_current_button:SetSize(94, 22)
            use_current_button:SetPoint("TOP", slider, "BOTTOM", 0, -8)
            use_current_button:SetText("Use Current")
            if addon.ApplyStandardButtonStyle then
                addon.ApplyStandardButtonStyle(use_current_button)
            end
            use_current_button:SetScript("OnClick", function()
                M.copy_current_sound_channels_to_fishing_focus()
                M.sync_fishing_focus_controls()
                M.resync_fishing_focus()
            end)
        end
    end
    refresh_current_values()
end

--#endregion FISHING TAB =======================================================

--#region SOUNDS TAB ===========================================================

local function build_sounds_tab(parent)
    local db = M.get_db()
    local targets = M.get_ordered_sound_targets()
    local selected_key = (db.last_sound_key and M.SOUND_TARGETS and M.SOUND_TARGETS[db.last_sound_key]) and db.last_sound_key or (targets[1] and targets[1].key)
    local target_rows = {}
    local slider_panels = {}

    local target_list_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    target_list_panel:SetSize(UI.list_width, 260)
    target_list_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.slider_panel_y)
    apply_box_backdrop(target_list_panel)

    local function select_sound(target_key)
        if not (target_key and M.SOUND_TARGETS and M.SOUND_TARGETS[target_key]) then
            return
        end
        selected_key = target_key
        db.last_sound_key = target_key
        for _, target_row in ipairs(target_rows) do
            local selected = target_row.target_key == selected_key
            target_row.bg:SetShown(selected)
            target_row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
        end
        for _, sound_slider_panel in pairs(slider_panels) do
            sound_slider_panel:Hide()
        end
        local target = M.SOUND_TARGETS and M.SOUND_TARGETS[selected_key]
        if target then
            if not slider_panels[selected_key] then
                slider_panels[selected_key] = build_slider_panel(parent, selected_key, target)
            end
            slider_panels[selected_key]:Show()
        end
    end

    for i, entry in ipairs(targets) do
        local target_row = CreateFrame("Button", nil, target_list_panel)
        target_row:SetSize(UI.list_width - 18, UI.list_row_height)
        target_row:SetPoint("TOPLEFT", target_list_panel, "TOPLEFT", 9, -(10 + ((i - 1) * UI.list_row_height)))
        target_row.target_key = entry.key

        target_row.bg = target_row:CreateTexture(nil, "BACKGROUND")
        target_row.bg:SetAllPoints()
        target_row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
        target_row.bg:Hide()

        local target_row_hover = target_row:CreateTexture(nil, "HIGHLIGHT")
        target_row_hover:SetAllPoints()
        target_row_hover:SetColorTexture(1, 1, 1, 0.08)

        target_row.text = target_row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        target_row.text:SetPoint("LEFT", target_row, "LEFT", 8, 0)
        target_row.text:SetPoint("RIGHT", target_row, "RIGHT", -8, 0)
        target_row.text:SetJustifyH("LEFT")
        target_row.text:SetText(entry.label)
        target_row:SetScript("OnClick", function()
            select_sound(entry.key)
        end)

        target_rows[#target_rows + 1] = target_row
    end

    if selected_key then
        select_sound(selected_key)
    end
end

--#endregion SOUNDS TAB ========================================================

--#region SETTINGS CONSTRUCTION ================================================

function M.BuildSettings(parent)
    local db = M.get_db()
    local tabs = {}
    local tab_panels = {}

    local tab_defs = {
        { label = "General", builder = build_general_tab },
        { label = "Sounds", builder = build_sounds_tab },
        { label = "Fishing", builder = build_fishing_tab },
    }
    local selected_index = math.max(1, math.min(#tab_defs, tonumber(db.last_tab_index) or 1))

    local function select_tab(index)
        if not tab_defs[index] then
            index = 1
        end
        selected_index = index
        db.last_tab_index = index
        for i, button in ipairs(tabs) do
            if i == selected_index then
                PanelTemplates_SelectTab(button)
                tab_panels[i]:Show()
                if tab_defs[i] and tab_defs[i].label == "Fishing" and M.controls.fishing_focus_refresh_current then
                    M.controls.fishing_focus_refresh_current()
                end
            else
                PanelTemplates_DeselectTab(button)
                tab_panels[i]:Hide()
            end
        end
    end

    for i, def in ipairs(tab_defs) do
        local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
        tab:SetText(def.label)
        tab:SetID(i)
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i-1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and UI.pad_x or 5, i == 1 and UI.pad_y or 0)
        PanelTemplates_TabResize(tab, 0)
        tabs[i] = tab

        local tab_panel = CreateFrame("Frame", nil, parent)
        tab_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, UI.content_top)
        tab_panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        tab_panel:Hide()
        tab_panels[i] = tab_panel

        def.builder(tab_panel)
        tab:SetScript("OnClick", function(self)
            select_tab(self:GetID())
        end)
    end

    PanelTemplates_SetNumTabs(parent, #tab_defs)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

--#endregion SETTINGS CONSTRUCTION =============================================
