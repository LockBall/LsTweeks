-- Shared settings UI support for the Audio Volumes module.
local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes

--#region CONFIGURATION ========================================================

local SLIDER_WITH_BOX_SIZE = addon.SLIDER_WITH_BOX_SIZE

local STRINGS = {
    use_original_label = "Original",
    play_on_adjust_label = "Play on Adjust",
    fishing_help_text =
        "Fishing Focus temporarily applies a second sound-channel situation while the player is channeling Fishing."
        .. "\n\nWhen the fishing channeling ends, the normal volumes are restored."
        .. "\n\nThe FishingBobber splash sound plays on the Effects channel. Increase that first. You can also reduce other channels to emphasize the difference.",
    combat_help_text =
        "Combat Volumes temporarily applies a second sound-channel situation while the player is in combat."
        .. "\n\nWhen combat ends, the normal channel volumes are restored."
        .. "\n\nEntering combat exits Fishing Focus so combat has priority over fishing audio."
        .. "\n\nCombat sounds are played on the Effects channel.",
    custom_help_text =
        "Quick Picks store reusable sound-channel situations."
        .. "\n\nEnable turns the selected Quick Pick on immediately. Use Play to preview it without leaving it on.",
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
    list_width = 130,
    list_row_height = 26,
    slider_panel_x = 230,
    slider_panel_y = -18,
    slider_panel_width = 370,
    slider_panel_pad_x = 16,
    slider_panel_height = 92,
    slider_width = 275,
    slider_height = 20,
    slider_frame_width = 400,
    slider_frame_height = 22,
    fishing_slider_width = SLIDER_WITH_BOX_SIZE.width,
    fishing_slider_gap = 10,
    fishing_slider_pad_x = 10,
    fishing_slider_row_start = -32,
    fishing_slider_row_height = SLIDER_WITH_BOX_SIZE.height + 20,
    fishing_volumes_panel_height = SLIDER_WITH_BOX_SIZE.height + 39,
}

M.GUI_STRINGS = STRINGS
M.GUI_LAYOUT = UI

--#endregion CONFIGURATION =====================================================

--#region SHARED HELPERS =======================================================

function M.ApplyGUIBoxBackdrop(frame)
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

function M.BuildSoundTargetSliderPanel(parent, target_key, target)
    local initial_target_db = M.get_target_db(target_key)

    local slider_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slider_panel:SetSize(UI.slider_panel_width, UI.slider_panel_height)
    slider_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.slider_panel_x, UI.slider_panel_y)
    M.ApplyGUIBoxBackdrop(slider_panel)

    local target_note = slider_panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    target_note:SetPoint("TOPLEFT", slider_panel, "TOPLEFT", UI.slider_panel_pad_x, -12)
    target_note:SetWidth(UI.slider_panel_width - (UI.slider_panel_pad_x * 2))
    target_note:SetJustifyH("LEFT")
    target_note:SetText((target.description ~= "" and target.description) or " ")

    local slider_container = CreateFrame("Frame", nil, slider_panel)
    slider_container:SetSize(UI.slider_frame_width, UI.slider_frame_height)
    slider_container:SetPoint("TOP", slider_panel, "TOP", 0, -36)

    local current_preset = M.get_preset_by_value(initial_target_db.preset)
    local preset_options = M.PRESET_OPTIONS or {}
    local slider_min = 0
    local slider_max = math.max(#preset_options - 1, 0)
    local slider_steps = slider_max - slider_min
    local initial_slider_value = initial_target_db.sound_off == true and slider_min or (current_preset and current_preset.slider_value or slider_max)

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

    local original_container, original_checkbox, original_label
    local suppress_original_clear = false

    local function set_slider_inactive(inactive)
        local alpha = inactive and 0.45 or 1
        slider_widget:SetAlpha(alpha)
    end

    local function sync_original_inactive_state()
        local target_db = M.get_target_db(target_key)
        set_slider_inactive(target_db.use_original == true)
    end

    local function clear_original_from_slider_interaction()
        local target_db = M.get_target_db(target_key)
        if target_db.use_original ~= true then return end
        target_db.use_original = false
        if original_container and original_container.SetCheckedSilently then
            original_container:SetCheckedSilently(false)
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
        local target_db = M.get_target_db(target_key)
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
                M.apply_audio_volumes()
            end
            return
        end

        new_preset = new_preset or target.default_preset or "0"
        if target_db.preset == new_preset then
            if changed then
                M.apply_audio_volumes()
            end
            return
        end

        target_db.preset = new_preset
        M.apply_audio_volumes()
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

    original_container, original_checkbox, original_label = addon.CreateCheckbox(
        slider_panel,
        STRINGS.use_original_label,
        initial_target_db.use_original == true,
        function(is_checked)
            local target_db = M.get_target_db(target_key)
            target_db.use_original = is_checked == true
            if is_checked == true then
                target_db.sound_off = false
            else
                target_db.sound_off = slider_widget.Slider:GetValue() == slider_min
            end
            sync_original_inactive_state()
            M.stop_preview_sound()
            M.apply_audio_volumes()
            if target_db.play_on_adjust == true then
                M.play_replacement(target_key)
            end
        end
    )
    sync_original_inactive_state()
    if not has_original_playback(target) then
        initial_target_db.use_original = false
        original_container:SetCheckedSilently(false)
        original_container:Disable()
        original_label:SetTextColor(0.55, 0.55, 0.55, 1)
        sync_original_inactive_state()
    end
    original_container:SetPoint("RIGHT", slider_options_row, "RIGHT", 0, 0)
    M.controls[target_key .. "_use_original"] = original_container

    local play_on_adjust_frame, play_on_adjust_checkbox = addon.CreateCheckbox(
        slider_panel,
        STRINGS.play_on_adjust_label,
        initial_target_db.play_on_adjust == true,
        function(is_checked)
            local target_db = M.get_target_db(target_key)
            target_db.play_on_adjust = is_checked == true
        end
    )
    play_on_adjust_frame:SetPoint("LEFT", slider_options_row, "LEFT", 0, 0)
    M.controls[target_key .. "_play_on_adjust"] = play_on_adjust_frame

    return slider_panel
end

--#endregion SOUND TARGET CONTROLS =============================================

--#region SETTINGS CONSTRUCTION ================================================

function M.BuildSettings(parent)
    local db = M.get_db()
    local tabs = {}
    local tab_panels = {}

    local tab_defs = {
        { label = "General", builder = M.BuildGeneralTab },
        { label = "Specifics", builder = M.BuildSpecificsTab },
        { label = "Situations", builder = M.BuildSituationsTab },
        { label = "Profiles", builder = M.BuildProfilesTab },
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
                if tab_panels[i] and tab_panels[i]._lstweeks_refresh_current then
                    tab_panels[i]._lstweeks_refresh_current()
                end
            else
                PanelTemplates_DeselectTab(button)
                tab_panels[i]:Hide()
            end
        end
    end

    local function build_tab_panel(index)
        local def = tab_defs[index]
        local tab_panel = CreateFrame("Frame", nil, parent)
        tab_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, UI.content_top)
        tab_panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        tab_panel:Hide()
        tab_panels[index] = tab_panel
        def.builder(tab_panel)
        return tab_panel
    end

    for i, def in ipairs(tab_defs) do
        local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
        tab:SetText(def.label)
        tab:SetID(i)
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i-1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and UI.pad_x or 5, i == 1 and UI.pad_y or 0)
        PanelTemplates_TabResize(tab, 0)
        tabs[i] = tab
        build_tab_panel(i)
        tab:SetScript("OnClick", function(self)
            select_tab(self:GetID())
        end)
    end

    M.rebuild_situations_tab = function()
        local situations_index = 3
        local old_panel = tab_panels[situations_index]
        if old_panel then
            old_panel:Hide()
        end
        for control_key in pairs(M.controls) do
            if control_key == "fishing_focus_refresh_current"
                or control_key:match("^normal_volume_")
                or control_key:match("^fishing_focus_")
                or control_key:match("^combat_volumes_")
                or control_key == "quiet_custom_enabled"
                or control_key:match("^situation_") then
                M.controls[control_key] = nil
            end
        end
        build_tab_panel(situations_index)
        if selected_index == situations_index then
            tab_panels[situations_index]:Show()
            if tab_panels[situations_index]._lstweeks_refresh_current then
                tab_panels[situations_index]._lstweeks_refresh_current()
            end
        end
    end

    PanelTemplates_SetNumTabs(parent, #tab_defs)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

--#endregion SETTINGS CONSTRUCTION =============================================
