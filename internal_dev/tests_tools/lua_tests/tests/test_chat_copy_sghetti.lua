-- ChatCopySghetti history bounds, readable-data boundaries, and lifecycle contracts.
---@diagnostic disable: undefined-global

--#region FILE CONTENTS =======================================================
package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub
h.load_addon("modules/chat_copy_sghetti")
h.boot({ modules = { chat_copy_sghetti = false } })
local M = h.addon.chat_copy_sghetti
local function history(lines)
    local frame = CreateFrame("Frame")
    function frame:GetNumMessages() return #lines end
    function frame:GetMessageInfo(index) return lines[index] end
    return frame
end
local options = { max_messages = 25, keep_brackets = true }

h.test("disabled startup installs no chat hooks or combat listeners", function()
    h.eq(stub.hooked_functions.FCF_OpenNewWindow, nil)
    h.eq(stub.hooked_functions.FCF_OpenTemporaryWindow, nil)
    for _, field in ipairs(h.addon.module_status_builders.chat_copy_sghetti()) do
        h.ok(field ~= "combat_events=true")
    end
    h.addon.set_module_enabled(M.MODULE_KEY, true)
end)

h.test("recent cap is exact and chronological without a leading separator", function()
    local lines = {}
    for i = 1, 40 do lines[i] = tostring(i) end
    local text, report = M.collect_snapshot(history(lines), options)
    h.eq(text, table.concat(lines, "\n", 16, 40))
    h.eq(report.exported, 25)
    h.eq(report.skipped, 15)
end)

h.test("secret text is never passed to native string processing", function()
    local secret = { __lstweeks_test_secret_value = true }
    local text, report = M.collect_snapshot(history({ secret, "one\ntwo", secret, "three" }), options)
    h.eq(text, "one\ntwo\nthree")
    h.eq(report.skipped, 2)
    h.eq(report.exported, 2)
end)

h.test("colored output keeps labels and intentional breaks", function()
    h.eq(M.normalize_text("|cffffffff|Hitem:1|h[Item]|h|r\r\nnext|nline", true), "|cffffffff[Item]|r\nnext\nline")
    h.eq(M.normalize_text("|Hitem:1|h[Item]|h", false), "Item")
end)

h.test("channel color surrounds a message and resumes after inline colors", function()
    local frame = history({ "guild |cffa335ee[Item]|r tail" })
    function frame:GetMessageInfo() return "guild |cffa335ee[Item]|r tail", 0, 1, 0 end
    local text = M.collect_snapshot(frame, options)
    h.eq(text, "|cff00ff00guild |cffa335ee[Item]|r|cff00ff00 tail|r")
end)

h.test("separate message colors cannot bleed into following messages", function()
    local frame = history({ "one", "two" })
    function frame:GetMessageInfo(index)
        if index == 1 then return "one", 1, 0, 0 end
        return "two", 0, 0, 1
    end
    h.eq(M.collect_snapshot(frame, options), "|cffff0000one|r\n|cff0000fftwo|r")
end)

h.test("secret color metadata is not inspected or converted", function()
    local frame = history({ "readable" })
    function frame:GetMessageInfo() return "readable", { __lstweeks_test_secret_value = true }, 1, 0 end
    h.eq(M.collect_snapshot(frame, options), "readable")
end)

h.test("empty and wholly unreadable history have no separators", function()
    h.eq(M.collect_snapshot(history({}), options), "")
    local text, report = M.collect_snapshot(history({ { __lstweeks_test_secret_value = true } }), options)
    h.eq(text, "")
    h.eq(report.skipped, 1)
end)

h.test("private-name markup is omitted without reconstruction", function()
    local text, report = M.collect_snapshot(history({ "From |Kq1|k: hello", "readable" }), options)
    h.eq(text, "readable")
    h.eq(report.skipped, 1)
end)

h.test("output bound retains complete recent messages", function()
    local huge = string.rep("x", M.MAX_EXPORT_BYTES)
    local text, report = M.collect_snapshot(history({ "older", huge }), options)
    h.eq(#text, M.MAX_EXPORT_BYTES)
    h.eq(report.exported, 1)
    h.eq(report.skipped, 1)
end)

h.test("unreadable count is rejected before arithmetic", function()
    local frame = history({})
    function frame:GetNumMessages() return { __lstweeks_test_secret_value = true } end
    local text, report = M.collect_snapshot(frame, options)
    h.eq(text, "")
    h.eq(report.unavailable, true)
end)

h.test("export lazily builds popup and close releases text", function()
    local frame = history({ "hello" })
    M.open_export(frame)
    h.ok(M.popup:IsShown())
    h.eq(M.popup.edit:GetText(), "hello")
    M.popup:Hide()
    h.eq(M.popup.edit:GetText(), "")
end)

h.test("lockdown blocks collection and combat clears open text", function()
    local frame = history({ "hello" })
    M.open_export(frame)
    h.enter_combat()
    h.eq(M.popup:IsShown(), false)
    h.eq(M.popup.edit:GetText(), "")
    function frame:GetNumMessages() error("must not collect") end
    M.open_export(frame)
    h.leave_combat()
    stub.chat_lockdown = true
    M.open_export(frame)
    stub.chat_lockdown = false
end)


h.test("disable stops events and hides copy buttons", function()
    local frame = history({})
    _G.ChatCopySghettiTestChat = frame
    CHAT_FRAMES = { "ChatCopySghettiTestChat" }
    M.refresh_buttons()
    h.ok(M.buttons[frame]:IsShown())
    h.addon.set_module_enabled(M.MODULE_KEY, false)
    h.eq(M.buttons[frame]:IsShown(), false)
    for _, field in ipairs(h.addon.module_status_builders.chat_copy_sghetti()) do
        h.ok(field ~= "combat_events=true")
    end
    h.addon.set_module_enabled(M.MODULE_KEY, true)
    h.ok(M.buttons[frame]:IsShown())
end)

h.test("settings use shared factories and reset resynchronizes them", function()
    M.build_options_panel(CreateFrame("Frame", nil, UIParent))
    M.get_db().keep_brackets = false
    M.on_reset_complete()
    h.eq(M.controls.keep_brackets:GetChecked(), false)
    h.eq(M.controls.max_messages:GetValue(), M.get_db().max_messages)
end)

h.test("resizing saves geometry and a recreated popup restores it", function()
    M.open_export(history({ "resize me" }))
    local popup = M.popup
    popup.resize_handle:GetScript("OnMouseDown")(popup.resize_handle, "LeftButton")
    popup:SetSize(900, 600)
    popup:GetScript("OnSizeChanged")(popup, 900, 600)
    local parent_x, parent_y = UIParent:GetCenter()
    function popup:GetCenter() return parent_x + 120, parent_y - 75 end
    popup.resize_handle:GetScript("OnMouseUp")(popup.resize_handle)
    h.eq(M.get_db().window.width, 900)
    h.eq(M.get_db().window.height, 600)
    h.eq(M.get_db().window.x, 120)
    h.eq(M.get_db().window.y, -75)
    h.eq(popup.edit:GetWidth(), 822)
    popup:Hide()
    -- Simulate reconstructing from saved data, without retaining any old frame.
    Ls_Tweeks_DB.chat_copy_sghetti = h.addon.deep_copy(M.get_db())
    M.popup = nil
    M.open_export(history({ "restored" }))
    h.eq(M.popup:GetWidth(), 900)
    h.eq(M.popup:GetHeight(), 600)
    local point, relative, relative_point, x, y = M.popup:GetPoint()
    h.eq(point, "CENTER")
    h.eq(relative, UIParent)
    h.eq(relative_point, "CENTER")
    h.eq(x, 120)
    h.eq(y, -75)
end)

h.test("interrupted movement saves position but normal hide cannot overwrite reset", function()
    local popup = M.popup
    popup:GetScript("OnDragStart")(popup)
    local parent_x, parent_y = UIParent:GetCenter()
    function popup:GetCenter() return parent_x - 40, parent_y + 50 end
    h.enter_combat()
    h.eq(popup.is_positioning, false)
    h.eq(M.get_db().window.x, -40)
    h.eq(M.get_db().window.y, 50)
    h.eq(popup.edit:GetText(), "")
    h.leave_combat()
    h.addon.deep_copy_into(M.defaults.chat_copy_sghetti, M.get_db())
    M.on_reset_complete()
    M.open_export(history({ "reset" }))
    h.eq(popup:GetWidth(), 720)
    h.eq(popup:GetHeight(), 460)
    local _, _, _, x, y = popup:GetPoint()
    h.eq(x, 0)
    h.eq(y, 0)
end)

h.test("saved oversized and offscreen geometry is constrained to current screen", function()
    M.get_db().window = { width = 9000, height = 10, x = 9000, y = -9000 }
    M.open_export(history({ "clamped" }))
    h.eq(M.popup:GetWidth(), UIParent:GetWidth())
    h.eq(M.popup:GetHeight(), M.WINDOW_MINIMUM.height)
    local _, _, _, x, y = M.popup:GetPoint()
    h.eq(x, 0)
    h.eq(y, -(UIParent:GetHeight() - M.WINDOW_MINIMUM.height) / 2)
end)

h.test("minimize preserves full size and restores content without saving collapsed height", function()
    h.addon.deep_copy_into(M.defaults.chat_copy_sghetti, M.get_db())
    M.open_export(history({ "keep this text" }))
    local popup = M.popup
    popup:SetMinimized(true)
    h.eq(popup:GetHeight(), 40)
    h.eq(popup.edit:GetParent():IsShown(), false)
    h.eq(popup.edit:GetText(), "keep this text")
    h.eq(M.get_db().window.height, 460)
    popup:GetScript("OnDragStart")(popup)
    local x, y = UIParent:GetCenter()
    function popup:GetCenter() return x + 20, y + 100 end
    popup:GetScript("OnDragStop")(popup)
    h.eq(M.get_db().window.height, 460)
    h.eq(M.get_db().window.y, 100 - (460 - 40) / 2)
    popup:SetMinimized(false)
    h.eq(popup:GetHeight(), 460)
    h.eq(popup.edit:GetParent():IsShown(), true)
    popup:SetMinimized(true)
    popup:Hide()
    M.open_export(history({ "new export" }))
    h.eq(popup.is_minimized, false)
    h.eq(popup:GetHeight(), 460)
end)

h.test("popup background applies selected RGBA directly without fading text", function()
    M.get_db().background_color = { r = 0.2, g = 0.4, b = 0.6, a = 0.3 }
    M.apply_popup_background()
    local calls = M.popup.background:GetCalls("SetColorTexture")
    h.ok(calls and #calls > 0, "solid color replaces the dark artwork rather than multiplying its pixels")
    local color = calls[#calls]
    h.eq(color[1], 0.2)
    h.eq(color[2], 0.4)
    h.eq(color[3], 0.6)
    h.eq(color[4], 0.3)
    h.eq(M.popup:GetAlpha(), 1)
end)

h.run("chat_copy_sghetti")
--#endregion FILE CONTENTS ====================================================
