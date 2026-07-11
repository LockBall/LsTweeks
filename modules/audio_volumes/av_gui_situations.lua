-- Situations tab UI for the Audio Volumes module.
local addon_name, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes
local STRINGS = M.GUI_STRINGS
local UI = M.GUI_LAYOUT

--#region CONTROL SYNCHRONIZATION ==============================================

local function set_checked_silently(control, value)
    if control and control.SetCheckedSilently then
        control:SetCheckedSilently(value == true)
    end
end

local function get_situation_control_key(situation_key, field)
    return "situation_" .. situation_key .. "_" .. field
end

function M.clear_custom_situation_controls(situation_key)
    M.controls[get_situation_control_key(situation_key, "enabled")] = nil
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        M.controls[get_situation_control_key(situation_key, channel.key)] = nil
    end
end

function M.sync_temporary_profile_controls()
    local focus_db = M.get_fishing_focus_db()
    local combat_db = M.get_combat_volumes_db()
    local quiet_custom_db = M.get_quiet_custom_db and M.get_quiet_custom_db() or nil
    set_checked_silently(M.controls.fishing_focus_enabled, focus_db.enabled)
    set_checked_silently(M.controls.combat_volumes_enabled, combat_db.enabled)
    if quiet_custom_db then
        set_checked_silently(M.controls.quiet_custom_enabled, quiet_custom_db.enabled)
    end
    for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        local slider = M.controls["fishing_focus_" .. channel.key]
        if slider and slider.SetValueSilently then
            slider:SetValueSilently(focus_db[channel.key])
        end
        local combat_slider = M.controls["combat_volumes_" .. channel.key]
        if combat_slider and combat_slider.SetValueSilently then
            combat_slider:SetValueSilently(combat_db[channel.key])
        end
        local quiet_slider = M.controls["situation_quiet_custom_" .. channel.key]
        if quiet_slider and quiet_slider.SetValueSilently and quiet_custom_db then
            quiet_slider:SetValueSilently(quiet_custom_db[channel.key])
        end
    end
    local custom_situations = M.get_custom_situations_db and M.get_custom_situations_db() or {}
    for situation_id, situation in pairs(custom_situations) do
        local situation_key = "custom:" .. situation_id
        local enabled_control = M.controls[get_situation_control_key(situation_key, "enabled")]
        set_checked_silently(enabled_control, situation.enabled)
        for _, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
            local slider = M.controls[get_situation_control_key(situation_key, channel.key)]
            if slider and slider.SetValueSilently then
                slider:SetValueSilently(situation[channel.key])
            end
        end
    end
    if M.controls.fishing_focus_refresh_current then
        M.controls.fishing_focus_refresh_current()
    end
end

--#endregion CONTROL SYNCHRONIZATION ===========================================

--#region SITUATIONS TAB ========================================================

local function create_situation_header_bar(parent, title_text, play_profile_key, action, opts)
    opts = opts or {}
    local title_bar, title = addon.CreateSettingsGroupTitleBar(parent, title_text)

    if opts.enable_control then
        local enable_row = addon.CreateCheckbox(
            title_bar,
            opts.enable_control.label or "Enable",
            opts.enable_control.checked == true,
            opts.enable_control.on_click
        )
        enable_row:SetPoint("LEFT", title_bar, "LEFT", 6, 0)
        if opts.enable_control.control_key then
            M.controls[opts.enable_control.control_key] = enable_row
        end
        title_bar._lstweeks_enable_row = enable_row
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

function M.BuildSituationsTab(parent)
    local db = M.get_db()
    local selection_db_key = "last_situation_key"
    local fallback_selection_key = "fishing"
    local focus_db = M.get_fishing_focus_db()
    local combat_db = M.get_combat_volumes_db()
    local quiet_custom_db = M.get_quiet_custom_db()
    local focus_defaults = {}
    local combat_defaults = {}
    local quiet_custom_defaults = {}
    local control_scope = "Situation"
    local slider_count = #(M.FISHING_FOCUS_CHANNELS or {})
    local slider_col_align = {}
    for i = 1, slider_count do slider_col_align[i] = "left" end
    local situation_panels = {}
    local situation_entries = {}
    local selected_key = nil
    local get_situation_entry = nil
    local select_situation
    local rebuild_situation_list
    local handle_delete_situation
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
        col_align = slider_col_align,
    })

    local situation_list_panel = addon.CreateGroupColumn(parent, {
        width = UI.fishing_slider_width,
        height = (UI.fishing_volumes_panel_height * 2) + 16,
        pad = 9,
        on_select = function(entry)
            if select_situation then
                select_situation(entry.key, true)
            end
        end,
        on_delete = function(entry)
            if handle_delete_situation then
                handle_delete_situation(entry)
            end
        end,
    })
    situation_grid:place_at(situation_list_panel, 3, 1)

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
        addon_name .. "_" .. control_scope .. "TestSound",
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
            if slider and slider.SetValueSilently then
                slider:SetValueSilently(current_percent)
            end
        end
    end
    parent._lstweeks_refresh_current = refresh_current_values
    M.controls.fishing_focus_refresh_current = refresh_current_values

    local channel_grid_opts = {
        column_count = slider_count,
        col_width = UI.fishing_slider_width,
        column_gap_x = UI.fishing_slider_gap,
        col_offset = UI.fishing_slider_pad_x,
        row_start = UI.fishing_slider_row_start,
        row_heights = { UI.fishing_slider_row_height },
        col_align = slider_col_align,
    }
    local current_grid = addon.CreateSettingsGrid(current_panel, channel_grid_opts)

    local function resync_situation_runtime(entry)
        if entry.key == "fishing" then
            M.resync_fishing_focus()
        elseif entry.key == "combat" then
            M.resync_combat_volumes()
        elseif M.resync_manual_situation_profile then
            M.resync_manual_situation_profile(entry.key)
        end
    end

    for i, channel in ipairs(M.FISHING_FOCUS_CHANNELS or {}) do
        current_values[channel.key] = M.get_current_sound_channel_percent(channel)
        current_defaults[channel.key] = current_values[channel.key]
        combat_defaults[channel.key] = current_values[channel.key]
        quiet_custom_defaults[channel.key] = 25

        local current_slider = addon.CreateSliderWithBox(
            addon_name .. "_" .. control_scope .. "NormalSound_" .. channel.key,
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
        current_grid:place_at(current_slider, 1, i)
        current_sliders[channel.key] = current_slider
        M.controls["normal_volume_" .. channel.key] = current_slider
    end

    local function build_situation_entries()
        local entries = {}
        entries[#entries + 1] = { label = "Triggered", header = true, group = "triggered", default_key = "fishing" }
        entries[#entries + 1] = { key = "fishing", label = "Fishing", db = focus_db, profile_key = "fishing", trigger = "fishing", group = "triggered" }
        entries[#entries + 1] = { key = "combat", label = "Combat", db = combat_db, profile_key = "combat", trigger = "combat", group = "triggered" }
        entries[#entries + 1] = { label = "Quick Picks", header = true, group = "quick_picks", default_key = "quiet_custom" }
        entries[#entries + 1] = { key = "quiet_custom", label = quiet_custom_db.name or "Quiet Custom", db = quiet_custom_db, profile_key = "quiet_custom", renameable = true, group = "quick_picks" }
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
                deletable = true,
                group = "quick_picks",
            }
        end
        return entries
    end

    get_situation_entry = function(situation_key)
        for _, entry in ipairs(situation_entries) do
            if not entry.header and entry.key == situation_key then return entry end
        end
        return nil
    end

    local function create_enable_control(entry)
        if entry.trigger == "fishing" then
            return {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = "fishing_focus_enabled",
                on_click = function(is_checked)
                    entry.db.enabled = is_checked == true
                    M.sync_fishing_focus_events()
                end,
            }
        elseif entry.trigger == "combat" then
            return {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = "combat_volumes_enabled",
                on_click = function(is_checked)
                    entry.db.enabled = is_checked == true
                    M.sync_combat_volumes_events()
                end,
            }
        elseif entry.key ~= "fishing" and entry.key ~= "combat" then
            return {
                label = "Enable",
                checked = entry.db.enabled == true,
                control_key = entry.key == "quiet_custom"
                    and "quiet_custom_enabled"
                    or get_situation_control_key(entry.key, "enabled"),
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
        return nil
    end

    local function create_situation_name_box(title_bar, title, entry)
        if not (entry.custom or entry.renameable) then return end

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

    local function get_situation_slider_defaults(entry)
        if entry.key == "fishing" then
            return focus_defaults
        elseif entry.key == "combat" then
            return combat_defaults
        elseif entry.key == "quiet_custom" then
            return quiet_custom_defaults
        end
        return entry.db
    end

    local function create_situation_sliders(panel, entry)
        local sliders_grid = addon.CreateSettingsGrid(panel, channel_grid_opts)
        local slider_name_key = entry.key:gsub("[^%w_]", "_")
        local slider_defaults = get_situation_slider_defaults(entry)

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
                    resync_situation_runtime(entry)
                end
            )
            sliders_grid:place_at(slider, 1, i)
            M.controls[get_situation_control_key(entry.key, channel.key)] = slider
            if entry.key == "fishing" then
                M.controls["fishing_focus_" .. channel.key] = slider
            elseif entry.key == "combat" then
                M.controls["combat_volumes_" .. channel.key] = slider
            end
        end
    end

    local function sync_test_sound_dropdown(entry)
        if entry.key == "fishing" then
            test_sound_dropdown:Hide()
            return
        end

        local fallback = "bloodlust"
        entry.db.test_sound = M.get_valid_test_sound_key and M.get_valid_test_sound_key(entry.db.test_sound, fallback) or entry.db.test_sound
        test_sound_dropdown:SetValue(entry.db.test_sound)
        test_sound_dropdown:Show()
    end

    local function create_situation_panel(entry)
        local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        panel:SetSize(sliders_panel_width, UI.fishing_volumes_panel_height)
        row_grid:place_at(panel, 2, 1)
        panel:Hide()
        addon.ApplySettingsGroupOutline(panel)

        local title_bar, title = create_situation_header_bar(panel, entry.label, entry.profile_key, {
            label = "Use Normal",
            width = 86,
            on_click = function()
                if M.copy_current_sound_channels_to_situation then
                    M.copy_current_sound_channels_to_situation(entry.key)
                end
                M.sync_temporary_profile_controls()
                resync_situation_runtime(entry)
            end,
        }, {
            enable_control = create_enable_control(entry),
            on_play = function()
                if M.play_situation_preview then
                    M.play_situation_preview(entry.profile_key, entry.db and entry.db.test_sound)
                else
                    M.play_fishing_bobber_preview(entry.profile_key)
                end
            end,
        })

        create_situation_name_box(title_bar, title, entry)
        create_situation_sliders(panel, entry)

        return panel
    end

    situation_entries = build_situation_entries()
    selected_key = (db[selection_db_key] and get_situation_entry(db[selection_db_key]))
        and db[selection_db_key]
        or fallback_selection_key

    select_situation = function(situation_key, from_group_column)
        local entry = get_situation_entry(situation_key)
        if not entry then return end
        selected_key = situation_key
        db[selection_db_key] = situation_key
        if not from_group_column then
            situation_list_panel:Select(situation_key, true)
        end
        for _, panel in pairs(situation_panels) do
            panel:Hide()
        end
        if not situation_panels[situation_key] then
            situation_panels[situation_key] = create_situation_panel(entry)
        end
        situation_panels[situation_key]:Show()
        set_situation_help_text(entry)
        sync_test_sound_dropdown(entry)
    end

    rebuild_situation_list = function()
        situation_entries = build_situation_entries()
        situation_list_panel:SetEntries(situation_entries)
    end

    handle_delete_situation = function(entry)
        if not (entry and entry.deletable) then return end
        local delete_key = entry.key
        local delete_label = entry.label
        StaticPopupDialogs["LSTWEEKS_DEL_CUSTOM_SITUATION"] = {
            text = 'Delete custom situation "' .. delete_label .. '"?',
            button1 = "Delete",
            button2 = "Cancel",
            OnAccept = function()
                if situation_panels[delete_key] then
                    situation_panels[delete_key]:Hide()
                    situation_panels[delete_key] = nil
                end
                if M.delete_custom_situation and M.delete_custom_situation(delete_key) then
                    selected_key = selected_key == delete_key and "quiet_custom" or selected_key
                    rebuild_situation_list()
                    select_situation(get_situation_entry(selected_key) and selected_key or fallback_selection_key)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("LSTWEEKS_DEL_CUSTOM_SITUATION")
    end

    situation_list_panel:SetGroupAction("quick_picks", "+ Custom", function()
        if M.create_custom_situation then
            local situation_key = M.create_custom_situation()
            db[selection_db_key] = situation_key
            rebuild_situation_list()
            select_situation(situation_key)
        end
    end, {
        width = UI.fishing_slider_width - 18,
        x = 9,
        position = "bottom",
    })

    rebuild_situation_list()
    select_situation(selected_key)
    refresh_current_values()
end

--#endregion SITUATIONS TAB ====================================================
