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
local unpack = unpack

local function now()
    return debugprofilestop and debugprofilestop() or 0
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
    -- Sound Levels module, including Fishing Focus helpers.
    {
        key = "sound_levels",
        label = "Sound Levels",
        install = function()
            wrap_table_functions(addon.sound_levels, "sound_levels")
        end,
    },
    -- Skyriding Vigor module.
    {
        key = "skyriding_vigor",
        label = "Skyriding Vigor",
        install = function()
            wrap_table_functions(addon.skyriding_vigor, "skyriding_vigor")
        end,
    },
    -- Aura Frames module, including scan/render/CDM/profile helpers.
    {
        key = "aura_frames",
        label = "Aura Frames",
        install = function()
            wrap_table_functions(addon.aura_frames, "aura_frames")
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
end

local function start_profile()
    install_wrappers()
    reset_profile()
    P.enabled = true
    print("|cff33ff99LsTweeks CPU Profile:|r started")
    print("|cff33ff99LsTweeks CPU Profile:|r targets: " .. get_enabled_target_names())
end

local function stop_profile()
    P.enabled = false
    restore_wrappers()
    print("|cff33ff99LsTweeks CPU Profile:|r stopped")
end

local function report_profile(limit)
    local elapsed = (now() - (P.started_at or now())) / 1000
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
    print("|cff33ff99LsTweeks CPU Profile:|r elapsed " .. format("%.1fs", elapsed))
    for i = 1, math.min(limit, #rows) do
        local row = rows[i]
        print(format(
            "|cff33ff99LsTweeks CPU Profile:|r %s calls=%d total=%.3fms avg=%.4fms max=%.3fms",
            row.name,
            row.calls,
            row.total,
            row.total / row.calls,
            row.max
        ))
    end
end

--#endregion PROFILE LIFECYCLE =================================================


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
        print("|cff33ff99LsTweeks CPU Profile:|r reset")
    elseif command == "status" then
        print("|cff33ff99LsTweeks CPU Profile:|r " .. (P.enabled and "running" or "stopped"))
        print("|cff33ff99LsTweeks CPU Profile:|r targets: " .. get_enabled_target_names())
    elseif command == "report" or command == "" then
        report_profile(arg)
    else
        print("|cff33ff99LsTweeks CPU Profile:|r start | stop | reset | status | report [limit]")
    end
end

--#endregion SLASH COMMAND =====================================================
