-- Aura Frames tooltip cache, secret-data fallback, hover, and native-delegate integration tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global, undefined-field


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function load_aura_frames()
    h.load_addon("modules/aura_frames")
    return h.addon.aura_frames
end

h.test("disabled module rejects tooltip cache prewarm before frame inspection", function()
    local M = load_aura_frames()
    local original_is_runtime_enabled = M.is_runtime_enabled
    local frame_inspected = false
    local blocked_frame = setmetatable({}, {
        __index = function()
            frame_inspected = true
            error("disabled prewarm must not inspect the frame")
        end,
    })

    M.is_runtime_enabled = function() return false end
    M.prewarm_aura_tooltip_cache(blocked_frame)
    M.is_runtime_enabled = original_is_runtime_enabled

    h.ok(not frame_inspected, "disabled module exits before reading tooltip frame state")
end)

h.test("world-entry tooltip cache eviction retains reusable spell lines", function()
    local M = load_aura_frames()
    local aura_lines = { { left_text = "Aura" } }
    local spell_lines = { { left_text = "Spell" } }
    M._tooltip_data_lines_cache = {
        ["aura:101"] = aura_lines,
        ["aura:202"] = aura_lines,
        ["spell:303"] = spell_lines,
    }

    M.clear_aura_tooltip_instance_cache()

    h.is_nil(M._tooltip_data_lines_cache["aura:101"], "first aura entry evicted")
    h.is_nil(M._tooltip_data_lines_cache["aura:202"], "second aura entry evicted")
    h.eq(M._tooltip_data_lines_cache["spell:303"], spell_lines, "spell entry survives world entry")
end)

h.test("Aura icon hover renders only copied safe tooltip data outside combat", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 1101
    icon.aura_spell_id = 1202
    icon.aura_name = "Test Aura"
    icon.tooltip_enabled = true

    local tooltip_info_calls = 0
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            tooltip_info_calls = tooltip_info_calls + 1
            return { lines = { { leftText = "Test Aura" }, { leftText = "Safe effect description." } } }
        end,
    }
    icon:GetScript("OnEnter")(icon)
    C_TooltipInfo = previous_tooltip_info

    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip_info_calls, 1, "Aura data is queried only for guarded copying")
    h.eq(tooltip.lines[2]:GetText(), "Safe effect description.", "validated Aura description is retained")
    h.eq(tooltip:IsShown(), true, "owned Aura tooltip is shown")
    h.is_nil(rawget(_G, "LsTweeksOpaqueAuraTooltip"), "hover creates no live-data GameTooltip")
    h.is_nil(GameTooltip:GetLastCall("SetOwner"), "Aura hover does not mutate Blizzard's shared GameTooltip")
    h.is_nil(GameTooltip:GetLastCall("SetUnitAuraByAuraInstanceID"), "Aura data never enters Blizzard's shared GameTooltip")
end)

h.test("experimental Aura hover delegates directly to Blizzard's global tooltip", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 3101
    icon.aura_spell_id = 3202
    icon.aura_name = "Native Test Aura"
    icon.tooltip_enabled = true
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            error("experimental native hover must not fetch TooltipInfo in addon code")
        end,
    }

    h.addon.SetNativeAuraTooltipTestEnabled(true)
    icon:GetScript("OnEnter")(icon)
    local hide_count = #(GameTooltip:GetCalls("Hide") or {})
    h.addon.SetNativeAuraTooltipTestEnabled(false)
    icon:GetScript("OnLeave")(icon)
    C_TooltipInfo = previous_tooltip_info

    local setter = GameTooltip:GetLastCall("SetUnitAuraByAuraInstanceID")
    h.eq(setter[1], "player", "hover delegates the unit directly")
    h.eq(setter[2], 3101, "hover delegates the Aura instance directly")
    h.eq(#(GameTooltip:GetCalls("Hide") or {}), hide_count + 1,
        "toggle-off hides the matching tooltip and clears hover ownership")
end)

h.test("Aura icon hover uses guarded basic data in combat", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 2101
    icon.aura_spell_id = 2202
    icon.aura_name = "Combat Aura"
    icon.tooltip_enabled = true
    h.stub.in_combat = true
    local tooltip_info_calls = 0
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            tooltip_info_calls = tooltip_info_calls + 1
            return {
                lines = {
                    { leftText = "Combat Aura" },
                    { leftText = "Live combat effect description." },
                },
            }
        end,
    }

    icon:GetScript("OnEnter")(icon)

    h.stub.in_combat = false
    C_TooltipInfo = previous_tooltip_info
    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip_info_calls, 0, "combat hover never requests restricted live tooltip data")
    h.eq(tooltip.lines[1]:GetText(), "Combat Aura", "combat fallback keeps the readable Aura title")
    h.eq(tooltip:IsShown(), true, "owned combat Aura tooltip is shown")
    h.is_nil(rawget(_G, "LsTweeksOpaqueAuraTooltip"), "combat hover creates no live-data GameTooltip")
end)

h.test("secret Aura tooltip data falls back without live forwarding", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 303
    icon.aura_spell_id = 404
    icon.aura_name = "Secret Aura"
    icon.tooltip_enabled = true
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            return { __lstweeks_test_secret_table = true }
        end,
    }

    icon:GetScript("OnEnter")(icon)
    local tooltip = h.addon.GetOwnedTooltip()
    C_TooltipInfo = previous_tooltip_info

    h.eq(tooltip.lines[1]:GetText(), "Secret Aura", "secret data falls back to the readable Aura title")
    h.eq(tooltip:IsShown(), true, "secret data still gets an owned basic tooltip")
    h.is_nil(rawget(_G, "LsTweeksOpaqueAuraTooltip"), "secret data creates no live-data GameTooltip")
end)

h.test("cached safe Aura lines render without refreshing live data", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 505
    icon.aura_name = "Aura"
    icon.tooltip_enabled = true
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = {
        GetUnitAuraByAuraInstanceID = function()
            error("cached hover must not refresh live tooltip data")
        end,
    }
    M._tooltip_data_lines_cache = {
        ["aura:505"] = {
            { left_text = "Known title", left_color = { r = 0.3, g = 0.5, b = 0.7 } },
            { left_text = "Known description", left_color = { r = 0.8, g = 0.6, b = 0.4 } },
        },
    }

    icon:GetScript("OnEnter")(icon)
    local tooltip = h.addon.GetOwnedTooltip()
    C_TooltipInfo = previous_tooltip_info

    h.eq(tooltip.lines[1]:GetText(), "Known title", "cached title is retained")
    h.eq(tooltip.lines[2]:GetText(), "Known description", "cached description is retained")
    h.eq(tooltip:IsShown(), true, "cached rich tooltip is shown on the owned frame")
end)

h.test("Aura icon leave hides the owned tooltip", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_index = 404
    icon.aura_name = "Owned Aura"
    icon.tooltip_enabled = true
    local previous_tooltip_info = C_TooltipInfo
    C_TooltipInfo = { GetUnitAuraByAuraInstanceID = function() return { lines = { { leftText = "Owned Aura" } } } end }

    icon:GetScript("OnEnter")(icon)
    local tooltip = h.addon.GetOwnedTooltip()
    h.eq(tooltip.owner, icon, "Aura icon owns the tooltip after enter")
    local hide_count = #(tooltip:GetCalls("Hide") or {})
    icon:GetScript("OnLeave")(icon)
    h.eq(#(tooltip:GetCalls("Hide") or {}), hide_count + 1, "leaving the Aura icon hides its owned tooltip")
    C_TooltipInfo = previous_tooltip_info
end)

h.test("combat Aura tooltip keeps live-only timed aura from reading as permanent", function()
    local M = load_aura_frames()
    M.db = {}
    local frame = M.create_aura_frame("show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "Short", false)
    local icon = frame.icons[1]
    icon.aura_name = "Combat Aura"
    icon.aura_duration = 0
    icon.aura_remaining = 90
    icon.aura_expiration = GetTime() + 90
    icon.tooltip_enabled = true
    h.stub.in_combat = true

    icon:GetScript("OnEnter")(icon)

    h.stub.in_combat = false
    local lines = h.addon.GetOwnedTooltip().lines
    h.eq(lines[2]:GetText(), "Remaining: 00h 01m 30s", "live remaining time is shown without a readable total duration")
    h.is_nil(lines[3], "combat fallback does not label the timed aura permanent")
end)


h.run("af_tooltip_integration")

--#endregion FILE CONTENTS ===================================================
