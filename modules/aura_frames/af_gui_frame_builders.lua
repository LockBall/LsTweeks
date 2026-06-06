-- Content panel builders for Aura Frames settings.
-- Builds the General tab and preset Buff/CDM frame settings panels.

local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function get_timer_font_options()
    local options = {}
    local defs = M.get_number_font_options()
    for _, def in ipairs(defs) do
        options[#options + 1] = {
            value = def.key,
            text = def.label,
            font_path = def.path,
            font_size = def.size,
            font_flags = def.flags,
        }
    end
    return options
end

local CANCEL_MODIFIER_OPTIONS = {
    { value = "OFF", text = "OFF" },
    { value = "CTRL", text = "CTRL" },
    { value = "ALT", text = "ALT" },
    { value = "SHIFT", text = "SHIFT" },
}

local function normalize_cancel_modifier(value)
    if value == "OFF" or value == "CTRL" or value == "ALT" or value == "SHIFT" then
        return value
    end
    return "CTRL"
end

local function create_bound_checkbox_control(parent, label, value_table, value_key, grid, row, column, control_key, on_change, default_update, after_checked, after_unchecked)
    local container, checkbox, _ = addon.CreateCheckbox(parent, label, value_table[value_key],
        function(is_checked)
            value_table[value_key] = is_checked
            if is_checked and after_checked then
                after_checked()
            end
            if not is_checked and after_unchecked then
                after_unchecked()
            end
            if on_change then
                on_change(is_checked)
            elseif default_update then
                default_update()
            end
        end
    )
    grid:place_at(container, row, column)
    if control_key then
        M.controls[control_key] = checkbox
    end
    return container, checkbox
end

local function create_snap_to_grid_checkbox(parent, anchor_to)
    local container, checkbox, _ = addon.CreateCheckbox(parent, "Snap to Grid", M.db.snap_to_grid == true,
        function(is_checked)
            M.db.snap_to_grid = is_checked
        end
    )
    container:SetPoint("TOPLEFT", anchor_to, "BOTTOMLEFT", 0, -4)
    M.controls.snap_to_grid_checkbox = checkbox
    return container, checkbox
end

-- Preset and custom panels use the same normalized presentation contract.
-- These config builders map different backing stores to common logical keys
-- so the shared panel builder does not branch on source type for common controls.
local function make_preset_frame_settings_config(data)
    local cat = data.show_key:sub(6)
    if M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[cat] and M.refresh_cdm_default_positions then
        M.refresh_cdm_default_positions()
    end
    return {
        id = cat,
        is_custom = false,
        value_table = M.db,
        defaults_table = M.defaults,
        frame_show_key = data.show_key,
        scale_key = data.scale_key,
        position_table = M.db.positions[cat],
        default_position = M.defaults.positions[cat],
        keys = {
            show = data.show_key,
            move = data.move_key,
            timer = data.timer_key,
            timer_swipe = "timer_swipe_" .. cat,
            tooltip = "tooltip_" .. cat,
            bg = data.bg_key,
            scale = data.scale_key,
            spacing = data.spacing_key,
            width = "width_" .. cat,
            bg_color = "bg_color_" .. cat,
            color = "color_" .. cat,
            bar_text_color = "bar_text_color_" .. cat,
            bar_bg_color = "bar_bg_color_" .. cat,
            fade_ooc = "fade_ooc_" .. cat,
            ooc_alpha = "ooc_alpha_" .. cat,
            fade_delay = "fade_delay_" .. cat,
            fade_length = "fade_length_" .. cat,
            bar_mode = "bar_mode_" .. cat,
            growth = "growth_" .. cat,
            max_icons = "max_icons_" .. cat,
            test_aura = "test_aura_" .. cat,
            timer_number_font = "timer_number_font_" .. cat,
            timer_number_font_size = "timer_number_font_size_" .. cat,
            timer_number_font_bold = "timer_number_font_bold_" .. cat,
            timer_color = "timer_color_" .. cat,
        },
    }
end

local function make_custom_frame_settings_config(entry)
    local id = entry.id
    local default_position = (M.get_default_custom_frame_position and M.get_default_custom_frame_position(id))
        or M.CUSTOM_FRAME_TEMPLATE.position
    entry.position = entry.position or {
        point = default_position.point,
        x = default_position.x,
        y = default_position.y,
    }
    if entry.tooltip == nil then entry.tooltip = true end
    if entry.timer_swipe == nil then entry.timer_swipe = true end
    if entry.fade_ooc == nil then entry.fade_ooc = false end
    if entry.ooc_alpha == nil then entry.ooc_alpha = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA end
    if entry.fade_delay == nil then entry.fade_delay = M.DEFAULT_OOC_FADE_DELAY end
    if entry.fade_length == nil then entry.fade_length = M.DEFAULT_OOC_FADE_LENGTH end
    return {
        id = id,
        is_custom = true,
        value_table = entry,
        defaults_table = M.CUSTOM_FRAME_TEMPLATE,
        frame_show_key = "show_" .. id,
        scale_key = "scale",
        position_table = entry.position,
        default_position = default_position,
        keys = {
            show = "show",
            move = "move",
            timer = "timer",
            timer_swipe = "timer_swipe",
            tooltip = "tooltip",
            bg = "bg",
            scale = "scale",
            spacing = "spacing",
            width = "width",
            bg_color = "bg_color",
            color = "color",
            bar_text_color = "bar_text_color",
            bar_bg_color = "bar_bg_color",
            fade_ooc = "fade_ooc",
            ooc_alpha = "ooc_alpha",
            fade_delay = "fade_delay",
            fade_length = "fade_length",
            bar_mode = "bar_mode",
            growth = "growth",
            max_icons = "max_icons",
            test_aura = "test_aura",
            timer_number_font = "timer_number_font",
            timer_number_font_size = "timer_number_font_size",
            timer_number_font_bold = "timer_number_font_bold",
            timer_color = "timer_color",
        },
    }
end

local function frame_setting_key(frame_config, logical_key)
    return frame_config.keys[logical_key]
end

local function create_frame_color_picker(parent, frame_config, grid, logical_key, has_alpha, label, row, column, update, control_key)
    local key = frame_setting_key(frame_config, logical_key)
    local picker = addon.CreateColorPicker(parent, frame_config.value_table, key, has_alpha, label, frame_config.defaults_table, update)
    grid:place_at(picker, row, column, "picker")
    if control_key then M.controls[control_key] = picker end
    return picker
end

local function create_frame_slider(parent, frame_config, name_suffix, label, min_v, max_v, step, logical_key, on_change)
    local key = frame_setting_key(frame_config, logical_key)
    return addon.CreateSliderWithBox(
        addon_name .. frame_config.id .. name_suffix,
        parent,
        label,
        min_v,
        max_v,
        step,
        frame_config.value_table,
        key,
        frame_config.defaults_table,
        on_change
    )
end

local function create_frame_timer_controls(parent, frame_config, grid, update, labels)
    local id = frame_config.id
    local control_prefix = labels.control_prefix or id
    local row = labels.row or 4
    local dropdown_name = labels.dropdown_name or (addon_name .. id .. "TimerFont")
    local font_size_name = labels.font_size_name or (addon_name .. id .. "TimerFontSize")
    local timer_text_key = frame_setting_key(frame_config, "timer")
    local timer_font_key = frame_setting_key(frame_config, "timer_number_font")
    local timer_font_size_key = frame_setting_key(frame_config, "timer_number_font_size")
    local timer_bold_key = frame_setting_key(frame_config, "timer_number_font_bold")
    local timer_color_key = frame_setting_key(frame_config, "timer_color")

    local function refresh_fonts()
        M.apply_number_font_to_all()
        update()
    end

    local timer_text_container = create_bound_checkbox_control(
        parent,
        labels.timer_text_label or "Timer Text",
        frame_config.value_table,
        timer_text_key,
        grid,
        row,
        1,
        labels.timer_text_control_key or timer_text_key,
        nil,
        update
    )

    local timer_bold_container = create_bound_checkbox_control(
        parent,
        labels.bold_label or "Bold",
        frame_config.value_table,
        timer_bold_key,
        grid,
        row,
        1,
        labels.bold_control_key or timer_bold_key,
        refresh_fonts,
        update
    )
    timer_bold_container:ClearAllPoints()
    timer_bold_container:SetPoint("TOPLEFT", timer_text_container, "BOTTOMLEFT", 0, -4)

    local timer_font = M.CreateListDropdown(dropdown_name, parent, labels.font_label or "Font", get_timer_font_options(),
        function()
            return frame_config.value_table[timer_font_key] or M.db.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY
        end,
        function(value)
            frame_config.value_table[timer_font_key] = value
            refresh_fonts()
        end,
        labels.font_dropdown_width or 120
    )
    grid:place_at(timer_font, row, 3, nil, { width = labels.font_dropdown_width or 120, y_offset = labels.font_y_offset or -15 })
    M.controls[labels.font_control_key or ("timer_number_font_dropdown_" .. control_prefix)] = timer_font

    local font_size_slider = addon.CreateSliderWithBox(
        font_size_name,
        parent,
        labels.font_size_label or "Font Size",
        8,
        14,
        0.5,
        frame_config.value_table,
        timer_font_size_key,
        frame_config.defaults_table,
        refresh_fonts
    )
    grid:place_at(font_size_slider, row, 4)
    M.controls[labels.font_size_control_key or ("timer_number_font_size_slider_" .. control_prefix)] = font_size_slider

    local timer_color_picker = addon.CreateColorPicker(
        parent,
        frame_config.value_table,
        timer_color_key,
        false,
        labels.color_label or "Color",
        frame_config.defaults_table,
        refresh_fonts
    )
    grid:place_at(timer_color_picker, row, 2, "picker")
    M.controls[labels.color_control_key or ("timer_color_picker_" .. control_prefix)] = timer_color_picker

    return {
        timer_text_container = timer_text_container,
        timer_font = timer_font,
        font_size_slider = font_size_slider,
    }
end

local function create_frame_position_controls(parent, frame_config, grid, update, options)
    local id = frame_config.id
    local frame_show_key = options.frame_show_key or frame_config.frame_show_key
    local show_key = frame_setting_key(frame_config, "show")
    local move_key = frame_setting_key(frame_config, "move")
    local width_key = frame_setting_key(frame_config, "width")
    local scale_key = options.scale_key or frame_config.scale_key
    local value_table = frame_config.value_table
    local defaults_table = frame_config.defaults_table
    local position_table = frame_config.position_table
    local default_position = frame_config.default_position
    local control_prefix = options.control_prefix or id
    local row = options.row or 1

    local function update_frame_position(axis, value)
        local f = M.frames[frame_show_key]
        if f and value ~= nil then
            M.set_saved_frame_position_axis(f, axis, value, scale_key)
        end
    end

    local move_container, move_cb = create_bound_checkbox_control(
        parent,
        "Move Mode",
        value_table,
        move_key,
        grid,
        row,
        1,
        options.move_control_key,
        function(is_checked)
            if is_checked then
                local enable_cb = M.controls and M.controls[options.show_control_key]
                if enable_cb and enable_cb.SetChecked and not enable_cb:GetChecked() then
                    enable_cb:SetChecked(true)
                    value_table[show_key] = true
                end
            end
            update()
        end,
        update
    )

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. id .. (options.x_name_suffix or "XPos"),
        parent,
        "X Position",
        -1000,
        1000,
        1,
        position_table,
        "x",
        default_position
    )
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("x", value)
    end)
    if options.x_control_key then M.controls[options.x_control_key] = x_slider end

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. id .. (options.y_name_suffix or "YPos"),
        parent,
        "Y Position",
        -1000,
        1000,
        1,
        position_table,
        "y",
        default_position
    )
    y_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("y", value)
    end)
    if options.y_control_key then M.controls[options.y_control_key] = y_slider end

    local width_slider = create_frame_slider(
        parent,
        frame_config,
        options.width_name_suffix or "Width",
        "Width",
        M.MIN_FRAME_WIDTH,
        M.MAX_FRAME_WIDTH,
        1,
        "width"
    )
    width_slider.slider:HookScript("OnValueChanged", function(_, value)
        local f = M.frames[frame_show_key]
        if not f then return end
        f:SetWidth(math.floor(value + 0.5))
        update()
    end)
    if options.width_control_key then M.controls[options.width_control_key] = width_slider end

    grid:place_at(x_slider, row, 2)
    grid:place_at(y_slider, row, 3)
    grid:place_at(width_slider, row, 4)

    local snap_container = create_snap_to_grid_checkbox(parent, move_container)

    M.create_move_reset_button(parent, snap_container, {
        width = grid.reset_btn_width,
        on_click = function()
            local f = M.frames[frame_show_key]
            if not f then return end
            local reset_default_position = default_position
            if M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[id] and M.refresh_cdm_default_positions then
                M.refresh_cdm_default_positions()
            elseif frame_config.is_custom and M.get_default_custom_frame_position then
                reset_default_position = M.get_default_custom_frame_position(id)
            end
            M.reset_frame_move_placement(f, {
                default_position = reset_default_position,
                default_width = defaults_table[width_key] or M.DEFAULT_FRAME_WIDTH,
                width_table = value_table,
                width_key = width_key,
                scale_key = scale_key,
                x_slider = x_slider,
                y_slider = y_slider,
                width_slider = width_slider,
                update = update,
            })
        end,
    })

    local function sync_xy_sliders_to_frame()
        local f = M.frames[frame_show_key]
        if not (f and x_slider and y_slider and x_slider.slider and y_slider.slider) then return end
        local pos = M.get_frame_position_table(f) or position_table
        if pos and pos.x ~= nil and pos.y ~= nil then
            x_slider.slider:SetValue(pos.x)
            y_slider.slider:SetValue(pos.y)
        end
    end

    if options.sync_on_drag_stop then
        local f = M.frames[frame_show_key]
        if f then
            for _, tb in ipairs({ f.title_bar, f.bottom_title_bar }) do
                if tb then
                    tb._lstweeks_sync_xy_sliders = sync_xy_sliders_to_frame
                    if not tb._lstweeks_sync_xy_sliders_hooked then
                        tb._lstweeks_sync_xy_sliders_hooked = true
                        tb:HookScript("OnDragStop", function(self)
                            if self._lstweeks_sync_xy_sliders then
                                self._lstweeks_sync_xy_sliders()
                            end
                        end)
                    end
                end
            end
        end
    end

    return {
        move_container = move_container,
        move_checkbox = move_cb,
        x_slider = x_slider,
        y_slider = y_slider,
        width_slider = width_slider,
        sync_xy_sliders_to_frame = sync_xy_sliders_to_frame,
    }
end

function M.build_general_tab(p)
    -- Manual layout for General tab

    -- Blizzard Buff & Debuff Enable Frames Section
    local enable_panel = CreateFrame("Frame", nil, p, "BackdropTemplate")
    enable_panel:SetSize(150, 45)
    enable_panel:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    M.apply_tooltip_panel_backdrop(enable_panel, 0.08, 0.08, 0.08, 0.85, 0.3, 0.3, 0.3, 1)

    local panel_title = enable_panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel_title:SetText("Enable Blizz Frame")
    panel_title:SetPoint("TOP", enable_panel, "TOP", 0, -5)

    -- Blizzard Buff Frame Checkbox (checked = enabled)
    local enable_blizz_buffs_container, enable_blizz_buffs_cb, _ = addon.CreateCheckbox(enable_panel, "Buff", M.db.enable_blizz_buffs,
        function(is_checked)
            M.db.enable_blizz_buffs = is_checked
            M.toggle_blizz_buffs(not is_checked)
        end
    )
    enable_blizz_buffs_container:SetPoint("CENTER", enable_panel, "CENTER", -40, -5)
    M.controls["enable_blizz_buffs"] = enable_blizz_buffs_cb

    -- Blizzard Debuff Frame Checkbox (checked = enabled)
    local enable_blizz_debuffs_container, enable_blizz_debuffs_cb, _ = addon.CreateCheckbox(
        enable_panel,
        "Debuff",
        M.db.enable_blizz_debuffs,
        function(is_checked)
            M.db.enable_blizz_debuffs = is_checked
            M.toggle_blizz_debuffs(not is_checked)
        end
    )
    enable_blizz_debuffs_container:SetPoint("CENTER", enable_panel, "CENTER", 35, -5)
    M.controls["enable_blizz_debuffs"] = enable_blizz_debuffs_cb

    -- Short Buff Threshold slider
    local threshold = addon.CreateSliderWithBox(addon_name.."Tslider", p, "Short Buff Threshold", 10, 300, 10, M.db, "short_threshold", M.defaults, function()
        local frames_list = M.frames_list
        if not frames_list then return end
        for i = 1, #frames_list do
            local v = frames_list[i]
            local params = v.update_params
            if params then
                M.update_auras(v, params.show_key, params.move_key, params.timer_key, params.bg_key,
                    params.scale_key, params.spacing_key, params.aura_filter)
            end
        end
    end)
    threshold:SetPoint("TOPLEFT", enable_panel, "BOTTOMLEFT", 0, -24)

    local cancel_modifier = addon.CreateDropdown(addon_name.."CancelModifier", p, "Cancel Modifier", CANCEL_MODIFIER_OPTIONS, {
        width = 120,
        get_value = function()
            return normalize_cancel_modifier(M.db.cancel_modifier or M.defaults.cancel_modifier)
        end,
        on_select = function(value)
            M.db.cancel_modifier = normalize_cancel_modifier(value)
        end,
    })
    cancel_modifier:SetPoint("LEFT", threshold, "RIGHT", 35, 0)
    M.controls.cancel_modifier_dropdown = cancel_modifier

    -- Show Bar Section Outlines Checkbox
    local outlines_container, outlines_btn, _ = addon.CreateCheckbox(p, "Show Bar Section Outlines", M.db.show_bar_section_outlines == true,
        function(is_checked)
            M.db.show_bar_section_outlines = is_checked
            if addon.aura_frames and addon.aura_frames.refresh_section_outlines then
                addon.aura_frames.refresh_section_outlines()
            end
        end
    )
    outlines_container:SetPoint("TOPLEFT", threshold, "BOTTOMLEFT", 0, -18)
    M.controls.show_bar_section_outlines_checkbox = outlines_btn

    -- reset panel
    local resetPanel = addon.CreateModuleReset(p, M.db, M.defaults, {
        preserve_label = "Keep Profiles",
        preserve_default = true,
        preserve_keys = { "profiles", "last_profile_name" },
        before_reset = function()
            if M.refresh_cdm_default_positions then
                M.refresh_cdm_default_positions()
            end
        end,
        after_reset = M.on_reset_complete,
    })
    resetPanel:SetPoint("TOPLEFT", outlines_container, "BOTTOMLEFT", 0, -16)
end

-- Custom filtered frame panel builders.
-- These back the Filters group in the Frames tree.

local function update_custom_frame(entry)
    if not (entry and entry.id and M.frames) then return end
    local show_key = "show_" .. entry.id
    local frame = M.frames[show_key]
    if not frame then return end
    local aura_filter = M.get_custom_aura_filter(entry)
    frame.update_params.aura_filter = aura_filter
    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", aura_filter)
end

function M.update_custom_frame_title(entry)
    if not (entry and entry.id and M.frames) then return end
    local frame = M.frames["show_" .. entry.id]
    if not frame then return end
    if frame.title_bar and frame.title_bar.label_text then
        frame.title_bar.label_text:SetText(entry.name or entry.id)
    end
    if frame.bottom_title_bar and frame.bottom_title_bar.label_text then
        frame.bottom_title_bar.label_text:SetText(entry.name or entry.id)
    end
end

local function create_frame_name_control(parent, entry)
    local id = entry.id
    local name_container = CreateFrame("Frame", nil, parent)
    name_container:SetSize(130, 24)
    local name_label = name_container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name_label:SetPoint("BOTTOM", name_container, "TOP", 0, 2)
    name_label:SetText("Frame Name")
    local name_box = CreateFrame("EditBox", nil, name_container, "InputBoxTemplate")
    name_box:SetSize(130, 22)
    name_box:SetPoint("TOP", name_container, "TOP", 0, 0)
    name_box:SetAutoFocus(false)
    name_box:SetMaxLetters(32)
    name_box:SetText(entry.name or id)
    local function commit_name()
        local new_name = (name_box:GetText() or ""):match("^%s*(.-)%s*$")
        if not new_name or new_name == "" then
            name_box:SetText(entry.name or id)
            name_box:ClearFocus()
            return
        end
        if new_name ~= entry.name then
            entry.name = new_name
            M.update_custom_frame_title(entry)
            if M.on_custom_frame_renamed then M.on_custom_frame_renamed(id, new_name) end
        end
        name_box:ClearFocus()
    end
    name_box:SetScript("OnEnterPressed", commit_name)
    name_box:SetScript("OnEditFocusLost", commit_name)
    return name_container
end

local function create_growth_dropdown(parent, frame_config, update)
    local id = frame_config.id
    local options = {}
    for _, dir in ipairs({ "RIGHT", "LEFT", "DOWN", "UP" }) do
        options[#options + 1] = { value = dir, text = dir }
    end
    return addon.CreateDropdown(addon_name .. id .. "Growth", parent, "Growth Direction", options, {
        width = 106,
        get_value = function()
            return frame_config.value_table[frame_setting_key(frame_config, "growth")] or "DOWN"
        end,
        on_select = function(value)
            frame_config.value_table[frame_setting_key(frame_config, "growth")] = value
            update()
        end,
    })
end

-- Shared frame settings conductor. Builds preset, CDM, and custom frame panels
-- in visual grid order; source-specific controls are injected through opts.
local function build_frame_settings_panel(parent, frame_config, opts)
    opts = opts or {}
    local update = opts.update
    local grid = M.create_settings_grid(parent)
    local value_table = frame_config.value_table

    local function control_key(logical_key)
        if opts.control_key_prefix then
            return opts.control_key_prefix .. frame_setting_key(frame_config, logical_key)
        end
        return frame_setting_key(frame_config, logical_key)
    end

    local function bound_cb(label, logical_key, row, column, on_change, custom_control_key, after_checked, after_unchecked)
        local key = frame_setting_key(frame_config, logical_key)
        return create_bound_checkbox_control(
            parent,
            label,
            value_table,
            key,
            grid,
            row,
            column,
            custom_control_key or control_key(logical_key),
            on_change,
            update,
            after_checked,
            after_unchecked
        )
    end

    local function bound_raw_cb(label, value_key, row, column, on_change, custom_control_key)
        return create_bound_checkbox_control(
            parent,
            label,
            value_table,
            value_key,
            grid,
            row,
            column,
            custom_control_key or value_key,
            on_change,
            update
        )
    end

    local function bound_picker(logical_key, has_alpha, label, row, column, custom_control_key)
        return create_frame_color_picker(parent, frame_config, grid, logical_key, has_alpha, label, row, column, update, custom_control_key)
    end

    local position_controls = create_frame_position_controls(parent, frame_config, grid, update, {
        frame_show_key = opts.frame_show_key or frame_config.frame_show_key,
        scale_key = opts.scale_key or frame_config.scale_key,
        show_control_key = control_key("show"),
        move_control_key = control_key("move"),
        x_control_key = opts.x_control_key,
        y_control_key = opts.y_control_key,
        width_control_key = opts.width_control_key,
        x_name_suffix = opts.x_name_suffix or "XPos",
        y_name_suffix = opts.y_name_suffix or "YPos",
        width_name_suffix = opts.width_name_suffix or "Width",
        sync_on_drag_stop = true,
        row = 2,
    })

    local enable_container, enable_cb
    enable_container, enable_cb = bound_cb("Enable Frame", "show", 1, 1, function(is_checked)
        if not is_checked then
            value_table[frame_setting_key(frame_config, "move")] = false
            if position_controls.move_checkbox and position_controls.move_checkbox.SetChecked then
                position_controls.move_checkbox:SetChecked(false)
            end
        end
        if opts.on_enable_changed then opts.on_enable_changed(is_checked, position_controls, enable_cb) end
        update()
    end)

    local test_aura_container = bound_cb("Test Aura", "test_aura", 1, 1, function(is_checked)
        if is_checked then
            value_table[frame_setting_key(frame_config, "show")] = true
            if enable_cb and enable_cb.SetChecked then enable_cb:SetChecked(true) end
        end
        if opts.on_test_aura_changed then opts.on_test_aura_changed(is_checked, enable_cb) end
        update()
    end)
    test_aura_container:ClearAllPoints()
    test_aura_container:SetPoint("TOPLEFT", enable_container, "BOTTOMLEFT", 0, 0)
    local tooltip_container = bound_cb("Tooltip", "tooltip", 2, 1)
    tooltip_container:ClearAllPoints()
    tooltip_container:SetPoint("TOPLEFT", test_aura_container, "BOTTOMLEFT", 0, 0)

    local frame_bg_container = bound_cb("Frame BG", "bg", 1, 2)
    local frame_bg_color_picker = bound_picker("bg_color", true, "Frame BG Color", 1, 2)
    frame_bg_color_picker:ClearAllPoints()
    frame_bg_color_picker:SetPoint("TOPLEFT", frame_bg_container, "BOTTOMLEFT", 0, -4)

    local scale_slider = create_frame_slider(parent, frame_config, "Scale", "Scale", 0.5, 2.5, 0.01, "scale", update)
    grid:place_at(scale_slider, 1, 3)

    local spacing_slider = create_frame_slider(parent, frame_config, "Spacing", "Spacing", 0, 20, 0.1, "spacing", update)
    grid:place_at(spacing_slider, 1, 4)

    if opts.build_source_controls then
        opts.build_source_controls({
            parent = parent,
            grid = grid,
            update = update,
            bound_raw_cb = bound_raw_cb,
            frame_config = frame_config,
            position_controls = position_controls,
            enable_checkbox = enable_cb,
            tooltip_container = tooltip_container,
        })
    end

    grid:add_row_separator(1)
    grid:add_row_separator(2)

    bound_cb("Fade OOC", "fade_ooc", 4, 1)
    local ooc_alpha_slider = create_frame_slider(parent, frame_config, "OOCAlpha", "OOC Alpha", 0.1, 1, 0.05, "ooc_alpha", update)
    grid:place_at(ooc_alpha_slider, 4, 2)

    local fade_delay_slider = create_frame_slider(parent, frame_config, "FadeDelay", "Fade Delay", 0, 10, 0.1, "fade_delay", update)
    grid:place_at(fade_delay_slider, 4, 3)

    local fade_length_slider = create_frame_slider(parent, frame_config, "FadeLength", "Fade Length", 0, 10, 0.1, "fade_length", update)
    grid:place_at(fade_length_slider, 4, 4)

    grid:add_row_separator(3)

    local timer_swipe_container, timer_swipe_checkbox
    local has_timer_controls = opts.show_timer_controls ~= false
    local function refresh_timer_swipe_control()
        if not timer_swipe_checkbox then return end
        local bar_mode_enabled = value_table[frame_setting_key(frame_config, "bar_mode")] == true
        if bar_mode_enabled then
            if timer_swipe_checkbox.SetChecked then timer_swipe_checkbox:SetChecked(false) end
            if timer_swipe_checkbox.Disable then timer_swipe_checkbox:Disable() end
            if timer_swipe_container then timer_swipe_container:SetAlpha(0.45) end
        else
            if timer_swipe_checkbox.SetChecked then
                timer_swipe_checkbox:SetChecked(value_table[frame_setting_key(frame_config, "timer_swipe")] == true)
            end
            if timer_swipe_checkbox.Enable then timer_swipe_checkbox:Enable() end
            if timer_swipe_container then timer_swipe_container:SetAlpha(1) end
        end
    end

    local bar_mode_container = bound_cb("Bar Mode", "bar_mode", 3, 1, function()
        refresh_timer_swipe_control()
        update()
    end)
    if has_timer_controls then
        timer_swipe_container, timer_swipe_checkbox = bound_cb("Timer Swipe", "timer_swipe", 3, 1)
        timer_swipe_container:ClearAllPoints()
        timer_swipe_container:SetPoint("TOPLEFT", bar_mode_container, "BOTTOMLEFT", 0, 0)
        M.controls["timer_swipe_refresh_" .. control_key("timer_swipe")] = refresh_timer_swipe_control
        refresh_timer_swipe_control()
    end

    local growth_dropdown = create_growth_dropdown(parent, frame_config, update)
    growth_dropdown:ClearAllPoints()
    growth_dropdown:SetPoint("TOPLEFT", timer_swipe_container or bar_mode_container, "BOTTOMLEFT", 0, -25)

    local bar_color_picker = addon.CreateColorPicker(parent, value_table, frame_setting_key(frame_config, "color"), true, "Bar Color", frame_config.defaults_table, update)
    bar_color_picker:SetPoint("TOPLEFT", bar_mode_container, "TOPLEFT", grid[2] - grid[1], 0)
    if opts.bar_color_control_key then
        M.controls[opts.bar_color_control_key] = bar_color_picker
    end
    local bar_text_color_picker = bound_picker("bar_text_color", false, "Bar Text Color", 3, 3)
    bar_text_color_picker:ClearAllPoints()
    bar_text_color_picker:SetPoint("TOPLEFT", bar_color_picker, "TOPLEFT", grid[2] - grid[1], 0)

    local bar_bg_color_picker = bound_picker("bar_bg_color", true, "Bar BG Color", 3, 4)
    bar_bg_color_picker:ClearAllPoints()
    bar_bg_color_picker:SetPoint("TOPLEFT", bar_color_picker, "TOPLEFT", grid[3] - grid[1], 0)

    grid:add_row_separator(4)

    if has_timer_controls then
        create_frame_timer_controls(parent, frame_config, grid, update, opts.timer_labels or {})
        grid:add_row_separator(5)
    end

    local max_icons_slider = create_frame_slider(parent, frame_config, opts.max_icons_name_suffix or "MaxIcons", "Max Icons", 5, M.MAX_ICONS_LIMIT, 1, "max_icons", opts.on_max_icons_changed)
    grid:place_at(max_icons_slider, has_timer_controls and 6 or 5, 4)
end

-- ============================================================================
function M.build_preset_frame_panel(p, data)
    local frame_config = make_preset_frame_settings_config(data)
    local cat = frame_config.id
    local aura_filter = data.is_debuff and "HARMFUL" or "HELPFUL"

    local function update() -- refreshes current category frame preview
        M.mark_aura_scan_dirty()
        M.update_auras(M.frames[data.show_key], data.show_key, data.move_key, data.timer_key, data.bg_key, data.scale_key, data.spacing_key, aura_filter)
    end

    local hide_blizz_cdm_label = ({
        essential = "Hide WoW Essential",
        utility = "Hide WoW Utility",
        tracked_buffs = "Hide WoW Tracked Buffs",
        tracked_bars = "Hide WoW Tracked Bars",
    })[cat]

    build_frame_settings_panel(p, frame_config, {
        update = update,
        frame_show_key = data.show_key,
        scale_key = data.scale_key,
        x_control_key = "x_pos_slider_" .. cat,
        y_control_key = "y_pos_slider_" .. cat,
        width_control_key = "width_slider_" .. cat,
        x_name_suffix = "XPosSlider",
        y_name_suffix = "YPosSlider",
        width_name_suffix = "WidthSlider",
        bar_color_control_key = "bar_color_picker_" .. cat,
        show_timer_controls = cat ~= "static",
        timer_labels = {
            row = 5,
            control_prefix = cat,
            dropdown_name = addon_name .. cat .. "TimerFont",
            font_size_name = addon_name .. cat .. "TimerFontSizeSlider",
            timer_text_label = "Timer Text",
            bold_label = "Bold",
            font_label = "Font",
            font_size_label = "Font Size",
            color_label = "Color",
            font_dropdown_width = 120,
            font_y_offset = -15,
        },
        max_icons_name_suffix = "PoolSlider",
        on_max_icons_changed = function()
            print("|cFFFFFF00LsTweaks:|r Pool size for " .. cat .. " changed. Please /reload to apply.")
        end,
        build_source_controls = function(ctx)
            if cat == "essential" or cat == "utility" then
                local cooldown_mode_container = ctx.bound_raw_cb("Cooldown Mode", "cooldown_mode_" .. cat, 6, 3, update)
                local hide_blizz_cdm_container = ctx.bound_raw_cb(hide_blizz_cdm_label, "hide_blizz_cdm_" .. cat, 6, 3, function()
                    M.update_blizz_cdm_visibility(cat)
                    update()
                end)
                hide_blizz_cdm_container:ClearAllPoints()
                hide_blizz_cdm_container:SetPoint("TOPLEFT", cooldown_mode_container, "BOTTOMLEFT", 0, 0)
            elseif hide_blizz_cdm_label then
                ctx.bound_raw_cb(hide_blizz_cdm_label, "hide_blizz_cdm_" .. cat, 6, 3, function()
                    M.update_blizz_cdm_visibility(cat)
                    update()
                end)
            end
        end
    })
end



-- Custom filtered frame panel builders.
-- These back the Filters group in the Frames tree.

function M.build_custom_settings_panel(p, entry)
    local frame_config = make_custom_frame_settings_config(entry)
    local id = frame_config.id

    local function update()
        M.mark_aura_scan_dirty()
        update_custom_frame(entry)
    end

    build_frame_settings_panel(p, frame_config, {
        update = update,
        control_key_prefix = "custom_" .. id .. "_",
        frame_show_key = frame_config.frame_show_key,
        scale_key = frame_config.scale_key,
        width_control_key = "custom_" .. id .. "_width",
        bar_color_control_key = "custom_" .. id .. "_bar_color",
        growth_y_offset = -33,
        timer_labels = {
            row = 5,
            control_prefix = "custom_" .. id,
            dropdown_name = addon_name .. id .. "TimerFont",
            font_size_name = addon_name .. id .. "TimerFontSize",
            timer_text_label = "Timer Text",
            bold_label = "Timer Bold",
            font_label = "Timer Font",
            font_size_label = "Timer Font Size",
            color_label = "Timer Color",
            font_dropdown_width = 120,
            font_y_offset = -15,
        },
        max_icons_name_suffix = "MaxIcons",
        on_max_icons_changed = function()
            print("|cFFFFFF00LsTweaks:|r Pool size for " .. (entry.name or id) .. " changed. Please /reload to apply.")
        end,
        build_source_controls = function(ctx)
            ctx.grid:place_at(create_frame_name_control(ctx.parent, entry), 6, 1, nil, { width = 130, y_offset = -30 })
        end,
    })
end

function M.build_custom_child_panel(p, entry)
    local id = entry and entry.id
    if not id then return end

    local header = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -18)
    header:SetText((entry.name or id) .. " Filters")

    local base_dd
    local modifier_dd

    local function set_base(value)
        entry.aura_base_filter = (value == "HARMFUL") and "HARMFUL" or "HELPFUL"
        if base_dd and base_dd.SetValue then base_dd:SetValue(entry.aura_base_filter) end
    end

    local function set_modifier(value)
        entry.aura_modifier = value or "NONE"
        local def = M.get_custom_modifier_def(entry.aura_modifier)
        if def and def.force_base then set_base(def.force_base) end
        if modifier_dd and modifier_dd.SetValue then modifier_dd:SetValue(entry.aura_modifier) end
    end

    entry.aura_base_filter = (entry.aura_base_filter == "HARMFUL") and "HARMFUL" or "HELPFUL"
    entry.aura_modifier = entry.aura_modifier or "NONE"
    set_modifier(entry.aura_modifier)

    base_dd = addon.CreateDropdown(addon_name..id.."AuraBase", p, "Base", M.CUSTOM_AURA_BASE_FILTERS, {
        width = 118,
        get_value = function() return entry.aura_base_filter or "HELPFUL" end,
        on_select = function(value)
            set_base(value)
            local def = M.get_custom_modifier_def(entry.aura_modifier)
            if def and def.force_base and def.force_base ~= entry.aura_base_filter then
                set_base(def.force_base)
            end
            update_custom_frame(entry)
        end,
    })
    base_dd:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -32)

    local pipe = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pipe:SetPoint("LEFT", base_dd, "RIGHT", 10, 0)
    pipe:SetText("|")

    modifier_dd = addon.CreateDropdown(addon_name..id.."AuraModifier", p, "Modifier", M.CUSTOM_AURA_MODIFIERS, {
        width = 185,
        get_value = function() return entry.aura_modifier or "NONE" end,
        on_select = function(value)
            set_modifier(value)
            update_custom_frame(entry)
        end,
    })
    modifier_dd:SetPoint("LEFT", pipe, "RIGHT", 10, 0)
end
