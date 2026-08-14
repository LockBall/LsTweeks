-- Aura Frames disabled-start settings regression tests. Runs under desktop Lua 5.1
-- against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function find_aura_frames_category()
    for _, category in ipairs(h.addon.categories or {}) do
        if category.module_key == "aura_frames" then
            return category
        end
    end
end

local function find_aura_frames_button()
    for _, button in ipairs(h.addon.main_frame and h.addon.main_frame.buttons or {}) do
        if button._category and button._category.module_key == "aura_frames" then
            return button
        end
    end
end

h.test("disabled Aura Frames settings build without starting runtime", function()
    h.load_addon()
    h.boot({ modules = { aura_frames = false } })

    local M = h.addon.aura_frames
    local category = find_aura_frames_category()
    h.ok(category, "Aura Frames settings category registered while disabled")
    h.eq(h.addon.is_module_enabled("aura_frames"), false, "Aura Frames remains disabled")
    h.ok(type(M.db) == "table", "disabled module still attaches its saved settings table")
    h.eq(M._module_started == true, false, "disabled settings preparation does not start runtime frames")
    h.eq(M._module_runtime_enabled == true, false, "disabled settings preparation does not start services")
    h.eq(#(M.frames_list or {}), 0, "disabled settings preparation creates no Aura frames")

    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(741, 700)
    category.builder(panel)

    h.ok(panel, "disabled Aura Frames settings page builds without error")
    h.eq(M._module_started == true, false, "building locked settings does not start runtime frames")
    h.eq(M._module_runtime_enabled == true, false, "building locked settings does not start services")
    h.eq(#(M.frames_list or {}), 0, "building locked settings creates no Aura frames")

    h.addon.main_frame:Show()
    local category_button = find_aura_frames_button()
    h.ok(category_button, "disabled Aura Frames sidebar button exists")
    h.eq(category_button:IsEnabled(), true, "disabled module button remains clickable for its locked page")
    local locked_color = category_button:GetFontString():GetLastCall("SetTextColor")
    h.eq(locked_color[1], 0.45, "unselected disabled module uses dark grey text")
    local lock_count = #(category_button:GetCalls("LockHighlight") or {})
    local unlock_count = #(category_button:GetCalls("UnlockHighlight") or {})
    category_button:Click()
    local selected_color = category_button:GetFontString():GetLastCall("SetTextColor")
    h.eq(selected_color[1], 0.45, "selected disabled module retains dark grey text")
    h.eq(selected_color[2], 0.45, "selected disabled module keeps the disabled grey channel balance")
    h.eq(selected_color[3], 0.45, "selected disabled module does not use active text color")
    h.eq(#(category_button:GetCalls("LockHighlight") or {}), lock_count + 1,
        "selected disabled module receives the normal button highlight")
    h.eq(#(category_button:GetCalls("UnlockHighlight") or {}), unlock_count,
        "selected disabled module keeps its selection highlight")

    h.addon.set_module_enabled("aura_frames", true)
    local started_frame_count = #(M.frames_list or {})
    h.ok(M._module_started == true, "enabling later starts Aura Frames")
    h.ok(M._module_runtime_enabled == true, "enabling later starts runtime services")
    h.ok(started_frame_count > 0, "enabling later creates Aura frames")
    h.eq(M.db, Ls_Tweeks_DB.aura_frames, "runtime reuses the prepared saved settings table")

    h.addon.set_module_enabled("aura_frames", true)
    h.eq(#(M.frames_list or {}), started_frame_count, "repeated enable does not duplicate Aura frames")
end)

h.run("af_disabled_settings")

--#endregion FILE CONTENTS ===================================================
