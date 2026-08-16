-- Aura Frames layout, movement, runtime ticker, background, and range-helper tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global, undefined-field


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function load_aura_frames()
    h.load_addon("modules/aura_frames")
    return h.addon.aura_frames
end

h.test("icon timer slots reserve width for long duration labels", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_long", "move_long", "timer_long", "bg_long", "scale_long", "spacing_long", "Long", false)
    frame._runtime_config_cache = {
        frame_width = 120,
        spacing = 2,
        growth = "RIGHT",
        show_timer_text = true,
        layout_show_timer_text = true,
        cooldown_icon_overlay = false,
    }

    M.setup_layout(frame, "show_long", "spacing_long", false)

    h.eq(frame.icons[1].timer_slot:GetWidth(), 36, "timer slot fits compact duration text")
    h.eq(frame.icons[1].time_text:GetWidth(), 36, "timer text uses the compact reserved slot")
    h.eq(frame._layout_cache.icons_per_row, 2, "horizontal layout keeps compact timer spacing")
end)

h.test("disabled preset frame starts hidden before its first event", function()
    local M = load_aura_frames()
    M.db = {
        show_short = false,
        move_short = false,
        width_short = 120,
    }

    local frame = M.create_aura_frame(
        "show_short", "move_short", "timer_short", "bg_short",
        "scale_short", "spacing_short", "Short", false
    )

    h.eq(frame:IsShown(), false, "disabled frame shell is hidden at creation")
    h.eq(frame.move_handle:IsShown(), false, "disabled frame move handle is hidden with shell")
    h.eq(frame.resizer:IsShown(), false, "disabled frame resizer is hidden with shell")
end)

h.test("move mode uses an inward border mover without changing aura layout", function()
    local M = load_aura_frames()
    M.db = { width_long = 120 }
    local frame = M.create_aura_frame(
        "show_long", "move_long", "timer_long", "bg_long",
        "scale_long", "spacing_long", "Long", false
    )

    M.update_aura_frame_move_controls(frame, true)
    M.setup_layout(frame, "show_long", "spacing_long", false)
    h.eq(#frame.move_handle.hit_areas, 4, "border mover exposes four inward edge hit areas")
    for _, edge in ipairs(frame.move_handle.hit_areas) do
        h.ok(edge:GetScript("OnEnter"), "each border edge owns the title tooltip entry path")
        h.ok(edge:GetScript("OnDragStart"), "each border edge starts the shared frame drag path")
        h.ok(edge:GetScript("OnDragStop"), "each border edge stops the shared frame drag path")
    end
    h.eq(frame._layout_cache.move_mode, nil, "Move Mode does not alter aura layout state")

    local _, resize_relative_to, resize_relative_point = frame.resizer:GetPoint(1)
    h.eq(resize_relative_to, frame, "resize grip remains on the safe addon frame shell")
    h.eq(resize_relative_point, "BOTTOMRIGHT", "resize grip overlays the border corner")

    h.eq(frame.bottom_title_bar, nil, "aura frames no longer create a second drag handle")
    M.update_aura_frame_move_controls(frame, false)
    h.eq(frame.move_handle:IsShown(), false, "leaving move mode hides the mover border")
    h.eq(frame.resizer:IsShown(), false, "leaving move mode hides the resize handle")
end)

h.test("combat background switches pre-sized Aura frame variants without geometry writes", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    frame._runtime_config_cache = {
        frame_width = 120,
        spacing = 2,
        growth = "DOWN",
        show_timer_text = false,
        layout_show_timer_text = false,
        cooldown_icon_overlay = false,
    }

    M.setup_layout(frame, "show_short", "spacing_short", false)
    local variants = frame._combat_background_variants
    h.eq(#variants, M.AURA_FRAME_LIMIT + 1,
        "one pre-sized background exists for every display count")

    local color = { r = 0.2, g = 0.3, b = 0.4, a = 0.5 }
    M.update_combat_background(frame, 0, true, color, false, false)
    h.ok(#(variants[M.AURA_FRAME_LIMIT + 1]:GetCalls("SetColorTexture") or {}) > 0,
        "maximum-count background receives the cached color")
    local size_calls_before = #(variants[3]:GetCalls("SetSize") or {})

    h.stub.in_combat = true
    local active = M.update_combat_background(frame, 2, true, color, true, false)
    h.ok(active, "combat background activates when frame background is enabled")
    h.ok(variants[3]:IsShown(), "two displayed auras select the two-aura background")
    h.ok(not variants[1]:IsShown(), "empty background remains hidden")
    h.eq(#(variants[3]:GetCalls("SetSize") or {}), size_calls_before, "combat selection does not resize the background")

    M.update_combat_background(frame, 1, true, color, true, false)
    h.ok(variants[2]:IsShown(), "count changes switch to the matching pre-sized background")
    h.ok(not variants[3]:IsShown(), "previous background is hidden")
    h.stub.in_combat = false
end)

h.test("saved preset and custom colors normalize to readable RGBA", function()
    local M = load_aura_frames()
    M.db = {
        color_static = { r = -1, g = 2, b = "0.5", a = 9 },
        stack_color_static = { r = 2, g = -1, b = "0.25" },
        bar_bg_color_static = "invalid",
        custom_frames = {
            {
                id = "custom_color_test",
                color = { r = 2, g = -1, b = 0.25 },
                bg_color = { r = 0.5, g = 0.5, b = 0.5, a = -1 },
                stack_color = { r = -1, g = "0.4", b = 2 },
            },
        },
    }

    M.normalize_saved_colors(M.db)
    h.eq(M.db.color_static.r, 0, "preset red clamps to zero")
    h.eq(M.db.color_static.g, 1, "preset green clamps to one")
    h.eq(M.db.color_static.b, 0.5, "preset blue coerces to a number")
    h.eq(M.db.color_static.a, 1, "preset alpha clamps to one")
    h.eq(M.db.stack_color_static.r, 1, "preset stack red clamps to one")
    h.eq(M.db.stack_color_static.g, 0, "preset stack green clamps to zero")
    h.eq(M.db.stack_color_static.b, 0.25, "preset stack blue coerces to a number")
    h.eq(M.db.custom_frames[1].color.r, 1, "custom red clamps to one")
    h.eq(M.db.custom_frames[1].color.g, 0, "custom green clamps to zero")
    h.eq(M.db.custom_frames[1].bg_color.a, 0, "custom alpha clamps to zero")
    h.eq(M.db.custom_frames[1].stack_color.r, 0, "custom stack red clamps to zero")
    h.eq(M.db.custom_frames[1].stack_color.g, 0.4, "custom stack green coerces to a number")
    h.eq(M.db.custom_frames[1].stack_color.b, 1, "custom stack blue clamps to one")
end)

h.test("visible icon ticker refresh stops idle ticker immediately", function()
    local M = load_aura_frames()
    local range = M.SETTING_RANGES.aura_visible_icon_tick
    M.db = { aura_visible_icon_tick = range.min }
    M.frames_list = {}

    h.eq(h.stub.ActiveTimerCount(), 0, "starts without timers")
    M.ensure_visible_icon_ticker(true)
    h.ok(M._visible_icon_ticker, "ticker started")
    h.eq(h.stub.ActiveTimerCount(), 1, "ticker queued")

    M.refresh_visible_icon_ticker()
    h.eq(M._visible_icon_ticker, nil, "ticker reference cleared")
    h.eq(h.stub.ActiveTimerCount(), 0, "queued ticker cancelled")
end)

h.test("visible icon ticker skips managed frames without legacy icon pools", function()
    local M = load_aura_frames()
    M.db = { short_threshold = M.DEFAULT_SHORT_THRESHOLD }
    local managed_frame = CreateFrame("Frame", nil, UIParent)
    managed_frame:Show()
    managed_frame.icons = nil
    M.frames_list = { managed_frame }

    h.eq(M.tick_visible_icons(GetTime()), false,
        "managed frame transition leaves no legacy icon work to tick")
end)

h.test("shared Aura bar range helper skips unchanged writes", function()
    local M = load_aura_frames()
    local writes = 0
    local bar = {
        SetMinMaxValues = function()
            writes = writes + 1
        end,
    }

    M.set_bar_minmax_if_changed(bar, 0, 10)
    M.set_bar_minmax_if_changed(bar, 0, 10)
    M.set_bar_minmax_if_changed(bar, 0, 20)

    h.eq(writes, 2, "shared helper writes only changed ranges")
end)

h.test("layout-owned Aura height calculation covers bars and icon growth", function()
    local M = load_aura_frames()
    local layout = { row_height = 18, icon_size = 32, icons_per_row = 2, growth = "RIGHT" }

    h.eq(M.get_aura_frame_height(layout, 3, true, 2, false), 72, "bar rows include shared bottom padding")
    layout.growth = "UP"
    h.eq(M.get_aura_frame_height(layout, 3, false, 2, true), 150, "vertical icons retain timer footprint")
    layout.growth = "RIGHT"
    h.eq(M.get_aura_frame_height(layout, 3, false, 2, true), 104, "horizontal icons use wrapped rows")
    h.eq(M.get_aura_frame_height(layout, 0, false, 2, false), 44, "empty icon frame keeps its base footprint")
    h.eq(M.get_aura_frame_height(nil, 3, false, 2, true), 132, "missing layout retains the stable legacy icon fallback")
end)


h.run("af_layout_runtime")

--#endregion FILE CONTENTS ===================================================
