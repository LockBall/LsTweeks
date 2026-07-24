-- Background Colors registry, policy, preset, profile, and GUI regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/background_color_sync")
h.boot({})

local addon = h.addon
local M = addon.background_color_sync
local refresh_calls = 0

M.register_consumer("aura_frames", {
    label = "Aura Frames",
    order = 100,
    default_color = { r = 0, g = 0, b = 0, a = 0.5 },
    refresh = function() refresh_calls = refresh_calls + 1 end,
})
M.register_target("aura_frames", "frame:static", {
    label = "Static Frame Background",
    row_key = "static",
    row_label = "Static",
    column = 2,
    column_label = "Frame BG",
    default_enabled = true,
    supports_visibility = true,
})
M.register_target("aura_frames", "bar:static", {
    label = "Static Bar Background",
    row_key = "static",
    row_label = "Static",
    column = 3,
    column_label = "Bar BG",
    default_enabled = false,
})

local function local_color()
    return { r = 0.12, g = 0.23, b = 0.34, a = 0.45 }
end

h.test("registered global, module, target, and local precedence is non-destructive", function()
    local db = M.get_db()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    db.global_enabled = false
    consumer_db.enabled = true
    consumer_db.targets["frame:static"] = true
    consumer_db.targets["bar:static"] = false
    consumer_db.color = { r = 1, g = 0, b = 0, a = 0.6 }
    db.global_color = { r = 0, g = 1, b = 0, a = 0.7 }
    local original = local_color()

    local resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, consumer_db.color, "module frame override resolves")
    h.eq(source, "module", "module source reported")

    resolved, source = M.resolve_color("aura_frames", "bar:static", original)
    h.eq(resolved, original, "disabled bar target preserves local table")
    h.eq(source, "local", "disabled target reports local source")

    db.global_enable_all_backgrounds = true
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        true,
        "visibility override works without global color"
    )

    db.global_enabled = true
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, db.global_color, "global override wins")
    h.eq(source, "global", "global source reported")
    h.eq(M.resolve_visibility("aura_frames", "frame:static", false), true, "visibility-capable target enables")
    h.eq(M.resolve_visibility("aura_frames", "bar:static", false), false, "bar target cannot force visibility")

    addon.set_module_enabled(M.MODULE_KEY, false)
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, original, "module disable restores local table")
    h.eq(source, "local", "disabled module reports local source")
    addon.set_module_enabled(M.MODULE_KEY, true)
end)

h.test("preset selection preserves registered module alpha", function()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    consumer_db.color = { r = 0.13, g = 0.24, b = 0.35, a = 0.42 }
    h.eq(M.get_color_preset(consumer_db.color), "custom", "manual RGB reports Custom")

    h.ok(M.set_color_preset("aura_frames", "violet"), "known preset applies")
    h.eq(M.get_color_preset(consumer_db.color), "violet", "applied RGB matches preset")
    h.eq(consumer_db.color.a, 0.42, "preset preserves alpha")
end)

h.test("dynamic profile restores registered target selections and colors", function()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    consumer_db.enabled = true
    consumer_db.targets["frame:static"] = false
    consumer_db.targets["bar:static"] = true
    consumer_db.color = { r = 0.2, g = 0.3, b = 0.4, a = 0.5 }

    local ok = M.profile_manager:save("Test", false)
    h.ok(ok, "profile saves")
    consumer_db.targets["frame:static"] = true
    consumer_db.targets["bar:static"] = false
    consumer_db.color.r = 0.9

    ok = M.profile_manager:load("Test")
    h.ok(ok, "profile loads")
    consumer_db = M.ensure_consumer_db("aura_frames")
    h.eq(consumer_db.targets["frame:static"], false, "explicit false target restored")
    h.eq(consumer_db.targets["bar:static"], true, "explicit true target restored")
    h.eq(consumer_db.color.r, 0.2, "saved nested color restored independently")
end)

h.test("settings page builds registered target matrix inside content width", function()
    local db = M.get_db()
    db.global_enabled = false
    db.global_enable_all_backgrounds = true

    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(900, 700)
    M.BuildSettings(parent)

    h.ok(M.controls.global_color_preset, "global preset selector built")
    h.ok(M.controls.global_enable_all_backgrounds:IsEnabled(), "visibility override stays editable without global color")
    h.ok(M.controls["consumer:aura_frames:color_preset"], "consumer preset selector built")
    h.ok(M.controls["target:aura_frames:frame:static"], "frame target checkbox built")
    h.ok(M.controls["target:aura_frames:bar:static"], "bar target checkbox built")
    local content_width = addon.main_frame:GetContentAreaSize()
    h.eq(
        M.color_groups.global:GetWidth(),
        content_width - 66,
        "scrolling Global group respects content width and margins"
    )
end)

h.test("custom target registration updates GUI and unregister removes saved state", function()
    M.register_target("aura_frames", "frame:custom_1", {
        row_key = "custom_1",
        row_label = "Custom 1",
        column = 2,
        column_label = "Frame BG",
        default_enabled = true,
        supports_visibility = true,
    })
    h.ok(M.controls["target:aura_frames:frame:custom_1"], "new target appears after registration")
    local consumer_db = M.ensure_consumer_db("aura_frames")
    h.eq(consumer_db.targets["frame:custom_1"], true, "new target gets registered default")

    M.unregister_target("aura_frames", "frame:custom_1")
    h.is_nil(consumer_db.targets["frame:custom_1"], "unregistered target removes saved selection")
end)

h.test("consumer refresh uses registered callback", function()
    refresh_calls = 0
    M.refresh_consumers()
    h.eq(refresh_calls, 1, "registered consumer notified once")
end)

h.run("bcs_sync")

--#endregion FILE CONTENTS ===================================================
