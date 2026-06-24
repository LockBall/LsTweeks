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
    slider_offset_y = -14,
    slider_row_height = 115,
    slider_row_gap_y = 0,
    grid_row_gap = 20,
    reset_bottom_x = 20,
    reset_bottom_y = 20,
}

local STRINGS = {
    enabled = "Enable Vigor Bar",
    fade_when_full = "Fade When Full",
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
    fill_add = "Fill Add",
    decor_style = "End Decor",
    decor_color = "Decor Color",
    decor_x_position = "End Decor X",
    decor_y_position = "End Decor Y",
    decor_scale = "End Decor Scale",
    spacing = "Node Spacing",
    scale = "Scale",
    x_position = "X Position",
    y_position = "Y Position",
    fill_test = "Fill Test",
    stop_fill_test = "Stop Test",
    race_profile_enabled = "Enable Race Profile",
    race_profile_test = "Race Profile Test",
    stop_race_profile_test = "Stop Race Test",
    skyriding_talents = "Skyriding Talents",
}

--#endregion CONFIGURATION =====================================================

--#region SHARED HELPERS =======================================================

local function get_spec(key)
    return M.SETTING_SPECS[key]
end

local function set_setting_from_slider(key)
    return function(value)
        if M._syncing_slider_controls then return end
        M.set_db_value(key, value)
    end
end

local function add_row_separator(parent, left_anchor, y_offset)
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", left_anchor, "TOPLEFT", 0, y_offset or 0)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, y_offset or 0)
    return line
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
    if button and button.SetText then
        button:SetText(M._fill_test_enabled and STRINGS.stop_fill_test or STRINGS.fill_test)
    end
end

function M.sync_race_profile_controls(root_db)
    root_db = root_db or (M.get_root_db and M.get_root_db())
    local checkbox = M.controls and M.controls.race_profile_enabled
    if checkbox and checkbox.SetChecked then
        checkbox:SetChecked(root_db and root_db.race_profile_enabled or false)
    end

    local button = M.controls and M.controls.race_profile_test_button
    if button and button.SetText then
        button:SetText(M._race_profile_test_enabled and STRINGS.stop_race_profile_test or STRINGS.race_profile_test)
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
            dropdown:SetEnabled(M.decor_style_supports_color())
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

function M.BuildSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db and M.get_db()
    local root_db = M.get_root_db and M.get_root_db()
    local defaults = M.DEFAULTS or {}
    local x_spec = get_spec("x_position")
    local y_spec = get_spec("y_position")
    local scale_spec = get_spec("scale")
    local spacing_spec = get_spec("spacing")
    local fill_add_spec = get_spec("fill_add_alpha")
    local decor_scale_spec = get_spec("decor_scale")
    local decor_x_spec = get_spec("decor_x_position")
    local decor_y_spec = get_spec("decor_y_position")
    local fade_alpha_spec = get_spec("fade_alpha")
    local fade_length_spec = get_spec("fade_length")
    local progress_update_hz_spec = get_spec("progress_update_hz")
    local spark_size_spec = get_spec("spark_size")
    local col_step_x = cfg.slider_width + cfg.slider_gap_x
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

    local enabled_container, enabled_cb = addon.CreateCheckbox(parent, STRINGS.enabled, db and db.enabled, function(is_checked)
        M.set_db_value("enabled", is_checked)
    end)
    M.controls.enabled = enabled_cb
    enabled_container:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.title_offset_x, cfg.title_offset_y)

    local skyriding_talents_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    skyriding_talents_button:SetSize(130, 22)
    skyriding_talents_button:SetText(STRINGS.skyriding_talents)
    skyriding_talents_button:SetPoint("TOPLEFT", enabled_container, "BOTTOMLEFT", 0, -8)
    skyriding_talents_button:SetScript("OnClick", open_skyriding_talents)
    M.controls.skyriding_talents_button = skyriding_talents_button

    local move_container, move_cb = addon.CreateCheckbox(parent, STRINGS.move_mode, db and db.move_mode, function(is_checked)
        M.set_db_value("move_mode", is_checked)
    end)
    M.controls.move_mode = move_cb
    move_container:SetPoint("TOPLEFT", enabled_container, "TOPLEFT", 0, -(cfg.slider_row_height + cfg.slider_row_gap_y))

    local snap_container, snap_cb = addon.CreateCheckbox(parent, STRINGS.snap_to_grid, db and db.snap_to_grid, function(is_checked)
        M.set_snap_to_grid(is_checked)
    end)
    M.controls.snap_to_grid = snap_cb
    snap_container:SetPoint("TOPLEFT", move_container, "BOTTOMLEFT", 0, -8)

    local reset_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset_button:SetSize(110, 22)
    reset_button:SetText("Reset Position")
    reset_button:SetPoint("TOPLEFT", snap_container, "BOTTOMLEFT", 0, -8)
    reset_button:SetScript("OnClick", M.reset_position)

    local fill_test_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    fill_test_button:SetSize(90, 22)
    fill_test_button:SetText(M._fill_test_enabled and STRINGS.stop_fill_test or STRINGS.fill_test)
    fill_test_button:SetPoint("TOPLEFT", enabled_container, "TOPLEFT", col_step_x, 0)
    fill_test_button:SetScript("OnClick", function()
        if M.toggle_fill_test then
            M.toggle_fill_test()
        end
    end)
    M.controls.fill_test_button = fill_test_button

    local style_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorStyle",
        parent,
        STRINGS.style,
        M.BAR_STYLE_OPTIONS or {},
        {
            width = 130,
            get_value = function()
                return db and db.style or defaults.style or M.BAR_STYLE_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("style", value)
            end,
        }
    )
    M.controls.style = style_dropdown
    style_dropdown:SetPoint("TOPLEFT", enabled_container, "TOPLEFT", col_step_x * 3, 0)

    local node_color_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorNodeColor",
        parent,
        STRINGS.node_color,
        M.NODE_COLOR_OPTIONS or {},
        {
            width = 130,
            get_value = function()
                return M.get_node_color and M.get_node_color() or M.NODE_COLOR_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("node_color", value)
            end,
        }
    )
    M.controls.node_color = node_color_dropdown
    node_color_dropdown:SetPoint("TOPLEFT", style_dropdown, "TOPRIGHT", cfg.slider_gap_x, 0)
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
    fill_color_picker:SetPoint("TOPLEFT", fill_test_button, "BOTTOMLEFT", 0, cfg.row_gap_y * -1)

    local fill_add_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "fill_add_alpha" then
                return M.get_style_fill_add_alpha and M.get_style_fill_add_alpha() or 0.18
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
                return M.get_style_fill_add_alpha_default and M.get_style_fill_add_alpha_default() or 0.18
            end
            return nil
        end,
    })
    local fill_add_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFillAdd",
        parent,
        STRINGS.fill_add,
        fill_add_spec.min,
        fill_add_spec.max,
        fill_add_spec.step,
        fill_add_proxy,
        "fill_add_alpha",
        fill_add_defaults_proxy,
        function(value)
            M.set_style_fill_add_alpha(value)
        end,
        { display_decimals = 2 }
    )
    M.controls.fill_add_alpha = fill_add_slider
    fill_add_slider:SetPoint("TOPLEFT", enabled_container, "TOPLEFT", col_step_x * 2, 0)

    db.position = db.position or {}
    local default_position = defaults.position or {}

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorXPosition",
        parent,
        STRINGS.x_position,
        x_spec.min,
        x_spec.max,
        x_spec.step,
        position_proxy,
        "x",
        default_position
    )
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        M.set_position_axis("x", value)
    end)
    M.controls.x_position = x_slider
    x_slider:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x, 0)
    add_row_separator(parent, move_container, math.floor(cfg.grid_row_gap / 2))

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorYPosition",
        parent,
        STRINGS.y_position,
        y_spec.min,
        y_spec.max,
        y_spec.step,
        position_proxy,
        "y",
        default_position
    )
    y_slider.slider:HookScript("OnValueChanged", function(_, value)
        M.set_position_axis("y", value)
    end)
    M.controls.y_position = y_slider
    y_slider:SetPoint("TOPLEFT", x_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local scale_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorScale",
        parent,
        STRINGS.scale,
        scale_spec.min,
        scale_spec.max,
        scale_spec.step,
        active_profile_proxy,
        "scale",
        defaults,
        set_setting_from_slider("scale"),
        { display_decimals = 2 }
    )
    M.controls.scale = scale_slider
    scale_slider:SetPoint("TOPLEFT", y_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local spacing_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorSpacing",
        parent,
        STRINGS.spacing,
        spacing_spec.min,
        spacing_spec.max,
        spacing_spec.step,
        active_profile_proxy,
        "spacing",
        defaults,
        set_setting_from_slider("spacing")
    )
    M.controls.spacing = spacing_slider
    spacing_slider:SetPoint("TOPLEFT", scale_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

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

    local decor_row_y = -(cfg.slider_row_height + cfg.slider_row_gap_y)
    local decor_dropdown_y = decor_row_y - 25

    local decor_style_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorDecorStyle",
        parent,
        STRINGS.decor_style,
        M.DECOR_STYLE_OPTIONS or {},
        {
            width = 130,
            get_value = function()
                return db and db.decor_style or defaults.decor_style or M.DECOR_STYLE_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("decor_style", value)
            end,
        }
    )
    M.controls.decor_style = decor_style_dropdown
    decor_style_dropdown:SetPoint("TOPLEFT", move_container, "TOPLEFT", 0, decor_dropdown_y)
    add_row_separator(parent, move_container, -(cfg.slider_row_height + cfg.slider_row_gap_y) + math.floor(cfg.grid_row_gap / 2))

    local decor_color_dropdown = addon.CreateDropdown(
        addon_name .. "SkyridingVigorDecorColor",
        parent,
        STRINGS.decor_color,
        M.DECOR_COLOR_OPTIONS or {},
        {
            width = 130,
            get_value = function()
                return M.get_decor_color and M.get_decor_color() or M.DECOR_COLOR_DEFAULT
            end,
            on_select = function(value)
                M.set_db_value("decor_color", value)
            end,
        }
    )
    M.controls.decor_color = decor_color_dropdown
    decor_color_dropdown:SetPoint("TOPLEFT", decor_style_dropdown, "TOPRIGHT", cfg.slider_gap_x, 0)
    M.sync_decor_color_controls()

    local decor_x_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorXPosition",
        parent,
        STRINGS.decor_x_position,
        decor_x_spec.min,
        decor_x_spec.max,
        decor_x_spec.step,
        decor_position_proxy,
        "x",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_position_axis("x", value)
        end
    )
    M.controls.decor_x_position = decor_x_slider
    decor_x_slider:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x * 2, decor_row_y)

    local decor_y_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorYPosition",
        parent,
        STRINGS.decor_y_position,
        decor_y_spec.min,
        decor_y_spec.max,
        decor_y_spec.step,
        decor_position_proxy,
        "y",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_position_axis("y", value)
        end
    )
    M.controls.decor_y_position = decor_y_slider
    decor_y_slider:SetPoint("TOPLEFT", decor_x_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local decor_scale_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorDecorScale",
        parent,
        STRINGS.decor_scale,
        decor_scale_spec.min,
        decor_scale_spec.max,
        decor_scale_spec.step,
        decor_position_proxy,
        "scale",
        decor_position_defaults_proxy,
        function(value)
            M.set_decor_scale(value)
        end,
        { display_decimals = 2 }
    )
    M.controls.decor_scale = decor_scale_slider
    decor_scale_slider:SetPoint("TOPLEFT", decor_y_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local fade_container, fade_cb = addon.CreateCheckbox(parent, STRINGS.fade_when_full, db and db.fade_when_full, function(is_checked)
        M.set_db_value("fade_when_full", is_checked)
    end)
    M.controls.fade_when_full = fade_cb
    fade_container:SetPoint("TOPLEFT", move_container, "TOPLEFT", 0, -((cfg.slider_row_height + cfg.slider_row_gap_y) * 2))
    add_row_separator(parent, move_container, -((cfg.slider_row_height + cfg.slider_row_gap_y) * 2) + math.floor(cfg.grid_row_gap / 2))

    local fade_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeAlpha",
        parent,
        STRINGS.fade_alpha,
        fade_alpha_spec.min,
        fade_alpha_spec.max,
        fade_alpha_spec.step,
        active_profile_proxy,
        "fade_alpha",
        defaults,
        set_setting_from_slider("fade_alpha")
    )
    M.controls.fade_alpha = fade_alpha_slider
    fade_alpha_slider:SetPoint("TOPLEFT", fade_container, "TOPLEFT", col_step_x, 0)

    local fade_length_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeLength",
        parent,
        STRINGS.fade_length,
        fade_length_spec.min,
        fade_length_spec.max,
        fade_length_spec.step,
        active_profile_proxy,
        "fade_length",
        defaults,
        set_setting_from_slider("fade_length")
    )
    M.controls.fade_length = fade_length_slider
    fade_length_slider:SetPoint("TOPLEFT", fade_alpha_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local progress_update_hz_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorProgressUpdateHz",
        parent,
        STRINGS.progress_update_hz,
        progress_update_hz_spec.min,
        progress_update_hz_spec.max,
        progress_update_hz_spec.step,
        active_profile_proxy,
        "progress_update_hz",
        defaults,
        set_setting_from_slider("progress_update_hz")
    )
    M.controls.progress_update_hz = progress_update_hz_slider
    progress_update_hz_slider:SetPoint("TOPLEFT", fade_length_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    local talents_row_y = -((cfg.slider_row_height + cfg.slider_row_gap_y) * 3)
    add_row_separator(parent, move_container, talents_row_y + math.floor(cfg.grid_row_gap / 2))

    local race_profile_container, race_profile_cb = addon.CreateCheckbox(
        parent,
        STRINGS.race_profile_enabled,
        root_db and root_db.race_profile_enabled,
        function(is_checked)
            M.set_race_profile_enabled(is_checked)
        end
    )
    M.controls.race_profile_enabled = race_profile_cb
    race_profile_container:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x * 4, talents_row_y)

    local race_profile_test_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    race_profile_test_button:SetSize(130, 22)
    race_profile_test_button:SetText(M._race_profile_test_enabled and STRINGS.stop_race_profile_test or STRINGS.race_profile_test)
    race_profile_test_button:SetPoint("TOPLEFT", race_profile_container, "BOTTOMLEFT", 0, -8)
    race_profile_test_button:SetScript("OnClick", function()
        if M.toggle_race_profile_test then
            M.toggle_race_profile_test()
        end
    end)
    M.controls.race_profile_test_button = race_profile_test_button
    M.sync_race_profile_controls(root_db)

    local spark_container, spark_cb = addon.CreateCheckbox(parent, STRINGS.show_spark, db and db.show_spark, function(is_checked)
        M.set_db_value("show_spark", is_checked)
    end)
    M.controls.show_spark = spark_cb
    spark_container:SetPoint("TOPLEFT", move_container, "TOPLEFT", 0, talents_row_y)

    db.spark_color = db.spark_color or { r = 1, g = 1, b = 1, a = 1 }
    local spark_color_defaults = {
        spark_color = defaults.spark_color or { r = 1, g = 1, b = 1, a = 1 },
    }
    local spark_color_picker = addon.CreateColorPicker(parent, active_profile_proxy, "spark_color", true, STRINGS.spark_color, spark_color_defaults, function()
        if M.apply_spark_settings then
            M.apply_spark_settings()
        end
    end)
    M.controls.spark_color = spark_color_picker
    spark_color_picker:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x, talents_row_y)

    local spark_size_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorSparkSize",
        parent,
        STRINGS.spark_size,
        spark_size_spec.min,
        spark_size_spec.max,
        spark_size_spec.step,
        active_profile_proxy,
        "spark_size",
        defaults,
        set_setting_from_slider("spark_size"),
        { display_decimals = 2 }
    )
    M.controls.spark_size = spark_size_slider
    spark_size_slider:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x * 2, talents_row_y)

    if addon.CreateModuleReset and root_db then
        local reset_panel = addon.CreateModuleReset(parent, root_db, defaults, {
            after_reset = M.on_reset_complete,
        })
        reset_panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", cfg.reset_bottom_x, cfg.reset_bottom_y)
        M.controls.reset_panel = reset_panel
    end
end

--#endregion SETTINGS CONSTRUCTION =============================================
