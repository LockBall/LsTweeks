-- Content panel builders for Aura Frames settings.
-- Builds the General tab and preset Buff/CDM frame settings panels.

local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region SHARED FRAME PANEL HELPERS ===========================================

local function get_setting_range(key)
    return M.SETTING_RANGES[key]
end

local function add_label_tooltip(container, label, text)
    if not (container and label and text) then return end
    local hitbox = CreateFrame("Frame", nil, container)
    hitbox:SetPoint("LEFT", label, "LEFT", 0, 0)
    hitbox:SetSize(math.ceil(label:GetStringWidth() or 0), math.ceil(label:GetStringHeight() or 16))
    hitbox:EnableMouse(true)
    hitbox:SetScript("OnEnter", function(self)
        addon.ShowOwnedTooltip(self, text, nil)
    end)
    hitbox:SetScript("OnLeave", function()
        addon.HideOwnedTooltip()
    end)
end

local function create_bound_checkbox_control(parent, label, value_table, value_key, grid, row, column, control_key, on_change, default_update, after_checked, after_unchecked)
    local container, checkbox, label_text = addon.CreateCheckbox(parent, label, value_table[value_key],
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
        M.controls[control_key] = container
    end
    return container, checkbox, label_text
end

local function create_snap_to_grid_checkbox(parent, anchor_to, grid)
    local container, checkbox, _ = addon.CreateCheckbox(parent, "Snap to Grid", M.db.snap_to_grid == true,
        function(is_checked)
            M.db.snap_to_grid = is_checked
        end
    )
    grid:stack_below(container, anchor_to, { spacing = "nested" })
    M.controls.snap_to_grid_checkbox = container
    return container, checkbox
end

-- Preset and custom panels use the same normalized presentation contract.
-- These config builders map different backing stores to common logical keys
-- so the shared panel builder does not branch on source type for common controls.
local function make_preset_frame_settings_config(data)
    local cat = data.show_key:sub(6)
    if M.WOW_COOLDOWN_CATEGORIES[cat] and M.refresh_cdm_default_positions then
        M.refresh_cdm_default_positions()
    end
    return {
        id = cat,
        is_custom = false,
        supports_test_aura = M.frame_supports_test_aura(cat),
        value_table = M.db,
        defaults_table = M.defaults,
        frame_show_key = data.show_key,
        scale_key = data.scale_key,
        position_table = M.db.positions[cat],
        default_position = M.defaults.positions[cat],
        keys = {
            show = data.show_key,
            move = data.move_key,
            move_bg_opt_out = "move_bg_opt_out_" .. cat,
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
            bar_text_font = "bar_text_font_" .. cat,
            bar_text_font_size = "bar_text_font_size_" .. cat,
            bar_text_font_bold = "bar_text_font_bold_" .. cat,
            bar_text_font_outline = "bar_text_font_outline_" .. cat,
            bar_bg_color = "bar_bg_color_" .. cat,
            fade_ooc = "fade_ooc_" .. cat,
            ooc_alpha = "ooc_alpha_" .. cat,
            fade_delay = "fade_delay_" .. cat,
            fade_length = "fade_length_" .. cat,
            bar_mode = "bar_mode_" .. cat,
            growth_icon = "growth_icon_" .. cat,
            growth_bar = "growth_bar_" .. cat,
            test_aura = M.frame_supports_test_aura(cat) and ("test_aura_" .. cat) or nil,
            timer_number_font = "timer_number_font_" .. cat,
            timer_number_font_size = "timer_number_font_size_" .. cat,
            timer_number_font_bold = "timer_number_font_bold_" .. cat,
            timer_number_font_outline = "timer_number_font_outline_" .. cat,
            timer_color = "timer_color_" .. cat,
            stack_number_font = "stack_number_font_" .. cat,
            stack_number_font_size = "stack_number_font_size_" .. cat,
            stack_number_font_bold = "stack_number_font_bold_" .. cat,
            stack_number_font_outline = "stack_number_font_outline_" .. cat,
            stack_color = "stack_color_" .. cat,
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
    if entry.ooc_alpha == nil then entry.ooc_alpha = addon.DEFAULT_FADE_ALPHA end
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
            move_bg_opt_out = "move_bg_opt_out",
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
            bar_text_font = "bar_text_font",
            bar_text_font_size = "bar_text_font_size",
            bar_text_font_bold = "bar_text_font_bold",
            bar_text_font_outline = "bar_text_font_outline",
            bar_bg_color = "bar_bg_color",
            fade_ooc = "fade_ooc",
            ooc_alpha = "ooc_alpha",
            fade_delay = "fade_delay",
            fade_length = "fade_length",
            bar_mode = "bar_mode",
            growth_icon = "growth_icon",
            growth_bar = "growth_bar",
            test_aura = "test_aura",
            timer_number_font = "timer_number_font",
            timer_number_font_size = "timer_number_font_size",
            timer_number_font_bold = "timer_number_font_bold",
            timer_number_font_outline = "timer_number_font_outline",
            timer_color = "timer_color",
            stack_number_font = "stack_number_font",
            stack_number_font_size = "stack_number_font_size",
            stack_number_font_bold = "stack_number_font_bold",
            stack_number_font_outline = "stack_number_font_outline",
            stack_color = "stack_color",
        },
    }
end

local function frame_setting_key(frame_config, logical_key)
    return frame_config.keys[logical_key]
end

local function make_frame_font_binding(frame_config, logical_key, fallback)
    local key = frame_setting_key(frame_config, logical_key)
    return {
        get = function()
            local value = frame_config.value_table[key]
            return value ~= nil and value or fallback
        end,
        set = function(value) frame_config.value_table[key] = value end,
        get_default = function()
            local value = frame_config.defaults_table[key]
            return value ~= nil and value or fallback
        end,
    }
end

local function create_frame_font_picker(parent, frame_config, grid, update, config)
    local text_color_sync_key = "sync_text_color_" .. frame_config.id
    local text_font_sync_key = "sync_text_font_" .. frame_config.id
    local function get_shared_notice()
        if M.db.shared_options_enabled ~= true then return nil end
        local color_shared = M.db[text_color_sync_key] == true
        local font_shared = M.db[text_font_sync_key] == true
        if color_shared and font_shared then
            return M.TEXT_OPTIONS_OVERRIDE_NOTICES.color_and_font
        elseif color_shared then
            return M.TEXT_OPTIONS_OVERRIDE_NOTICES.color
        elseif font_shared then
            return M.TEXT_OPTIONS_OVERRIDE_NOTICES.font
        end
    end
    local function refresh()
        if M.apply_number_font_to_all then M.apply_number_font_to_all() end
        update()
    end
    local picker = addon.CreateFontPicker(parent, {
        label = config.label,
        popup_label = config.popup_label or config.label,
        width = config.width or grid.reset_btn_width,
        role = config.role,
        color = make_frame_font_binding(frame_config, config.color_key, config.color_default),
        font = make_frame_font_binding(frame_config, config.font_key, M.DEFAULT_AURA_FONT_KEY),
        size = make_frame_font_binding(frame_config, config.size_key, config.size_default),
        bold = make_frame_font_binding(frame_config, config.bold_key, false),
        outline = make_frame_font_binding(frame_config, config.outline_key, config.outline_default),
        get_notice = get_shared_notice,
        on_preview = refresh,
    })
    grid:place_at(picker, config.row, config.column, nil, {
        width = config.width or grid.reset_btn_width,
        y_offset = config.y_offset,
    })
    M.controls[config.control_key] = picker
    return picker
end

local function create_frame_color_picker(parent, frame_config, grid, logical_key, has_alpha, label, row, column, update, control_key)
    local key = frame_setting_key(frame_config, logical_key)
    local picker = addon.CreateColorPicker(parent, frame_config.value_table, key, has_alpha, label, frame_config.defaults_table, update)
    grid:place_at(picker, row, column)
    if control_key then M.controls[control_key] = picker end
    return picker
end

local function create_frame_slider(parent, frame_config, name_suffix, label, min_v, max_v, step, logical_key, on_change, slider_opts)
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
        on_change,
        slider_opts
    )
end

local function create_frame_timer_options(parent, frame_config, grid, update, labels)
    local row = labels.row or 3
    local timer_key = frame_setting_key(frame_config, "timer")
    local timer_text_checkbox = create_bound_checkbox_control(
        parent, labels.timer_text_label or "Timer Text", frame_config.value_table, timer_key,
        grid, row, 1, labels.timer_text_control_key or timer_key, nil, update)
    local timer_text_button = create_frame_font_picker(parent, frame_config, grid, update, {
        label = "Timer Text",
        popup_label = "Timer Text Options",
        role = "timer",
        row = row,
        column = 3,
        control_key = labels.font_control_key or ("timer_text_options_" .. frame_config.id),
        color_key = "timer_color",
        color_default = { r = 1, g = 1, b = 1 },
        font_key = "timer_number_font",
        size_key = "timer_number_font_size",
        size_default = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
        bold_key = "timer_number_font_bold",
        outline_key = "timer_number_font_outline",
        outline_default = true,
    })
    return timer_text_checkbox, timer_text_button
end

local function create_frame_stack_options(parent, frame_config, grid, update)
    return create_frame_font_picker(parent, frame_config, grid, update, {
        label = "Stack Text",
        popup_label = "Stack Text Options",
        role = "stack",
        row = 3,
        column = 3,
        control_key = "stack_text_options_" .. frame_config.id,
        color_key = "stack_color",
        color_default = { r = 1, g = 1, b = 1 },
        font_key = "stack_number_font",
        size_key = "stack_number_font_size",
        size_default = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
        bold_key = "stack_number_font_bold",
        outline_key = "stack_number_font_outline",
        outline_default = true,
    })
end

local function create_frame_position_controls(parent, frame_config, grid, update, options)
    local id = frame_config.id
    local frame_show_key = options.frame_show_key or frame_config.frame_show_key
    local show_key = frame_setting_key(frame_config, "show")
    local move_key = frame_setting_key(frame_config, "move")
    local move_bg_opt_out_key = frame_setting_key(frame_config, "move_bg_opt_out")
    local bg_key = frame_setting_key(frame_config, "bg")
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

    local move_container, move_cb, move_label = create_bound_checkbox_control(
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
                if enable_cb and enable_cb.SetCheckedSilently and enable_cb.GetChecked and not enable_cb:GetChecked() then
                    enable_cb:SetCheckedSilently(true)
                    value_table[show_key] = true
                end
                if value_table[move_bg_opt_out_key] ~= true and value_table[bg_key] ~= true then
                    value_table[bg_key] = true
                    local bg_cb = M.controls and M.controls[options.bg_control_key]
                    if bg_cb and bg_cb.SetCheckedSilently then
                        bg_cb:SetCheckedSilently(true)
                    end
                end
            end
            update()
        end,
        update
    )
    add_label_tooltip(move_container, move_label, "Disables OOC Fade")
    addon.AttachTooltip(move_cb, "Disables OOC Fade")

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. id .. (options.x_name_suffix or "XPos"),
        parent,
        "X Position",
        get_setting_range("frame_position").min,
        get_setting_range("frame_position").max,
        get_setting_range("frame_position").step,
        position_table,
        "x",
        default_position
    )
    x_slider:HookValueChanged(function(_, value)
        update_frame_position("x", value)
    end)
    if options.x_control_key then M.controls[options.x_control_key] = x_slider end

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. id .. (options.y_name_suffix or "YPos"),
        parent,
        "Y Position",
        get_setting_range("frame_position").min,
        get_setting_range("frame_position").max,
        get_setting_range("frame_position").step,
        position_table,
        "y",
        default_position
    )
    y_slider:HookValueChanged(function(_, value)
        update_frame_position("y", value)
    end)
    if options.y_control_key then M.controls[options.y_control_key] = y_slider end

    local width_slider = create_frame_slider(
        parent,
        frame_config,
        options.width_name_suffix or "Width",
        "Width",
        get_setting_range("width").min,
        get_setting_range("width").max,
        get_setting_range("width").step,
        "width"
    )
    width_slider:HookValueChanged(function(_, value)
        local f = M.frames[frame_show_key]
        if not f then return end
        f:SetWidth(math.floor(value + 0.5))
        update()
    end)
    if options.width_control_key then M.controls[options.width_control_key] = width_slider end

    grid:place_at(x_slider, row, 2)
    grid:place_at(y_slider, row, 3)
    grid:place_at(width_slider, row, 4)

    local snap_container = create_snap_to_grid_checkbox(parent, move_container, grid)

    M.create_move_reset_button(parent, snap_container, {
        width = grid.reset_btn_width,
        on_click = function()
            local f = M.frames[frame_show_key]
            if not f then return end
            local reset_default_position = default_position
            if M.WOW_COOLDOWN_CATEGORIES[id] and M.refresh_cdm_default_positions then
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
        if not (f and x_slider and y_slider and x_slider.SetValueSilently and y_slider.SetValueSilently) then return end
        local pos = M.get_frame_position_table(f) or position_table
        if pos and pos.x ~= nil and pos.y ~= nil then
            x_slider:SetValueSilently(pos.x)
            y_slider:SetValueSilently(pos.y)
        end
    end

    if options.sync_on_drag_stop then
        local f = M.frames[frame_show_key]
        local handle = f and f.move_handle
        if handle then
            handle._lstweeks_sync_xy_sliders = sync_xy_sliders_to_frame
        end
    end

    return {
        move_container = move_container,
        move_checkbox = move_container,
        x_slider = x_slider,
        y_slider = y_slider,
        width_slider = width_slider,
        sync_xy_sliders_to_frame = sync_xy_sliders_to_frame,
    }
end

function M.build_general_tab(p)
    local section_spacing = addon.CONTROL_STACK_SPACING.section

    -- Blizzard Buff & Debuff Enable Frames Section
    local enable_panel = CreateFrame("Frame", nil, p, "BackdropTemplate")
    enable_panel:SetSize(150, 45)
    M.apply_tooltip_panel_backdrop(enable_panel, 0.08, 0.08, 0.08, 0.85, 0.3, 0.3, 0.3, 1)

    local panel_title = enable_panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel_title:SetText("Enable Blizz Frame")
    panel_title:SetPoint("TOP", enable_panel, "TOP", 0, -5)

    -- Blizzard Buff Frame Checkbox (checked = enabled)
    local enable_blizz_buffs_container = addon.CreateCheckbox(enable_panel, "Buff", M.db.enable_blizz_buffs,
        function(is_checked)
            M.db.enable_blizz_buffs = is_checked
            M.set_blizz_buffs_enabled(is_checked)
        end
    )
    enable_blizz_buffs_container:SetPoint("CENTER", enable_panel, "CENTER", -40, -5)
    M.controls["enable_blizz_buffs"] = enable_blizz_buffs_container

    -- Blizzard Debuff Frame Checkbox (checked = enabled)
    local enable_blizz_debuffs_container = addon.CreateCheckbox(
        enable_panel,
        "Debuff",
        M.db.enable_blizz_debuffs,
        function(is_checked)
            M.db.enable_blizz_debuffs = is_checked
            M.set_blizz_debuffs_enabled(is_checked)
        end
    )
    enable_blizz_debuffs_container:SetPoint("CENTER", enable_panel, "CENTER", 35, -5)
    M.controls["enable_blizz_debuffs"] = enable_blizz_debuffs_container

    local visible_icon_tick = addon.CreateSliderWithBox(
        addon_name.."AuraVisibleIconTick",
        p,
        "Addon Timer Tick Sec",
        get_setting_range("aura_visible_icon_tick").min,
        get_setting_range("aura_visible_icon_tick").max,
        get_setting_range("aura_visible_icon_tick").step,
        M.db,
        "aura_visible_icon_tick",
        M.defaults,
        function()
            if M.restart_visible_icon_ticker then
                M.restart_visible_icon_ticker()
            end
        end,
        {
            display_decimals = 2,
            tooltip = "How often addon-rendered custom and Cooldown Manager timer text and bars update. Managed Short, Static / Long, Timed, and Debuff animation is controlled by WoW.\nHigher values use less CPU but update less smoothly.",
        }
    )
    M.controls.aura_visible_icon_tick_slider = visible_icon_tick

    -- Show Bar Section Outlines Checkbox
    local outlines_container = addon.CreateCheckbox(p, "Show Bar Section Outlines", M.db.show_bar_section_outlines == true,
        function(is_checked)
            M.db.show_bar_section_outlines = is_checked
            if addon.aura_frames and addon.aura_frames.refresh_section_outlines then
                addon.aura_frames.refresh_section_outlines()
            end
        end
    )
    M.controls.show_bar_section_outlines_checkbox = outlines_container

    -- reset panel
    local resetPanel = addon.CreateModuleReset(p, M.db, M.defaults, {
        preserve_label = "Keep Profiles",
        preserve_default = true,
        preserve_keys = { "profiles", "last_profile_name" },
        before_reset = function()
            if addon.CloseFontOptionsPopup then addon.CloseFontOptionsPopup(false) end
            if M.refresh_cdm_default_positions then
                M.refresh_cdm_default_positions()
            end
        end,
        after_reset = M.on_reset_complete,
    })
    local grid = addon.CreateSettingsGrid(p, {
        column_count = 1,
        col_width = 190,
        col_gap = 190,
        col_offset = 16,
        col_align = { "left" },
        row_start = -16,
        row_heights = {
            45 + section_spacing,
            addon.SLIDER_WITH_BOX_SIZE.height + section_spacing,
            24 + section_spacing,
            115,
        },
        content_rows = 4,
    })
    grid:place_at(enable_panel, 1, 1)
    grid:place_at(visible_icon_tick, 2, 1)
    grid:place_at(outlines_container, 3, 1)
    grid:place_at(resetPanel, 4, 1)
end

-- Custom filtered frame panel builders.
-- These back the Filters group in the Frames tree.

local function update_custom_frame(entry)
    if not (entry and entry.id and M.frames) then return end
    local show_key = "show_" .. entry.id
    local frame = M.frames[show_key]
    if not frame then return end
    if M.invalidate_frame_runtime_config then
        M.invalidate_frame_runtime_config(frame)
    end
    local aura_filter = M.get_custom_aura_filter(entry)
    frame.update_params.aura_filter = aura_filter
    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", aura_filter)
end

function M.update_custom_frame_title(entry)
    if not (entry and entry.id and M.frames) then return end
    local frame = M.frames["show_" .. entry.id]
    if not frame then return end
    if frame.move_handle then
        frame.move_handle.title = entry.name or entry.id
    end
    if M.rebuild_shared_options_group then
        M.rebuild_shared_options_group()
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

local function create_growth_dropdown(parent, frame_config, update, vertical_only)
    local id = frame_config.id
    local function get_growth_key()
        local bar_mode = frame_config.value_table[frame_setting_key(frame_config, "bar_mode")] == true
        return frame_setting_key(frame_config, M.get_growth_logical_key(bar_mode))
    end
    return addon.CreateGrowthDirectionDropdown(addon_name .. id .. "Growth", parent, {
        width = 106,
        get_value = function()
            return addon.GetGrowthDirection(
                frame_config.value_table[get_growth_key()]
            ).value
        end,
        on_select = function(value)
            frame_config.value_table[get_growth_key()] = value
            update()
        end,
        vertical_only = vertical_only,
    })
end

-- Shared frame settings conductor. Builds preset, CDM, and custom frame panels
-- in visual grid order; source-specific controls are injected through opts.
local function build_frame_settings_panel(parent, frame_config, opts)
    opts = opts or {}
    local update = opts.update
    local has_timer_controls = opts.show_timer_controls ~= false
    local grid = addon.CreateSettingsGrid(parent, {
        row_separators = { 1, 2, 3, 4, 5 },
    })
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
        bg_control_key = control_key("bg"),
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
            if position_controls.move_checkbox and position_controls.move_checkbox.SetCheckedSilently then
                position_controls.move_checkbox:SetCheckedSilently(false)
            end
        end
        if opts.on_enable_changed then opts.on_enable_changed(is_checked, position_controls, enable_cb) end
        update()
    end)

    local test_aura_container
    if frame_config.supports_test_aura ~= false then
        local test_aura_key = frame_setting_key(frame_config, "test_aura")
        local preview_show_key = opts.frame_show_key or frame_config.frame_show_key
        local pause_test_aura_button
        local function refresh_pause_test_aura_button()
            if not pause_test_aura_button then return end
            local is_enabled = value_table[test_aura_key] == true
            local is_paused = M.is_test_preview_paused(preview_show_key)
            pause_test_aura_button:SetEnabled(is_enabled)
            pause_test_aura_button:SetPaused(is_paused)
        end

        test_aura_container = bound_cb("Test Aura", "test_aura", 1, 1, function(is_checked)
            if M.set_test_aura_enabled then
                M.set_test_aura_enabled(frame_config.id, is_checked)
            else
                if is_checked then
                    value_table[frame_setting_key(frame_config, "show")] = true
                    if M.start_test_preview_paused then M.start_test_preview_paused(preview_show_key) end
                elseif M.stop_test_preview_clock then
                    M.stop_test_preview_clock(preview_show_key)
                end
                update()
            end
            if opts.on_test_aura_changed then opts.on_test_aura_changed(is_checked, enable_cb) end
            refresh_pause_test_aura_button()
        end)
        pause_test_aura_button = addon.CreatePlayPauseButton(parent, function()
            if M.toggle_test_aura_preview then
                M.toggle_test_aura_preview(frame_config.id)
            else
                M.toggle_test_preview_pause(preview_show_key)
                update()
            end
            refresh_pause_test_aura_button()
        end, { width = 32, height = 32 })
        pause_test_aura_button:SetPoint("LEFT", test_aura_container, "RIGHT", 6, 0)
        M.controls[control_key("test_aura") .. "_pause"] = pause_test_aura_button
        refresh_pause_test_aura_button()
    end
    local tooltip_container = bound_cb("Tooltip", "tooltip", 2, 1)
    grid:stack_below(tooltip_container, enable_container, { spacing = "checkbox" })

    local frame_bg_container, _, frame_bg_label = bound_cb("Frame BG", "bg", 1, 2, function(is_checked)
        value_table[frame_setting_key(frame_config, "move_bg_opt_out")] = not is_checked
        update()
    end)
    local frame_bg_tooltip = "Shows the background behind this Aura frame. Frame BG Color is used unless this frame participates in Shared Options."
    add_label_tooltip(frame_bg_container, frame_bg_label, frame_bg_tooltip)
    local frame_bg_color_picker = bound_picker("bg_color", true, "Frame BG Color", 1, 2)
    grid:stack_below(frame_bg_color_picker, frame_bg_container, { spacing = "picker" })
    if test_aura_container then
        grid:stack_below(test_aura_container, frame_bg_color_picker, { spacing = "nested" })
    end

    local scale_range = get_setting_range("scale")
    local scale_slider = create_frame_slider(
        parent,
        frame_config,
        "Scale",
        "Scale",
        scale_range.min,
        scale_range.max,
        scale_range.step,
        "scale",
        update,
        { immediate_callback = true }
    )
    grid:place_at(scale_slider, 1, 3)

    local spacing_range = get_setting_range("spacing")
    local spacing_slider = create_frame_slider(
        parent,
        frame_config,
        "Spacing",
        "Spacing",
        spacing_range.min,
        spacing_range.max,
        spacing_range.step,
        "spacing",
        update,
        { immediate_callback = true }
    )
    grid:place_at(spacing_slider, 1, 4)

    local growth_anchor = tooltip_container
    if opts.build_source_controls then
        local source_controls = opts.build_source_controls({
            parent = parent,
            grid = grid,
            update = update,
            bound_raw_cb = bound_raw_cb,
            frame_config = frame_config,
            position_controls = position_controls,
            enable_container = enable_container,
            enable_checkbox = enable_cb,
            tooltip_container = tooltip_container,
        })
        if source_controls and source_controls.growth_anchor then
            growth_anchor = source_controls.growth_anchor
        end
    end

    local function on_fade_ooc_changed(is_checked)
        local color_sync = addon.all_the_colors
        if is_checked and color_sync and color_sync.set_disable_ooc_fade then
            color_sync.set_disable_ooc_fade(false)
            if color_sync.sync_controls then color_sync.sync_controls() end
            if M.sync_shared_options_controls then M.sync_shared_options_controls() end
            if color_sync.refresh_consumers then
                color_sync.refresh_consumers()
                return
            end
        end
        update()
    end

    local fade_ooc_container, _, fade_ooc_label = bound_cb(
        "Fade OOC",
        "fade_ooc",
        4,
        1,
        on_fade_ooc_changed
    )
    add_label_tooltip(fade_ooc_container, fade_ooc_label, "Fade Out Of Combat")
    local ooc_alpha_slider = create_frame_slider(
        parent,
        frame_config,
        "OOCAlpha",
        "Fade Alpha",
        get_setting_range("ooc_alpha").min,
        get_setting_range("ooc_alpha").max,
        get_setting_range("ooc_alpha").step,
        "ooc_alpha",
        update,
        { immediate_callback = true }
    )
    grid:place_at(ooc_alpha_slider, 4, 2)

    local fade_delay_range = get_setting_range("fade_delay")
    local fade_delay_slider = create_frame_slider(parent, frame_config, "FadeDelay", "Fade Delay", fade_delay_range.min, fade_delay_range.max, fade_delay_range.step, "fade_delay", update, { immediate_callback = true })
    grid:place_at(fade_delay_slider, 4, 3)

    local fade_length_range = get_setting_range("fade_length")
    local fade_length_slider = create_frame_slider(parent, frame_config, "FadeLength", "Fade Length", fade_length_range.min, fade_length_range.max, fade_length_range.step, "fade_length", update, { immediate_callback = true })
    grid:place_at(fade_length_slider, 4, 4)

    local timer_swipe_container
    local growth_dropdown
    local function refresh_growth_control()
        if not growth_dropdown then return end
        local bar_mode_enabled = value_table[frame_setting_key(frame_config, "bar_mode")] == true
        growth_dropdown:RefreshOptions()
        growth_dropdown:SetValue(M.get_mode_growth(value_table, frame_config.id, bar_mode_enabled))
    end
    local function refresh_timer_swipe_control()
        if not timer_swipe_container then return end
        local bar_mode_enabled = value_table[frame_setting_key(frame_config, "bar_mode")] == true
        if bar_mode_enabled then
            if timer_swipe_container.SetCheckedSilently then timer_swipe_container:SetCheckedSilently(false) end
            if timer_swipe_container.Disable then timer_swipe_container:Disable() end
            if timer_swipe_container then timer_swipe_container:SetAlpha(0.45) end
        else
            if timer_swipe_container.SetCheckedSilently then
                timer_swipe_container:SetCheckedSilently(value_table[frame_setting_key(frame_config, "timer_swipe")] == true)
            end
            if timer_swipe_container.Enable then timer_swipe_container:Enable() end
            if timer_swipe_container then timer_swipe_container:SetAlpha(1) end
        end
    end

    local bar_mode_container = bound_cb("Bar Mode", "bar_mode", 3, 1, function()
        refresh_timer_swipe_control()
        refresh_growth_control()
        update()
    end)
    if has_timer_controls then
        timer_swipe_container = bound_cb("Duration Swipe", "timer_swipe", 3, 1)
        M.controls["timer_swipe_refresh_" .. control_key("timer_swipe")] = refresh_timer_swipe_control
        refresh_timer_swipe_control()
    end

    growth_dropdown = create_growth_dropdown(parent, frame_config, update, function()
        return value_table[frame_setting_key(frame_config, "bar_mode")] == true
    end)
    M.controls["growth_dropdown_" .. frame_config.id] = growth_dropdown
    refresh_growth_control()
    grid:stack_below(growth_dropdown, growth_anchor, { y = -25 })

    local bar_color_picker = addon.CreateColorPicker(parent, value_table, frame_setting_key(frame_config, "color"), true, "Bar Color", frame_config.defaults_table, update)
    grid:place_at(bar_color_picker, 3, 2)
    if opts.bar_color_control_key then
        M.controls[opts.bar_color_control_key] = bar_color_picker
    end
    local bar_text_button = create_frame_font_picker(parent, frame_config, grid, update, {
        label = "Bar Text",
        popup_label = "Bar Text Options",
        role = "body",
        row = 3,
        column = 3,
        control_key = "bar_text_options_" .. frame_config.id,
        color_key = "bar_text_color",
        color_default = { r = 1, g = 1, b = 1 },
        font_key = "bar_text_font",
        size_key = "bar_text_font_size",
        size_default = 10,
        bold_key = "bar_text_font_bold",
        outline_key = "bar_text_font_outline",
        outline_default = false,
    })
    local bar_bg_color_picker = bound_picker("bar_bg_color", true, "Bar BG Color", 3, 2)
    grid:stack_below(bar_bg_color_picker, bar_color_picker, { spacing = "picker" })

    local timer_text_button
    if has_timer_controls then
        local timer_text_checkbox
        timer_text_checkbox, timer_text_button = create_frame_timer_options(
            parent, frame_config, grid, update, opts.timer_labels or {})
        grid:stack_below(timer_text_checkbox, bar_mode_container, { spacing = "checkbox" })
        grid:stack_below(timer_swipe_container, timer_text_checkbox, { spacing = "checkbox" })
        grid:stack_below(timer_text_button, bar_text_button, { spacing = "button" })
    end
    local stack_text_button = create_frame_stack_options(parent, frame_config, grid, update)
    grid:stack_below(stack_text_button, timer_text_button or bar_text_button, { spacing = "button" })
end

--#endregion SHARED FRAME PANEL HELPERS ========================================
--#region FRAME PANEL BUILDERS =================================================
function M.build_preset_frame_panel(p, data)
    local frame_config = make_preset_frame_settings_config(data)
    local cat = frame_config.id
    local aura_filter = data.is_debuff and "HARMFUL" or "HELPFUL"

    local function update() -- refreshes current category frame preview
        M.invalidate_aura_scan_caches()
        if M.invalidate_frame_runtime_config then
            M.invalidate_frame_runtime_config(M.frames[data.show_key])
        end
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
        show_timer_controls = true,
        timer_labels = {
            row = 3,
            control_prefix = cat,
            dropdown_name = addon_name .. cat .. "TimerFont",
            font_size_name = addon_name .. cat .. "TimerFontSizeSlider",
            timer_text_label = "Timer Text",
            bold_label = "Bold",
            font_label = "Text Font",
            font_size_label = "Font Size",
            color_label = "Text Color",
            font_dropdown_width = 120,
        },
        on_enable_changed = function(is_checked)
            if is_checked or not hide_blizz_cdm_label then return end
            local hide_key = "hide_blizz_cdm_" .. cat
            M.db[hide_key] = false
            local hide_cb = M.controls and M.controls[hide_key]
            if hide_cb and hide_cb.SetCheckedSilently then
                hide_cb:SetCheckedSilently(false)
            end
            M.update_blizz_cdm_visibility(cat)
        end,
        build_source_controls = function(ctx)
            local function create_hide_blizz_cdm_control()
                if not hide_blizz_cdm_label then return end
                local hide_blizz_cdm_container = ctx.bound_raw_cb(hide_blizz_cdm_label, "hide_blizz_cdm_" .. cat, 2, 1, function()
                    M.update_blizz_cdm_visibility(cat)
                    update()
                end)
                ctx.grid:stack_below(
                    hide_blizz_cdm_container,
                    ctx.enable_container,
                    { spacing = "checkbox" }
                )
                return hide_blizz_cdm_container
            end

            local cooldown_mode_container
            if cat == "essential" or cat == "utility" then
                cooldown_mode_container = ctx.bound_raw_cb(
                    "Cooldown Mode",
                    "cooldown_mode_" .. cat,
                    6,
                    1,
                    update
                )
                ctx.grid:stack_below(
                    ctx.tooltip_container,
                    cooldown_mode_container,
                    { spacing = "checkbox" }
                )
            elseif hide_blizz_cdm_label then
                ctx.grid:place_at(ctx.tooltip_container, 6, 1)
            end
            if cat == "short" then
                local short_threshold_range = get_setting_range("short_threshold")
                local function update_short_threshold()
                    update()
                    if M.refresh_managed_learned_buff_filters then
                        M.refresh_managed_learned_buff_filters()
                    end
                end
                local threshold = addon.CreateSliderWithBox(
                    addon_name .. "ShortMaxDuration",
                    ctx.parent,
                    "Max Duration Sec",
                    short_threshold_range.min,
                    short_threshold_range.max,
                    short_threshold_range.step,
                    M.db,
                    "short_threshold",
                    M.defaults,
                    update_short_threshold,
                    {
                        immediate_callback = true,
                        tooltip = "Shows helpful auras whose total duration is at most this many seconds. Buffs are ordered by the next expiration.",
                    }
                )
                ctx.grid:place_at(threshold, 6, 1)
                M.controls.short_threshold_slider = threshold
            end
            if cat == "static_long" then
                local clear_learned = CreateFrame("Button", nil, ctx.parent, "UIPanelButtonTemplate")
                clear_learned:SetSize(130, 24)
                clear_learned:SetText("Clear Learned Buffs")
                clear_learned:SetScript("OnClick", function()
                    if M.clear_learned_helpful_durations then
                        M.clear_learned_helpful_durations()
                    end
                end)
                addon.AttachTooltip(
                    clear_learned,
                    "Clear Learned Buffs",
                    "Clears saved OOC duration observations. Active helpful Auras are learned again after the next readable Aura update."
                )
                ctx.grid:place_at(clear_learned, 6, 1)
                M.controls.clear_learned_buffs = clear_learned
            end
            return { growth_anchor = create_hide_blizz_cdm_control() }
        end
    })
end



-- Custom filtered frame panel builders.
-- These back the Filters group in the Frames tree.

function M.build_custom_settings_panel(p, entry)
    local frame_config = make_custom_frame_settings_config(entry)
    local id = frame_config.id

    local function update()
        M.invalidate_aura_scan_caches()
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
            row = 3,
            control_prefix = "custom_" .. id,
            dropdown_name = addon_name .. id .. "TimerFont",
            font_size_name = addon_name .. id .. "TimerFontSize",
            timer_text_label = "Timer Text",
            bold_label = "Timer Bold",
            font_label = "Timer Font",
            font_size_label = "Timer Font Size",
            color_label = "Timer Color",
            font_dropdown_width = 120,
        },
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

--#endregion FRAME PANEL BUILDERS ==============================================
