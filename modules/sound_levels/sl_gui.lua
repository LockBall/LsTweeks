-- Settings UI for the Audio Volumes module: General and Specifics tabs,
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
        .. "\n\nWhen the fishing channeling ends, the normal volumes are restored."
        .. "\n\nThe FishingBobber splash sound plays on the Effects channel. Increase that first. You can also reduce other channels to emphasize the difference.",
    combat_help_text =
        "Combat Volumes temporarily applies a second sound-channel profile while the player is in combat."
        .. "\n\nWhen combat ends, the normal channel volumes are restored."
        .. "\n\nEntering combat exits Fishing Focus so combat has priority over fishing audio."
        .. "\n\nCombat sounds are played on the Effects channel.",
    custom_help_text =
        "Custom situations store a reusable sound-channel profile."
        .. "\n\nEnable turns the selected custom profile on immediately. Use Play to preview it without leaving it on.",
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
    fishing_slider_width = 130,
    fishing_slider_gap = 10,
    fishing_slider_pad_x = 10,
    fishing_slider_row_start = -32,
    fishing_volumes_panel_height = 134,
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
    target_note:SetPoint("TOPLEFT", slider_panel, "TOPLEFT", UI.slider_panel_pad_x, -12)
    target_note:SetWidth(UI.slider_panel_width - (UI.slider_panel_pad_x * 2))
    target_note:SetJustifyH("LEFT")
    target_note:SetText((target.description ~= "" and target.description) or " ")

    local slider_container = CreateFrame("Frame", nil, slider_panel)
    slider_container:SetSize(UI.slider_frame_width, UI.slider_frame_height)
    slider_container:SetPoint("TOP", slider_panel, "TOP", 0, -36)

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
            M.play_replacement(target_key)
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

local function create_specifics_help_panel(parent, anchor, anchor_point, offset_x, offset_y)
    local panel, text = addon.CreateRivetedPanel(
        parent,
        UI.panel_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        anchor,
        anchor_point,
        offset_x,
        offset_y
    )
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetText(STRINGS.help_text)
    local panel_padding = addon.RIVETED_PANEL_STYLE.padding
    panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, text:GetHeight() + (panel_padding * 2)))
    return panel
end

local function build_general_tab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y)
    title:SetText("General")

    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.sound_levels, {
        after_reset = M.on_reset_complete,
    })
    reset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
end

--#endregion GENERAL TAB =======================================================

--#region CONTROL SYNCHRONIZATION ==============================================

function M.sync_temporary_profile_controls()
    local focus_db = M.get_fishing_focus_db()
    local combat_db = M.get_combat_volumes_db()
    local quiet_custom_db = M.get_quiet_custom_db and M.get_quiet_custom_db() or nil
    local focus_enabled = M.controls.fishing_focus_enabled
    if focus_enabled and focus_enabled.SetChecked then
        focus_enabled:SetChecked(focus_db.enabled == true)
    end
    local combat_enabled = M.controls.combat_volumes_enabled
    if combat_enabled and combat_enabled.SetChecked then
        combat_enabled:SetChecked(combat_db.enabled == true)
    end
    local quiet_enabled = M.controls.quiet_custom_enabled
    if quiet_enabled and quiet_enabled.SetChecked and quiet_custom_db then
        quiet_enabled:SetChecked(quiet_custom_db.enabled == true)
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local slider = M.controls["fishing_focus_" .. channel.key]
        if slider and slider.slider and slider.slider.SetValue then
            slider.slider:SetValue(focus_db[channel.key])
        end
        local combat_slider = M.controls["combat_volumes_" .. channel.key]
        if combat_slider and combat_slider.slider and combat_slider.slider.SetValue then
            combat_slider.slider:SetValue(combat_db[channel.key])
        end
        local quiet_slider = M.controls["situation_quiet_custom_" .. channel.key]
        if quiet_slider and quiet_slider.slider and quiet_slider.slider.SetValue and quiet_custom_db then
            quiet_slider.slider:SetValue(quiet_custom_db[channel.key])
        end
    end
    local custom_situations = M.get_custom_situations_db and M.get_custom_situations_db() or {}
    for situation_id, situation in pairs(custom_situations) do
        local situation_key = "custom:" .. situation_id
        local enabled_control = M.controls["situation_" .. situation_key:gsub("[^%w_]", "_") .. "_enabled"]
        if enabled_control and enabled_control.SetChecked then
            enabled_control:SetChecked(situation.enabled == true)
        end
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            local slider = M.controls["situation_" .. situation_key .. "_" .. channel.key]
            if slider and slider.slider and slider.slider.SetValue then
                slider.slider:SetValue(situation[channel.key])
            end
        end
    end
    if M.controls.fishing_focus_refresh_current then
        M.controls.fishing_focus_refresh_current()
    end
end

M.sync_fishing_focus_controls = M.sync_temporary_profile_controls
M.sync_combat_volumes_controls = M.sync_temporary_profile_controls

--#endregion CONTROL SYNCHRONIZATION ===========================================

--#region SITUATIONS TAB ========================================================

local function create_situation_header_bar(parent, title_text, play_profile_key, action, opts)
    opts = opts or {}
    local title_bar, title = addon.CreateSettingsGroupTitleBar(parent, title_text)

    if opts.trigger then
        local trigger_row, trigger_checkbox = addon.CreateCheckbox(
            title_bar,
            opts.trigger.label or "Enable",
            opts.trigger.checked == true,
            opts.trigger.on_click
        )
        trigger_row:SetPoint("LEFT", title_bar, "LEFT", 6, 0)
        if opts.trigger.control_key then
            M.controls[opts.trigger.control_key] = trigger_checkbox
        end
        title_bar._lstweeks_trigger_row = trigger_row
    end

    local play_button = CreateFrame("Button", nil, title_bar, "UIPanelButtonTemplate")
    play_button:SetSize(54, 20)
    play_button:SetPoint("RIGHT", title_bar, "RIGHT", -8, 0)
    play_button:SetText("Play")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(play_button)
    end
    play_button:SetScript("OnClick", function()
        if opts.on_play then
            opts.on_play()
        elseif M.play_situation_preview then
            M.play_situation_preview(play_profile_key)
        else
            M.play_fishing_bobber_preview(play_profile_key)
        end
    end)

    if action then
        local action_button = CreateFrame("Button", nil, title_bar, "UIPanelButtonTemplate")
        action_button:SetSize(action.width or 84, 20)
        action_button:SetPoint("RIGHT", play_button, "LEFT", -6, 0)
        action_button:SetText(action.label or "")
        if addon.ApplyStandardButtonStyle then
            addon.ApplyStandardButtonStyle(action_button)
        end
        action_button:SetScript("OnClick", action.on_click)
    end

    return title_bar, title
end

local function build_situations_tab(parent)
    local focus_db = M.get_fishing_focus_db()
    local combat_db = M.get_combat_volumes_db()
    local quiet_custom_db = M.get_quiet_custom_db()
    local focus_defaults = {}
    local combat_defaults = {}
    local quiet_custom_defaults = {}
    local slider_count = #(M.FISHING_FOCUS_CHANNELS or {})
    local situation_rows = {}
    local situation_panels = {}
    local selected_key = nil
    local get_situation_entry = nil
    local sliders_panel_width = math.max(
        UI.panel_width,
        (UI.fishing_slider_pad_x * 2) + (slider_count * UI.fishing_slider_width) + (math.max(slider_count - 1, 0) * UI.fishing_slider_gap)
    )
    local situation_description_columns = math.max(slider_count - 1, 1)
    local situation_description_width = (situation_description_columns * UI.fishing_slider_width)
        + (math.max(situation_description_columns - 1, 0) * UI.fishing_slider_gap)
    local row_grid = addon.CreateSettingsGrid(parent, {
        column_count = 1,
        col_width = sliders_panel_width,
        col_offset = UI.pad_x,
        row_start = UI.pad_y,
        row_heights = {
            UI.fishing_volumes_panel_height + 16,
            UI.fishing_volumes_panel_height + 16,
            UI.fishing_volumes_panel_height,
        },
        col_align = { "left" },
    })
    local situation_grid = addon.CreateSettingsGrid(parent, {
        column_count = slider_count,
        col_width = UI.fishing_slider_width,
        column_gap_x = UI.fishing_slider_gap,
        col_offset = UI.pad_x + UI.fishing_slider_pad_x,
        row_start = UI.pad_y,
        row_heights = {
            UI.fishing_volumes_panel_height + 16,
            UI.fishing_volumes_panel_height + 16,
            UI.fishing_volumes_panel_height,
        },
        col_align = { "left", "left", "left", "left", "left" },
    })

    local situation_list_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    situation_list_panel:SetSize(UI.fishing_slider_width, (UI.fishing_volumes_panel_height * 2) + 16)
    situation_grid:place_at(situation_list_panel, 3, 1)
    apply_box_backdrop(situation_list_panel)

    local current_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    current_panel:SetSize(sliders_panel_width, UI.fishing_volumes_panel_height)
    row_grid:place_at(current_panel, 1, 1)
    addon.ApplySettingsGroupOutline(current_panel)

    local help_panel, help_text = addon.CreateRivetedPanel(
        parent,
        situation_description_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        parent,
        "TOPLEFT",
        0,
        0
    )
    help_panel:ClearAllPoints()
    situation_grid:place_at(help_panel, 3, 2)
    local help_padding = addon.RIVETED_PANEL_STYLE.padding
    help_text:SetFontObject(GameFontHighlight)
    help_text:SetJustifyH("LEFT")
    help_text:SetJustifyV("TOP")
    help_text:SetWordWrap(true)
    local function set_situation_help_text(entry)
        local text = STRINGS.custom_help_text
        if entry and entry.key == "fishing" then
            text = STRINGS.fishing_help_text
        elseif entry and entry.key == "combat" then
            text = STRINGS.combat_help_text
        end
        help_text:SetText(text)
        help_panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, help_text:GetHeight() + (help_padding * 2)))
    end
    set_situation_help_text({ key = "fishing" })

    local test_sound_dropdown = addon.CreateDropdown(
        addon_name .. "_SituationTestSound",
        parent,
        "Test Sound",
        M.TEST_SOUND_OPTIONS or {},
        {
            width = 190,
            get_value = function()
                local entry = selected_key and get_situation_entry and get_situation_entry(selected_key)
                return (entry and entry.db and entry.db.test_sound) or "bloodlust"
            end,
            on_select = function(value)
                local entry = selected_key and get_situation_entry and get_situation_entry(selected_key)
                if not (entry and entry.db) then return end
                entry.db.test_sound = M.get_valid_test_sound_key and M.get_valid_test_sound_key(value, "bloodlust") or value
            end,
        }
    )
    test_sound_dropdown:SetPoint("TOPLEFT", help_panel, "BOTTOMLEFT", 0, -18)
    test_sound_dropdown:Hide()

    local function get_selected_test_sound_key()
        local entry = selected_key and get_situation_entry and get_situation_entry(selected_key)
        if entry and entry.key ~= "fishing" and entry.db then
            return entry.db.test_sound
        end
        return nil
    end

    create_situation_header_bar(current_panel, "Normal", "current", nil, {
        on_play = function()
            if M.play_situation_preview then
                M.play_situation_preview("current", get_selected_test_sound_key())
            else
                M.play_fishing_bobber_preview("current")
            end
        end,
    })

    local current_values = {}
    local current_defaults = {}
    local current_sliders = {}

    local function refresh_current_values()
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            local current_percent = M.get_current_sound_channel_percent(channel)
            current_values[channel.key] = current_percent
            focus_defaults[channel.key] = M.get_default_fishing_focus_channel_percent(channel, current_percent)
            combat_defaults[channel.key] = current_percent
            quiet_custom_defaults[channel.key] = 25
            if current_defaults[channel.key] == nil then
                current_defaults[channel.key] = current_percent
            end
            local slider = current_sliders[channel.key]
            if slider and slider.slider and slider.slider.SetValue then
                slider._suppress_callback = true
                slider.slider:SetValue(current_percent)
                slider._suppress_callback = false
            end
        end
    end
    M.controls.fishing_focus_refresh_current = refresh_current_values

    local channel_grid_opts = {
        column_count = slider_count,
        col_width = UI.fishing_slider_width,
        column_gap_x = UI.fishing_slider_gap,
        col_offset = UI.fishing_slider_pad_x,
        row_start = UI.fishing_slider_row_start,
        row_heights = { 115 },
        col_align = { "left", "left", "left", "left", "left" },
    }
    local current_grid = addon.CreateSettingsGrid(current_panel, channel_grid_opts)

    for i, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        current_values[channel.key] = M.get_current_sound_channel_percent(channel)
        current_defaults[channel.key] = current_values[channel.key]
        combat_defaults[channel.key] = current_values[channel.key]
        quiet_custom_defaults[channel.key] = 25

        local current_slider = addon.CreateSliderWithBox(
            addon_name .. "_NormalSound_" .. channel.key,
            current_panel,
            channel.label,
            0,
            100,
            1,
            current_values,
            channel.key,
            current_defaults,
            function(value)
                M.set_current_sound_channel_percent(channel, value)
                focus_defaults[channel.key] = M.get_default_fishing_focus_channel_percent(channel, tonumber(value) or 0)
                combat_defaults[channel.key] = tonumber(value) or 0
            end
        )
        current_slider:SetSize(UI.fishing_slider_width, 95)
        current_grid:place_at(current_slider, 1, i)
        current_sliders[channel.key] = current_slider
        M.controls["normal_volume_" .. channel.key] = current_slider
    end

    local function get_situation_entries()
        local entries = {
            { key = "fishing", label = "Fishing", db = focus_db, profile_key = "fishing", trigger = "fishing" },
            { key = "combat", label = "Combat", db = combat_db, profile_key = "combat", trigger = "combat" },
            { key = "quiet_custom", label = quiet_custom_db.name or "Quiet Custom", db = quiet_custom_db, profile_key = "quiet_custom", renameable = true },
        }
        local custom_situations = M.get_custom_situations_db and M.get_custom_situations_db() or {}
        local custom_ids = {}
        for situation_id in pairs(custom_situations) do
            custom_ids[#custom_ids + 1] = situation_id
        end
        table.sort(custom_ids, function(a, b)
            return (tonumber(a) or 0) < (tonumber(b) or 0)
        end)
        for _, situation_id in ipairs(custom_ids) do
            local situation = custom_situations[situation_id]
            entries[#entries + 1] = {
                key = "custom:" .. situation_id,
                label = situation.name or ("Custom " .. situation_id),
                db = situation,
                profile_key = "custom:" .. situation_id,
                custom = true,
            }
        end
        return entries
    end

    get_situation_entry = function(situation_key)
        for _, entry in ipairs(get_situation_entries()) do
            if entry.key == situation_key then return entry end
        end
        return nil
    end

    local select_situation
    local rebuild_situation_list

    local function create_situation_panel(entry)
        local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        panel:SetSize(sliders_panel_width, UI.fishing_volumes_panel_height)
        row_grid:place_at(panel, 2, 1)
        panel:Hide()
        addon.ApplySettingsGroupOutline(panel)

        local trigger = nil
        if entry.trigger == "fishing" then
            trigger = {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = "fishing_focus_enabled",
                on_click = function(is_checked)
                    entry.db.enabled = is_checked == true
                    M.sync_fishing_focus_events()
                end,
            }
        elseif entry.trigger == "combat" then
            trigger = {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = "combat_volumes_enabled",
                on_click = function(is_checked)
                    entry.db.enabled = is_checked == true
                    M.sync_combat_volumes_events()
                end,
            }
        elseif entry.key ~= "fishing" and entry.key ~= "combat" then
            trigger = {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = entry.key == "quiet_custom"
                    and "quiet_custom_enabled"
                    or ("situation_" .. entry.key:gsub("[^%w_]", "_") .. "_enabled"),
                on_click = function(is_checked)
                    if M.set_manual_situation_enabled then
                        M.set_manual_situation_enabled(entry.key, is_checked == true)
                        M.sync_temporary_profile_controls()
                    else
                        entry.db.enabled = is_checked == true
                    end
                end,
            }
        end

        local title_bar, title = create_situation_header_bar(panel, entry.label, entry.profile_key, {
            label = "Use Normal",
            width = 86,
            on_click = function()
                if M.copy_current_sound_channels_to_situation then
                    M.copy_current_sound_channels_to_situation(entry.key)
                end
                M.sync_temporary_profile_controls()
                if entry.key == "fishing" then
                    M.resync_fishing_focus()
                elseif entry.key == "combat" then
                    M.resync_combat_volumes()
                elseif M.resync_manual_situation_profile then
                    M.resync_manual_situation_profile()
                end
            end,
        }, {
            trigger = trigger,
            on_play = function()
                if M.play_situation_preview then
                    M.play_situation_preview(entry.profile_key, entry.db and entry.db.test_sound)
                else
                    M.play_fishing_bobber_preview(entry.profile_key)
                end
            end,
        })

        if entry.custom or entry.renameable then
            local name_box = CreateFrame("EditBox", nil, title_bar, "InputBoxTemplate")
            name_box:SetSize(180, 18)
            name_box:SetPoint("CENTER", title_bar, "CENTER", 0, 0)
            name_box:SetAutoFocus(false)
            name_box:SetJustifyH("CENTER")
            name_box:SetMaxLetters(32)
            name_box:SetText(entry.label)
            name_box:SetTextColor(1, 0.82, 0, 1)
            if title then
                title:Hide()
            end
            name_box:SetScript("OnEditFocusGained", function(self)
                self:SetTextColor(1, 1, 1, 1)
            end)
            name_box:SetScript("OnEditFocusLost", function(self)
                self:SetTextColor(1, 0.82, 0, 1)
            end)
            name_box:SetScript("OnEnterPressed", function(self)
                if M.rename_situation then
                    M.rename_situation(entry.key, self:GetText())
                    entry.label = entry.db.name or entry.label
                    self:SetText(entry.label)
                    if title then
                        title:SetText(entry.label)
                    end
                    rebuild_situation_list()
                    select_situation(entry.key)
                end
                self:ClearFocus()
            end)
            name_box:SetScript("OnEscapePressed", function(self)
                self:SetText(entry.label)
                self:ClearFocus()
            end)
        end

        local situation_grid = addon.CreateSettingsGrid(panel, channel_grid_opts)
        local slider_name_key = entry.key:gsub("[^%w_]", "_")
        local slider_defaults = entry.db
        if entry.key == "fishing" then
            slider_defaults = focus_defaults
        elseif entry.key == "combat" then
            slider_defaults = combat_defaults
        elseif entry.key == "quiet_custom" then
            slider_defaults = quiet_custom_defaults
        end
        for i, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            local slider = addon.CreateSliderWithBox(
                addon_name .. "_Situation_" .. slider_name_key .. "_" .. channel.key,
                panel,
                channel.label,
                0,
                100,
                1,
                entry.db,
                channel.key,
                slider_defaults,
                function()
                    if entry.key == "fishing" then
                        M.resync_fishing_focus()
                    elseif entry.key == "combat" then
                        M.resync_combat_volumes()
                    elseif M.resync_manual_situation_profile then
                        M.resync_manual_situation_profile()
                    end
                end
            )
            slider:SetSize(UI.fishing_slider_width, 95)
            situation_grid:place_at(slider, 1, i)
            M.controls["situation_" .. entry.key .. "_" .. channel.key] = slider
            if entry.key == "fishing" then
                M.controls["fishing_focus_" .. channel.key] = slider
            elseif entry.key == "combat" then
                M.controls["combat_volumes_" .. channel.key] = slider
            end
        end

        return panel
    end

    selected_key = (M.get_db().last_situation_key and get_situation_entry(M.get_db().last_situation_key))
        and M.get_db().last_situation_key
        or "fishing"

    select_situation = function(situation_key)
        local entry = get_situation_entry(situation_key)
        if not entry then return end
        selected_key = situation_key
        M.get_db().last_situation_key = situation_key
        for _, row in ipairs(situation_rows) do
            local selected = row.situation_key == selected_key
            row.bg:SetShown(selected)
            row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
        end
        for _, panel in pairs(situation_panels) do
            panel:Hide()
        end
        if not situation_panels[situation_key] then
            situation_panels[situation_key] = create_situation_panel(entry)
        end
        situation_panels[situation_key]:Show()
        set_situation_help_text(entry)
        if entry.key == "fishing" then
            test_sound_dropdown:Hide()
        else
            local fallback = "bloodlust"
            entry.db.test_sound = M.get_valid_test_sound_key and M.get_valid_test_sound_key(entry.db.test_sound, fallback) or entry.db.test_sound
            test_sound_dropdown:SetValue(entry.db.test_sound)
            test_sound_dropdown:Show()
        end
    end

    rebuild_situation_list = function()
        for _, row in ipairs(situation_rows) do
            row:Hide()
        end
        situation_rows = {}
        local entries = get_situation_entries()
        for i, entry in ipairs(entries) do
            local row = CreateFrame("Button", nil, situation_list_panel)
            row:SetSize(UI.fishing_slider_width - 18, UI.list_row_height)
            row:SetPoint("TOPLEFT", situation_list_panel, "TOPLEFT", 9, -(10 + ((i - 1) * UI.list_row_height)))
            row.situation_key = entry.key

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
            row.bg:Hide()

            local row_hover = row:CreateTexture(nil, "HIGHLIGHT")
            row_hover:SetAllPoints()
            row_hover:SetColorTexture(1, 1, 1, 0.08)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", entry.custom and -24 or -8, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetText(entry.label)
            row:SetScript("OnClick", function()
                select_situation(entry.key)
            end)
            if entry.custom then
                local delete_button = CreateFrame("Button", nil, row, "UIPanelCloseButton")
                delete_button:SetSize(16, 16)
                delete_button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                delete_button:SetAlpha(0)

                row:SetScript("OnEnter", function()
                    delete_button:SetAlpha(1)
                end)
                row:SetScript("OnLeave", function()
                    delete_button:SetAlpha(0)
                end)
                delete_button:SetScript("OnEnter", function()
                    delete_button:SetAlpha(1)
                end)
                delete_button:SetScript("OnLeave", function()
                    delete_button:SetAlpha(0)
                end)

                local delete_key = entry.key
                local delete_label = entry.label
                delete_button:SetScript("OnClick", function()
                    StaticPopupDialogs["LSTWEEKS_DEL_CUSTOM_SITUATION"] = {
                        text = 'Delete custom situation "' .. delete_label .. '"?',
                        button1 = "Delete",
                        button2 = "Cancel",
                        OnAccept = function()
                            if situation_panels[delete_key] then
                                situation_panels[delete_key]:Hide()
                                situation_panels[delete_key] = nil
                            end
                            local was_enabled = delete_key ~= "quiet_custom"
                                and M.get_situation_profile_db
                                and M.get_situation_profile_db(delete_key)
                                and M.get_situation_profile_db(delete_key).enabled == true
                            if M.delete_custom_situation and M.delete_custom_situation(delete_key) then
                                if was_enabled and M.sync_manual_situation_profile then
                                    M.sync_manual_situation_profile()
                                end
                                selected_key = selected_key == delete_key and "fishing" or selected_key
                                rebuild_situation_list()
                                select_situation(get_situation_entry(selected_key) and selected_key or "fishing")
                            end
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("LSTWEEKS_DEL_CUSTOM_SITUATION")
                end)
            end
            situation_rows[#situation_rows + 1] = row
        end
    end

    local add_custom_button = CreateFrame("Button", nil, situation_list_panel, "UIPanelButtonTemplate")
    add_custom_button:SetSize(UI.fishing_slider_width - 18, 22)
    add_custom_button:SetPoint("BOTTOMLEFT", situation_list_panel, "BOTTOMLEFT", 9, 10)
    add_custom_button:SetText("+ Custom")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(add_custom_button)
    end
    add_custom_button:SetScript("OnClick", function()
        if M.create_custom_situation then
            local situation_key = M.create_custom_situation()
            rebuild_situation_list()
            select_situation(situation_key)
        end
    end)

    rebuild_situation_list()
    select_situation(selected_key)
    refresh_current_values()
end

--#endregion SITUATIONS TAB ====================================================

--#region SPECIFICS TAB =========================================================

local function build_specifics_tab(parent)
    local db = M.get_db()
    local targets = M.get_ordered_sound_targets()
    local selected_key = (db.last_sound_key and M.SOUND_TARGETS and M.SOUND_TARGETS[db.last_sound_key]) and db.last_sound_key or (targets[1] and targets[1].key)
    local target_rows = {}
    local slider_panels = {}

    local slider_x = UI.pad_x + UI.list_width + 20
    local help_panel = create_specifics_help_panel(parent, parent, "TOPLEFT", UI.pad_x, UI.pad_y)

    local target_list_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    target_list_panel:SetSize(UI.list_width, 260)
    target_list_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y - help_panel:GetHeight() - 16)
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
                slider_panels[selected_key]:ClearAllPoints()
                slider_panels[selected_key]:SetPoint("TOPLEFT", parent, "TOPLEFT", slider_x, UI.pad_y - help_panel:GetHeight() - 16)
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

--#endregion SPECIFICS TAB ======================================================

--#region SETTINGS CONSTRUCTION ================================================

function M.BuildSettings(parent)
    local db = M.get_db()
    local tabs = {}
    local tab_panels = {}

    local tab_defs = {
        { label = "General", builder = build_general_tab },
        { label = "Specifics", builder = build_specifics_tab },
        { label = "Situations", builder = build_situations_tab },
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
                if tab_defs[i] and tab_defs[i].builder == build_situations_tab and M.controls.fishing_focus_refresh_current then
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
