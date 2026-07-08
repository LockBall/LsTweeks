-- Behavioral tests for Objectives section-count helper contracts.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/objectives")

local M = h.addon.objectives

local function find_upvalue(fn, wanted_name)
    local index = 1
    while true do
        local name, value = debug.getupvalue(fn, index)
        if not name then return nil end
        if name == wanted_name then return value end
        index = index + 1
    end
end

h.test("disabled count settings return four explicit false values", function()
    Ls_Tweeks_DB = { objectives = {}, modules = { objectives = false } }
    local get_count_settings = find_upvalue(M.get_section_count_status, "get_count_settings")
    h.ok(type(get_count_settings) == "function", "get_count_settings upvalue found")

    h.eq(select("#", get_count_settings()), 4, "disabled arity")
    local quest, achievement, quest_hover, achievement_hover = get_count_settings()
    h.eq(quest, false, "quest count disabled")
    h.eq(achievement, false, "achievement count disabled")
    h.eq(quest_hover, false, "quest hover disabled")
    h.eq(achievement_hover, false, "achievement hover disabled")
end)

h.run("ob_section_count")

--#endregion FILE CONTENTS ===================================================
