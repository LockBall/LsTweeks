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

local function get_long_preview_timing(M)
    return M.get_long_preview_test_timing()
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

h.test("long Aura timer labels retain hours and minutes", function()
    local M = load_aura_frames()
    local text = CreateFrame("Frame"):CreateFontString()

    M.set_timer_text(text, "long", 2 * 3600 + 15 * 60, { enabled = true, format = "time" })
    h.eq(text:GetText(), "2h15m", "single-digit hours retain minutes")

    M.set_timer_text(text, "long", 3600, { enabled = true, format = "time" })
    h.eq(text:GetText(), "1h00m", "single-digit hours retain fixed minute width at zero")

    M.set_timer_text(text, "long", 43 * 3600 + 15 * 60, { enabled = true, format = "time" })
    h.eq(text:GetText(), "1.8d", "single-digit days use one decimal place")

    M.set_timer_text(text, "long", 30.5 * 86400, { enabled = true, format = "time" })
    h.eq(text:GetText(), "30.5d", "double-digit days retain one decimal place")

    M.set_timer_text(text, "long", 86400, { enabled = true, format = "time" })
    h.eq(text:GetText(), "1.0d", "single-digit days retain fixed decimal precision")

    M.set_timer_text(text, "long", 10.04 * 86400, { enabled = true, format = "time" })
    h.eq(text:GetText(), "10.0d", "double-digit days retain fixed decimal precision")

    M.set_timer_text(text, "long", 365.9 * 86400, { enabled = true, format = "time" })
    h.eq(text:GetText(), "365d", "triple-digit days use whole-day precision")

    M.set_timer_text(text, "long", 23.5 * 3600, { enabled = true, format = "time" })
    h.eq(text:GetText(), "23.5h", "double-digit hours retain one decimal place")

    M.set_timer_text(text, "long", 10.04 * 3600, { enabled = true, format = "time" })
    h.eq(text:GetText(), "10.0h", "double-digit hours retain fixed decimal precision")

    M.set_timer_text(text, "long", 48.6 * 60, { enabled = true, format = "time" })
    h.eq(text:GetText(), "48.6m", "double-digit minutes retain one decimal place")

    M.set_timer_text(text, "long", 10.04 * 60, { enabled = true, format = "time" })
    h.eq(text:GetText(), "10.0m", "double-digit minutes retain fixed decimal precision")

    M.set_timer_text(text, "long", 9 * 60 + 59, { enabled = true, format = "time" })
    h.eq(text:GetText(), "9m59s", "single-digit minutes retain seconds")

    M.set_timer_text(text, "long", 9 * 60, { enabled = true, format = "time" })
    h.eq(text:GetText(), "9m00s", "single-digit minutes retain fixed second width at zero")

    M.set_timer_text(text, "long", 48.6, { enabled = true, format = "time" })
    h.eq(text:GetText(), "48.6s", "sub-minute duration uses decimal seconds")

    M.set_timer_text(text, "long", 10.04, { enabled = true, format = "time" })
    h.eq(text:GetText(), "10.0s", "seconds-only countdown keeps fixed decimal precision")
end)

h.test("long Aura test preview cycles through every compact countdown format", function()
    local M = load_aura_frames()
    local preview = {}
    local text = CreateFrame("Frame"):CreateFontString()
    local ranges, phase_start, cycle_seconds, zero_hold_seconds = get_long_preview_timing(M)
    local function whole(value, unit)
        return string.format("%d%s", math.floor(value), unit)
    end
    local function decimal(value, unit)
        return string.format("%.1f%s", value, unit)
    end
    local function hours_and_minutes(value)
        local hours = math.floor(value)
        local minutes = math.floor(value * 60) % 60
        return string.format("%dh%02dm", hours, minutes)
    end
    local function minutes_and_seconds(value)
        local minutes = math.floor(value)
        local seconds = math.floor(value * 60) % 60
        return string.format("%dm%02ds", minutes, seconds)
    end
    local function after_first_unit(name)
        return phase_start[name] + (ranges[name].handoff_seconds or 0) + (ranges[name].seconds_per_unit or 1)
    end
    local function check_preview_at(now, expected, message)
        M.update_test_preview_state(preview, "show_long", now)
        M.set_timer_text(text, "long", preview.aura_remaining, { enabled = true, format = "time" })
        h.eq(text:GetText(), expected, message)
    end

    M.update_test_preview_state(preview, "show_long", 0)
    h.eq(preview.aura_duration, ranges.many_days.start * ranges.many_days.unit, "first phase starts in the whole-day range")
    h.eq(preview.aura_remaining, preview.aura_duration, "long preview begins at its full duration")
    check_preview_at(phase_start.many_days, whole(ranges.many_days.start, "d"), "first phase displays whole days")
    check_preview_at(phase_start.many_days + 1, whole(ranges.many_days.start - 1, "d"), "many-day phase counts down one day per second")
    check_preview_at(phase_start.tens_days, decimal(ranges.tens_days.start, "d"), "tens-day phase starts after the many-day sample")
    check_preview_at(after_first_unit("tens_days"), decimal(ranges.tens_days.start - 1, "d"), "tens-day phase completes its slowed handoff")
    check_preview_at(phase_start.single_days, decimal(ranges.single_days.start, "d"), "single-day phase starts after the tens-day sample")
    check_preview_at(after_first_unit("single_days"), decimal(ranges.single_days.start - 1, "d"), "single-digit days complete their slowed handoff")
    check_preview_at(phase_start.double_hours, decimal(ranges.double_hours.start / 24, "d"), "double-hour phase starts in the day display range")
    check_preview_at(after_first_unit("double_hours"), decimal(ranges.double_hours.start - 1, "h"), "double-digit hours complete their slowed handoff")
    check_preview_at(phase_start.single_hours, decimal(ranges.single_hours.start, "h"), "single-hour phase starts from its configured range")
    check_preview_at(after_first_unit("single_hours"), hours_and_minutes(ranges.single_hours.start - 1), "single-digit hours complete their slowed handoff")
    check_preview_at(phase_start.double_minutes, hours_and_minutes(ranges.double_minutes.start / 60), "double-minute phase starts from its configured range")
    check_preview_at(after_first_unit("double_minutes"), decimal(ranges.double_minutes.start - 1, "m"), "double-digit minutes complete their slowed handoff")
    check_preview_at(phase_start.single_minutes, decimal(ranges.single_minutes.start, "m"), "single-minute phase starts from its configured range")
    check_preview_at(after_first_unit("single_minutes"), minutes_and_seconds(ranges.single_minutes.start - 1), "single-digit minutes complete their slowed handoff")
    check_preview_at(phase_start.double_seconds, minutes_and_seconds(ranges.double_seconds.start / 60), "double-seconds phase starts from its configured range")
    check_preview_at(after_first_unit("double_seconds"), decimal(ranges.double_seconds.start - 1, "s"), "seconds complete their slowed handoff")
    check_preview_at(phase_start.single_seconds, decimal(ranges.single_seconds.start, "s"), "seconds phase reaches the real-time final ten seconds")
    check_preview_at(phase_start.single_seconds + 5, decimal(ranges.single_seconds.start - 5, "s"), "final ten seconds count down in real time")
    M.update_test_preview_state(preview, "show_long", cycle_seconds - zero_hold_seconds)
    h.eq(preview.aura_remaining, 0, "single-seconds phase reaches zero before the preview resets")
    check_preview_at(cycle_seconds, whole(ranges.many_days.start, "d"), "preview loops only after the zero state has been visible")

    M.update_test_preview_state(preview, "show_long", phase_start.single_seconds + 5)
    h.eq(M.format_aura_tooltip_duration(preview.aura_remaining), "00h 00m 05s", "tooltip duration retains full hours, minutes, and seconds")
end)

h.test("long Aura test preview pause preserves and resumes its countdown phase", function()
    local M = load_aura_frames()
    local preview = {}
    local ranges, phase_start = get_long_preview_timing(M)
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}

    M.reset_test_preview_clock("show_long", 0)
    M.toggle_test_preview_pause("show_long", phase_start.single_days)
    h.ok(M.is_test_preview_paused("show_long"), "preview reports paused state")
    M.update_test_preview_state(preview, "show_long", 100)
    h.eq(preview.aura_remaining, ranges.single_days.start * ranges.single_days.unit, "paused preview retains its captured phase")

    M.toggle_test_preview_pause("show_long", 100)
    h.ok(not M.is_test_preview_paused("show_long"), "preview reports resumed state")
    M.update_test_preview_state(preview, "show_long", 101)
    h.eq(preview.aura_remaining,
        ranges.single_days.start * ranges.single_days.unit,
        "resumed preview remains on the held handoff label")
end)

h.test("long Aura test preview starts from whole days when enabled", function()
    local M = load_aura_frames()
    local preview = {}
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}

    h.ok(M.is_test_preview_paused("show_long"), "uninitialized restored preview reports paused for the Play button")
    M.append_test_aura({}, "show_long", "HELPFUL")
    M.reset_test_preview_clock("show_long", 100)
    M.update_test_preview_state(preview, "show_long", 100)

    h.eq(preview.aura_remaining, 365 * 86400, "new preview begins at the whole-day phase")
end)

h.test("restored test preview starts paused until played", function()
    local M = load_aura_frames()
    local preview = {}
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}

    M.append_test_aura({}, "show_long", "HELPFUL")
    h.ok(M.is_test_preview_paused("show_long"), "restored preview begins paused")
    M.update_test_preview_state(preview, "show_long", 100)
    h.eq(preview.aura_remaining, 365 * 86400, "paused restored preview retains its initial value")

    M.toggle_test_preview_pause("show_long", 100)
    M.update_test_preview_state(preview, "show_long", 101)
    h.eq(math.floor(preview.aura_remaining), 364 * 86400, "playing restored preview begins its countdown")
end)

h.test("play on a never-started preview starts its clock playing", function()
    local M = load_aura_frames()
    local preview = {}
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}

    h.ok(M.is_test_preview_paused("show_long"), "unstarted preview reads as paused")
    local paused = M.toggle_test_preview_pause("show_long", 100)
    h.ok(not paused, "play click on an unstarted preview reports playing")
    h.ok(not M.is_test_preview_paused("show_long"), "unstarted preview plays after one click")
    M.update_test_preview_state(preview, "show_long", 101)
    h.eq(math.floor(preview.aura_remaining), 364 * 86400, "started clock counts down from cycle zero")
end)

h.test("rechecking test aura after a silent uncheck restarts paused at zero", function()
    local M = load_aura_frames()
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}

    -- Preview was playing when a profile load silently unchecked the box:
    -- the uncheck callback never ran, so the started clock survives.
    M.reset_test_preview_clock("show_long", 0)
    M.toggle_test_preview_pause("show_long", 50)
    M.toggle_test_preview_pause("show_long", 50)

    M.start_test_preview_paused("show_long", 60)
    h.ok(M.is_test_preview_paused("show_long"), "recheck starts the preview paused")
    local preview = {}
    M.update_test_preview_state(preview, "show_long", 60)
    h.eq(preview.aura_remaining, 365 * 86400, "recheck discards the stale clock and shows the initial value")
end)

h.test("test preview stacks tick live with the timer", function()
    local M = load_aura_frames()
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}
    M.reset_test_preview_clock("show_short", 0)

    -- Icon factories create count_text hidden (af_main.lua); mirror that here.
    local preview = { count_text = CreateFrame("Frame"):CreateFontString() }
    preview.count_text:Hide()
    -- sec_per_stack is 2.0 with stack_min 1: bucket 1 hides the count text,
    -- bucket 2 shows "2" without waiting for a scan rebuild.
    M.update_test_preview_state(preview, "show_short", 1)
    h.ok(not preview.count_text:IsShown(), "stack count of one stays hidden")
    M.update_test_preview_state(preview, "show_short", 3)
    h.ok(preview.count_text:IsShown(), "ticker reveals the next stack bucket live")
    h.eq(preview._lstweeks_count_text, 2, "ticker writes the live stack value through the render cache")
end)

h.test("long Aura test preview transfers to Short at the configured threshold", function()
    local M = load_aura_frames()
    local ranges, phase_start = get_long_preview_timing(M)
    M.db = { show_long = true, test_aura_long = true }
    M._aura_map = {}
    M._test_preview_time_offsets = {}
    M._test_preview_paused_times = {}
    M._test_preview_started = {}
    M.reset_test_preview_clock("show_long")

    M.unified_scan(nil, M.DEFAULT_SHORT_THRESHOLD, 0, 0)
    h.ok(M._aura_maps_by_category.long.__test_preview__, "preview begins in the Long bucket")

    local threshold_time = phase_start.double_seconds
        + (ranges.double_seconds.handoff_seconds or 0)
        + (math.max(0, ranges.double_seconds.start - M.DEFAULT_SHORT_THRESHOLD)
            * (ranges.double_seconds.seconds_per_unit or 1)) + 0.001
    M._test_preview_time_offsets.show_long = GetTime() - threshold_time
    M.unified_scan(nil, M.DEFAULT_SHORT_THRESHOLD, 0, 0)
    h.is_nil(M._aura_maps_by_category.long.__test_preview__, "preview leaves Long at the threshold")
    h.ok(M._aura_maps_by_category.short.__test_preview__, "preview enters Short at the threshold")
end)

h.test("threshold reclassification coalesces into one shared refresh", function()
    local M = load_aura_frames()
    local original_mark_dirty = M.mark_aura_scan_dirty
    local original_update = M.update_auras
    local original_frames = M.frames_list
    local marks, updates = 0, 0
    M.frames_list = {
        {
            update_params = {
                show_key = "show_long", move_key = "move_long", timer_key = "timer_long",
                bg_key = "bg_long", scale_key = "scale_long", spacing_key = "spacing_long", aura_filter = "HELPFUL",
            },
        },
    }
    M.mark_aura_scan_dirty = function() marks = marks + 1 end
    M.update_auras = function() updates = updates + 1 end

    M.queue_threshold_reclassification()
    M.queue_threshold_reclassification()
    h.stub.Advance(0)

    M.mark_aura_scan_dirty = original_mark_dirty
    M.update_auras = original_update
    M.frames_list = original_frames

    h.eq(marks, 1, "threshold crossing marks one shared scan")
    h.eq(updates, 1, "threshold crossing refreshes each frame once")
end)

h.test("cycling long test preview reclassifies back to Long after restart", function()
    local M = load_aura_frames()
    local threshold = M.DEFAULT_SHORT_THRESHOLD
    h.ok(M.should_reclassify_aura_category("long", threshold, threshold, false),
        "real Long aura transfers at the threshold")
    h.ok(not M.should_reclassify_aura_category("short", threshold + 1, threshold, false),
        "real Short aura cannot move back to Long")
    h.ok(M.should_reclassify_aura_category("short", threshold + 1, threshold, true),
        "cycling test preview returns from Short to Long after restart")
end)

h.test("icon timer slots reserve width for long duration labels", function()
    local M = load_aura_frames()
    M.db = { max_icons = 2 }
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

h.test("Aura icon hover uses the centralized taint-safe tooltip outside combat", function()
    local M = load_aura_frames()
    M.db = { max_icons = 1 }
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 101
    icon.aura_spell_id = 202
    icon.aura_name = "Test Aura"
    icon.tooltip_enabled = true

    icon:GetScript("OnEnter")(icon)

    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip.__kind, "Frame", "Aura tooltip avoids Blizzard GameTooltip widget state")
    h.is_nil(tooltip:GetLastCall("SetUnitAuraByAuraInstanceID"), "Aura hover never binds live data to a GameTooltip")
    h.eq(tooltip.lines[1]:GetText(), "Test Aura", "safe Aura details still render")
end)

h.test("Aura icon hover uses the centralized taint-safe tooltip in combat", function()
    local M = load_aura_frames()
    M.db = { max_icons = 1 }
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 101
    icon.aura_spell_id = 202
    icon.aura_name = "Combat Aura"
    icon.tooltip_enabled = true
    h.stub.in_combat = true

    icon:GetScript("OnEnter")(icon)

    h.stub.in_combat = false
    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip.__kind, "Frame", "combat Aura tooltip avoids Blizzard GameTooltip widget state")
    h.is_nil(tooltip:GetLastCall("SetUnitAuraByAuraInstanceID"), "combat hover never binds live Aura data")
end)

h.test("centralized tooltip renderer preserves rich left and right text", function()
    load_aura_frames()
    local owner = CreateFrame("Frame", nil, UIParent)
    h.addon.ShowOwnedTooltipLines(owner, {
        {
            left_text = "Test Aura",
            right_text = "1 min",
            left_color = { r = 1, g = 0.82, b = 0 },
            right_color = { r = 0.7, g = 0.7, b = 1 },
        },
    })

    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip.__kind, "Frame", "rich line rendering stays off Blizzard GameTooltip")
    h.eq(tooltip.lines[1]:GetText(), "Test Aura", "left text retained")
    h.eq(tooltip.right_lines[1]:GetText(), "1 min", "right text retained")
end)

h.test("centralized tooltip renderer shows right-text-only cached lines", function()
    load_aura_frames()
    local owner = CreateFrame("Frame", nil, UIParent)
    h.addon.ShowOwnedTooltipLines(owner, {
        { right_text = "500 armor", right_color = { r = 0.7, g = 0.7, b = 1 } },
    })

    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip:IsShown(), true, "right-only cached lines still show the tooltip")
    h.eq(tooltip.right_lines[1]:GetText(), "500 armor", "right-only text renders")
    h.eq(tooltip.right_lines[1]:IsShown(), true, "right-only line is visible")
end)

h.test("centralized tooltip renderer matches native fonts and flips at screen edges", function()
    load_aura_frames()
    local owner = CreateFrame("Frame", nil, UIParent)
    owner.GetCenter = function()
        return 1800, 100
    end
    h.addon.ShowOwnedTooltipLines(owner, {
        { left_text = "Header" },
        { left_text = "Body" },
    })

    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip.lines[1].__template, "GameTooltipHeaderText", "first row uses the native tooltip header font")
    h.eq(tooltip.lines[2].__template, "GameTooltipText", "later rows use the native tooltip body font")
    h.eq(tooltip:GetLastCall("SetClampedToScreen")[1], true, "tooltip is clamped as a final screen-edge guard")

    local point, relative_to, relative_point, x, y = tooltip:GetPoint()
    h.eq(point, "BOTTOMRIGHT", "bottom-right owner places tooltip above and to the left")
    h.eq(relative_to, owner, "smart anchor remains attached to its owner")
    h.eq(relative_point, "TOPLEFT", "owner-facing corner is selected")
    h.eq(x, -8, "smart anchor keeps a horizontal gap")
    h.eq(y, 8, "smart anchor keeps a vertical gap")
end)

h.test("combat Aura tooltip keeps live-only timed aura from reading as permanent", function()
    local M = load_aura_frames()
    M.db = { max_icons = 1 }
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_name = "Combat Aura"
    icon.aura_duration = 0
    icon.aura_remaining = 90
    icon.aura_expiration = GetTime() + 90
    icon.tooltip_enabled = true
    h.stub.in_combat = true

    icon:GetScript("OnEnter")(icon)

    h.stub.in_combat = false
    local lines = h.addon.GetOwnedTooltip().lines
    h.eq(lines[2]:GetText(), "Remaining: 00h 01m 30s", "live remaining time is shown without a readable total duration")
    h.is_nil(lines[3], "combat fallback does not label the timed aura permanent")
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
