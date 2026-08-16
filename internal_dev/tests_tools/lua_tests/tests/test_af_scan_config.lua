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

h.test("custom helpful frames retain per-entry static short and long timer classes", function()
    local M = load_aura_frames()
    M.db = { short_threshold = 300 }
    M.clear_custom_aura_scan_cache()
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 801, spellId = 8001, name = "Custom Static", icon = 1, duration = 0, expirationTime = 0 },
            { auraInstanceID = 802, spellId = 8002, name = "Custom Short", icon = 2, duration = 120, expirationTime = 120 },
            { auraInstanceID = 803, spellId = 8003, name = "Custom Long", icon = 3, duration = 600, expirationTime = 600 },
        },
        debuffs = {},
    }
    local target_map = {}

    M.scan_custom_aura_map(
        CreateFrame("Frame", nil, UIParent),
        { aura_base_filter = "HELPFUL", aura_modifier = "" },
        target_map,
        M.AURA_FRAME_LIMIT,
        300
    )

    h.eq(target_map[801].category, "static", "custom permanent Aura retains static timer behavior")
    h.eq(target_map[802].category, "short", "custom short Aura retains short timer behavior")
    h.eq(target_map[803].category, "long", "custom long Aura retains long timer behavior")
    h.stub.auras.player = nil
end)

h.test("custom secret-timing helpful Aura classifies from DoesAuraHaveExpirationTime", function()
    local M = load_aura_frames()
    M.db = { short_threshold = 300 }
    local previous_expiration_check = C_UnitAuras.DoesAuraHaveExpirationTime
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 601, spellId = 6001, name = "Secret Permanent", icon = 1 },
        },
        debuffs = {},
    }
    local target_map = {}
    local custom_entry = { aura_base_filter = "HELPFUL", aura_modifier = "" }

    rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return false end)
    M.clear_custom_aura_scan_cache()
    M.scan_custom_aura_map(CreateFrame("Frame"), custom_entry, target_map, M.AURA_FRAME_LIMIT, 300)
    h.eq(target_map[601].category, "static", "known non-expiring secret Aura classifies as static")

    h.stub.auras.player.buffs[1] = { auraInstanceID = 602, spellId = 6002, name = "Secret Timed", icon = 1 }
    rawset(C_UnitAuras, "DoesAuraHaveExpirationTime", function() return true end)
    M.clear_custom_aura_scan_cache()
    M.scan_custom_aura_map(CreateFrame("Frame"), custom_entry, target_map, M.AURA_FRAME_LIMIT, 300)
    h.eq(target_map[602].category, "short", "known expiring secret Aura with no history falls back safely")

    C_UnitAuras.DoesAuraHaveExpirationTime = previous_expiration_check
    h.stub.auras.player = nil
end)

h.test("CDM Aura mode delegates active Aura transport to managed groups", function()
    local M = load_aura_frames()
    M.db = { cooldown_mode_essential = false }
    local aura_reads = 0
    local previous_get_by_instance = C_UnitAuras.GetAuraDataByAuraInstanceID
    rawset(C_UnitAuras, "GetAuraDataByAuraInstanceID", function()
        aura_reads = aura_reads + 1
        error("CDM must not inspect active AuraData")
    end)
    local child = { GetAuraSpellInstanceID = function() return 901 end }
    local viewer = { GetChildren = function() return child end }
    M.get_cdm_viewer_frame = function() return viewer end
    local target_map = {}

    M.add_cooldown_viewer_category_entries(target_map, "essential")

    h.eq(aura_reads, 0, "CDM Aura mode performs no addon-owned AuraData read")
    h.eq(next(target_map), nil, "managed groups own the complete active Aura display")
    rawset(C_UnitAuras, "GetAuraDataByAuraInstanceID", previous_get_by_instance)
end)

h.test("CDM cooldown rendering does not request unit Aura instance ordering", function()
    local M = load_aura_frames()
    local previous_get_ids = C_UnitAuras.GetUnitAuraInstanceIDs
    rawset(C_UnitAuras, "GetUnitAuraInstanceIDs", function()
        error("CDM must not request unit Aura instance ordering")
    end)
    local frame = {
        category = "essential",
        icons = {},
    }

    local ok, err = pcall(M.render_aura_map, frame, {
        [11001] = { spell_id = 11001, cdm_order = 1 },
    }, false, nil, nil, M.AURA_FRAME_LIMIT, "HELPFUL", "default", false, nil)

    rawset(C_UnitAuras, "GetUnitAuraInstanceIDs", previous_get_ids)
    h.ok(ok, tostring(err))
end)

h.test("CDM cooldown scans use public APIs without touching Blizzard viewer frames", function()
    local M = load_aura_frames()
    local previous_cdm_api = C_CooldownViewer
    local previous_cooldown_duration = C_Spell.GetSpellCooldownDuration
    local previous_charge_duration = C_Spell.GetSpellChargeDuration
    local cooldown_duration = { kind = "cooldown" }
    local charge_duration = { kind = "charge" }
    C_CooldownViewer = {
        GetCooldownViewerCategorySet = function()
            return { 81, 82 }
        end,
        GetCooldownViewerCooldownInfo = function(cooldown_id)
            if cooldown_id == 82 then
                return { cooldownID = cooldown_id, spellID = 8201, linkedSpellIDs = {}, charges = true }
            end
            return {
                cooldownID = cooldown_id,
                spellID = 8101,
                overrideSpellID = 8102,
                linkedSpellIDs = { 8103 },
                charges = false,
            }
        end,
    }
    rawset(C_Spell, "GetSpellCooldownDuration", function(spell_id, ignore_gcd)
        h.eq(spell_id, 8102, "cooldown duration uses the active override spell")
        h.eq(ignore_gcd, true, "cooldown duration excludes the global cooldown")
        return cooldown_duration
    end)
    rawset(C_Spell, "GetSpellChargeDuration", function(spell_id)
        h.eq(spell_id, 8201, "charge cooldown uses the public charge-duration API")
        return charge_duration
    end)
    M.db = { cooldown_mode_essential = true }
    M.get_cdm_viewer_frame = function()
        error("public CDM scan must not access Blizzard viewer frames")
    end
    local target_map = {}

    local ok, err = pcall(M.add_cooldown_viewer_category_entries, target_map, "essential")

    C_CooldownViewer = previous_cdm_api
    rawset(C_Spell, "GetSpellCooldownDuration", previous_cooldown_duration)
    rawset(C_Spell, "GetSpellChargeDuration", previous_charge_duration)
    h.ok(ok, tostring(err))
    h.eq(target_map.cd_81.spell_id, 8102, "public cooldown metadata builds the render entry")
    h.eq(target_map.cd_81.duration_object, cooldown_duration, "public duration object reaches the renderer")
    h.eq(target_map.cd_81.cdm_order, 1, "category-set order is preserved")
    h.eq(target_map.cd_82.duration_object, charge_duration, "charge duration object reaches the renderer")
    h.eq(target_map.cd_82.cdm_order, 2, "charge cooldown preserves category-set order")
end)

h.test("addon-owned Aura cancellation remains custom-frame only", function()
    local M = load_aura_frames()
    local previous_cancel = CancelUnitBuff
    local cancellations = 0
    CancelUnitBuff = function() cancellations = cancellations + 1 end
    M.frames_list = {}
    h.stub.auras.player = {
        buffs = { { auraInstanceID = 1001, spellId = 10001, name = "Cancelable" } },
        debuffs = {},
    }
    local function make_icon(parent)
        return { aura_index = 1001, GetParent = function() return parent end }
    end

    h.eq(M.try_cancel_aura_icon(make_icon({ category = "long" }), "RightButton"), false,
        "removed preset category cannot cancel Auras")
    h.eq(M.try_cancel_aura_icon(make_icon({ is_custom = true }), "RightButton"), true,
        "custom frame retains out-of-combat cancellation")
    h.eq(cancellations, 1, "only the custom frame reaches CancelUnitBuff")

    CancelUnitBuff = previous_cancel
    h.stub.auras.player = nil
end)


h.run("af_scan_config")

--#endregion FILE CONTENTS ===================================================
