-- Aura Frames ownership tests for shared background color controls.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon()
h.boot({})

local addon = h.addon
local M = addon.aura_frames
local color_sync = addon.background_color_sync

h.test("Shared BG Colors tab owns the Aura frame participation matrix", function()
    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(925, 700)
    M.BuildSettings(parent)

    h.ok(M.controls.background_color_sync_frame_preset, "frame preset is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_frame_picker, "frame color picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_bar_preset, "bar preset is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_bar_picker, "bar color picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_enabled, "shared color section exposes its enable checkbox")
    h.eq(M.db.shared_background_color_enabled, false, "shared color defaults disabled")
    h.ok(M.shared_background_color_group, "tab exposes shared color controls")
    h.ok(M.background_color_matrix_group, "tab exposes the participation matrix")
    h.eq(M.shared_background_color_group:GetWidth(), 700, "shared color section fits all four columns")
    h.eq(
        M.background_color_matrix_group:GetParent(),
        M.shared_background_color_group,
        "participation matrix shares the color section"
    )

    local frame_control = M.controls["background_color_sync:frame:static"]
    local bar_control = M.controls["background_color_sync:bar:static"]
    local test_control = M.controls["shared_test_aura:static"]
    local test_button = M.controls["shared_test_aura:static:pause"]
    h.ok(frame_control, "selected Aura frame exposes frame background participation")
    h.ok(bar_control, "selected Aura frame exposes bar background participation")
    h.ok(test_control, "selected Aura frame exposes its linked test-aura checkbox")
    h.ok(test_button, "selected Aura frame exposes its linked test-aura play button")
    h.ok(not frame_control.checkbox:IsEnabled(), "disabled shared color makes participation inactive")
    h.ok(test_control.checkbox:IsEnabled(), "test-aura controls stay independent from shared color")
    h.eq(M.background_color_matrix_group:GetAlpha(), 1, "independent test-aura column stays at full alpha")

    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    h.is_nil(consumer_db.color, "Background Colors stores no Aura module color")
    h.is_nil(consumer_db.targets, "Background Colors stores no Aura target selections")
    h.eq(M.db.sync_frame_bg_static, true, "frame background starts selected in Aura DB")
    h.eq(M.db.sync_bar_bg_static, false, "bar background starts deselected in Aura DB")

    M.controls.background_color_sync_enabled:SetChecked(true)
    M.controls.background_color_sync_enabled.checkbox:Click()
    h.ok(frame_control.checkbox:IsEnabled(), "enabling shared color activates participation")

    frame_control:SetChecked(false)
    frame_control.checkbox:Click()
    bar_control:SetChecked(true)
    bar_control.checkbox:Click()
    h.eq(M.db.sync_frame_bg_static, false, "frame control updates Aura-owned participation")
    h.eq(M.db.sync_bar_bg_static, true, "bar control updates Aura-owned participation")

    test_control:SetChecked(false)
    test_control.checkbox:Click()
    h.eq(M.db.test_aura_static, false, "shared tab test control updates the Frames-tab setting")
    test_control:SetChecked(true)
    test_control.checkbox:Click()
    h.eq(M.db.test_aura_static, true, "shared tab test control re-enables the same setting")
end)

h.test("shared color matrix tracks custom frame lifecycle", function()
    local entry = M.spawn_custom_frame()
    h.ok(entry and entry.id, "custom frame created")
    h.ok(M.controls["background_color_sync:frame:" .. entry.id], "custom frame background joins the matrix")
    h.ok(M.controls["background_color_sync:bar:" .. entry.id], "custom bar background joins the matrix")

    M.destroy_custom_frame(entry.id)
    h.is_nil(M.controls["background_color_sync:frame:" .. entry.id], "deleted custom frame leaves the matrix")
    h.is_nil(M.controls["background_color_sync:bar:" .. entry.id], "deleted custom bar leaves the matrix")
end)

h.test("Aura Frames resolves shared color before the global override", function()
    local db = color_sync.get_db()
    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    local local_color = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    M.db.shared_frame_background_color = { r = 0.5, g = 0.6, b = 0.7, a = 0.8 }
    M.db.shared_bar_background_color = { r = 0.8, g = 0.7, b = 0.6, a = 0.5 }
    M.db.shared_background_color_enabled = true
    M.db.sync_frame_bg_static = true
    M.db.sync_bar_bg_static = false
    db.global_enabled = false

    local resolved, source = M.resolve_background_color("static", "frame", local_color)
    h.eq(resolved, M.db.shared_frame_background_color, "selected target uses Aura-owned shared frame color")
    h.eq(source, "local", "Background Colors reports no global override")

    resolved = M.resolve_background_color("static", "bar", local_color)
    h.eq(resolved, local_color, "deselected target keeps its local Aura color")

    db.global_enabled = true
    consumer_db.global_enabled = true
    resolved, source = M.resolve_background_color("static", "frame", local_color)
    h.eq(resolved, db.global_color, "global color overrides selected Aura target")
    h.eq(source, "global", "global source reported")
    resolved = M.resolve_background_color("static", "bar", local_color)
    h.eq(resolved, db.global_color, "global color ignores Aura shared participation")

    consumer_db.global_enabled = false
    resolved = M.resolve_background_color("static", "frame", local_color)
    h.eq(resolved, M.db.shared_frame_background_color, "unchecked module falls back to Aura shared frame color")
end)

h.test("Aura profiles own shared color and target selections", function()
    M.db.shared_frame_background_color = { r = 0.2, g = 0.3, b = 0.4, a = 0.5 }
    M.db.shared_bar_background_color = { r = 0.6, g = 0.7, b = 0.8, a = 0.9 }
    M.db.shared_background_color_enabled = false
    M.db.sync_frame_bg_static = false
    M.db.sync_bar_bg_static = true
    local saved = M.export_aura_frame_profile_data()

    M.db.shared_frame_background_color.r = 0.9
    M.db.shared_bar_background_color.r = 0.1
    M.db.shared_background_color_enabled = true
    M.db.sync_frame_bg_static = true
    M.db.sync_bar_bg_static = false
    local ok = M.apply_aura_frame_profile_data(saved)

    h.ok(ok, "Aura profile applies")
    h.eq(M.db.shared_frame_background_color.r, 0.2, "Aura profile restores shared frame color")
    h.eq(M.db.shared_bar_background_color.r, 0.6, "Aura profile restores shared bar color")
    h.eq(M.db.shared_background_color_enabled, false, "Aura profile restores shared enablement")
    h.eq(M.db.sync_frame_bg_static, false, "Aura profile restores frame selection")
    h.eq(M.db.sync_bar_bg_static, true, "Aura profile restores bar selection")
end)

h.run("af_color_sync")

--#endregion FILE CONTENTS ===================================================
