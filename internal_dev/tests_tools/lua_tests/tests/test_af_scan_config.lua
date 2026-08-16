-- Aura Frames scan-cache, configuration, color resolution, and secret-timing tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global, undefined-field


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local function load_aura_frames()
    h.load_addon("modules/aura_frames")
    return h.addon.aura_frames
end

h.test("repeated dirty marks do not clear Aura scan caches before the pending scan", function()
    local M = load_aura_frames()
    local custom_cache_clears = 0
    local sorted_cache_clears = 0
    M._aura_scan_dirty = false
    M.clear_custom_aura_scan_cache = function()
        custom_cache_clears = custom_cache_clears + 1
    end
    M.clear_sorted_aura_ids_cache = function()
        sorted_cache_clears = sorted_cache_clears + 1
    end

    M.mark_aura_scan_dirty()
    M.mark_aura_scan_dirty()

    h.eq(custom_cache_clears, 1, "custom Aura cache clears once per pending scan")
    h.eq(sorted_cache_clears, 1, "sorted Aura cache clears once per pending scan")
end)

h.test("custom frame deletion clears its scan cache and controls", function()
    local M = load_aura_frames()
    local cache_clears = 0
    local frame = CreateFrame("Frame", nil, UIParent)
    frame._display_count = 4
    frame._tooltip_cache_retry_count = 2
    frame._tooltip_cache_retry_pending = true
    M.db = { custom_frames = { { id = "custom_test" } } }
    M.frames = { show_custom_test = frame }
    M.frames_list = { frame }
    M.controls = { custom_custom_test_scale = {} }
    M.clear_custom_aura_scan_cache = function() cache_clears = cache_clears + 1 end

    M.destroy_custom_frame("custom_test")

    h.eq(#M.db.custom_frames, 0, "custom frame DB entry is removed")
    h.is_nil(M.controls.custom_custom_test_scale, "custom frame controls are removed")
    h.eq(cache_clears, 1, "custom frame deletion clears its scan cache")
    h.eq(frame._display_count, 0, "custom frame display state cleared")
    h.eq(frame._tooltip_cache_retry_count, 0, "custom frame retry count cleared")
    h.eq(frame._tooltip_cache_retry_pending, false, "custom frame retry state cleared")
end)

h.test("category-specific false settings override flat Aura Frame fallbacks", function()
    local M = load_aura_frames()
    local original_activity = M.get_frame_activity_state
    local original_timer_text = M.is_timer_text_enabled
    local original_cooldown_overlay = M.uses_cooldown_icon_overlay
    local original_render = M.render_aura_map
    local original_refresh_fade = M.refresh_frame_ooc_fade
    local original_refresh_ticker = M.refresh_visible_icon_ticker
    M.db = {
        short_threshold = 5,
        bar_mode_short = false,
        bar_mode = true,
        bg_short = false,
        bg = true,
        width_short = 120,
        spacing_short = 2,
        scale_short = 1,
        growth_icon_short = "DOWN",
        color_short = { r = 1, g = 1, b = 1 },
        bar_bg_color_short = { r = 0, g = 0, b = 0, a = 1 },
        bar_text_color_short = { r = 1, g = 1, b = 1 },
        bg_color_short = { r = 1, g = 0, b = 0, a = 0.5 },
    }
    M._aura_map = {}
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.category = "short"
    frame.icons = {}
    frame._layout_cache = {
        frame_width = 120,
        bar_mode = false,
        show_timer_text = false,
        layout_show_timer_text = false,
        cooldown_icon_overlay = false,
        spacing = 2,
        growth = "DOWN",
    }

    M.get_frame_activity_state = function()
        return { enabled = true, moving = false, test_aura = false }
    end
    M.is_timer_text_enabled = function() return false end
    M.uses_cooldown_icon_overlay = function() return false end
    M.render_aura_map = function() return 0 end
    M.refresh_frame_ooc_fade = function() end
    M.refresh_visible_icon_ticker = function() end

    M.update_auras(frame, "show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "HELPFUL")

    M.get_frame_activity_state = original_activity
    M.is_timer_text_enabled = original_timer_text
    M.uses_cooldown_icon_overlay = original_cooldown_overlay
    M.render_aura_map = original_render
    M.refresh_frame_ooc_fade = original_refresh_fade
    M.refresh_visible_icon_ticker = original_refresh_ticker

    h.eq(frame._bar_mode, false, "category false keeps icon mode")
    h.eq(frame._lstweeks_bg_a, 0, "category false hides background")
end)

h.test("shared frame and bar colors resolve through Aura runtime configuration", function()
    local M = load_aura_frames()
    local addon = h.addon
    local original_sync = addon.all_the_colors
    local original_activity = M.get_frame_activity_state
    local original_timer_text = M.is_timer_text_enabled
    local original_cooldown_overlay = M.uses_cooldown_icon_overlay
    local original_render = M.render_aura_map
    local original_refresh_fade = M.refresh_frame_ooc_fade
    local original_refresh_ticker = M.refresh_visible_icon_ticker
    local rendered_bar_background

    addon.all_the_colors = {
        resolve_color = function(module_key, target_key, color)
            h.eq(module_key, "aura_frames", "Aura Frames requests its module color")
            if target_key == "frame:short" then
                return { r = 0.21, g = 0.31, b = 0.41, a = 0.51 }
            end
            return color
        end,
        resolve_module_color = function(module_key, color_key, color)
            h.eq(module_key, "aura_frames", "Aura Frames requests its module style color")
            if color_key == "aura_bar_bg_color" then
                return { r = 0.61, g = 0.71, b = 0.81, a = 0.91 }
            end
            return color
        end,
    }
    M.db = {
        short_threshold = 5,
        bar_mode_short = true,
        bg_short = true,
        width_short = 120,
        spacing_short = 2,
        scale_short = 1,
        growth_bar_short = "DOWN",
        color_short = { r = 1, g = 1, b = 1 },
        bar_bg_color_short = { r = 0, g = 0, b = 0, a = 1 },
        bar_text_color_short = { r = 1, g = 1, b = 1 },
        bg_color_short = { r = 1, g = 0, b = 0, a = 0.5 },
    }
    M._aura_map = {}
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.category = "short"
    frame.icons = {}
    frame._layout_cache = {
        frame_width = 120,
        bar_mode = true,
        show_timer_text = false,
        layout_show_timer_text = false,
        cooldown_icon_overlay = false,
        spacing = 2,
        growth = "DOWN",
    }

    M.get_frame_activity_state = function()
        return { enabled = true, moving = false, test_aura = false }
    end
    M.is_timer_text_enabled = function() return false end
    M.uses_cooldown_icon_overlay = function() return false end
    M.render_aura_map = function(_, _, _, _, bar_background)
        rendered_bar_background = bar_background
        return 0
    end
    M.refresh_frame_ooc_fade = function() end
    M.refresh_visible_icon_ticker = function() end

    M.update_auras(frame, "show_short", "move_short", "timer_short", "bg_short", "scale_short", "spacing_short", "HELPFUL")
    local frame_red = frame._lstweeks_bg_r
    local frame_alpha = frame._lstweeks_bg_a
    local bar_red = rendered_bar_background and rendered_bar_background.r
    local bar_alpha = rendered_bar_background and rendered_bar_background.a

    addon.all_the_colors = original_sync
    M.get_frame_activity_state = original_activity
    M.is_timer_text_enabled = original_timer_text
    M.uses_cooldown_icon_overlay = original_cooldown_overlay
    M.render_aura_map = original_render
    M.refresh_frame_ooc_fade = original_refresh_fade
    M.refresh_visible_icon_ticker = original_refresh_ticker

    h.eq(frame_red, 0.21, "frame override reaches backdrop")
    h.eq(frame_alpha, 0.51, "frame override preserves alpha")
    h.eq(bar_red, 0.61, "bar override reaches renderer")
    h.eq(bar_alpha, 0.91, "bar override preserves alpha")
end)

h.test("unified scan continues after malformed helpful and debuff records", function()
    local M = load_aura_frames()
    M.db = {}
    h.stub.auras.player = {
        buffs = {
            { spellId = 1001, name = "Malformed Buff", icon = 1, duration = 10, expirationTime = 10 },
            { auraInstanceID = 101, spellId = 1002, name = "Valid Buff", icon = 2, duration = 10, expirationTime = 10 },
        },
        debuffs = {
            { spellId = 2001, name = "Malformed Debuff", icon = 3, duration = 10, expirationTime = 10 },
            { auraInstanceID = 202, spellId = 2002, name = "Valid Debuff", icon = 4, duration = 10, expirationTime = 10 },
        },
    }
    M._aura_map = {}

    M.unified_scan(nil, 5)

    h.ok(M._aura_map[101], "valid helpful record survives an earlier malformed record")
    h.ok(M._aura_map[202], "valid debuff record survives an earlier malformed record")
    h.stub.auras.player = nil
end)

h.test("unified scan refreshes an Aura order key when identity changes", function()
    local M = load_aura_frames()
    M.db = {}
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 303, spellId = 3003, name = "Original", icon = 3, duration = 10, expirationTime = 10 },
        },
        debuffs = {},
    }
    M._aura_map = {}

    M.unified_scan(nil, 5)
    local original_key = M._aura_map[303].order_key
    h.stub.auras.player.buffs[1].name = "Updated"
    M.unified_scan(nil, 5)

    h.ok(M._aura_map[303].order_key ~= original_key, "identity change refreshes ordering")
    h.stub.auras.player = nil
end)

h.test("secret-timing helpful Aura classifies from DoesAuraHaveExpirationTime", function()
    local M = load_aura_frames()
    M.db = {}
    local previous_expiration_check = C_UnitAuras.DoesAuraHaveExpirationTime
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 601, spellId = 6001, name = "Secret Permanent", icon = 1 },
        },
        debuffs = {},
    }
    M._aura_map = {}

    rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return false end)
    M.unified_scan(nil, 5)
    h.eq(M._aura_map[601].category, "static", "known non-expiring secret Aura classifies as static")

    h.stub.auras.player.buffs[1] = { auraInstanceID = 602, spellId = 6002, name = "Secret Timed", icon = 1 }
    rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return true end)
    M.unified_scan(nil, 5)
    h.eq(M._aura_map[602].category, "short", "known expiring secret Aura with no history classifies as short")

    h.stub.auras.player.buffs[1] = { auraInstanceID = 603, spellId = 6003, name = "Unavailable Result", icon = 1 }
    rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return nil end)
    M.unified_scan(nil, 5)
    h.eq(M._aura_map[603].category, "short", "unreadable expiration result with no history falls back to short")

    C_UnitAuras.DoesAuraHaveExpirationTime = previous_expiration_check
    h.stub.auras.player = nil
end)

h.test("secret-timing debuff always joins the debuff bucket regardless of expiration readability", function()
    local M = load_aura_frames()
    M.db = {}
    local previous_expiration_check = C_UnitAuras.DoesAuraHaveExpirationTime
    M._aura_map = {}

    for _, result in ipairs({ false, true, nil }) do
        h.stub.auras.player = {
            buffs = {},
            debuffs = {
                { auraInstanceID = 701, spellId = 7001, name = "Secret Debuff", icon = 1 },
            },
        }
        rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return result end)
        M.unified_scan(nil, 5)
        h.eq(M._aura_map[701].category, "debuff",
            "debuff belongs to the debuff frame when expiration readability is " .. tostring(result))
    end

    C_UnitAuras.DoesAuraHaveExpirationTime = previous_expiration_check
    h.stub.auras.player = nil
end)


h.run("af_scan_config")

--#endregion FILE CONTENTS ===================================================
