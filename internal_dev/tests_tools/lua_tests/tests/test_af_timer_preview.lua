-- Aura Frames timer formatting and generic preview playback tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global, undefined-field

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

h.test("long Aura timer labels retain compact duration detail", function()
    local M = load_aura_frames()
    local text = CreateFrame("Frame"):CreateFontString()
    local cases = {
        { 2 * 3600 + 15 * 60, "2h15m" }, { 3600, "1h00m" },
        { 43 * 3600 + 15 * 60, "1.8d" }, { 30.5 * 86400, "30.5d" },
        { 365.9 * 86400, "365d" }, { 23.5 * 3600, "23.5h" },
        { 48.6 * 60, "48.6m" }, { 9 * 60 + 59, "9m59s" }, { 48.6, "48.6s" },
    }
    for _, case in ipairs(cases) do
        M.set_timer_text(text, "long", case[1], { enabled = true, format = "time" })
        h.eq(text:GetText(), case[2], "formats " .. tostring(case[1]) .. " seconds")
    end
end)

h.test("restored test preview starts paused and resumes its countdown", function()
    local M = load_aura_frames()
    local preview = {}
    M._test_preview_time_offsets, M._test_preview_paused_times, M._test_preview_started = {}, {}, {}
    M.append_test_aura({}, "show_essential", "HELPFUL")
    h.ok(M.is_test_preview_paused("show_essential"), "restored preview begins paused")
    M.update_test_preview_state(preview, "show_essential", 100)
    h.eq(preview.aura_remaining, 20, "paused preview retains its initial value")
    M.toggle_test_preview_pause("show_essential", 100)
    M.update_test_preview_state(preview, "show_essential", 101)
    h.eq(math.floor(preview.aura_remaining), 19, "playing preview resumes its countdown")
end)

h.test("play on a never-started preview starts its clock playing", function()
    local M = load_aura_frames()
    local preview = {}
    M._test_preview_time_offsets, M._test_preview_paused_times, M._test_preview_started = {}, {}, {}
    h.ok(M.is_test_preview_paused("show_essential"), "unstarted preview reads as paused")
    h.eq(M.toggle_test_preview_pause("show_essential", 100), false, "Play reports playing")
    M.update_test_preview_state(preview, "show_essential", 101)
    h.eq(math.floor(preview.aura_remaining), 19, "started clock counts down from cycle zero")
end)

h.test("rechecking test Aura discards a stale preview clock", function()
    local M = load_aura_frames()
    M._test_preview_time_offsets, M._test_preview_paused_times, M._test_preview_started = {}, {}, {}
    M.reset_test_preview_clock("show_essential", 0)
    M.toggle_test_preview_pause("show_essential", 10)
    M.toggle_test_preview_pause("show_essential", 10)
    M.start_test_preview_paused("show_essential", 60)
    local preview = {}
    M.update_test_preview_state(preview, "show_essential", 60)
    h.ok(M.is_test_preview_paused("show_essential"), "rechecked preview starts paused")
    h.eq(preview.aura_remaining, 20, "rechecked preview returns to its initial value")
end)

h.test("global test Aura playback keeps enabled preview clocks synchronized", function()
    local M = load_aura_frames()
    M.db = {
        show_essential = true, show_short = true, show_tracked_buffs = true,
        custom_frames = { { id = "custom_1", show = true }, { id = "custom_2", show = false } },
    }
    M._test_preview_time_offsets, M._test_preview_paused_times, M._test_preview_started = {}, {}, {}
    M.refresh_test_aura_category = function() end
    M.start_global_test_aura_previews_paused()
    h.ok(M.is_test_preview_paused("show_essential"), "enabled preview-capable preset starts paused")
    h.ok(M.is_test_preview_paused("show_tracked_buffs"), "second preview-capable preset starts paused")
    h.ok(M.is_test_preview_paused("show_custom_1"), "enabled custom frame starts paused")
    h.ok(not M._test_preview_started.show_short, "managed preset has no preview clock")
    h.ok(not M._test_preview_started.show_custom_2, "disabled custom frame has no preview clock")
    h.eq(M.toggle_global_test_aura_previews(), false, "Play starts every enabled preview")
    h.ok(not M.is_test_preview_paused("show_essential"), "preset preview is playing")
    h.ok(not M.is_test_preview_paused("show_custom_1"), "custom preview is playing")
    h.eq(M.toggle_global_test_aura_previews(), true, "Pause stops every enabled preview")
    h.ok(M.are_global_test_aura_previews_paused(), "all enabled previews report paused")
end)

h.test("test preview stacks tick live with the timer", function()
    local M = load_aura_frames()
    M._test_preview_time_offsets, M._test_preview_paused_times, M._test_preview_started = {}, {}, {}
    M.reset_test_preview_clock("show_essential", 0)
    local preview = { count_text = CreateFrame("Frame"):CreateFontString() }
    preview.count_text:Hide()
    M.update_test_preview_state(preview, "show_essential", 1)
    h.ok(not preview.count_text:IsShown(), "stack count of one stays hidden")
    M.update_test_preview_state(preview, "show_essential", 3)
    h.ok(preview.count_text:IsShown(), "ticker reveals the next stack bucket live")
    h.eq(preview._lstweeks_count_text, 2, "ticker writes the live stack value")
end)

h.run("af_timer_preview")

--#endregion FILE CONTENTS ===================================================
