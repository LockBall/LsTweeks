-- Settings UI for the Skyriding Vigor module.
-- Owns control construction and synchronization from the Skyriding Vigor DB.
-- Runtime behavior and DB mutation helpers live in sv_main.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

--#region CONFIGURATION ========================================================

local UI_CONFIG = {
    title_offset_x = 20,
    title_offset_y = -20,
    row_gap_y = 18,
    slider_gap_x = 18,
    slider_width = 130,
    color_picker_width = 95,
    button_height = 22,
    button_padding_x = 24,
    race_profile_panel_padding_x = 8,
    race_profile_panel_padding_y = 8,
    slider_offset_y = -14,
    slider_row_height = 115,
    slider_row_gap_y = 0,
    grid_row_gap = 20,
    reset_bottom_x = 20,
    reset_panel_padding_top = 8,
    reset_row_height = 150,
}

local ROWS = {
    top = 1,
    position = 2,
    decor = 3,
    fade = 4,
    spark = 5,
}

local CONTROL_GRID = {
    enabled = { row = ROWS.top, col = 1 },
    skyriding_talents = { row = ROWS.spark, col = 5, center = true },
    fill_test = { row = ROWS.top, col = 2, center = true },
    fill_color = {
        row = ROWS.top,
        col = 2,
        y = -(UI_CONFIG.button_height + UI_CONFIG.row_gap_y),
        width = UI_CONFIG.color_picker_width,
        center = true,
    },
    fill_add = { row = ROWS.top, col = 3 },
    style = { row = ROWS.top, col = 4, center = true },
    node_color = { row = ROWS.top, col = 5, center = true },

    move_mode = { row = ROWS.position, col = 1 },
    snap_to_grid = { x = 0, y = -8 },
    reset_position = { x = 0, y = -8, center = true },
    x_position = { row = ROWS.position, col = 2 },
    y_position = { row = ROWS.position, col = 3 },
    scale = { row = ROWS.position, col = 4 },
    spacing = { row = ROWS.position, col = 5 },

    decor_style = { row = ROWS.decor, col = 1, y = -25, center = true },
    decor_color = { row = ROWS.decor, col = 2, y = -25, center = true },
    decor_x_position = { row = ROWS.decor, col = 3 },
    decor_y_position = { row = ROWS.decor, col = 4 },
    decor_scale = { row = ROWS.decor, col = 5 },

    fade_when_full = { row = ROWS.fade, col = 1 },
    fade_alpha = { row = ROWS.fade, col = 2 },
    fade_length = { row = ROWS.fade, col = 3 },
    progress_update_hz = { row = ROWS.fade, col = 5 },

    show_spark = { row = ROWS.spark, col = 1 },
    spark_color = { row = ROWS.spark, col = 2, width = UI_CONFIG.color_picker_width, center = true },
    spark_size = { row = ROWS.spark, col = 3 },
    race_profile_panel = { row = ROWS.top, col = 1, y = -32, center = true },
    race_profile_test = { x = 0, y = -8 },
}

local STRINGS = {
    enabled = "Enable Vigor Bar",
    fade_when_full = "Fade When Full",
    fade_when_full_tooltip = "Visible while flying or filling. \nFades when full and idle.",
    fade_alpha = "Fade Alpha",
    fade_length = "Fade Length",
    progress_update_hz = "Fill FPS",
    show_spark = "Show Spark",
    spark_color = "Spark Color",
    spark_size = "Spark Thickness",
    move_mode = "Move Mode",
    snap_to_grid = "Snap to Grid",
    style = "Style",
    node_color = "Node Color",
    fill_color = "Fill Color",
    fill_add = "Fill Brightness",
    decor_style = "End Decor",
    decor_color = "Decor Color",
    decor_x_position = "End Decor X",
    decor_y_position = "End Decor Y",
    decor_scale = "End Decor Scale",
    spacing = "Node Spacing",
    scale = "Scale",
    x_position = "X Position",
    y_position = "Y Position",
    fill_test = "Start Fill Test",
    stop_fill_test = "Stop Fill Test",
    race_profile_enabled = "Race Profile",
    race_profile_test = "Start Race Test",
    stop_race_profile_test = "Stop Race Test",
    skyriding_talents = "Skyriding Talents",
}

--#endregion CONFIGURATION =====================================================

--#region SHARED HELPERS =======================================================

local function get_setting_range(key)
    local range = M.SETTING_RANGES and M.SETTING_RANGES[key]
    if not range then
        error("LsTweaks Skyriding Vigor missing setting range: " .. tostring(key), 2)
    end
    return range
end

local function set_setting_from_slider(key)
    return function(value)
        if M._syncing_slider_controls then return end
        M.set_db_value(key, value)
    end
end

local function create_control_panel(parent)
    return addon.CreateControlPanel(parent)
end

local function size_panel_to_controls(panel, cfg, ...)
    local max_width = 0
    local total_height = 0
    for i = 1, select("#", ...) do
        local control = select(i, ...)
        if control then
            max_width = math.max(max_width, control:GetWidth() or 0)
            total_height = total_height + (control:GetHeight() or 0)
        end
    end

    local control_gap = math.abs(CONTROL_GRID.race_profile_test.y or 0)
    panel:SetSize(
        max_width + (cfg.race_profile_panel_padding_x * 2),
        total_height + control_gap + (cfg.race_profile_panel_padding_y * 2)
    )
end

local function sync_race_profile_panel_size()
    local controls = M.controls
    if not controls or not controls.race_profile_panel then return end
    size_panel_to_controls(
        controls.race_profile_panel,
        UI_CONFIG,
        controls.race_profile_container,
        controls.race_profile_test_button
    )
    if M.settings_grid then
        M.settings_grid:center(controls.race_profile_panel, CONTROL_GRID.race_profile_panel)
    end
end

local function place_grid_control(frame, placement, place_opts)
    if M.settings_grid then
        M.settings_grid:place(frame, placement, nil, place_opts)
    end
end

local function get_separator_y(row, cfg)
    return cfg.title_offset_y - ((row - 1) * (cfg.slider_row_height + cfg.slider_row_gap_y))
        + math.floor(cfg.grid_row_gap / 2)
end

local function get_reset_panel_y(reset_panel, cfg)
    local reset_row_top_y = get_separator_y(ROWS.spark + 1, cfg)
    local reset_panel_height = reset_panel and reset_panel:GetHeight() or cfg.reset_row_height
    return reset_row_top_y - cfg.reset_panel_padding_top - ((cfg.reset_row_height - reset_panel_height) / 2)
end

local function open_skyriding_talents()
    if InCombatLockdown and InCombatLockdown() then
        print("|cFFFFFF00LsTweaks: Cannot open Skyriding Talents while in combat. Try again out of combat.|r")
        return
    end

    if GenericTraitUI_LoadUI then
        GenericTraitUI_LoadUI()
    end

    if GenericTraitFrame and Constants and Constants.MountDynamicFlightConsts
        and GenericTraitFrame.SetConfigIDBySystemID and GenericTraitFrame.SetTreeID
    then
        GenericTraitFrame:SetConfigIDBySystemID(Constants.MountDynamicFlightConsts.TRAIT_SYSTEM_ID)
        GenericTraitFrame:SetTreeID(Constants.MountDynamicFlightConsts.TREE_ID)
        if ToggleFrame then
            ToggleFrame(GenericTraitFrame)
        elseif GenericTraitFrame.Show then
            GenericTraitFrame:Show()
        end
        return
    end

    print("|cFFFFFF00LsTweaks:|r Skyriding Talents UI is not available.")
end

--#endregion SHARED HELPERS ====================================================

--#region CONTROL SYNCHRONIZATION ==============================================

function M.sync_fill_test_button()
    local button = M.controls and M.controls.fill_test_button
    if button and button.SetTextToFit then
        local width = button:SetTextToFit(M._fill_test_enabled and STRINGS.stop_fill_test or STRINGS.fill_test)
        if M.controls_parent then
            place_grid_control(button, CONTROL_GRID.fill_test, { width = width })
        end
    end
end

function M.sync_race_profile_controls(root_db)
    root_db = root_db or (M.get_root_db and M.get_root_db())
    local checkbox = M.controls and M.controls.race_profile_enabled
    if checkbox and checkbox.SetChecked then
        checkbox:SetChecked(root_db and root_db.race_profile_enabled or false)
    end

    local button = M.controls and M.controls.race_profile_test_button
    if button and button.SetTextToFit then
        button:SetTextToFit(M._race_profile_test_enabled and STRINGS.stop_race_profile_test or STRINGS.race_profile_test)
    end
    if button and button.SetEnabled then
        button:SetEnabled(root_db and root_db.race_profile_enabled or false)
    elseif button then
        if root_db and root_db.race_profile_enabled then
            button:Enable()
        else
            button:Disable()
        end
    end
    sync_race_profile_panel_size()
    if M.sync_fade_controls_enabled then
        M.sync_fade_controls_enabled()
    end
end

function M.sync_fade_controls_enabled()
    local controls = M.controls
    if not controls then return end

    local enabled = not (M.is_race_profile_active and M.is_race_profile_active())
    local fade_controls = {
        controls.fade_when_full,
        controls.fade_alpha,
        controls.fade_length,
    }

    for i = 1, #fade_controls do
        local control = fade_controls[i]
        if control then
            if control.SetEnabled then
                control:SetEnabled(enabled)
            elseif enabled and control.Enable then
                control:Enable()
            elseif not enabled and control.Disable then
                control:Disable()
            end
        end
    end
end

function M.sync_position_controls(db)
    local position = db and db.position
    if not position then return end

    local x_slider = M.controls.x_position
    if x_slider and x_slider.slider and position.x ~= nil and x_slider.slider:GetValue() ~= position.x then
        M._syncing_position_controls = true
        x_slider.slider:SetValue(position.x)
        M._syncing_position_controls = nil
    end

    local y_slider = M.controls.y_position
    if y_slider and y_slider.slider and position.y ~= nil and y_slider.slider:GetValue() ~= position.y then
        M._syncing_position_controls = true
        y_slider.slider:SetValue(position.y)
        M._syncing_position_controls = nil
    end
end

function M.sync_slider_controls(db)
    if not db then return end
    local defaults = M.DEFAULTS or {}

    M._syncing_slider_controls = true
    for _, key in ipairs(M.SLIDER_KEYS or {}) do
        local control = M.controls[key]
        if control and control.slider then
            local value
            if key == "scale" and M.get_style_scale then
                value = M.get_style_scale()
            elseif key == "fill_add_alpha" and M.get_style_fill_add_alpha then
                value = M.get_style_fill_add_alpha()
            else
                value = db[key]
            end
            if value == nil then value = defaults[key] end
            if value ~= nil and control.slider:GetValue() ~= value then
                control._suppress_callback = true
                control.slider:SetValue(value)
                control._suppress_callback = nil
            end
        end
    end
    M._syncing_slider_controls = nil
end

function M.sync_decor_position_controls(db)
    db = db or (M.get_db and M.get_db())
    if not db then return end

    local x_slider = M.controls.decor_x_position
    if x_slider and x_slider.slider then
        local value = M.get_decor_position_axis and M.get_decor_position_axis("x")
        if value ~= nil and x_slider.slider:GetValue() ~= value then
            x_slider._suppress_callback = true
            x_slider.slider:SetValue(value)
            x_slider._suppress_callback = nil
        end
    end

    local y_slider = M.controls.decor_y_position
    if y_slider and y_slider.slider then
        local value = M.get_decor_position_axis and M.get_decor_position_axis("y")
        if value ~= nil and y_slider.slider:GetValue() ~= value then
            y_slider._suppress_callback = true
            y_slider.slider:SetValue(value)
            y_slider._suppress_callback = nil
        end
    end

    local scale_slider = M.controls.decor_scale
    if scale_slider and scale_slider.slider then
        local value = M.get_decor_scale and M.get_decor_scale()
        if value ~= nil and scale_slider.slider:GetValue() ~= value then
            scale_slider._suppress_callback = true
            scale_slider.slider:SetValue(value)
            scale_slider._suppress_callback = nil
        end
    end
end

function M.sync_style_color_controls()
    local picker = M.controls and M.controls.fill_color
    if picker and picker.SetValue and M.get_style_fill_color then
        picker:SetValue(M.get_style_fill_color())
    end
end

function M.sync_spark_color_controls()
    local picker = M.controls and M.controls.spark_color
    if picker and picker.SetValue and M.get_spark_color then
        picker:SetValue(M.get_spark_color())
    end
end

function M.sync_node_color_controls()
    local dropdown = M.controls and M.controls.node_color
    if dropdown and dropdown.SetValue and M.get_node_color then
        dropdown:SetValue(M.get_node_color())
        if dropdown.SetEnabled and M.bar_style_supports_node_color then
            dropdown:SetEnabled(M.bar_style_supports_node_color())
        end
    end
end

function M.sync_decor_color_controls()
    local dropdown = M.controls and M.controls.decor_color
    if dropdown and dropdown.SetValue and M.get_decor_color then
        dropdown:SetValue(M.get_decor_color())
        if dropdown.SetEnabled and M.decor_style_supports_color then
            local style_dropdown = M.controls and M.controls.decor_style
            local style_key = style_dropdown and style_dropdown.GetValue and style_dropdown:GetValue() or nil
            dropdown:SetEnabled(M.decor_style_supports_color(style_key))
        end
    end
end

function M.sync_settings_controls(db)
    db = db or (M.get_db and M.get_db())
    if not db then return end

    local defaults = M.DEFAULTS or {}
    local enabled_cb = M.controls.enabled
    if enabled_cb and enabled_cb.SetChecked then
        enabled_cb:SetChecked(db.enabled or false)
    end
    local fade_cb = M.controls.fade_when_full
    if fade_cb and fade_cb.SetChecked then
        fade_cb:SetChecked(db.fade_when_full or false)
    end
    local spark_cb = M.controls.show_spark
    if spark_cb and spark_cb.SetChecked then
        spark_cb:SetChecked(db.show_spark or false)
    end
    local move_cb = M.controls.move_mode
    if move_cb and move_cb.SetChecked then
        move_cb:SetChecked(db.move_mode or false)
    end
    local snap_cb = M.controls.snap_to_grid
    if snap_cb and snap_cb.SetChecked then
        snap_cb:SetChecked(db.snap_to_grid or false)
    end
    local style_dropdown = M.controls.style
    if style_dropdown and style_dropdown.SetValue then
        style_dropdown:SetValue(db.style or defaults.style or M.BAR_STYLE_DEFAULT)
    end
    M.sync_node_color_controls()
    local decor_style_dropdown = M.controls.decor_style
    if decor_style_dropdown and decor_style_dropdown.SetValue then
        decor_style_dropdown:SetValue(db.decor_style or defaults.decor_style or M.DECOR_STYLE_DEFAULT)
    end
    M.sync_decor_color_controls()

    M.sync_slider_controls(db)
    M.sync_style_color_controls()
    M.sync_spark_color_controls()
    M.sync_decor_position_controls(db)
    M.sync_position_controls(db)
    M.sync_fill_test_button()
    M.sync_race_profile_controls()
end

--#endregion CONTROL SYNCHRONIZATION ===========================================

--#region SETTINGS CONSTRUCTION ================================================

local function build_top_row(parent, context)
    local cfg = context.cfg
    local db = context.db
    local defaults = context.defaults

    local enabled_container, enabled_cb = addon.CreateCheckbox(parent, STRINGS.enabled, db and db.enabled, function(is_checked)
        M.set_db_value("enabled", is_checked)
    end)
    M.controls.enabled = enabled_cb
    place_grid_control(enabled_container, CONTROL_GRID.enabled)

    local fill_test_button = addon.CreateTextButton(parent, M._fill_test_enabled and STRINGS.stop_fill_test or STRINGS.fill_test, function()
        if M.toggle_fill_test then
            M.toggle_fill_test()
        end
    end, {
        fit_texts = { STRINGS.fill_test, STRINGS.stop_fill_test },
        height = cfg.button_height,
        padding_x = cfg.button_padding_x,
    })
    place_grid_control(fill_test_button, CONTROL_GRID.fill_test)
    M.controls.fill_test_button = fill_test_button

    local style_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorStyle",
        parent,
        STRINGS.style,
        M.BAR_STYLE_OPTIONS or {},
        {
            fit_to_text = true,
            text_padding_x = cfg.button_padding_x,
            get_value = function()
                local active_db = M.get_db and M.get_db()
                return active_db and active_db.style or defaults.style or M.BAR_STYLE_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("style", value)
            end,
        }
    )
    M.controls.style = style_dropdown
    place_grid_control(style_dropdown, CONTROL_GRID.style)

    local node_color_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorNodeColor",
        parent,
        STRINGS.node_color,
        M.NODE_COLOR_OPTIONS or {},
        {
            fit_to_text = true,
            text_padding_x = cfg.button_padding_x,
            get_value = function()
                return M.get_node_color and M.get_node_color() or M.NODE_COLOR_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("node_color", value)
            end,
        }
    )
    M.controls.node_color = node_color_dropdown
    place_grid_control(node_color_dropdown, CONTROL_GRID.node_color)
    M.sync_node_color_controls()

    local fill_color_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "fill_color" then
                return M.get_style_fill_color and M.get_style_fill_color() or { r = 1, g = 1, b = 1, a = 1 }
            end
            return nil
        end,
        __newindex = function(_, key, value)
            if key == "fill_color" then
                M.set_style_fill_color(value)
            end
        end,
    })
    local fill_color_defaults_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "fill_color" then
                return M.get_style_fill_color_default and M.get_style_fill_color_default() or { r = 1, g = 1, b = 1, a = 1 }
            end
            return nil
        end,
    })
    local fill_color_picker = addon.CreateColorPicker(parent, fill_color_proxy, "fill_color", true, STRINGS.fill_color, fill_color_defaults_proxy, function()
        if M.apply_fill_color then
            M.apply_fill_color()
        end
    end)
    M.controls.fill_color = fill_color_picker
    place_grid_control(fill_color_picker, CONTROL_GRID.fill_color)

    local fill_add_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "fill_add_alpha" then
                return M.get_style_fill_add_alpha and M.get_style_fill_add_alpha() or 0.5
            end
            return nil
        end,
        __newindex = function(_, key, value)
            if key == "fill_add_alpha" then
                M.set_style_fill_add_alpha(value)
            end
        end,
    })
    local fill_add_defaults_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "fill_add_alpha" then
                return M.get_style_fill_add_alpha_default and M.get_style_fill_add_alpha_default() or 0.5
            end
            return nil
        end,
    })
    local fill_add_range = context.fill_add_range
    local fill_add_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFillAdd",
        parent,
        STRINGS.fill_add,
        fill_add_range.min,
        fill_add_range.max,
        fill_add_range.step,
        fill_add_proxy,
        "fill_add_alpha",
        fill_add_defaults_proxy,
        function(value)
            M.set_style_fill_add_alpha(value)
        end,
        { display_decimals = 2 }
    )
    M.controls.fill_add_alpha = fill_add_slider
    place_grid_control(fill_add_slider, CONTROL_GRID.fill_add)
end

local function build_position_row(parent, context)
    local db = context.db
    local defaults = context.defaults
    local active_profile_proxy = context.active_profile_proxy
    local position_proxy = context.position_proxy

    local move_container, move_cb = addon.CreateCheckbox(parent, STRINGS.move_mode, db and db.move_mode, function(is_checked)
        M.set_db_value("move_mode", is_checked)
    end)
    M.controls.move_mode = move_cb
    place_grid_control(move_container, CONTROL_GRID.move_mode)

    local snap_container, snap_cb = addon.CreateCheckbox(parent, STRINGS.snap_to_grid, db and db.snap_to_grid, function(is_checked)
        M.set_snap_to_grid(is_checked)
    end)
    M.controls.snap_to_grid = snap_cb
    M.settings_grid:stack_below(snap_container, move_container, CONTROL_GRID.snap_to_grid)

    local reset_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset_button:SetSize(110, 22)
    reset_button:SetText("Reset Position")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(reset_button)
    end
    M.settings_grid:stack_below(reset_button, snap_container, {
        x = CONTROL_GRID.reset_position.x,
        y = CONTROL_GRID.reset_position.y,
        width = reset_button:GetWidth(),
        center = true,
    })
    reset_button:SetScript("OnClick", M.reset_position)

    if db then
        db.position = db.position or {}
    end
    local default_position = defaults.position or {}

    local x_range = context.x_range
    local x_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorXPosition",
        parent,
        STRINGS.x_position,
        x_range.min,
        x_range.max,
        x_range.step,
        position_proxy,
        "x",
        default_position
    )
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        M.set_position_axis("x", value)
    end)
    M.controls.x_position = x_slider
    place_grid_control(x_slider, CONTROL_GRID.x_position)

    local y_range = context.y_range
    local y_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorYPosition",
        parent,
        STRINGS.y_position,
        y_range.min,
        y_range.max,
        y_range.step,
        position_proxy,
        "y",
        default_position
    )
    y_slider.slider:HookScript("OnValueChanged", function(_, value)
        M.set_position_axis("y", value)
    end)
    M.controls.y_position = y_slider
    place_grid_control(y_slider, CONTROL_GRID.y_position)

    local scale_range = context.scale_range
    local scale_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorScale",
        parent,
        STRINGS.scale,
        scale_range.min,
        scale_range.max,
        scale_range.step,
        active_profile_proxy,
        "scale",
        defaults,
        set_setting_from_slider("scale"),
        { display_decimals = 2 }
    )
    M.controls.scale = scale_slider
    place_grid_control(scale_slider, CONTROL_GRID.scale)

    local spacing_range = context.spacing_range
    local spacing_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorSpacing",
        parent,
        STRINGS.spacing,
        spacing_range.min,
        spacing_range.max,
        spacing_range.step,
        active_profile_proxy,
        "spacing",
        defaults,
        set_setting_from_slider("spacing")
    )
    M.controls.spacing = spacing_slider
    place_grid_control(spacing_slider, CONTROL_GRID.spacing)
end

local function build_decor_row(parent, context)
    local cfg = context.cfg
    local defaults = context.defaults

    local decor_position_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "x" or key == "y" then
                return M.get_decor_position_axis and M.get_decor_position_axis(key) or 0
            elseif key == "scale" then
                return M.get_decor_scale and M.get_decor_scale() or 1
            end
            return nil
        end,
        __newindex = function(_, key, value)
            if key == "x" or key == "y" then
                M.set_decor_position_axis(key, value)
            elseif key == "scale" then
                M.set_decor_scale(value)
            end
        end,
    })
    local decor_position_defaults_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "x" or key == "y" then
                return M.get_decor_position_default and M.get_decor_position_default(key) or 0
            elseif key == "scale" then
                return M.get_decor_scale_default and M.get_decor_scale_default() or 1
            end
            return nil
        end,
    })

    local decor_style_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorDecorStyle",
        parent,
        STRINGS.decor_style,
        M.DECOR_STYLE_OPTIONS or {},
        {
            fit_to_text = true,
            text_padding_x = cfg.button_padding_x,
            get_value = function()
                local active_db = M.get_db and M.get_db()
                return active_db and active_db.decor_style or defaults.decor_style or M.DECOR_STYLE_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("decor_style", value)
            end,
        }
    )
    M.controls.decor_style = decor_style_dropdown
    place_grid_control(decor_style_dropdown, CONTROL_GRID.decor_style)

    local decor_color_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorDecorColor",
        parent,
        STRINGS.decor_color,
        M.DECOR_COLOR_OPTIONS or {},
        {
            fit_to_text = true,
            text_padding_x = cfg.button_padding_x,
            get_value = function()
                return M.get_decor_color and M.get_decor_color() or M.DECOR_COLOR_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("decor_color", value)
            end,
        }
    )
    M.controls.decor_color = decor_color_dropdown
    place_grid_control(decor_color_dropdown, CONTROL_GRID.decor_color)
    M.sync_decor_color_controls()

    local decor_x_range = context.decor_x_range
    local decor_x_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorXPosition",
        parent,
        STRINGS.decor_x_position,
        decor_x_range.min,
        decor_x_range.max,
        decor_x_range.step,
        decor_position_proxy,
        "x",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_position_axis("x", value)
        end
    )
    M.controls.decor_x_position = decor_x_slider
    place_grid_control(decor_x_slider, CONTROL_GRID.decor_x_position)

    local decor_y_range = context.decor_y_range
    local decor_y_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorYPosition",
        parent,
        STRINGS.decor_y_position,
        decor_y_range.min,
        decor_y_range.max,
        decor_y_range.step,
        decor_position_proxy,
        "y",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_position_axis("y", value)
        end
    )
    M.controls.decor_y_position = decor_y_slider
    place_grid_control(decor_y_slider, CONTROL_GRID.decor_y_position)

    local decor_scale_range = context.decor_scale_range
    local decor_scale_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorScale",
        parent,
        STRINGS.decor_scale,
        decor_scale_range.min,
        decor_scale_range.max,
        decor_scale_range.step,
        decor_position_proxy,
        "scale",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_scale(value)
        end,
        { display_decimals = 2 }
    )
    M.controls.decor_scale = decor_scale_slider
    place_grid_control(decor_scale_slider, CONTROL_GRID.decor_scale)
end

local function build_fade_row(parent, context)
    local db = context.db
    local defaults = context.defaults
    local active_profile_proxy = context.active_profile_proxy

    local fade_container, fade_cb, fade_label = addon.CreateCheckbox(parent, STRINGS.fade_when_full, db and db.fade_when_full, function(is_checked)
        M.set_db_value("fade_when_full", is_checked)
    end)
    M.controls.fade_when_full = fade_cb
    place_grid_control(fade_container, CONTROL_GRID.fade_when_full)
    addon.AttachTooltipToTargets(STRINGS.fade_when_full_tooltip, fade_container, fade_cb, fade_label)

    local fade_alpha_range = context.fade_alpha_range
    local fade_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeAlpha",
        parent,
        STRINGS.fade_alpha,
        fade_alpha_range.min,
        fade_alpha_range.max,
        fade_alpha_range.step,
        active_profile_proxy,
        "fade_alpha",
        defaults,
        set_setting_from_slider("fade_alpha")
    )
    M.controls.fade_alpha = fade_alpha_slider
    place_grid_control(fade_alpha_slider, CONTROL_GRID.fade_alpha)

    local fade_length_range = context.fade_length_range
    local fade_length_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeLength",
        parent,
        STRINGS.fade_length,
        fade_length_range.min,
        fade_length_range.max,
        fade_length_range.step,
        active_profile_proxy,
        "fade_length",
        defaults,
        set_setting_from_slider("fade_length")
    )
    M.controls.fade_length = fade_length_slider
    place_grid_control(fade_length_slider, CONTROL_GRID.fade_length)

    local progress_update_hz_range = context.progress_update_hz_range
    local progress_update_hz_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorProgressUpdateHz",
        parent,
        STRINGS.progress_update_hz,
        progress_update_hz_range.min,
        progress_update_hz_range.max,
        progress_update_hz_range.step,
        active_profile_proxy,
        "progress_update_hz",
        defaults,
        set_setting_from_slider("progress_update_hz")
    )
    M.controls.progress_update_hz = progress_update_hz_slider
    place_grid_control(progress_update_hz_slider, CONTROL_GRID.progress_update_hz)
end

local function build_race_profile_panel(parent, context)
    local cfg = context.cfg
    local root_db = context.root_db

    local race_profile_panel = create_control_panel(parent)
    M.controls.race_profile_panel = race_profile_panel

    local race_profile_container, race_profile_cb = addon.CreateCheckbox(
        race_profile_panel,
        STRINGS.race_profile_enabled,
        root_db and root_db.race_profile_enabled,
        function(is_checked)
            M.set_race_profile_enabled(is_checked)
        end
    )
    M.controls.race_profile_enabled = race_profile_cb
    M.controls.race_profile_container = race_profile_container
    race_profile_container:SetPoint(
        "TOPLEFT",
        race_profile_panel,
        "TOPLEFT",
        cfg.race_profile_panel_padding_x,
        -cfg.race_profile_panel_padding_y
    )

    local race_profile_test_button = addon.CreateTextButton(race_profile_panel, M._race_profile_test_enabled and STRINGS.stop_race_profile_test or STRINGS.race_profile_test, function()
        if M.toggle_race_profile_test then
            M.toggle_race_profile_test()
        end
    end, {
        fit_texts = { STRINGS.race_profile_test, STRINGS.stop_race_profile_test },
        height = cfg.button_height,
        padding_x = cfg.button_padding_x,
    })
    race_profile_test_button:SetPoint(
        "TOPLEFT",
        race_profile_container,
        "BOTTOMLEFT",
        CONTROL_GRID.race_profile_test.x,
        CONTROL_GRID.race_profile_test.y
    )
    M.controls.race_profile_test_button = race_profile_test_button
    size_panel_to_controls(race_profile_panel, cfg, race_profile_container, race_profile_test_button)
    M.settings_grid:center(race_profile_panel, CONTROL_GRID.race_profile_panel)
    M.sync_race_profile_controls(root_db)
end

local function build_spark_row(parent, context)
    local cfg = context.cfg
    local db = context.db
    local defaults = context.defaults
    local active_profile_proxy = context.active_profile_proxy

    local skyriding_talents_button = addon.CreateTextButton(parent, STRINGS.skyriding_talents, open_skyriding_talents, {
        height = cfg.button_height,
        padding_x = cfg.button_padding_x,
    })
    place_grid_control(skyriding_talents_button, CONTROL_GRID.skyriding_talents)
    M.controls.skyriding_talents_button = skyriding_talents_button

    local spark_container, spark_cb = addon.CreateCheckbox(parent, STRINGS.show_spark, db and db.show_spark, function(is_checked)
        M.set_db_value("show_spark", is_checked)
    end)
    M.controls.show_spark = spark_cb
    place_grid_control(spark_container, CONTROL_GRID.show_spark)

    if db then
        db.spark_color = db.spark_color or { r = 1, g = 1, b = 1, a = 1 }
    end
    local spark_color_defaults = {
        spark_color = defaults.spark_color or { r = 1, g = 1, b = 1, a = 1 },
    }
    local spark_color_picker = addon.CreateColorPicker(parent, active_profile_proxy, "spark_color", true, STRINGS.spark_color, spark_color_defaults, function()
        M.set_db_value("show_spark", true)
        if M.controls.show_spark and M.controls.show_spark.SetChecked then
            M.controls.show_spark:SetChecked(true)
        end
        if M.apply_spark_settings then
            M.apply_spark_settings()
        end
    end)
    M.controls.spark_color = spark_color_picker
    place_grid_control(spark_color_picker, CONTROL_GRID.spark_color)

    local spark_size_range = context.spark_size_range
    local spark_size_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorSparkSize",
        parent,
        STRINGS.spark_size,
        spark_size_range.min,
        spark_size_range.max,
        spark_size_range.step,
        active_profile_proxy,
        "spark_size",
        defaults,
        set_setting_from_slider("spark_size"),
        { display_decimals = 2 }
    )
    M.controls.spark_size = spark_size_slider
    place_grid_control(spark_size_slider, CONTROL_GRID.spark_size)
end

local function build_reset_panel(parent, context)
    local cfg = context.cfg
    local root_db = context.root_db
    local defaults = context.defaults

    if addon.CreateModuleReset and root_db then
        local reset_panel = addon.CreateModuleReset(parent, root_db, defaults, {
            after_reset = M.on_reset_complete,
        })
        reset_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.reset_bottom_x, get_reset_panel_y(reset_panel, cfg))
        M.controls.reset_panel = reset_panel
    end
end

function M.BuildSettings(parent)
    local cfg = UI_CONFIG
    M.controls_parent = parent
    M.settings_grid = addon.CreateSettingsGrid(parent, {
        column_count = 5,
        col_gap = cfg.slider_width + cfg.slider_gap_x,
        col_width = cfg.slider_width,
        col_offset = cfg.title_offset_x,
        row_start = cfg.title_offset_y,
        row_gap = cfg.grid_row_gap,
        row_heights = {
            cfg.slider_row_height,
            cfg.slider_row_height,
            cfg.slider_row_height,
            cfg.slider_row_height,
            cfg.slider_row_height,
            cfg.reset_row_height,
        },
        col_align = { "left", "left", "left", "left", "left" },
        offsets = { default = 0 },
        separator_left = cfg.title_offset_x,
        separator_right_pad = 20,
        separator_stretch = true,
        row_separators = {
            ROWS.top,
            ROWS.position,
            ROWS.decor,
            ROWS.fade,
            ROWS.spark,
        },
    })
    local db = M.get_db and M.get_db()
    local root_db = M.get_root_db and M.get_root_db()
    local defaults = M.DEFAULTS or {}
    local x_range = get_setting_range("x_position")
    local y_range = get_setting_range("y_position")
    local scale_range = get_setting_range("scale")
    local spacing_range = get_setting_range("spacing")
    local fill_add_range = get_setting_range("fill_add_alpha")
    local decor_scale_range = get_setting_range("decor_scale")
    local decor_x_range = get_setting_range("decor_x_position")
    local decor_y_range = get_setting_range("decor_y_position")
    local fade_alpha_range = get_setting_range("fade_alpha")
    local fade_length_range = get_setting_range("fade_length")
    local progress_update_hz_range = get_setting_range("progress_update_hz")
    local spark_size_range = get_setting_range("spark_size")
    local active_profile_proxy = setmetatable({}, {
        __index = function(_, key)
            local active_db = M.get_db and M.get_db()
            return active_db and active_db[key]
        end,
        __newindex = function(_, key, value)
            local active_db = M.get_db and M.get_db()
            if active_db then
                active_db[key] = value
            end
        end,
    })
    local position_proxy = setmetatable({}, {
        __index = function(_, key)
            local active_db = M.get_db and M.get_db()
            return active_db and active_db.position and active_db.position[key]
        end,
        __newindex = function(_, key, value)
            local active_db = M.get_db and M.get_db()
            if not active_db then return end
            active_db.position = active_db.position or {}
            active_db.position[key] = value
        end,
    })
    local context = {
        cfg = cfg,
        db = db,
        root_db = root_db,
        defaults = defaults,
        x_range = x_range,
        y_range = y_range,
        scale_range = scale_range,
        spacing_range = spacing_range,
        fill_add_range = fill_add_range,
        decor_scale_range = decor_scale_range,
        decor_x_range = decor_x_range,
        decor_y_range = decor_y_range,
        fade_alpha_range = fade_alpha_range,
        fade_length_range = fade_length_range,
        progress_update_hz_range = progress_update_hz_range,
        spark_size_range = spark_size_range,
        active_profile_proxy = active_profile_proxy,
        position_proxy = position_proxy,
    }

    build_top_row(parent, context)

    build_position_row(parent, context)

    build_decor_row(parent, context)

    build_fade_row(parent, context)

    build_race_profile_panel(parent, context)

    build_spark_row(parent, context)

    build_reset_panel(parent, context)
end

--#endregion SETTINGS CONSTRUCTION =============================================
