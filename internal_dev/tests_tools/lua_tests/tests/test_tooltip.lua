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

h.test("Aura data never enters the native Aura tooltip processor", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local shown = addon.ShowNativeAuraTooltip(owner, "player", 808, "ANCHOR_RIGHT")

    h.eq(shown, false, "native Aura rendering is disabled")
    h.is_nil(rawget(_G, "LsTweeksNativeTooltip"), "Aura data creates no native GameTooltip")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("instance=world"), "trace records coarse instance context")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("skip%-disabled native%-aura"), "trace records the disabled native route")
end)

h.test("experimental native Aura route uses only Blizzard's secure global setter", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local setter_count = #(GameTooltip:GetCalls("SetUnitAuraByAuraInstanceID") or {})
    local show_count = #(GameTooltip:GetCalls("Show") or {})
    local tooltip_info_calls = 0
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            tooltip_info_calls = tooltip_info_calls + 1
        end,
    }

    addon.SetNativeAuraTooltipTestEnabled(true)
    local shown = addon.ShowNativeAuraTooltip(owner, "player", 818, "ANCHOR_RIGHT")
    addon.SetNativeAuraTooltipTestEnabled(false)
    C_TooltipInfo = previous_tooltip_info

    local setter = GameTooltip:GetLastCall("SetUnitAuraByAuraInstanceID")
    h.eq(shown, true, "enabled experimental route owns the hover")
    h.eq(#(GameTooltip:GetCalls("SetUnitAuraByAuraInstanceID") or {}), setter_count + 1,
        "native route calls the secure setter exactly once")
    h.eq(setter[1], "player", "secure setter receives the unit directly")
    h.eq(setter[2], 818, "secure setter receives the Aura instance directly")
    h.eq(tooltip_info_calls, 0, "addon code never fetches live TooltipInfo")
    h.eq(#(GameTooltip:GetCalls("Show") or {}), show_count, "addon code never manually shows GameTooltip")
    h.is_nil(rawget(_G, "LsTweeksNativeTooltip"), "native route creates no custom GameTooltip")
end)

h.test("Aura spell data never enters the native spell processor", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local shown = addon.ShowNativeSpellTooltip(owner, 909, "ANCHOR_RIGHT")

    h.eq(shown, false, "native Aura spell rendering is disabled")
    h.is_nil(rawget(_G, "LsTweeksNativeTooltip"), "Aura spell data creates no native GameTooltip")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("skip%-disabled native%-spell"), "trace records the disabled native spell route")
end)

h.test("opaque Aura entry point never queries or renders live data", function()
    local addon = load_tooltip()
    local owner = CreateFrame("Frame", nil, UIParent)
    local getter_calls = 0
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            getter_calls = getter_calls + 1
            return { lines = { { leftText = "Live Aura description" } } }
        end,
    }

    local shown = addon.ShowOpaqueAuraTooltip(owner, "player", 909, "ANCHOR_RIGHT")
    C_TooltipInfo = previous_tooltip_info

    h.eq(shown, false, "opaque live rendering is permanently disabled")
    h.eq(getter_calls, 0, "disabled renderer never queries live Aura data")
    h.is_nil(rawget(_G, "LsTweeksOpaqueAuraTooltip"), "disabled renderer creates no GameTooltip")
    h.ok(addon.GetTooltipDebugTrace()[1]:find("skip%-disabled opaque%-aura"), "trace records the disabled route")
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
