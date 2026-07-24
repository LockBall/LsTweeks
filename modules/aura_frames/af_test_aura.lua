-- Fake aura preview data for layout and UI testing outside of combat.
-- Preview entries are rendered by the normal aura-frame renderer/ticker path.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local GetTime = GetTime

--#region TEST AURA CONFIG =====================================================
-- Tune preview appearance and animation behavior here.

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR
local HANDOFF_SECONDS = 3 -- hold the new range's first label after each display-format change
local ZERO_HOLD_SECONDS = 1 -- keep the completed countdown visible before restarting
local POST_SINGLE_HOUR_SECONDS_PER_UNIT = 2 -- slow each preview unit from single hours through double seconds

-- All countdown phases use the same linear pacing rule.  Configure only the
-- segment's visible start, end, and real-time duration; the rate is derived
-- here so a later duration adjustment cannot create a mismatched jump.
local function make_linear_phase(seconds, start, finish)
    return {
        seconds = seconds,
        start = start,
        rate = (start - finish) / seconds,
    }
end

-- Edit only `start` and `finish` to tune the long-preview sequence.  Each
-- range advances at one configured unit per `seconds_per_unit` real-time seconds.
-- `handoff_seconds` holds its incoming value so a display-format change is visible.
local LONG_PREVIEW_RANGES = {
    -- 100+ days: whole-day label; samples the high-duration display.
    many_days = { start = 365, finish = 350, unit = SECONDS_PER_DAY },
    -- 10+ days: one decimal day; samples the lower end before single-digit days.
    tens_days = { start = 25, finish = 10, unit = SECONDS_PER_DAY, handoff_seconds = HANDOFF_SECONDS },
    -- 1.0-9.9 days: one decimal is retained, including the 1.0d handoff.
    single_days = { start = 9.9, finish = 1.0, unit = SECONDS_PER_DAY, handoff_seconds = HANDOFF_SECONDS },
    -- 10-24 hours: one decimal hour; begins just above one day and ends at 10h.
    double_hours = { start = 24.1, finish = 10.1, unit = SECONDS_PER_HOUR, handoff_seconds = HANDOFF_SECONDS },
    -- 1-9 hours: hours and minutes; finishes at the one-hour handoff.
    single_hours = {
        start = 10.1, finish = 1.0, unit = SECONDS_PER_HOUR,
        handoff_seconds = HANDOFF_SECONDS, seconds_per_unit = POST_SINGLE_HOUR_SECONDS_PER_UNIT,
    },
    -- 10-60 minutes: one decimal minute; begins just above one hour.
    double_minutes = {
        start = 60.1, finish = 45.1, unit = SECONDS_PER_MINUTE,
        handoff_seconds = HANDOFF_SECONDS, seconds_per_unit = POST_SINGLE_HOUR_SECONDS_PER_UNIT,
    },
    -- 1-9 minutes: minutes and seconds; finishes at the one-minute handoff.
    single_minutes = {
        start = 10.1, finish = 1.0, unit = SECONDS_PER_MINUTE,
        handoff_seconds = HANDOFF_SECONDS, seconds_per_unit = POST_SINGLE_HOUR_SECONDS_PER_UNIT,
    },
    -- 10-60 seconds: decimal seconds; finishes at the real-time final ten.
    double_seconds = {
        start = 60.1, finish = 45.1, unit = 1,
        handoff_seconds = HANDOFF_SECONDS, seconds_per_unit = POST_SINGLE_HOUR_SECONDS_PER_UNIT,
    },
    -- 0-10 seconds: decimal seconds in real time, then holds zero for one second.
    single_seconds = { start = 10.0, finish = 0, unit = 1 },
}

local LONG_PREVIEW_RANGE_ORDER = {
    "many_days", "tens_days", "single_days", "double_hours", "single_hours",
    "double_minutes", "single_minutes", "double_seconds", "single_seconds",
}

-- Return copies so test code can derive timing assertions without changing the
-- live preview configuration.
function M.get_long_preview_test_ranges()
    local ranges = {}
    for name, range in pairs(LONG_PREVIEW_RANGES) do
        ranges[name] = {
            start = range.start,
            finish = range.finish,
            unit = range.unit,
            handoff_seconds = range.handoff_seconds,
            seconds_per_unit = range.seconds_per_unit,
        }
    end
    return ranges, ZERO_HOLD_SECONDS
end

local function make_configured_phase(range)
    local units = range.start - range.finish
    local start = range.start * range.unit
    local finish = range.finish * range.unit
    local handoff_seconds = range.handoff_seconds
    local seconds_per_unit = range.seconds_per_unit or 1
    if handoff_seconds and units > 0 then
        local handoff_hold = { seconds = handoff_seconds, start = start, rate = 0 }
        local countdown = make_linear_phase(units * seconds_per_unit, start, finish)
        return {
            seconds = handoff_hold.seconds + countdown.seconds,
            start = start,
            segments = { handoff_hold, countdown },
        }
    end
    return make_linear_phase(units * seconds_per_unit, start, finish)
end

local function make_single_seconds_phase()
    local final_countdown = make_configured_phase(LONG_PREVIEW_RANGES.single_seconds)
    final_countdown.allow_zero = true
    local zero_hold = { seconds = ZERO_HOLD_SECONDS, start = 0, rate = 0, allow_zero = true }
    local segments = final_countdown.segments or { final_countdown }
    segments[#segments + 1] = zero_hold
    return {
        seconds = final_countdown.seconds + zero_hold.seconds,
        start = LONG_PREVIEW_RANGES.single_seconds.start,
        segments = segments,
    }
end

local function make_long_preview_phases()
    local phases = {}
    for i = 1, #LONG_PREVIEW_RANGE_ORDER do
        local name = LONG_PREVIEW_RANGE_ORDER[i]
        phases[#phases + 1] = name == "single_seconds"
            and make_single_seconds_phase()
            or make_configured_phase(LONG_PREVIEW_RANGES[name])
    end
    return phases
end

local CFG = {
    icon            = "Interface\\Icons\\INV_Misc_QuestionMark",
    short_duration  = 20,   -- short preview duration (seconds)
    long_preview_phases = make_long_preview_phases(),
    sec_per_stack   = 2.0,  -- seconds each stack value is held (0.1 increments)
    stack_steps     = 4,    -- number of distinct steps in the cycle
    stack_min       = 1,    -- lowest stack count shown during the cycle
    stack_max       = 4,    -- highest stack count shown during the cycle
    min_remaining   = 0.1,  -- floor except the final allow-zero segment
}

-- Phases are fixed at load, so the ticker-path cycle length is summed once.
local LONG_PREVIEW_CYCLE_SECONDS = 0
for i = 1, #CFG.long_preview_phases do
    LONG_PREVIEW_CYCLE_SECONDS = LONG_PREVIEW_CYCLE_SECONDS + CFG.long_preview_phases[i].seconds
end

-- The test suite reads this runtime-derived snapshot instead of reproducing
-- range order, handoff durations, or the final zero hold on its own.
function M.get_long_preview_test_timing()
    local ranges, zero_hold_seconds = M.get_long_preview_test_ranges()
    local phase_start, phase_offset = {}, 0
    for i = 1, #CFG.long_preview_phases do
        phase_start[LONG_PREVIEW_RANGE_ORDER[i]] = phase_offset
        phase_offset = phase_offset + CFG.long_preview_phases[i].seconds
    end
    return ranges, phase_start, LONG_PREVIEW_CYCLE_SECONDS, zero_hold_seconds
end

M._test_preview_time_offsets = M._test_preview_time_offsets or {}
M._test_preview_paused_times = M._test_preview_paused_times or {}
M._test_preview_started = M._test_preview_started or {}

local function get_test_preview_clock(show_key, now)
    local paused_time = M._test_preview_paused_times[show_key]
    if paused_time ~= nil then return paused_time end
    return now - (M._test_preview_time_offsets[show_key] or 0)
end

function M.is_test_preview_paused(show_key)
    if not show_key then return false end
    -- Before the first post-reload scan restores a saved preview clock, expose
    -- it as paused so the UI correctly offers Play rather than Pause.
    return M._test_preview_paused_times[show_key] ~= nil
        or M._test_preview_started[show_key] ~= true
end

function M.toggle_test_preview_pause(show_key, now)
    if not show_key then return false end
    now = now or GetTime()
    -- A never-started preview reads as paused in the UI; its Play click must
    -- start the clock rather than freeze the unstarted one.
    if M._test_preview_started[show_key] ~= true then
        M.reset_test_preview_clock(show_key, now)
        return false
    end
    local paused_time = M._test_preview_paused_times[show_key]
    if paused_time ~= nil then
        M._test_preview_time_offsets[show_key] = now - paused_time
        M._test_preview_paused_times[show_key] = nil
        return false
    end

    M._test_preview_paused_times[show_key] = get_test_preview_clock(show_key, now)
    return true
end

function M.reset_test_preview_clock(show_key, now)
    if not show_key then return end
    now = now or GetTime()
    M._test_preview_time_offsets[show_key] = now
    M._test_preview_paused_times[show_key] = nil
    M._test_preview_started[show_key] = true
end

-- A saved active preview is first discovered during the post-reload scan.
-- Start it paused so the user can inspect the initial value before playing it.
function M.restore_test_preview_clock_paused(show_key, now)
    if not show_key or M._test_preview_started[show_key] then return end
    now = now or GetTime()
    M.reset_test_preview_clock(show_key, now)
    -- A freshly reset clock reads exactly zero; freeze it there directly.
    M._test_preview_paused_times[show_key] = 0
end

-- Checkbox-on entry point: always begin a fresh paused preview, even when a
-- silent settings resync (profile load/reset) skipped the stop on uncheck.
function M.start_test_preview_paused(show_key, now)
    if not show_key then return end
    M.stop_test_preview_clock(show_key)
    M.restore_test_preview_clock_paused(show_key, now)
end

function M.stop_test_preview_clock(show_key)
    if not show_key then return end
    M._test_preview_time_offsets[show_key] = nil
    M._test_preview_paused_times[show_key] = nil
    M._test_preview_started[show_key] = nil
end

function M.get_test_aura_binding(category)
    if not (category and M.db) then return nil end
    local show_key = "show_" .. category
    if M.FRAME_DEFS_BY_KEY and M.FRAME_DEFS_BY_KEY[category] then
        return M.db, "test_aura_" .. category, show_key, show_key
    end
    for _, entry in ipairs(M.db.custom_frames or {}) do
        if entry.id == category then
            return entry, "test_aura", "show", show_key
        end
    end
    return nil
end

function M.refresh_test_aura_category(category)
    local _, _, _, show_key = M.get_test_aura_binding(category)
    local frame = show_key and M.frames and M.frames[show_key]
    local params = frame and frame.update_params
    if M.mark_aura_scan_dirty then M.mark_aura_scan_dirty() end
    if params then
        M.update_auras(frame, params.show_key, params.move_key, params.timer_key,
            params.bg_key, params.scale_key, params.spacing_key, params.aura_filter)
    end
end

function M.set_test_aura_enabled(category, enabled)
    local value_table, test_key, show_storage_key, show_key = M.get_test_aura_binding(category)
    if not (value_table and test_key and show_storage_key and show_key) then return false end
    enabled = enabled == true
    value_table[test_key] = enabled
    if enabled then
        value_table[show_storage_key] = true
        M.start_test_preview_paused(show_key)
    else
        M.stop_test_preview_clock(show_key)
    end
    M.refresh_test_aura_category(category)
    if M.sync_test_aura_controls then M.sync_test_aura_controls(category) end
    return true
end

function M.toggle_test_aura_preview(category)
    local value_table, test_key, _, show_key = M.get_test_aura_binding(category)
    if not (value_table and value_table[test_key] == true) then return false end
    M.toggle_test_preview_pause(show_key)
    M.refresh_test_aura_category(category)
    if M.sync_test_aura_controls then M.sync_test_aura_controls(category) end
    return true
end

local function normalize_preview_remaining(remaining, allow_zero, compensate_boundary)
    local minimum = allow_zero and 0 or CFG.min_remaining
    remaining = M.normalize_aura_timer_remaining(remaining, allow_zero, compensate_boundary)
    return math_max(minimum, remaining)
end

local function get_preview_segment_remaining(segment, elapsed)
    return normalize_preview_remaining(segment.start - (elapsed * segment.rate), segment.allow_zero,
        segment.rate ~= 0 and elapsed > 0)
end

local function get_long_test_preview_state(now)
    local elapsed = now % LONG_PREVIEW_CYCLE_SECONDS
    for i = 1, #CFG.long_preview_phases do
        local phase = CFG.long_preview_phases[i]
        if M.is_aura_timer_phase_active(elapsed, phase.seconds) then
            local remaining
            if phase.segments then
                local segment_elapsed = elapsed
                for j = 1, #phase.segments do
                    local segment = phase.segments[j]
                    if M.is_aura_timer_phase_active(segment_elapsed, segment.seconds) then
                        remaining = get_preview_segment_remaining(segment, segment_elapsed)
                        break
                    end
                    segment_elapsed = segment_elapsed - segment.seconds
                end
            else
                remaining = get_preview_segment_remaining(phase, elapsed)
            end
            return phase.start, remaining
        end
        elapsed = elapsed - phase.seconds
    end

    -- Treat an exhausted loop caused by floating-point residue as the next
    -- cycle's exact reset rather than exposing a near-zero phantom state.
    local phase = CFG.long_preview_phases[1]
    return phase.start, phase.start
end

local function get_test_preview_state(show_key, now)
    now = now or GetTime()
    now = get_test_preview_clock(show_key, now)

    if show_key == "show_static" then
        return 0, 0, 0
    end

    local short_duration = CFG.short_duration
    local duration, remaining
    if show_key == "show_long" then
        duration, remaining = get_long_test_preview_state(now)
    else
        duration = short_duration
        local elapsed = now % duration
        remaining = normalize_preview_remaining(duration - elapsed, false, elapsed > 0)
    end

    -- Stack count cycles on its own period, independent of the timer length.
    -- Each stack value is held for sec_per_stack seconds (tunable in 0.1s increments).
    local full_cycle = CFG.sec_per_stack * CFG.stack_steps
    local stack_bucket = math_floor((now % full_cycle) / CFG.sec_per_stack) + 1
    local count = math_min(CFG.stack_max, math_max(CFG.stack_min, stack_bucket))

    return duration, remaining, count
end

local function build_test_aura_entry(show_key, filter)
    local now = GetTime()
    local duration, remaining, count = get_test_preview_state(show_key, now)
    local frame_def = M.get_frame_def_from_show_key(show_key)
        or ((filter and filter:find("HARMFUL", 1, true)) and M.get_frame_def("debuff"))
    local preview_name = (frame_def and frame_def.test_label) or "Test Custom Buff"
    local preview_sort_id = (frame_def and frame_def.test_sort_id) or 10

    return {
        name            = preview_name,
        icon            = CFG.icon,
        duration        = duration,
        expiration      = duration > 0 and (now + remaining) or 0,
        remaining       = remaining,
        count           = count,
        filter          = filter,
        instance_id     = "__test_preview__",
        added_at        = now,
        preview_sort_id = preview_sort_id,
        is_test_preview = true,
        test_preview_show_key = show_key,
    }
end

function M.is_shared_long_test_preview_active()
    return M.db and M.db.show_long == true and M.db.test_aura_long == true
end

-- The long preview joins the normal helpful-aura category buckets so it can
-- exercise the same Long -> Short threshold transfer as a real buff.
function M.add_shared_long_test_aura(category_buckets, short_threshold)
    if not (category_buckets and M.is_shared_long_test_preview_active()) then return end
    M.restore_test_preview_clock_paused("show_long")

    local entry = build_test_aura_entry("show_long", "HELPFUL")
    entry.is_helpful = true
    entry.category = entry.remaining <= short_threshold and "short" or "long"
    local bucket = category_buckets[entry.category]
    if bucket then
        bucket[entry.instance_id] = entry
    end
end

function M.append_test_aura(aura_map, show_key, filter)
    M.restore_test_preview_clock_paused(show_key)
    aura_map["__test_preview__"] = build_test_aura_entry(show_key, filter)
end

function M.update_test_preview_state(obj, show_key, now)
    now = now or GetTime()
    local duration, remaining, count = get_test_preview_state(show_key, now)

    obj.aura_duration = duration
    obj.aura_remaining = remaining
    obj.aura_expiration = now + remaining
    obj.aura_scan_time = now
    -- Stacks tick live alongside the timer so a scan rebuild (e.g. from the
    -- pause button) never reveals a stale count with a visible jump.
    M.update_preview_count_text(obj, count)
end

--#endregion TEST AURA CONFIG ==================================================
