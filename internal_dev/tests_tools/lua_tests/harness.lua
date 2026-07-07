-- Headless test harness: loads addon Lua files in TOC order into the wow_stub environment
-- and provides assertion/event/clock helpers so tests drive addon logic like the game client would.
-- Runs under desktop Lua 5.1 (io/os/require/loadfile), which the WoW-profile LuaLS does not know.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

local ADDON_NAME = "LsTweeks"

-- Resolve the addon root from this file's own path so tests run from any cwd.
local this_file = debug.getinfo(1, "S").source:match("^@(.*)$")
local ADDON_ROOT = this_file:gsub("[\\/]internal_dev[\\/].*$", "")

package.path = ADDON_ROOT .. "/internal_dev/tests_tools/lua_tests/?.lua;" .. package.path

local stub = require("wow_stub")

local harness = {
    stub = stub,
    addon_name = ADDON_NAME,
    addon = {},
    root = ADDON_ROOT,
    loaded_files = {},
}


--#region file loading

-- Load one addon Lua file with the WoW vararg convention (addonName, addonTable).
function harness.load_file(rel_path)
    local full = ADDON_ROOT .. "/" .. rel_path:gsub("\\", "/")
    local chunk, err = loadfile(full)
    if not chunk then
        error("load failed for " .. rel_path .. ": " .. tostring(err), 2)
    end
    local ok, run_err = pcall(chunk, ADDON_NAME, harness.addon)
    if not ok then
        error("runtime error in " .. rel_path .. ": " .. tostring(run_err), 2)
    end
    harness.loaded_files[#harness.loaded_files + 1] = rel_path
end

-- Parse the TOC and return addon Lua paths in load order. Libs are skipped by
-- default: they are vendored third-party code and lean hardest on real client API.
function harness.toc_files(opts)
    opts = opts or {}
    local files = {}
    local toc = ADDON_ROOT .. "/LsTweeks.toc"
    for line in io.lines(toc) do
        line = line:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            local is_lib = line:lower():match("^libs[\\/]")
            if line:lower():match("%.lua$") and (opts.include_libs or not is_lib) then
                files[#files + 1] = line
            end
        end
    end
    return files
end

-- Load every addon file (or one module's slice) in TOC order.
-- filter: optional string matched against the path, e.g. "modules/player_frame"
-- Core + functions files always load first because modules depend on them.
function harness.load_addon(filter)
    for _, rel in ipairs(harness.toc_files({ include_libs = true })) do
        local norm = rel:gsub("\\", "/")
        local is_shared = norm:lower():match("^libs/") or norm:match("^core/") or norm:match("^functions/")
        if not filter or is_shared or norm:find(filter, 1, true) then
            harness.load_file(rel)
        end
    end
end

-- Simulate the client finishing the addon load (fires ADDON_LOADED then
-- PLAYER_ENTERING_WORLD like a fresh login).
function harness.boot(saved_variables)
    _G.Ls_Tweeks_DB = saved_variables or {}
    stub.FireEvent("ADDON_LOADED", ADDON_NAME)
    stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
end

--#endregion file loading


--#region gameplay helpers

function harness.enter_combat()
    stub.in_combat = true
    stub.FireEvent("PLAYER_REGEN_DISABLED")
end

function harness.leave_combat()
    stub.in_combat = false
    stub.FireEvent("PLAYER_REGEN_ENABLED")
end

function harness.set_health(percent_0_to_1)
    stub.player_health_percent = percent_0_to_1
    stub.FireEvent("UNIT_HEALTH", "player")
end

harness.advance = stub.Advance
harness.fire_event = stub.FireEvent

--#endregion gameplay helpers


--#region test registry and asserts

local tests = {}

function harness.test(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

function harness.eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            label or "eq", tostring(expected), tostring(actual)), 2)
    end
end

function harness.near(actual, expected, tolerance, label)
    tolerance = tolerance or 0.001
    if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected ~%s (tol %s), got %s",
            label or "near", tostring(expected), tostring(tolerance), tostring(actual)), 2)
    end
end

function harness.ok(value, label)
    if not value then
        error(string.format("%s: expected truthy, got %s", label or "ok", tostring(value)), 2)
    end
end

function harness.is_nil(value, label)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", label or "is_nil", tostring(value)), 2)
    end
end

-- Run all registered tests; print a per-test line and a summary; return failure count.
function harness.run(suite_name)
    local failures = 0
    for _, t in ipairs(tests) do
        local ok, err = pcall(t.fn)
        if ok then
            print(string.format("  PASS  %s", t.name))
        else
            failures = failures + 1
            print(string.format("  FAIL  %s\n        %s", t.name, tostring(err)))
        end
    end
    print(string.format("%s: %d/%d passed", suite_name or "suite", #tests - failures, #tests))
    if failures > 0 then os.exit(1) end
end

--#endregion test registry and asserts

return harness

--#endregion FILE CONTENTS ===================================================
