-- Temporary whole-addon CPU profiler for in-game hotspot checks.
-- Load from LsTweeks.toc after all normal addon files, then use:
--   /lstprofile start
--   /lstprofile report 30
--   /lstprofile stop

local addon_name, addon = ...
if not addon then return end

--#region PROFILE TARGET SWITCHES ==============================================

-- Top-level target switches. Edit these before /reload to profile specific
-- modules without changing the wrapper code below.
local PROFILE_TARGETS = {
    core = false,
    settings = false,
    player_frame = false,
    sound_levels = false,
    skyriding_vigor = false,
    aura_frames = true,
}

--#endregion PROFILE TARGET SWITCHES ===========================================


--#region PROFILER STATE AND HELPERS ===========================================

local P = addon.cpu_profile or {}
addon.cpu_profile = P

local debugprofilestop = debugprofilestop
local format = string.format
local sort = table.sort
local tonumber = tonumber
local UnitAffectingCombat = UnitAffectingCombat
local unpack = unpack

local SKYRIDING_POLL_SECONDS = 0.20

local function now()
    return debugprofilestop and debugprofilestop() or 0
end

local function is_player_in_combat()
    return UnitAffectingCombat and UnitAffectingCombat("player") or false
end

local function reset_combat_timer(start_time)
    start_time = start_time or now()
    P.combat_total = 0
    P.combat_segments = 0
    P.combat_started_at = nil
    if is_player_in_combat() then
        P.combat_started_at = start_time
        P.combat_segments = 1
    end
end

local function current_combat_total(current_time)
    current_time = current_time or now()
    local total = P.combat_total or 0
    if P.combat_started_at then
        total = total + (current_time - P.combat_started_at)
    end
    return total
end

local function finish_active_combat(current_time)
    if not P.combat_started_at then return 0 end
    current_time = current_time or now()
    local duration = current_time - P.combat_started_at
    P.combat_total = (P.combat_total or 0) + duration
    P.combat_started_at = nil
    return duration
end

local function is_skyriding_workload_active()
    if not PROFILE_TARGETS.skyriding_vigor then return false end

    local M = addon.skyriding_vigor
    if not M then return false end
    if M._fill_test_enabled then return true end

    local is_gliding, can_glide = false, false
    if M.get_gliding_state then
        is_gliding, can_glide = M.get_gliding_state()
    end
    if is_gliding then return true end
    if not can_glide then return false end
    if M.is_player_flying and M.is_player_flying() then return true end
    if M.is_mounted_in_advanced_flyable_area and M.is_mounted_in_advanced_flyable_area(can_glide) then return true end

    return false
end

local function reset_skyriding_timer(start_time)
    start_time = start_time or now()
    P.skyriding_total = 0
    P.skyriding_segments = 0
    P.skyriding_started_at = nil
    P.skyriding_poll_elapsed = 0
    if is_skyriding_workload_active() then
        P.skyriding_started_at = start_time
        P.skyriding_segments = 1
    end
end

local function current_skyriding_total(current_time)
    current_time = current_time or now()
    local total = P.skyriding_total or 0
    if P.skyriding_started_at then
        total = total + (current_time - P.skyriding_started_at)
    end
    return total
end

local function finish_active_skyriding(current_time)
    if not P.skyriding_started_at then return 0 end
    current_time = current_time or now()
    local duration = current_time - P.skyriding_started_at
    P.skyriding_total = (P.skyriding_total or 0) + duration
    P.skyriding_started_at = nil
    return duration
end

local function update_skyriding_timer(current_time)
    current_time = current_time or now()
    local active = is_skyriding_workload_active()
    if active and not P.skyriding_started_at then
        P.skyriding_started_at = current_time
        P.skyriding_segments = (P.skyriding_segments or 0) + 1
        print("skyriding active started")
    elseif not active and P.skyriding_started_at then
        local duration = finish_active_skyriding(current_time)
        if duration > 0 then
            print(format(
                "skyriding active ended duration=%.1fs total=%.1fs",
                duration / 1000,
                (P.skyriding_total or 0) / 1000
            ))
        end
    end
end

local function pack_returns(...)
    return { n = select("#", ...), ... }
end

local function metric_for(name)
    P.metrics = P.metrics or {}
    local metric = P.metrics[name]
    if not metric then
        metric = { calls = 0, total = 0, max = 0 }
        P.metrics[name] = metric
    end
    return metric
end

local function record(name, elapsed)
    if not P.enabled then return end
    local metric = metric_for(name)
    metric.calls = metric.calls + 1
    metric.total = metric.total + elapsed
    if elapsed > metric.max then
        metric.max = elapsed
    end
end

local function wrap_function(owner, key, name)
    if type(owner) ~= "table" or type(owner[key]) ~= "function" then return end
    P.wrappers = P.wrappers or {}
    if P.wrappers[name] then return end

    local original = owner[key]
    owner[key] = function(...)
        if not P.enabled then
            return original(...)
        end

        local start_time = now()
        local results = pack_returns(original(...))
        record(name, now() - start_time)
        return unpack(results, 1, results.n)
    end

    P.wrappers[name] = {
        owner = owner,
        key = key,
        original = original,
    }
end

local function restore_wrappers()
    if not P.wrappers then return end
    for _, wrapper in pairs(P.wrappers) do
        if wrapper.owner and wrapper.key and wrapper.original then
            wrapper.owner[wrapper.key] = wrapper.original
        end
    end
    P.wrappers = nil
end

local function wrap_table_functions(tbl, prefix)
    if type(tbl) ~= "table" then return end

    for key, value in pairs(tbl) do
        if type(key) == "string" and type(value) == "function" then
            wrap_function(tbl, key, prefix .. "." .. key)
        end
    end
end

--#endregion PROFILER STATE AND HELPERS ========================================


--#region MODULE WRAPPER SECTIONS ==============================================

local PROFILE_SECTIONS = {
    -- Core/shared addon helpers and status/debug commands.
    {
        key = "core",
        label = "Core/Shared",
        install = function()
            wrap_table_functions(addon, "addon")
        end,
    },
    -- General Settings module.
    {
        key = "settings",
        label = "Settings",
        install = function()
            wrap_table_functions(addon.st, "settings")
        end,
    },
    -- Player Frame module, including OOC fade helpers.
    {
        key = "player_frame",
        label = "Player Frame",
        install = function()
            wrap_table_functions(addon.player_frame, "player_frame")
            wrap_table_functions(addon.player_frame and addon.player_frame.fade, "player_frame.fade")
        end,
    },
    -- Audio Volumes module, including temporary profile helpers.
    {
        key = "sound_levels",
        label = "Audio Volumes",
        install = function()
            wrap_table_functions(addon.sound_levels, "sound_levels")
        end,
    },
    -- Skyriding Vigor module.
    {
        key = "skyriding_vigor",
        label = "Skyriding Vigor",
        install = function()
            wrap_table_functions(addon.skyriding_vigor, "sv")
        end,
    },
    -- Aura Frames module, including scan/render/CDM/profile helpers.
    {
        key = "aura_frames",
        label = "Aura Frames",
        install = function()
            wrap_table_functions(addon.aura_frames, "af")
        end,
    },
}

local function is_target_enabled(key)
    return PROFILE_TARGETS[key] == true
end

local function get_enabled_target_names()
    local names = {}
    for _, section in ipairs(PROFILE_SECTIONS) do
        if is_target_enabled(section.key) then
            names[#names + 1] = section.label
        end
    end
    if #names == 0 then return "none" end
    return table.concat(names, ", ")
end

local function print_target_settings()
    if is_target_enabled("aura_frames") then
        local M = addon.aura_frames
        local timer_tick = M and M.db and M.db.aura_visible_icon_tick
        timer_tick = tonumber(timer_tick) or (M and M.defaults and M.defaults.aura_visible_icon_tick)
            or (addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.aura_visible_icon_tick)
        if timer_tick then
            print(format("aura_timer_tick %.2fs", timer_tick))
        end
    end
end

--#endregion MODULE WRAPPER SECTIONS ===========================================


--#region PROFILE LIFECYCLE ====================================================

local function install_wrappers()
    restore_wrappers()

    for _, section in ipairs(PROFILE_SECTIONS) do
        if is_target_enabled(section.key) and section.install then
            section.install()
        end
    end
end

local function reset_profile()
    P.metrics = {}
    P.started_at = now()
    reset_combat_timer(P.started_at)
    reset_skyriding_timer(P.started_at)
end

local function start_profile()
    install_wrappers()
    reset_profile()
    P.enabled = true
    print("|cff33ff99== LsTweeks CPU Profile started ==|r")
    print("targets: " .. get_enabled_target_names())
    print_target_settings()
end

local function stop_profile()
    finish_active_combat()
    finish_active_skyriding()
    P.enabled = false
    restore_wrappers()
    print("|cff33ff99== LsTweeks CPU Profile stopped ==|r")
end

local function report_profile(limit)
    local report_time = now()
    local elapsed = (report_time - (P.started_at or report_time)) / 1000
    local combat_elapsed = current_combat_total(report_time) / 1000
    local combat_pct = elapsed > 0 and (combat_elapsed / elapsed * 100) or 0
    local skyriding_elapsed = current_skyriding_total(report_time) / 1000
    local skyriding_pct = elapsed > 0 and (skyriding_elapsed / elapsed * 100) or 0
    local rows = {}

    for name, metric in pairs(P.metrics or {}) do
        if metric.calls > 0 then
            rows[#rows + 1] = {
                name = name,
                calls = metric.calls,
                total = metric.total,
                max = metric.max,
            }
        end
    end

    sort(rows, function(a, b)
        if a.total == b.total then
            return a.name < b.name
        end
        return a.total > b.total
    end)

    limit = tonumber(limit) or 25
    print("|cff33ff99== LsTweeks CPU Profile report ==|r")
    print("elapsed " .. format("%.1fs", elapsed))
    print_target_settings()
    print(format(
        "combat %.1fs %.1f%% segments=%d active=%s",
        combat_elapsed,
        combat_pct,
        P.combat_segments or 0,
        P.combat_started_at and "yes" or "no"
    ))
    print(format(
        "skyriding_active %.1fs %.1f%% segments=%d active=%s",
        skyriding_elapsed,
        skyriding_pct,
        P.skyriding_segments or 0,
        P.skyriding_started_at and "yes" or "no"
    ))
    for i = 1, math.min(limit, #rows) do
        local row = rows[i]
        local normalized = ""
        if skyriding_elapsed > 0 then
            normalized = format(" sv_msps=%.3f sv_callsps=%.2f", row.total / skyriding_elapsed, row.calls / skyriding_elapsed)
        end
        print(format(
            "%s calls=%d total=%.3fms avg=%.4fms max=%.3fms%s",
            row.name,
            row.calls,
            row.total,
            row.total / row.calls,
            row.max,
            normalized
        ))
    end
end

--#endregion PROFILE LIFECYCLE =================================================


--#region COMBAT TIMER =========================================================

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
event_frame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
event_frame:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
event_frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
event_frame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
event_frame:SetScript("OnEvent", function(_, event)
    if not P.enabled then return end
    local event_time = now()
    if event == "PLAYER_REGEN_DISABLED" then
        if P.combat_started_at then return end
        P.combat_started_at = event_time
        P.combat_segments = (P.combat_segments or 0) + 1
        print("combat started")
    elseif event == "PLAYER_REGEN_ENABLED" then
        local duration = finish_active_combat(event_time)
        if duration > 0 then
            print(format(
                "combat ended duration=%.1fs total=%.1fs",
                duration / 1000,
                (P.combat_total or 0) / 1000
            ))
        end
    elseif event == "PLAYER_CAN_GLIDE_CHANGED" or event == "PLAYER_IS_GLIDING_CHANGED"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "MOUNT_JOURNAL_USABILITY_CHANGED"
    then
        update_skyriding_timer(event_time)
    end
end)

event_frame:SetScript("OnUpdate", function(_, elapsed)
    if not P.enabled or not is_target_enabled("skyriding_vigor") then return end
    P.skyriding_poll_elapsed = (P.skyriding_poll_elapsed or 0) + (elapsed or 0)
    if P.skyriding_poll_elapsed < SKYRIDING_POLL_SECONDS then return end
    P.skyriding_poll_elapsed = 0
    update_skyriding_timer(now())
end)

--#endregion COMBAT TIMER ======================================================


--#region SLASH COMMAND ========================================================

SLASH_LSTWEEKS_CPU_PROFILE1 = "/lstprofile"
SlashCmdList["LSTWEEKS_CPU_PROFILE"] = function(msg)
    local command, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command and command:lower() or ""

    if command == "start" then
        start_profile()
    elseif command == "stop" then
        stop_profile()
    elseif command == "reset" then
        reset_profile()
        print("|cff33ff99== LsTweeks CPU Profile reset ==|r")
    elseif command == "status" then
        print("|cff33ff99== LsTweeks CPU Profile status ==|r")
        print(P.enabled and "running" or "stopped")
        print("targets: " .. get_enabled_target_names())
        print_target_settings()
        print(format(
            "combat %.1fs segments=%d active=%s",
            current_combat_total() / 1000,
            P.combat_segments or 0,
            P.combat_started_at and "yes" or "no"
        ))
        print(format(
            "skyriding_active %.1fs segments=%d active=%s",
            current_skyriding_total() / 1000,
            P.skyriding_segments or 0,
            P.skyriding_started_at and "yes" or "no"
        ))
    elseif command == "report" or command == "" then
        report_profile(arg)
    else
        print("|cff33ff99LsTweeks CPU Profile:|r start | stop | reset | status | report [limit]")
    end
end

--#endregion SLASH COMMAND =====================================================
