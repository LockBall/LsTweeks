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

h.run("af_ranges")

--#endregion FILE CONTENTS ===================================================
