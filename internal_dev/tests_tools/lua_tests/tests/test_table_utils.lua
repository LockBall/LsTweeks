-- Tests for the shared table/default utilities in functions/table_utils.lua: deep copy,
-- fill-missing default application, and numeric clamping used by every module's DB handling.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global, lowercase-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_file("functions/table_utils.lua")
local addon = h.addon

h.test("deep_copy_into copies nested tables by value", function()
    local src = { a = 1, nested = { b = 2, deeper = { c = 3 } } }
    local dest = {}
    addon.deep_copy_into(src, dest)
    h.eq(dest.a, 1)
    h.eq(dest.nested.deeper.c, 3)
    dest.nested.b = 99
    h.eq(src.nested.b, 2, "source untouched by dest mutation")
end)

h.test("apply_defaults fills only missing keys", function()
    local defaults = { alpha = 0.5, pos = { x = 10, y = 20 }, flag = true }
    local db = { alpha = 0.9, pos = { x = 42 } }
    addon.apply_defaults(defaults, db)
    h.eq(db.alpha, 0.9, "user value preserved")
    h.eq(db.pos.x, 42, "nested user value preserved")
    h.eq(db.pos.y, 20, "missing nested default filled")
    h.eq(db.flag, true, "missing top-level default filled")
end)

h.test("apply_defaults preserves explicit false values", function()
    local db = { flag = false }
    addon.apply_defaults({ flag = true }, db)
    h.eq(db.flag, false, "false is not treated as missing")
end)

h.test("clamp_number clamps, falls back, and coerces strings", function()
    local range = { min = 0, max = 10 }
    h.eq(addon.clamp_number(5, 1, range), 5)
    h.eq(addon.clamp_number(-3, 1, range), 0, "clamped to min")
    h.eq(addon.clamp_number(99, 1, range), 10, "clamped to max")
    h.eq(addon.clamp_number("7", 1, range), 7, "string coerced")
    h.eq(addon.clamp_number("junk", 4, range), 4, "fallback used")
    h.eq(addon.clamp_number(nil, 4, nil), 4, "no range still falls back")
end)

h.run("table_utils")

--#endregion FILE CONTENTS ===================================================
