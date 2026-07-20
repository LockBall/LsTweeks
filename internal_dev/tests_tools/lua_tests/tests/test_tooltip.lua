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
