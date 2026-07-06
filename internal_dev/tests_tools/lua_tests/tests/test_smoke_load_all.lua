-- Smoke test: loads every addon file from the TOC into the stub environment, boots the
-- simulated client, and pokes the shared runtime paths to prove no file errors at load.


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.test("all TOC files load without error", function()
    h.load_addon()
    h.ok(#h.loaded_files > 30, "expected 30+ files loaded, got " .. #h.loaded_files)
end)

h.test("boot fires ADDON_LOADED and PLAYER_ENTERING_WORLD cleanly", function()
    h.boot({})
    h.ok(Ls_Tweeks_DB.modules, "module flags table created")
    h.eq(Ls_Tweeks_DB.modules.player_frame, true, "player_frame default-enabled")
end)

h.test("module enable/disable round-trips through the registry", function()
    h.addon.set_module_enabled("player_frame", false)
    h.eq(h.addon.is_module_enabled("player_frame"), false, "disabled")
    h.addon.set_module_enabled("player_frame", true)
    h.eq(h.addon.is_module_enabled("player_frame"), true, "re-enabled")
end)

h.test("/lst status runs for every module without error", function()
    h.ok(SlashCmdList["LSTWEEKS"], "slash command registered")
    SlashCmdList["LSTWEEKS"]("status")
end)

h.test("advancing simulated time drives pending timers without error", function()
    h.advance(30)
end)

h.test("report stub API gaps hit during full load", function()
    local names = {}
    for name in pairs(stub.missing_globals) do names[#names + 1] = name end
    table.sort(names)
    if #names > 0 then
        print("        (info) globals the stub returned nil for: " .. table.concat(names, ", "))
    end
end)

h.run("smoke_load_all")

--#endregion FILE CONTENTS ===================================================
