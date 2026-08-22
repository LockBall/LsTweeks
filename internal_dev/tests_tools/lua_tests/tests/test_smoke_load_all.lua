-- Smoke test: loads every addon file from the TOC into the stub environment, boots the
-- simulated client, and pokes the shared runtime paths to prove no file errors at load.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


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

h.test("/lst filtered status emits readable multiline fields", function()
    local messages = {}
    local original_print = print
    print = function(message)
        messages[#messages + 1] = tostring(message)
    end
    SlashCmdList["LSTWEEKS"]("status objectives")
    print = original_print

    local output = table.concat(messages, "\n")
    h.ok(output:find("Objectives: enabled=true\n  campaign_available=", 1, true),
        "filtered Objectives fields use newline separators")
    h.ok(output:find("campaign_available=true\n  campaign_auto_collapse=false", 1, true),
        "every filtered Objectives field uses a newline separator")
    h.eq(output:find("Objectives: enabled=true, campaign_available=", 1, true), nil,
        "filtered Objectives output is not one comma-separated line")
end)

h.test("/lst tooltipdebug retains trace markers", function()
    local before_marker_count = #h.addon.GetTooltipDebugTrace()
    SlashCmdList["LSTWEEKS"]("tooltipdebug mark")
    h.eq(#h.addon.GetTooltipDebugTrace(), before_marker_count + 1, "tooltip marker retains earlier diagnostic events")
    h.ok(h.addon.GetTooltipDebugTrace()[#h.addon.GetTooltipDebugTrace()]:find("marker session"), "tooltip marker is visible in the trace")
end)

h.test("/lst tooltipdebug controls the reload-scoped native Aura experiment", function()
    SlashCmdList["LSTWEEKS"]("tooltipdebug native-on")
    h.eq(h.addon.IsNativeAuraTooltipTestEnabled(), true, "native experiment enabled")
    SlashCmdList["LSTWEEKS"]("tooltipdebug native-off")
    h.eq(h.addon.IsNativeAuraTooltipTestEnabled(), false, "native experiment disabled")
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
