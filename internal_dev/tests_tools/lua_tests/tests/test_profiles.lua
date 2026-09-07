-- Shared profile manager regression coverage.
---@diagnostic disable: undefined-global

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

--#region PROFILE MANAGER ======================================================

h.load_addon()
h.boot({})

local function assert_profile_covers_defaults(label, defaults, exported, excluded)
    for key in pairs(defaults) do
        if not excluded[key] then
            h.ok(exported[key] ~= nil, label .. " profile schema covers default " .. key)
        end
    end
end

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
    local ok = AF.profile_manager:save("Aura Regression", false)
    h.ok(ok, "Aura Frames profile saves through shared manager")
    AF.db.short_threshold = 19
    ok = AF.profile_manager:load("Aura Regression")
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
        growth_icon_static_long = "LEFT",
        growth_bar_static_long = "UP",
        stack_number_font_size_static_long = 13,
        stack_number_font_bold_static_long = true,
        timer_number_font_outline_static_long = false,
        stack_number_font_outline_static_long = false,
        stack_color_static_long = { r = 0.2, g = 0.4, b = 0.6 },
        bar_text_font_size_static_long = 12.5,
        bar_text_font_bold_static_long = true,
        bar_text_font_outline_static_long = true,
    })

    h.ok(ok, "Aura Frames profile data applies")
    h.eq(AF.db.growth_icon_static_long, "LEFT", "profile restores Icon Mode growth")
    h.eq(AF.db.growth_bar_static_long, "UP", "profile restores Bar Mode growth")
    h.eq(AF.db.stack_number_font_size_static_long, 13, "profile restores stack font size")
    h.eq(AF.db.stack_number_font_bold_static_long, true, "profile restores stack bold face")
    h.eq(AF.db.timer_number_font_outline_static_long, false, "profile restores timer outline")
    h.eq(AF.db.stack_number_font_outline_static_long, false, "profile restores stack outline")
    h.eq(AF.db.stack_color_static_long.g, 0.4, "profile restores stack color")
    h.eq(AF.db.bar_text_font_size_static_long, 12.5, "profile restores Bar text font size")
    h.eq(AF.db.bar_text_font_bold_static_long, true, "profile restores Bar text bold face")
    h.eq(AF.db.bar_text_font_outline_static_long, true, "profile restores Bar text outline")
    local data = AF.export_aura_frame_profile_data()
    h.eq(data.growth_icon_static_long, "LEFT", "profile exports the Static / Long category")
end)

h.test("Objectives profile import preserves an explicit false setting", function()
    local OB = h.addon.objectives
    local db = OB.get_db()
    local original_default = OB.defaults.objectives.collapse_campaign
    OB.defaults.objectives.collapse_campaign = true
    db.collapse_campaign = true

    local ok = OB.apply_objectives_profile_data({
        collapse_campaign = false,
        show_auto_collapse_activation_tooltip = false,
    })

    OB.defaults.objectives.collapse_campaign = original_default

    h.ok(ok, "Objectives profile data applies")
    h.eq(db.collapse_campaign, false, "explicit false survives profile fallback")
    h.eq(db.show_auto_collapse_activation_tooltip, false,
        "Objectives profiles preserve the disabled activation reminder")
end)

h.test("module profile schemas cover every non-session default", function()
    local AF = h.addon.aura_frames
    assert_profile_covers_defaults("Aura Frames", AF.defaults, AF.export_aura_frame_profile_data(), {
        last_frames_node = true,
        last_tab_index = true,
        profiles = true,
        snap_to_grid = true,
        show_grid = true,
        show_bar_section_outlines = true,
        learned_helpful_durations = true,
    })

    local OB = h.addon.objectives
    assert_profile_covers_defaults("Objectives", OB.defaults.objectives, OB.export_objectives_profile_data(), {
        last_tab_index = true,
        profiles = true,
    })

    local AV = h.addon.audio_volumes
    assert_profile_covers_defaults("Audio Volumes", AV.defaults.audio_volumes, AV.export_audio_volumes_profile_data(), {
        last_tab_index = true,
        last_sound_key = true,
        last_situation_key = true,
        last_quick_pick_key = true,
        profiles = true,
    })

    local SV = h.addon.skyriding_vigor
    assert_profile_covers_defaults("Skyriding Vigor", h.addon.module_defaults.sv.skyriding_vigor,
        SV.export_skyriding_vigor_profile_data(), {
            last_tab_index = true,
            last_profile_name = true,
            profiles = true,
        })
end)

h.run("profiles")

--#endregion PROFILE MANAGER ===================================================
