-- Managed Short Buff native duration-filter and expiration-sort regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Short Buffs use native maximum duration and expiration ordering", function()
    local M = fixture.boot_managed_presets()
    local short_frame = M.frames.show_short
    local short_backend = short_frame and short_frame._managed_aura_backend

    h.ok(short_backend, "Short Buffs frame owns a managed backend")
    h.eq(#short_frame.icons, 1, "Short Buffs precreate one addon-owned preview visual")
    h.ok(not short_frame.icons[1]:IsShown(), "managed preview visual starts hidden")
    h.eq(short_frame.__events.UNIT_AURA, nil, "Short Buffs do not register UNIT_AURA")

    h.ok(M.frame_supports_test_aura("short"), "managed Short Buffs support addon-owned Test Auras")
    h.eq(M.db.test_aura_short, false, "managed Test Aura starts disabled")
    h.ok(short_frame._managed_test_preview_background,
        "managed Test Aura precreates a shell-owned Frame BG controller")
    h.ok(not short_frame._managed_test_preview_background.texture:IsShown(),
        "managed Test Aura Frame BG starts hidden")
    M.db.bar_mode_short = false
    M.db.bg_short = true
    M.db.bg_color_short = { r = 0.15, g = 0.25, b = 0.35, a = 0.45 }
    h.ok(M.set_test_aura_enabled("short", true), "managed Test Aura can be enabled")
    h.eq(short_backend.feature_enabled, true, "Test Aura keeps native managed content enabled")
    h.ok(short_frame.icons[1]:IsShown(), "Test Aura shows the addon-owned preview visual")
    h.ok(short_frame._managed_test_preview_background.texture:IsShown(),
        "Test Aura uses the resolved Frame BG visibility")
    local preview_bg_color = short_frame._managed_test_preview_background.texture:GetLastCall("SetColorTexture")
    h.eq(preview_bg_color[1], 0.15, "Test Aura uses the resolved Frame BG red channel")
    h.eq(preview_bg_color[2], 0.25, "Test Aura uses the resolved Frame BG green channel")
    h.eq(preview_bg_color[3], 0.35, "Test Aura uses the resolved Frame BG blue channel")
    h.eq(preview_bg_color[4], 0.45, "Test Aura uses the resolved Frame BG alpha channel")
    M.db.bg_short = false
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.ok(not short_frame._managed_test_preview_background.texture:IsShown(),
        "Test Aura Frame BG follows visibility changes in real time")
    M.db.bg_short = true
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.ok(short_frame._managed_test_preview_background.texture:IsShown(),
        "Test Aura Frame BG returns when re-enabled")
    h.eq(short_frame.icons[1].aura_name, "Test Short Buff", "preview uses the managed frame label")
    h.ok(short_frame.icons[1].is_test_preview, "preview is marked as synthetic")
    local preview_point, preview_relative_to, preview_relative_point =
        short_frame._managed_test_preview_background_anchor:GetPoint(1)
    h.eq(preview_point, "BOTTOMLEFT", "Down-growing native content puts the Test Aura above its origin")
    h.eq(preview_relative_to, short_frame, "managed Test Aura remains attached to the addon shell")
    h.eq(preview_relative_point, "TOPLEFT", "managed Test Aura occupies the side opposite Down growth")
    local icon_point, icon_relative_to, icon_relative_point = short_frame.icons[1]:GetPoint(1)
    h.eq(icon_point, "TOPLEFT", "managed Test Aura icon starts at its Frame BG cell")
    h.eq(icon_relative_to, short_frame._managed_test_preview_background_anchor,
        "managed Test Aura icon uses the separate Frame BG cell")
    h.eq(icon_relative_point, "TOPLEFT", "managed Test Aura icon aligns with its Frame BG cell")
    local opposite_points = {
        RIGHT = { "TOPRIGHT", "TOPLEFT" },
        LEFT = { "TOPLEFT", "TOPRIGHT" },
        DOWN = { "BOTTOMLEFT", "TOPLEFT" },
        UP = { "TOPLEFT", "BOTTOMLEFT" },
    }
    for growth, expected in pairs(opposite_points) do
        M.db.growth_icon_short = growth
        M.invalidate_frame_runtime_config(short_frame)
        M.update_auras(short_frame, "show_short", "move_short", "timer_short",
            "bg_short", "scale_short", "spacing_short", "HELPFUL")
        local point, relative_to, relative_point =
            short_frame._managed_test_preview_background_anchor:GetPoint(1)
        h.eq(point, expected[1], growth .. " growth uses the opposite preview anchor")
        h.eq(relative_to, short_frame, growth .. " preview stays on the addon shell")
        h.eq(relative_point, expected[2], growth .. " preview sits opposite native growth")
    end
    M.db.bar_mode_short = true
    M.db.growth_bar_short = "DOWN"
    M.invalidate_frame_runtime_config(short_frame)
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.ok(M.set_test_aura_enabled("short", false), "managed Test Aura can be disabled")
    h.eq(short_backend.feature_enabled, true, "disabling Test Aura leaves native managed content enabled")
    h.ok(not short_frame.icons[1]:IsShown(), "disabling Test Aura hides the mock visual")
    h.ok(not short_frame._managed_test_preview_background.texture:IsShown(),
        "disabling Test Aura hides its separate Frame BG cell")

    for _, group_key in ipairs({ "short_buffs:bar", "short_buffs:icon" }) do
        local group = short_backend.container.__groups[group_key]
        h.ok(group, "Short Buffs create managed presentation group " .. group_key)
        h.eq(group.filter_string, "HELPFUL", "Short Buffs request helpful Auras")
        h.eq(group.options.candidateFilters.maxDuration, 300,
            "Short Buffs default to a five-minute maximum duration")
        h.eq(group.options.sortMethod, AuraContainerSortMethod.ExpirationOnly,
            "Short Buffs sort only by expiration")
        h.eq(group.options.sortDirection, AuraContainerSortDirection.Normal,
            "Short Buffs put the next expiration first")
    end
    h.ok(short_frame.move_handle.body:find("300 seconds", 1, true),
        "Short Buff mover tooltip reports its configured duration")

    M.db.short_threshold = 120
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    for _, group_key in ipairs({ "short_buffs:bar", "short_buffs:icon" }) do
        h.eq(short_backend.container.__groups[group_key].options.candidateFilters.maxDuration, 120,
            "Short Buff duration changes refresh native candidate filters")
    end
    h.ok(short_frame.move_handle.body:find("120 seconds", 1, true),
        "Short Buff mover tooltip follows duration changes")

    M.db.bg_short = true
    M.db.bar_mode_short = false
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    short_backend.container:SetSize(1, 1)
    h.ok(short_backend.frame_background.texture:IsShown(),
        "empty Short Buff Icon Mode keeps its shell-owned minimum Frame BG visible after native layout")

    M.db.scale_short = 1.4
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.eq(short_frame:GetScale(), 1.4,
        "managed Short Buff shell applies saved scale changes")
    local _, _, _, scaled_x, scaled_y = short_frame:GetPoint(1)
    h.eq(scaled_x, M.db.positions.short.x / 1.4,
        "managed scale keeps the saved horizontal screen position")
    h.eq(scaled_y, M.db.positions.short.y / 1.4,
        "managed scale keeps the saved vertical screen position")

    short_frame._is_user_positioning = true
    M.db.scale_short = 1.6
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.eq(short_frame:GetScale(), 1.4,
        "managed runtime refresh does not rescale during user positioning")
    short_frame._is_user_positioning = nil
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    h.eq(short_frame:GetScale(), 1.6,
        "managed shell applies the pending scale after user positioning")

    h.eq(M.get_managed_aura_backend("preset:short"), short_backend,
        "Short Buffs register one stable managed backend")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_short_presentation")

--#endregion FILE CONTENTS ===================================================
