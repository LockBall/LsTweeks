-- Shared owned-tooltip factory tests: verifies functions/tooltip.lua renders rich line data,
-- bounds widths, and anchors without GameTooltip machinery. Runs under desktop Lua 5.1 against
-- the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function load_tooltip()
    h.load_file("functions/tooltip.lua")
    return h.addon
end

h.test("centralized tooltip renderer preserves rich left and right text", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    addon.ShowOwnedTooltipLines(owner, {
        {
            left_text = "Test Aura",
            right_text = "1 min",
            left_color = { r = 1, g = 0.82, b = 0 },
            right_color = { r = 0.7, g = 0.7, b = 1 },
        },
    })

    local tooltip = addon.GetOwnedTooltip()
    h.eq(tooltip.__kind, "Frame", "rich line rendering stays off Blizzard GameTooltip")
    h.eq(tooltip.lines[1]:GetText(), "Test Aura", "left text retained")
    h.eq(tooltip.right_lines[1]:GetText(), "1 min", "right text retained")
end)

h.test("native tooltip keeps rich data rendering without the widget cleanup template", function()
    local addon = load_tooltip()
    local tooltip = addon.GetNativeTooltip()

    h.eq(tooltip.__kind, "GameTooltip", "native tooltip retains Blizzard tooltip data rendering")
    h.eq(tooltip.__template, "SharedTooltipArtTemplate", "native tooltip uses only the lightweight art template")
    h.ok(not tooltip.__template:find("GameTooltipTemplate", 1, true), "widget cleanup template is not inherited")
    h.eq(tooltip:GetScript("OnHide"), SharedTooltip_OnHide, "hide uses lightweight shared cleanup")
    h.ok(tooltip:GetScript("OnHide") ~= GameTooltip_OnHide, "hide cannot enter GameTooltip widget cleanup")
    h.eq(tooltip:GetScript("OnTooltipCleared"), SharedTooltip_ClearInsertedFrames, "inserted text frames still clear")
    h.eq(tooltip:GetScript("OnEvent"), GameTooltipDataMixin.OnEvent, "native tooltip data can refresh")
end)

h.test("Aura data never enters the native Aura tooltip processor", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local shown = addon.ShowNativeAuraTooltip(owner, "player", 808, "ANCHOR_RIGHT")
    local setter_call = addon.GetNativeTooltip():GetLastCall("SetUnitAuraByAuraInstanceID")

    h.eq(shown, false, "native Aura rendering is disabled")
    h.is_nil(setter_call, "Aura data never reaches the native Aura setter")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("instance=world"), "trace records coarse instance context")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("skip%-disabled native%-aura"), "trace records the disabled native route")
end)

h.test("Aura spell data never enters the native spell processor", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local shown = addon.ShowNativeSpellTooltip(owner, 909, "ANCHOR_RIGHT")
    local setter_call = addon.GetNativeTooltip():GetLastCall("SetSpellByID")

    h.eq(shown, false, "native Aura spell rendering is disabled")
    h.is_nil(setter_call, "Aura spell data never reaches the native spell setter")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("skip%-disabled native%-spell"), "trace records the disabled native spell route")
end)

h.test("opaque Aura renderer forwards secret text without reading secret formatting", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local line = setmetatable({
        leftText = "Full secret Aura description",
        rightText = "12 sec",
    }, {
        __index = function(_, key)
            error("opaque renderer inspected forbidden field " .. tostring(key))
        end,
    })
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            return { lines = { line } }
        end,
    }

    local shown = addon.ShowOpaqueAuraTooltip(owner, "player", 909, "ANCHOR_RIGHT", {
        {
            left_color = { r = 0.2, g = 0.4, b = 0.6 },
            right_color = { r = 0.7, g = 0.8, b = 0.9 },
        },
    })
    local tooltip = rawget(_G, "LsTweeksOpaqueAuraTooltip")
    local rendered = tooltip:GetLastCall("AddDoubleLine")
    C_TooltipInfo = previous_tooltip_info

    h.eq(shown, true, "opaque Aura text is shown")
    h.eq(tooltip.__template, "SharedTooltipArtTemplate", "opaque renderer has no data-processing template")
    h.eq(rendered[1], "Full secret Aura description", "left text passes through unchanged")
    h.eq(rendered[2], "12 sec", "right text passes through unchanged")
    h.eq(rendered[3], 0.2, "known safe left red is retained")
    h.eq(rendered[4], 0.4, "known safe left green is retained")
    h.eq(rendered[5], 0.6, "known safe left blue is retained")
    h.eq(rendered[6], 0.7, "known safe right red is retained")
    h.eq(rendered[7], 0.8, "known safe right green is retained")
    h.eq(rendered[8], 0.9, "known safe right blue is retained")
    local history = addon.GetTooltipRendererHistory()
    h.eq(history[#history], "opaque-aura", "opaque Aura route is retained in the diagnostic trace")
end)

h.test("opaque Aura test switch bypasses only its live renderer", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            return { lines = { { leftText = "Live Aura description" } } }
        end,
    }

    addon.SetOpaqueAuraTooltipTestDisabled(true)
    local shown = addon.ShowOpaqueAuraTooltip(owner, "player", 1001, "ANCHOR_RIGHT")
    addon.SetOpaqueAuraTooltipTestDisabled(false)
    C_TooltipInfo = previous_tooltip_info

    h.eq(shown, false, "test switch bypasses only the opaque live renderer")
end)

h.test("centralized tooltip data copier rejects secret containers", function()
    local addon = load_tooltip()
    local secret_data = setmetatable({
        __lstweeks_test_secret_table = true,
    }, {
        __index = function()
            error("secret tooltip data was inspected")
        end,
    })
    local secret_lines = {
        __lstweeks_test_secret_table = true,
        setmetatable({}, {
            __index = function()
                error("secret tooltip line was inspected")
            end,
        }),
    }

    h.is_nil(addon.CopySafeTooltipDataLines(secret_data), "secret outer tooltip data is rejected")
    h.is_nil(addon.CopySafeTooltipDataLines({ lines = secret_lines }), "secret tooltip lines are rejected")
end)

h.test("centralized tooltip renderer shows right-text-only cached lines", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    addon.ShowOwnedTooltipLines(owner, {
        { right_text = "500 armor", right_color = { r = 0.7, g = 0.7, b = 1 } },
    })

    local tooltip = addon.GetOwnedTooltip()
    h.eq(tooltip:IsShown(), true, "right-only cached lines still show the tooltip")
    h.eq(tooltip.right_lines[1]:GetText(), "500 armor", "right-only text renders")
    h.eq(tooltip.right_lines[1]:IsShown(), true, "right-only line is visible")
end)

h.test("centralized tooltip renderer bounds long single and double lines", function()
    local addon = load_tooltip()
    local tooltip = addon.CreateOwnedTooltip("LsTweeksWidthTestTooltip", UIParent)

    tooltip:ClearLines()
    tooltip:AddLine(string.rep("L", 100))
    tooltip:ApplyContentWidth()
    h.eq(tooltip:GetWidth(), 240, "long single line caps the tooltip at its maximum width")
    h.eq(tooltip.lines[1]:GetWidth(), 224, "long single line is constrained to the content width")

    tooltip:ClearLines()
    tooltip:AddDoubleLine("Left", string.rep("R", 100))
    tooltip:ApplyContentWidth()
    local left_width = tooltip.lines[1]:GetWidth()
    local right_width = tooltip.right_lines[1]:GetWidth()
    h.ok(left_width >= 0, "long right column never produces a negative left width")
    h.ok(right_width >= 0, "long right column receives a nonnegative width")
    h.ok(left_width + 10 + right_width <= 224, "double-line columns remain inside the content width")
end)

h.test("centralized tooltip renderer shrinks short wrap-flagged lines to fit", function()
    local addon = load_tooltip()
    local tooltip = addon.CreateOwnedTooltip("LsTweeksWrapShrinkTestTooltip", UIParent)

    tooltip:ClearLines()
    tooltip:AddLine("A short wrapped body", nil, nil, nil, true)
    tooltip:ApplyContentWidth()
    h.ok(tooltip:GetWidth() < 240, "short wrap-flagged line does not force the maximum tooltip width")
    h.eq(tooltip:GetWidth(), tooltip.lines[1]:GetWidth() + 16, "tooltip width tracks the measured line width plus insets")
end)

h.test("centralized tooltip renderer matches native fonts and flips at screen edges", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    owner.GetCenter = function()
        return 1800, 100
    end
    addon.ShowOwnedTooltipLines(owner, {
        { left_text = "Header" },
        { left_text = "Body" },
    })

    local tooltip = addon.GetOwnedTooltip()
    h.eq(tooltip.lines[1].__template, "GameTooltipHeaderText", "first row uses the native tooltip header font")
    h.eq(tooltip.lines[2].__template, "GameTooltipText", "later rows use the native tooltip body font")
    h.eq(tooltip:GetLastCall("SetClampedToScreen")[1], true, "tooltip is clamped as a final screen-edge guard")

    local point, relative_to, relative_point, x, y = tooltip:GetPoint()
    h.eq(point, "BOTTOMRIGHT", "bottom-right owner places tooltip above and to the left")
    h.eq(relative_to, owner, "smart anchor remains attached to its owner")
    h.eq(relative_point, "TOPLEFT", "owner-facing corner is selected")
    h.eq(x, -8, "smart anchor keeps a horizontal gap")
    h.eq(y, 8, "smart anchor keeps a vertical gap")
end)

h.run("tooltip")

--#endregion FILE CONTENTS ===================================================
