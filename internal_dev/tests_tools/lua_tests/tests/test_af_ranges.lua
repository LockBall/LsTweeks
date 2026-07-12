-- Aura Frames setting range tests: verifies centralized numeric metadata drives public clamp helpers.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function load_aura_frames()
    h.load_addon("modules/aura_frames")
    return h.addon.aura_frames
end

h.test("visible icon tick clamps and snaps from centralized range metadata", function()
    local M = load_aura_frames()
    local range = M.SETTING_RANGES.aura_visible_icon_tick
    h.ok(range, "range exists")
    h.eq(M.MIN_VISIBLE_ICON_TICK, range.min, "min compatibility constant follows range")
    h.eq(M.MAX_VISIBLE_ICON_TICK, range.max, "max compatibility constant follows range")
    h.eq(M.VISIBLE_ICON_TICK_STEP, range.step, "step compatibility constant follows range")

    M.db = { aura_visible_icon_tick = range.min - range.step }
    h.eq(M.get_visible_icon_tick_interval(), range.min, "below range clamps to min")

    M.db.aura_visible_icon_tick = range.max + range.step
    h.eq(M.get_visible_icon_tick_interval(), range.max, "above range clamps to max")

    M.db.aura_visible_icon_tick = range.min + (range.step * 0.6)
    h.eq(M.get_visible_icon_tick_interval(), range.min + range.step, "in-range value snaps to nearest step")
end)

h.test("saved preset and custom colors normalize to readable RGBA", function()
    local M = load_aura_frames()
    M.db = {
        color_static = { r = -1, g = 2, b = "0.5", a = 9 },
        bar_bg_color_static = "invalid",
        custom_frames = {
            {
                id = "custom_color_test",
                color = { r = 2, g = -1, b = 0.25 },
                bg_color = { r = 0.5, g = 0.5, b = 0.5, a = -1 },
            },
        },
    }

    M.normalize_saved_colors(M.db)
    h.eq(M.db.color_static.r, 0, "preset red clamps to zero")
    h.eq(M.db.color_static.g, 1, "preset green clamps to one")
    h.eq(M.db.color_static.b, 0.5, "preset blue coerces to a number")
    h.eq(M.db.color_static.a, 1, "preset alpha clamps to one")
    h.eq(M.db.custom_frames[1].color.r, 1, "custom red clamps to one")
    h.eq(M.db.custom_frames[1].color.g, 0, "custom green clamps to zero")
    h.eq(M.db.custom_frames[1].bg_color.a, 0, "custom alpha clamps to zero")
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

h.test("disabled module rejects tooltip cache prewarm before frame inspection", function()
    local M = load_aura_frames()
    local original_is_runtime_enabled = M.is_runtime_enabled
    local frame_inspected = false
    local blocked_frame = setmetatable({}, {
        __index = function()
            frame_inspected = true
            error("disabled prewarm must not inspect the frame")
        end,
    })

    M.is_runtime_enabled = function() return false end
    M.prewarm_aura_tooltip_cache(blocked_frame)
    M.is_runtime_enabled = original_is_runtime_enabled

    h.ok(not frame_inspected, "disabled module exits before reading tooltip frame state")
end)

h.test("repeated dirty marks do not clear Aura scan caches before the pending scan", function()
    local M = load_aura_frames()
    local custom_cache_clears = 0
    local sorted_cache_clears = 0
    M._aura_scan_dirty = false
    M.clear_custom_aura_scan_cache = function()
        custom_cache_clears = custom_cache_clears + 1
    end
    M.clear_sorted_aura_ids_cache = function()
        sorted_cache_clears = sorted_cache_clears + 1
    end

    M.mark_aura_scan_dirty()
    M.mark_aura_scan_dirty()

    h.eq(custom_cache_clears, 1, "custom Aura cache clears once per pending scan")
    h.eq(sorted_cache_clears, 1, "sorted Aura cache clears once per pending scan")
end)

h.test("custom frame deletion clears its scan cache and controls", function()
    local M = load_aura_frames()
    local cache_clears = 0
    M.db = { custom_frames = { { id = "custom_test" } } }
    M.frames = {}
    M.frames_list = {}
    M.controls = { custom_custom_test_scale = {} }
    M.clear_custom_aura_scan_cache = function() cache_clears = cache_clears + 1 end

    M.destroy_custom_frame("custom_test")

    h.eq(#M.db.custom_frames, 0, "custom frame DB entry is removed")
    h.is_nil(M.controls.custom_custom_test_scale, "custom frame controls are removed")
    h.eq(cache_clears, 1, "custom frame deletion clears its scan cache")
end)

h.run("af_ranges")

--#endregion FILE CONTENTS ===================================================
