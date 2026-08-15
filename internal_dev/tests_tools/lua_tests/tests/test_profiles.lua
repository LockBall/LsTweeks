-- Shared profile manager regression coverage.
---@diagnostic disable: undefined-global

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

--#region PROFILE MANAGER ======================================================

h.load_addon()
h.boot({})

h.test("shared profile manager isolates saved data and tracks selection", function()
    local db = {}
    local live = { nested = { value = 10 } }
    local manager = h.addon.CreateProfileManager({
        label = "Test",
        get_db = function() return db end,
        export_data = function() return live end,
        apply_data = function(data)
            live = data
            return true, "Loaded profile."
        end,
    })
    local ok = manager:save("One", false)
    h.ok(ok, "save succeeds")
    live.nested.value = 40
    ok = manager:load("One")
    h.ok(ok, "load succeeds")
    h.eq(live.nested.value, 10, "load restores independent copy")
    h.eq(manager:get_selected_name(), "One", "saved profile remains selected")
end)

h.test("shared profile manager rejects saves without persistent data", function()
    local manager = h.addon.CreateProfileManager({
        get_db = function() return nil end,
        export_data = function() return {} end,
    })
    local ok, message = manager:save("Unavailable", false)
    h.ok(not ok, "save fails when profile storage is unavailable")
    h.eq(message, "Profile storage is unavailable.", "failure explains the missing storage")
end)

h.test("shared profile manager rejects invalid profile exports", function()
    local manager = h.addon.CreateProfileManager({
        get_db = function() return {} end,
        export_data = function() return nil end,
    })
    local ok, message = manager:save("Invalid", false)
    h.ok(not ok, "save fails when export data is invalid")
    h.eq(message, "Profile data is unavailable.", "failure explains the invalid export")
end)

h.test("Aura Frames profiles retain their module-specific refresh contract", function()
    local AF = h.addon.aura_frames
    AF.db.profiles = {}
    AF.db.short_threshold = 7
    local ok = AF.save_aura_frame_profile("Aura Regression", false)
    h.ok(ok, "Aura Frames profile saves through shared manager")
    AF.db.short_threshold = 19
    ok = AF.load_aura_frame_profile("Aura Regression")
    h.ok(ok, "Aura Frames profile loads through shared manager")
    h.eq(AF.db.short_threshold, 7, "Aura Frames schema restores its own setting")
end)

h.test("Skyriding Vigor profile storage resolves after module initialization", function()
    local SV = h.addon.skyriding_vigor
    local db = SV.get_root_db()
    db.profiles = {}

    local ok, message = SV.profile_manager:save("Skyriding Regression", false)

    h.ok(ok, message or "Skyriding Vigor profile save succeeds")
    h.eq(SV.profile_manager:get_selected_name(), "Skyriding Regression", "saved Skyriding profile remains selected")
end)

h.test("Aura Frames profile import preserves an explicit false category setting", function()
    local AF = h.addon.aura_frames
    AF.db.bar_mode_short = true

    local ok = AF.apply_aura_frame_profile_data({ bar_mode_short = false })

    h.ok(ok, "Aura Frames profile data applies")
    h.eq(AF.db.bar_mode_short, false, "explicit false survives profile fallback")
end)

h.test("Aura Frames profiles preserve independent mode growth settings", function()
    local AF = h.addon.aura_frames

    local ok = AF.apply_aura_frame_profile_data({
        growth_icon_combined = "LEFT",
        growth_bar_combined = "UP",
        stack_number_font_size_combined = 13,
        stack_number_font_bold_combined = true,
        timer_number_font_outline_combined = false,
        stack_number_font_outline_combined = false,
        stack_color_combined = { r = 0.2, g = 0.4, b = 0.6 },
    })

    h.ok(ok, "Aura Frames profile data applies")
    h.eq(AF.db.growth_icon_combined, "LEFT", "profile restores Icon Mode growth")
    h.eq(AF.db.growth_bar_combined, "UP", "profile restores Bar Mode growth")
    h.eq(AF.db.stack_number_font_size_combined, 13, "profile restores stack font size")
    h.eq(AF.db.stack_number_font_bold_combined, true, "profile restores stack bold face")
    h.eq(AF.db.timer_number_font_outline_combined, false, "profile restores timer outline")
    h.eq(AF.db.stack_number_font_outline_combined, false, "profile restores stack outline")
    h.eq(AF.db.stack_color_combined.g, 0.4, "profile restores stack color")
end)

h.test("Objectives profile import preserves an explicit false setting", function()
    local OB = h.addon.objectives
    local db = OB.get_db()
    local original_default = OB.defaults.objectives.collapse_all
    OB.defaults.objectives.collapse_all = true
    db.collapse_all = true

    local ok = OB.apply_objectives_profile_data({ collapse_all = false })

    OB.defaults.objectives.collapse_all = original_default

    h.ok(ok, "Objectives profile data applies")
    h.eq(db.collapse_all, false, "explicit false survives profile fallback")
end)

h.run("profiles")

--#endregion PROFILE MANAGER ===================================================
