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

h.test("world-entry tooltip cache eviction retains reusable spell lines", function()
    local M = load_aura_frames()
    local aura_lines = { { left_text = "Aura" } }
    local spell_lines = { { left_text = "Spell" } }
    M._tooltip_data_lines_cache = {
        ["aura:101"] = aura_lines,
        ["aura:202"] = aura_lines,
        ["spell:303"] = spell_lines,
    }

    M.clear_aura_tooltip_instance_cache()

    h.is_nil(M._tooltip_data_lines_cache["aura:101"], "first aura entry evicted")
    h.is_nil(M._tooltip_data_lines_cache["aura:202"], "second aura entry evicted")
    h.eq(M._tooltip_data_lines_cache["spell:303"], spell_lines, "spell entry survives world entry")
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
    local frame = CreateFrame("Frame", nil, UIParent)
    frame._display_count = 4
    frame._tooltip_cache_retry_count = 2
    frame._tooltip_cache_retry_pending = true
    M.db = { custom_frames = { { id = "custom_test" } } }
    M.frames = { show_custom_test = frame }
    M.frames_list = { frame }
    M.controls = { custom_custom_test_scale = {} }
    M.clear_custom_aura_scan_cache = function() cache_clears = cache_clears + 1 end

    M.destroy_custom_frame("custom_test")

    h.eq(#M.db.custom_frames, 0, "custom frame DB entry is removed")
    h.is_nil(M.controls.custom_custom_test_scale, "custom frame controls are removed")
    h.eq(cache_clears, 1, "custom frame deletion clears its scan cache")
    h.eq(frame._display_count, 0, "custom frame display state cleared")
    h.eq(frame._tooltip_cache_retry_count, 0, "custom frame retry count cleared")
    h.eq(frame._tooltip_cache_retry_pending, false, "custom frame retry state cleared")
end)

h.test("category-specific false settings override flat Aura Frame fallbacks", function()
    local M = load_aura_frames()
    local original_activity = M.get_frame_activity_state
    local original_timer_text = M.is_timer_text_enabled
    local original_cooldown_overlay = M.uses_cooldown_icon_overlay
    local original_render = M.render_aura_map
    local original_refresh_fade = M.refresh_frame_ooc_fade
    local original_refresh_ticker = M.refresh_visible_icon_ticker
    M.db = {
        short_threshold = 5,
        bar_mode_short = false,
        bar_mode = true,
        bg_short = false,
        bg = true,
        width_short = 120,
        spacing_short = 2,
        scale_short = 1,
        growth_short = "DOWN",
        max_icons_short = 1,
        color_short = { r = 1, g = 1, b = 1 },
        bar_bg_color_short = { r = 0, g = 0, b = 0, a = 1 },
        bar_text_color_short = { r = 1, g = 1, b = 1 },
        bg_color_short = { r = 1, g = 0, b = 0, a = 0.5 },
    }
    M._aura_map = {}
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.category = "short"
    frame.icons = {}
    frame._layout_cache = {
        frame_width = 120,
        bar_mode = false,
        show_timer_text = false,
        layout_show_timer_text = false,
        cooldown_icon_overlay = false,
        spacing = 2,
        growth = "DOWN",
    }

    M.get_frame_activity_state = function()
        return { enabled = true, moving = false, test_aura = false }
    end
    M.is_timer_text_enabled = function() return false end
    M.uses_cooldown_icon_overlay = function() return false end
    M.render_aura_map = function() return 0 end
    M.refresh_frame_ooc_fade = function() end
    M.refresh_visible_icon_ticker = function() end

    M.update_auras(frame, "show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "HELPFUL")

    M.get_frame_activity_state = original_activity
    M.is_timer_text_enabled = original_timer_text
    M.uses_cooldown_icon_overlay = original_cooldown_overlay
    M.render_aura_map = original_render
    M.refresh_frame_ooc_fade = original_refresh_fade
    M.refresh_visible_icon_ticker = original_refresh_ticker

    h.eq(frame._bar_mode, false, "category false keeps icon mode")
    h.eq(frame._lstweeks_bg_a, 0, "category false hides background")
end)

h.test("unified scan continues after malformed helpful and debuff records", function()
    local M = load_aura_frames()
    M.db = {
        max_icons_static = 2,
        max_icons_short = 2,
        max_icons_long = 2,
        max_icons_debuff = 2,
    }
    h.stub.auras.player = {
        buffs = {
            { spellId = 1001, name = "Malformed Buff", icon = 1, duration = 10, expirationTime = 10 },
            { auraInstanceID = 101, spellId = 1002, name = "Valid Buff", icon = 2, duration = 10, expirationTime = 10 },
        },
        debuffs = {
            { spellId = 2001, name = "Malformed Debuff", icon = 3, duration = 10, expirationTime = 10 },
            { auraInstanceID = 202, spellId = 2002, name = "Valid Debuff", icon = 4, duration = 10, expirationTime = 10 },
        },
    }
    M._aura_map = {}

    M.unified_scan(nil, 5, 2, 2)

    h.ok(M._aura_map[101], "valid helpful record survives an earlier malformed record")
    h.ok(M._aura_map[202], "valid debuff record survives an earlier malformed record")
    h.stub.auras.player = nil
end)

h.test("unified scan refreshes an Aura order key when identity changes", function()
    local M = load_aura_frames()
    M.db = {
        max_icons_static = 1,
        max_icons_short = 1,
        max_icons_long = 1,
        max_icons_debuff = 1,
    }
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 303, spellId = 3003, name = "Original", icon = 3, duration = 10, expirationTime = 10 },
        },
        debuffs = {},
    }
    M._aura_map = {}

    M.unified_scan(nil, 5, 1, 1)
    local original_key = M._aura_map[303].order_key
    h.stub.auras.player.buffs[1].name = "Updated"
    M.unified_scan(nil, 5, 1, 1)

    h.ok(M._aura_map[303].order_key ~= original_key, "identity change refreshes ordering")
    h.stub.auras.player = nil
end)

h.run("af_ranges")

--#endregion FILE CONTENTS ===================================================
