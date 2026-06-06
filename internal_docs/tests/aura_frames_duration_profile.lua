-- Aura Frames duration profiling probe.
-- Not loaded by LsTweeks.toc; add this file after af_main.lua temporarily.
-- Commands:
--   /lstafprofile start
--   /lstafprofile stop
--   /lstafprofile reset
--   /lstafprofile status
--   /lstafprofile report
local addon_name, addon = ...

local M = addon and addon.aura_frames
if not M then return end

local P = M.duration_profile or {}
M.duration_profile = P

local debugprofilestop = debugprofilestop
local format = string.format
local print = print
local unpack = unpack

local function pack_returns(...)
    return { n = select("#", ...), ... }
end

local tracked = {
    "tick_visible_icons",
    "render_aura_map",
    "unified_scan",
    "scan_custom_aura_map",
    "add_cooldown_viewer_category_entries",
}

local function now_ms()
    return debugprofilestop and debugprofilestop() or 0
end

local function ensure_metric(name)
    P.metrics = P.metrics or {}
    local metric = P.metrics[name]
    if not metric then
        metric = { calls = 0, total_ms = 0, max_ms = 0 }
        P.metrics[name] = metric
    end
    return metric
end

local function record(name, elapsed)
    local metric = ensure_metric(name)
    metric.calls = metric.calls + 1
    metric.total_ms = metric.total_ms + elapsed
    if elapsed > metric.max_ms then metric.max_ms = elapsed end
end

local function wrap_table_function(owner, key, name)
    if not (owner and key and type(owner[key]) == "function") then return end
    P.originals = P.originals or {}
    if P.originals[owner] and P.originals[owner][key] then return end

    P.originals[owner] = P.originals[owner] or {}
    local original = owner[key]
    P.originals[owner][key] = original
    owner[key] = function(...)
        if not P.enabled then
            return original(...)
        end
        local start = now_ms()
        local results = pack_returns(original(...))
        record(name, now_ms() - start)
        return unpack(results, 1, results.n)
    end
end

local function restore_wrapped_functions()
    if not P.originals then return end
    for owner, funcs in pairs(P.originals) do
        for key, original in pairs(funcs) do
            owner[key] = original
        end
    end
    P.originals = nil
end

local function reset_metrics()
    P.metrics = {}
    P.started_at = P.enabled and now_ms() or nil
end

local function install_wrappers()
    for _, key in ipairs(tracked) do
        wrap_table_function(M, key, key)
    end
    if C_UnitAuras then
        wrap_table_function(C_UnitAuras, "GetAuraDuration", "C_UnitAuras.GetAuraDuration")
        wrap_table_function(C_UnitAuras, "GetUnitAuraInstanceIDs", "C_UnitAuras.GetUnitAuraInstanceIDs")
    end
end

local function start_profile()
    install_wrappers()
    reset_metrics()
    P.enabled = true
    P.started_at = now_ms()
    print("|cff33ff99LsTweeks AF Profile:|r started")
end

local function stop_profile()
    P.enabled = false
    restore_wrapped_functions()
    print("|cff33ff99LsTweeks AF Profile:|r stopped")
end

local function print_report()
    local elapsed = P.started_at and ((now_ms() - P.started_at) / 1000) or 0
    print("|cff33ff99LsTweeks AF Profile:|r elapsed " .. format("%.1fs", elapsed))
    local metrics = P.metrics or {}
    for _, name in ipairs({
        "C_UnitAuras.GetAuraDuration",
        "C_UnitAuras.GetUnitAuraInstanceIDs",
        "tick_visible_icons",
        "render_aura_map",
        "unified_scan",
        "scan_custom_aura_map",
        "add_cooldown_viewer_category_entries",
    }) do
        local metric = metrics[name]
        if metric and metric.calls > 0 then
            local avg = metric.total_ms / metric.calls
            print(format(
                "|cff33ff99LsTweeks AF Profile:|r %s calls=%d total=%.3fms avg=%.4fms max=%.3fms",
                name,
                metric.calls,
                metric.total_ms,
                avg,
                metric.max_ms
            ))
        end
    end
end

SLASH_LSTWEEKS_AURA_FRAMES_PROFILE1 = "/lstafprofile"
SlashCmdList.LSTWEEKS_AURA_FRAMES_PROFILE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "start" then
        start_profile()
    elseif msg == "stop" then
        stop_profile()
    elseif msg == "reset" then
        reset_metrics()
        print("|cff33ff99LsTweeks AF Profile:|r reset")
    elseif msg == "status" then
        print("|cff33ff99LsTweeks AF Profile:|r " .. (P.enabled and "running" or "stopped"))
        print_report()
    elseif msg == "report" or msg == "" then
        print_report()
    else
        print("|cff33ff99LsTweeks AF Profile:|r start | stop | reset | status | report")
    end
end
