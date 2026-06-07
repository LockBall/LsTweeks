-- Settings UI for the Skyriding Vigor module.
-- Runtime behavior and DB mutation helpers live in sv_main.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local CreateFrame = CreateFrame

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
    move_mode = "Move Mode",
    snap_to_grid = "Snap to Grid",
    style = "Style",
    decor_style = "End Decor",
    decor_x_position = "End Decor X",
    decor_y_position = "End Decor Y",
    spacing = "Spacing",
    scale = "Scale",
    x_position = "X Position",
    y_position = "Y Position",
    fill_test = "Fill Test",
    stop_fill_test = "Stop Test",
}

local function get_spec(key)
    return M.SETTING_SPECS[key]
end

local function set_setting_from_slider(key)
    return function(value)
        if M._syncing_slider_controls then return end
        M.set_db_value(key, value)
    end
end

local function add_row_separator(parent, anchor, y_offset)
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y_offset or 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    return line
end

function M.BuildSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db and M.get_db()
    local defaults = M.DEFAULTS or {}
    local x_spec = get_spec("x_position")
    local y_spec = get_spec("y_position")
    local scale_spec = get_spec("scale")
    local spacing_spec = get_spec("spacing")
    local decor_x_spec = get_spec("decor_x_position")
    local decor_y_spec = get_spec("decor_y_position")
    local fade_alpha_spec = get_spec("fade_alpha")
    local fade_length_spec = get_spec("fade_length")
    local col_step_x = cfg.slider_width + cfg.slider_gap_x

    local enabled_container, enabled_cb = addon.CreateCheckbox(parent, STRINGS.enabled, db and db.enabled, function(is_checked)
        M.set_db_value("enabled", is_checked)
    end)
    M.controls.enabled = enabled_cb
    enabled_container:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.title_offset_x, cfg.title_offset_y)

    local move_container, move_cb = addon.CreateCheckbox(parent, STRINGS.move_mode, db and db.move_mode, function(is_checked)
        M.set_db_value("move_mode", is_checked)
    end)
    M.controls.move_mode = move_cb
    move_container:SetPoint("TOPLEFT", enabled_container, "BOTTOMLEFT", 0, cfg.row_gap_y * -1)

    local snap_container, snap_cb = addon.CreateCheckbox(parent, STRINGS.snap_to_grid, db and db.snap_to_grid, function(is_checked)
        M.set_snap_to_grid(is_checked)
    end)
    M.controls.snap_to_grid = snap_cb
    snap_container:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x, 0)

    local reset_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset_button:SetSize(110, 22)
    reset_button:SetText("Reset Position")
    reset_button:SetPoint("TOPLEFT", move_container, "TOPLEFT", col_step_x * 2, 0)
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
    style_dropdown:SetPoint("TOPLEFT", enabled_container, "TOPLEFT", col_step_x * 2, 0)

    db.position = db.position or {}
    local default_position = defaults.position or {}

    local x_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorXPosition",
        parent,
        STRINGS.x_position,
        x_spec.min,
        x_spec.max,
        x_spec.step,
        db.position,
        "x",
        default_position
    )
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        M.set_position_axis("x", value)
    end)
    M.controls.x_position = x_slider
    x_slider:SetPoint("TOPLEFT", move_container, "BOTTOMLEFT", 0, cfg.slider_offset_y)
    add_row_separator(parent, x_slider, math.floor(cfg.grid_row_gap / 2))

    local y_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorYPosition",
        parent,
        STRINGS.y_position,
        y_spec.min,
        y_spec.max,
        y_spec.step,
        db.position,
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
        db,
        "scale",
        defaults,
        set_setting_from_slider("scale")
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
        db,
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
            end
            return nil
        end,
        __newindex = function(_, key, value)
            if key == "x" or key == "y" then
                M.set_decor_position_axis(key, value)
            end
        end,
    })
    local decor_position_defaults_proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "x" or key == "y" then
                return M.get_decor_position_default and M.get_decor_position_default(key) or 0
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
    decor_style_dropdown:SetPoint("TOPLEFT", x_slider, "TOPLEFT", 0, -(cfg.slider_row_height + cfg.slider_row_gap_y))
    add_row_separator(parent, decor_style_dropdown, math.floor(cfg.grid_row_gap / 2))

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
    decor_x_slider:SetPoint("TOPLEFT", decor_style_dropdown, "TOPRIGHT", cfg.slider_gap_x, 0)

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

    local fade_container, fade_cb = addon.CreateCheckbox(parent, STRINGS.fade_when_full, db and db.fade_when_full, function(is_checked)
        M.set_db_value("fade_when_full", is_checked)
    end)
    M.controls.fade_when_full = fade_cb
    fade_container:SetPoint("TOPLEFT", decor_style_dropdown, "TOPLEFT", 0, -(cfg.slider_row_height + cfg.slider_row_gap_y))
    add_row_separator(parent, fade_container, math.floor(cfg.grid_row_gap / 2))

    local fade_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeAlpha",
        parent,
        STRINGS.fade_alpha,
        fade_alpha_spec.min,
        fade_alpha_spec.max,
        fade_alpha_spec.step,
        db,
        "fade_alpha",
        defaults,
        set_setting_from_slider("fade_alpha")
    )
    M.controls.fade_alpha = fade_alpha_slider
    fade_alpha_slider:SetPoint("TOPLEFT", fade_container, "TOPRIGHT", 24, 0)

    local fade_length_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeLength",
        parent,
        STRINGS.fade_length,
        fade_length_spec.min,
        fade_length_spec.max,
        fade_length_spec.step,
        db,
        "fade_length",
        defaults,
        set_setting_from_slider("fade_length")
    )
    M.controls.fade_length = fade_length_slider
    fade_length_slider:SetPoint("TOPLEFT", fade_alpha_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    if addon.CreateModuleReset and db then
        local reset_panel = addon.CreateModuleReset(parent, db, defaults, {
            after_reset = M.on_reset_complete,
        })
        reset_panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", cfg.reset_bottom_x, cfg.reset_bottom_y)
        M.controls.reset_panel = reset_panel
    end
end
