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
local target_state = {
    ["frame:static"] = true,
    ["bar:static"] = false,
}

M.register_consumer("aura_frames", {
    label = "Buffs & Debuffs",
    order = 100,
    global_toggle = true,
    global_order = 200,
    default_global_enabled = true,
    supports_ooc_fade = true,
    refresh = function() refresh_calls = refresh_calls + 1 end,
})
M.register_target("aura_frames", "frame:static", {
    label = "Static Frame Background",
    default_enabled = true,
    supports_visibility = true,
    get_enabled = function() return target_state["frame:static"] end,
})
M.register_target("aura_frames", "bar:static", {
    label = "Static Bar Background",
    default_enabled = false,
    get_enabled = function() return target_state["bar:static"] end,
})
M.register_consumer("objectives", {
    label = "Objectives",
    order = 200,
    global_toggle = true,
    global_order = 100,
    default_global_enabled = true,
    global_only = true,
})
M.register_target("objectives", "custom_background", {
    label = "Custom Background",
    default_enabled = true,
    supports_visibility = true,
})

local function local_color()
    return { r = 0.12, g = 0.23, b = 0.34, a = 0.45 }
end

h.test("registered global, target, and local precedence is non-destructive", function()
    local db = M.get_db()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    db.global_enabled = false
    target_state["frame:static"] = true
    target_state["bar:static"] = false
    db.global_color = { r = 0, g = 1, b = 0, a = 0.7 }
    local original = local_color()

    local resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, original, "selected target retains module-owned input without global color")
    h.eq(source, "local", "local source reported")

    resolved, source = M.resolve_color("aura_frames", "bar:static", original)
    h.eq(resolved, original, "disabled bar target preserves local table")
    h.eq(source, "local", "disabled target reports local source")

    db.global_enable_all_backgrounds = true
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        true,
        "visibility override works without global color"
    )
    target_state["frame:static"] = false
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        true,
        "visibility override ignores color participation"
    )
    target_state["frame:static"] = true

    db.global_enabled = true
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, db.global_color, "global override wins")
    h.eq(source, "global", "global source reported")
    db.global_enable_all_backgrounds = false
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        true,
        "global color enables visibility-capable target in a checked module"
    )
    h.eq(M.resolve_visibility("aura_frames", "bar:static", false), false, "bar target cannot force visibility")
    db.global_enable_all_backgrounds = true
    h.ok(M.set_disable_ooc_fade(true), "dedicated fade policy setter accepts the value")
    h.eq(M.get_disable_ooc_fade(), true, "dedicated fade policy getter returns saved state")
    h.eq(M.is_ooc_fade_disabled(), true, "effective fade policy reports active")
    h.eq(M.resolve_ooc_fade("aura_frames", true), false, "global policy suppresses registered OOC fade")
    db.global_enable_all_backgrounds = false
    h.eq(M.resolve_ooc_fade("aura_frames", true), false, "fade policy is independent from Enable All Backgrounds")
    db.global_enable_all_backgrounds = true

    consumer_db.global_enabled = false
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, original, "unchecked global consumer falls back to module-owned input")
    h.eq(source, "local", "unchecked global consumer reports local source")
    db.global_enable_all_backgrounds = false
    h.eq(
        M.resolve_visibility("aura_frames", "frame:static", false),
        false,
        "unchecked module does not gain visibility from global color"
    )
    db.global_enable_all_backgrounds = true
    consumer_db.global_enabled = true

    addon.set_module_enabled(M.MODULE_KEY, false)
    resolved, source = M.resolve_color("aura_frames", "frame:static", original)
    h.eq(resolved, original, "module disable restores local table")
    h.eq(source, "local", "disabled module reports local source")
    addon.set_module_enabled(M.MODULE_KEY, true)
end)

h.test("preset selection preserves global alpha", function()
    local db = M.get_db()
    db.global_color = { r = 0.13, g = 0.24, b = 0.35, a = 0.42 }
    h.eq(M.get_color_preset(db.global_color), "custom", "manual RGB reports Custom")

    h.ok(M.set_color_preset("violet"), "known preset applies")
    h.eq(M.get_color_preset(db.global_color), "violet", "applied RGB matches preset")
    h.eq(db.global_color.a, 0.42, "preset preserves alpha")
end)

h.test("profile restores whole-module participation without owning target selections", function()
    local consumer_db = M.ensure_consumer_db("aura_frames")
    consumer_db.global_enabled = false
    target_state["frame:static"] = false

    local ok = M.profile_manager:save("Test", false)
    h.ok(ok, "profile saves")
    consumer_db.global_enabled = true
    target_state["frame:static"] = true

    ok = M.profile_manager:load("Test")
    h.ok(ok, "profile loads")
    consumer_db = M.ensure_consumer_db("aura_frames")
    h.eq(consumer_db.global_enabled, false, "explicit false module participation restored")
    h.eq(target_state["frame:static"], true, "module-owned target selection is untouched")
end)

h.test("settings page exposes only global controls for consumer-owned settings", function()
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
    h.is_nil(M.color_groups.aura_frames, "consumer-owned Aura controls stay out of the global page")
    h.is_nil(M.color_groups.objectives, "global-only consumer omits a separate section")
    h.is_nil(M.BuildColorsTab, "obsolete Colors tab builder is removed")
    h.ok(M.rebuild_general_tab, "registry rebuilds target the consolidated General tab")
end)

h.test("global-only consumer falls back to its local color", function()
    local db = M.get_db()
    local consumer_db = M.ensure_consumer_db("objectives")
    local original = local_color()
    db.global_enabled = false

    local resolved, source = M.resolve_color("objectives", "custom_background", original)
    h.eq(resolved, original, "consumer-owned local color is retained")
    h.eq(source, "local", "global-only consumer reports local source")

    consumer_db.global_enabled = true
    db.global_enabled = true
    resolved, source = M.resolve_color("objectives", "custom_background", original)
    h.eq(resolved, db.global_color, "global-only consumer ignores obsolete hidden target state")
    h.eq(source, "global", "enabled global-only consumer reports global source")
end)

h.test("consumer-owned target registration keeps state outside Background Colors", function()
    local custom_enabled = true
    M.register_target("aura_frames", "frame:custom_1", {
        default_enabled = true,
        supports_visibility = true,
        get_enabled = function() return custom_enabled end,
    })
    h.is_nil(M.controls["target:aura_frames:frame:custom_1"], "new target stays out of the global page")
    h.eq(M.get_target_enabled("aura_frames", "frame:custom_1"), true, "target reads consumer-owned state")
    M.unregister_target("aura_frames", "frame:custom_1")
    h.eq(custom_enabled, true, "unregister does not mutate consumer-owned state")
end)

h.test("consumer refresh uses registered callback", function()
    refresh_calls = 0
    M.refresh_consumers()
    h.eq(refresh_calls, 1, "registered consumer notified once")
end)

h.run("bcs_sync")

--#endregion FILE CONTENTS ===================================================
