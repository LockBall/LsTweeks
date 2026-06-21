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
    short_duration  = 20,   -- short preview duration (seconds)
    long_extra_min  = 30,   -- minimum seconds added above threshold for long preview
    long_extra_frac = 0.5,  -- fraction of threshold added for long preview
    sec_per_stack   = 2.0,  -- seconds each stack value is held (0.1 increments)
    stack_steps     = 4,    -- number of distinct steps in the cycle
    stack_min       = 1,    -- lowest stack count shown during the cycle
    stack_max       = 4,    -- highest stack count shown during the cycle
    min_remaining   = 0.1,  -- floor for remaining time so bar never shows fully empty
}

local function get_test_preview_state(show_key, short_threshold, now)
    now = now or GetTime()

    if show_key == "show_static" then
        return 0, 0, 0
    end

    local threshold = short_threshold or M.DEFAULT_SHORT_THRESHOLD
    local short_duration = CFG.short_duration
    local duration = (show_key == "show_long")
        and (threshold + math_max(CFG.long_extra_min, math_floor(threshold * CFG.long_extra_frac)))
        or  short_duration

    local remaining = math_max(CFG.min_remaining, duration - (now % duration))

    -- Stack count cycles on its own period, independent of the timer length.
    -- Each stack value is held for sec_per_stack seconds (tunable in 0.1s increments).
    local full_cycle = CFG.sec_per_stack * CFG.stack_steps
    local stack_bucket = math_floor((now % full_cycle) / CFG.sec_per_stack) + 1
    local count = math_min(CFG.stack_max, math_max(CFG.stack_min, stack_bucket))

    return duration, remaining, count
end

local function build_test_aura_entry(show_key, filter, short_threshold)
    local now = GetTime()
    local duration, remaining, count = get_test_preview_state(show_key, short_threshold, now)
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
    }
end

function M.append_test_aura(aura_map, show_key, filter, short_threshold)
    aura_map["__test_preview__"] = build_test_aura_entry(show_key, filter, short_threshold)
end

function M.update_test_preview_state(obj, show_key, short_threshold, now)
    local duration, remaining = get_test_preview_state(show_key, short_threshold, now)

    obj.aura_duration = duration
    obj.aura_remaining = remaining
    obj.aura_expiration = now + remaining
    obj.aura_scan_time = now
end

--#endregion TEST AURA CONFIG ==================================================
