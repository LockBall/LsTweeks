-- Settings UI for the Skyriding Vigor module.
-- Runtime behavior and DB mutation helpers live in sv_main.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local UI_CONFIG = {
    title_offset_x = 20,
    title_offset_y = -20,
    row_gap_y = 18,
    slider_gap_x = 18,
    slider_offset_y = -14,
}

local STRINGS = {
    enabled = "Enable Vigor Bar",
    fade_when_full = "Fade When Full",
    fade_alpha = "Fade Alpha",
    move_mode = "Move Mode",
    snap_to_grid = "Snap to Grid",
    spacing = "Spacing",
    scale = "Scale",
}

function M.BuildSettings(parent)
    local cfg = UI_CONFIG
    local db = M.get_db and M.get_db()
    local defaults = M.DEFAULTS or {}

    local enabled_container, enabled_cb = addon.CreateCheckbox(parent, STRINGS.enabled, db and db.enabled, function(is_checked)
        M.set_db_value("enabled", is_checked)
    end)
    M.controls.enabled = enabled_cb
    enabled_container:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.title_offset_x, cfg.title_offset_y)

    local fade_container, fade_cb = addon.CreateCheckbox(parent, STRINGS.fade_when_full, db and db.fade_when_full, function(is_checked)
        M.set_db_value("fade_when_full", is_checked)
    end)
    M.controls.fade_when_full = fade_cb
    fade_container:SetPoint("TOPLEFT", enabled_container, "BOTTOMLEFT", 0, cfg.row_gap_y * -1)

    local fade_alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorFadeAlpha",
        parent,
        STRINGS.fade_alpha,
        0.05,
        1,
        0.05,
        db,
        "fade_alpha",
        defaults,
        M.refresh
    )
    M.controls.fade_alpha = fade_alpha_slider
    fade_alpha_slider:SetPoint("LEFT", fade_container, "RIGHT", 24, 0)

    local move_container, move_cb = addon.CreateCheckbox(parent, STRINGS.move_mode, db and db.move_mode, function(is_checked)
        M.set_db_value("move_mode", is_checked)
    end)
    M.controls.move_mode = move_cb
    move_container:SetPoint("TOPLEFT", fade_container, "BOTTOMLEFT", 0, cfg.row_gap_y * -1)

    local snap_container, snap_cb = addon.CreateCheckbox(parent, STRINGS.snap_to_grid, db and db.snap_to_grid, function(is_checked)
        M.set_snap_to_grid(is_checked)
    end)
    M.controls.snap_to_grid = snap_cb
    snap_container:SetPoint("LEFT", move_container, "RIGHT", 24, 0)

    local reset_button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset_button:SetSize(110, 22)
    reset_button:SetText("Reset Position")
    reset_button:SetPoint("LEFT", snap_container, "RIGHT", 24, 0)
    reset_button:SetScript("OnClick", M.reset_position)

    local spacing_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorSpacing",
        parent,
        STRINGS.spacing,
        0,
        30,
        1,
        db,
        "spacing",
        defaults,
        M.refresh
    )
    M.controls.spacing = spacing_slider
    spacing_slider:SetPoint("TOPLEFT", move_container, "BOTTOMLEFT", 0, cfg.slider_offset_y)

    local scale_slider = addon.CreateSliderWithBox(
        addon_name .. "SkyridingVigorScale",
        parent,
        STRINGS.scale,
        0.5,
        2,
        0.05,
        db,
        "scale",
        defaults,
        M.refresh
    )
    M.controls.scale = scale_slider
    scale_slider:SetPoint("TOPLEFT", spacing_slider, "TOPRIGHT", cfg.slider_gap_x, 0)

    if addon.CreateGlobalReset and db then
        local reset_panel = addon.CreateGlobalReset(parent, db, defaults)
        reset_panel:SetPoint("TOPLEFT", spacing_slider, "BOTTOMLEFT", 0, -18)
        M.controls.reset_panel = reset_panel
    end
end
