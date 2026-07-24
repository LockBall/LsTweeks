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
    label = "Buffs & Debuffs",
    order = 100,
    global_toggle = true,
    global_order = 200,
    default_global_enabled = true,
    supports_ooc_fade = true,
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
M.register_consumer("objectives", {
    label = "Objectives",
    order = 200,
    global_toggle = true,
    global_order = 100,
    default_global_enabled = true,
    global_only = true,
    default_color = { r = 0.25, g = 0.25, b = 0.25, a = 0.75 },
})
M.register_target("objectives", "custom_background", {
    label = "Custom Background",
    default_enabled = true,
    supports_visibility = true,
})

local function local_color()
    return { r = 0.12, g = 0.23, b = 0.34, a = 0.45 }
end

h.test("registered global, module, target, and local precedence is non-destructive", function()
    local db = M.get_db()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    db.global_enabled = false
    consumer_db.enabled = false
    consumer_db.targets["frame:static"] = true
    consumer_db.targets["bar:static"] = false
    consumer_db.color = { r = 1, g = 0, b = 0, a = 0.6 }
    db.global_color = { r = 0, g = 1, b = 0, a = 0.7 }
    local original = local_color()

    local resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, consumer_db.color, "selected target uses implicit module override")
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
    consumer_db.targets["frame:static"] = false
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        true,
        "visibility override ignores color participation"
    )
    consumer_db.targets["frame:static"] = true

    db.global_enabled = true
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, db.global_color, "global override wins")
    h.eq(source, "global", "global source reported")
    h.eq(M.resolve_visibility("aura_frames", "frame:static", false), true, "visibility-capable target enables")
    h.eq(M.resolve_visibility("aura_frames", "bar:static", false), false, "bar target cannot force visibility")
    db.global_disable_ooc_fade = true
    h.eq(M.resolve_ooc_fade("aura_frames", true), false, "global policy suppresses registered OOC fade")
    db.global_enable_all_backgrounds = false
    h.eq(M.resolve_ooc_fade("aura_frames", true), true, "fade policy requires Enable All Backgrounds")
    db.global_enable_all_backgrounds = true

    consumer_db.global_enabled = false
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, consumer_db.color, "unchecked global consumer falls back to module override")
    h.eq(source, "module", "unchecked global consumer reports module source")
    consumer_db.global_enabled = true

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

h.test("settings page exposes registered global consumers", function()
    local db = M.get_db()
    db.global_enabled = false
    db.global_enable_all_backgrounds = true

    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(900, 700)
    M.BuildSettings(parent)

    h.ok(M.controls["global_consumer:objectives"], "Objectives global toggle appears in Global")
    h.ok(M.controls["global_consumer:aura_frames"], "Buffs & Debuffs global toggle appears in Global")
    h.ok(
        not M.controls["global_consumer:objectives"].checkbox:IsEnabled(),
        "global consumer toggles are disabled without global color"
    )
    h.ok(M.color_groups.aura_frames, "non-global-only consumer retains its section")
    h.is_nil(M.color_groups.objectives, "global-only consumer omits a separate section")
end)

h.test("global-only consumer falls back to its local color", function()
    local db = M.get_db()
    local consumer_db = M.ensure_consumer_db("objectives")
    local original = local_color()
    consumer_db.enabled = true
    consumer_db.color = { r = 1, g = 0, b = 0, a = 1 }
    consumer_db.targets.custom_background = true
    db.global_enabled = false

    local resolved, source = M.resolve_color("objectives", "custom_background", original)
    h.eq(resolved, original, "saved module override is ignored")
    h.eq(source, "local", "global-only consumer reports local source")

    consumer_db.targets.custom_background = false
    consumer_db.global_enabled = true
    db.global_enabled = true
    resolved, source = M.resolve_color("objectives", "custom_background", original)
    h.eq(resolved, db.global_color, "global-only consumer ignores obsolete hidden target state")
    h.eq(source, "global", "enabled global-only consumer reports global source")
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
