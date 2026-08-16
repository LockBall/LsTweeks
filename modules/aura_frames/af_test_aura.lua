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

local CFG = {
    icon            = "Interface\\Icons\\INV_Misc_QuestionMark",
    duration        = 20,
    sec_per_stack   = 2.0,  -- seconds each stack value is held (0.1 increments)
    stack_steps     = 4,    -- number of distinct steps in the cycle
    stack_min       = 1,    -- lowest stack count shown during the cycle
    stack_max       = 4,    -- highest stack count shown during the cycle
    min_remaining   = 0.1,
}

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

local function for_each_enabled_test_preview(callback)
    if not (M.db and callback) then return end
    for _, frame_def in ipairs(M.FRAME_DEFS or {}) do
        local show_key = "show_" .. frame_def.key
        if frame_def.supports_test_aura ~= false and M.db[show_key] == true then
            callback(frame_def.key, show_key)
        end
    end
    for _, entry in ipairs(M.db.custom_frames or {}) do
        if entry.show == true and entry.id then callback(entry.id, "show_" .. entry.id) end
    end
end

function M.start_global_test_aura_previews_paused()
    for_each_enabled_test_preview(function(_, show_key)
        M.start_test_preview_paused(show_key)
    end)
end

function M.are_global_test_aura_previews_paused()
    local all_paused = true
    for_each_enabled_test_preview(function(_, show_key)
        if not M.is_test_preview_paused(show_key) then all_paused = false end
    end)
    return all_paused
end

function M.toggle_global_test_aura_previews()
    local pause_previews = not M.are_global_test_aura_previews_paused()
    for_each_enabled_test_preview(function(category, show_key)
        if M.is_test_preview_paused(show_key) ~= pause_previews then
            M.toggle_test_preview_pause(show_key)
        end
        M.refresh_test_aura_category(category)
    end)
    if M.sync_test_aura_controls then M.sync_test_aura_controls() end
    return pause_previews
end

function M.get_test_aura_binding(category)
    if not (category and M.db) then return nil end
    local show_key = "show_" .. category
    if M.FRAME_DEFS_BY_KEY and M.FRAME_DEFS_BY_KEY[category]
        and M.frame_supports_test_aura(category)
    then
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
    if M.invalidate_aura_scan_caches then M.invalidate_aura_scan_caches() end
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

local function get_test_preview_state(show_key, now)
    now = now or GetTime()
    now = get_test_preview_clock(show_key, now)
    local duration = CFG.duration
    local elapsed = now % duration
    local remaining = normalize_preview_remaining(duration - elapsed, false, elapsed > 0)

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
