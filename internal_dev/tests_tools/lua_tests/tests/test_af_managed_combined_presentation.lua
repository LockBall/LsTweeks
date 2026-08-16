-- Managed Combined Buff presentation, background, resize, and mode-switch tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Combined Buff presentation preserves native groups and OOC reconfiguration", function()
    local M = fixture.boot_managed_presets()
    local buffs_frame = M.frames.show_combined
    local buffs_backend = buffs_frame._managed_aura_backend
    h.ok(buffs_backend, "combined Buffs frame owns a managed backend")
    h.ok(buffs_backend.frame_background, "combined Buff backend owns its frame background")
    h.ok(buffs_backend.frame_background.texture:IsShown(), "enabled combined Frame BG is visible")
    local combined_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(combined_bg_color[1], 0.4, "combined Frame BG applies saved red")
    h.eq(combined_bg_color[4], 0.1, "combined Frame BG applies saved alpha")
    M.db.bg_combined = false
    M.update_managed_preset_frame(buffs_frame, "show_combined", "move_combined")
    h.eq(buffs_backend.frame_background.texture:IsShown(), false,
        "disabling combined Frame BG hides the managed background")
    local combined_bar_buttons = buffs_backend.container.__groups["buffs:bar"].buttons
    h.eq(buffs_backend.frame_background_rows[combined_bar_buttons[2]].background.texture:IsShown(), false,
        "disabling combined Frame BG hides native row extensions")

    local color_sync = h.addon.all_the_colors
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_bg_combined = true
    M.db.shared_frame_background_color = { r = 0.6, g = 0.5, b = 0.4, a = 0.3 }
    color_sync.get_db().global_enabled = false
    M.update_managed_preset_frame(buffs_frame, "show_combined", "move_combined")
    h.ok(buffs_backend.frame_background.texture:IsShown(),
        "Shared BG Colors can show a managed background when local Frame BG is off")
    combined_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(combined_bg_color[1], 0.6, "managed Frame BG receives the Aura shared color")

    color_sync.get_db().global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    color_sync.get_db().global_color = { r = 0.9, g = 0.8, b = 0.7, a = 0.6 }
    M.update_managed_preset_frame(buffs_frame, "show_combined", "move_combined")
    combined_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(combined_bg_color[1], 0.9, "All the Colors globally overrides managed Frame BG")
    h.eq(combined_bg_color[4], 0.6, "managed Frame BG receives global override alpha")

    color_sync.get_db().global_enabled = false
    M.db.shared_background_color_enabled = false
    M.db.bg_combined = true
    M.update_managed_preset_frame(buffs_frame, "show_combined", "move_combined")
    h.eq(buffs_backend.container.__groups["buffs:bar"].filter_string, "HELPFUL",
        "combined Buff groups request every helpful Aura")
    h.eq(buffs_backend.container.__groups["buffs:bar"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "combined Buff bar pool uses the fixed Aura limit")
    h.eq(buffs_backend.container.__groups["buffs:icon"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "combined Buff icon pool uses the fixed Aura limit")
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "bar-mode combined Buffs use vertical flow")
    h.eq(buffs_frame.icons, nil, "combined Buffs frame creates no legacy icon pool")
    h.eq(buffs_frame.__events.UNIT_AURA, nil, "combined Buffs frame does not register UNIT_AURA")
    h.ok(buffs_frame:IsShown(), "runtime startup shows enabled combined Buffs")
    h.eq(buffs_frame:GetAlpha(), 0.25,
        "combined Buff shell applies its saved out-of-combat alpha")
    h.eq(buffs_backend.container:GetAlpha(), 0.25,
        "combined Buff container applies its saved out-of-combat alpha")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__width, 128, "combined Buff bars use the saved inner frame width")
        h.eq(aura_button.__height, 18, "combined Buff bars use the shared native row height")
        h.eq(#(aura_button:GetCalls("SetIcon") or {}), 1,
            "combined Buffs AuraButtons bind their native icon")
        h.ok(aura_button.__spell_name_region, "combined Buff bars bind native spell text")
        h.ok(aura_button.__duration_text_region, "combined Buff bars bind native duration text")
        h.ok(aura_button.__application_count_region, "combined Buff bars bind native stack text")
        h.ok(aura_button.__duration_bar_region, "combined Buff bars bind a native duration bar")
        h.eq(aura_button.__hide_tooltip_in_combat, false,
            "combined Buffs AuraButtons allow native tooltips in combat")
    end
    h.eq(buffs_backend.presentation_mode, "bar", "saved Bar Mode activates the combined Buff bar group")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, M.AURA_FRAME_LIMIT,
        "combined Buff bar group is active")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, 0,
        "combined Buff icon group is parked")

    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        aura_button.CanBeAccessedInContext = function() return true end
    end
    M.db.color_combined = { r = 0.15, g = 0.25, b = 0.35, a = 0.45 }
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        local color_call = aura_button.__duration_bar_region:GetLastCall("SetStatusBarColor")
        h.eq(color_call[1], 0.15, "managed Buff bar applies an OOC red color change")
        h.eq(color_call[2], 0.25, "managed Buff bar applies an OOC green color change")
        h.eq(color_call[3], 0.35, "managed Buff bar applies an OOC blue color change")
        h.eq(color_call[4], 0.45, "managed Buff bar applies an OOC alpha change")
    end
    local unchanged_color_call_count = #buffs_backend.container.__groups["buffs:bar"].buttons[1]
        .__duration_bar_region:GetCalls("SetStatusBarColor")
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    h.eq(#buffs_backend.container.__groups["buffs:bar"].buttons[1]
        .__duration_bar_region:GetCalls("SetStatusBarColor"), unchanged_color_call_count,
        "unchanged managed bar color does not write again")

    buffs_frame.resizer.__scripts.OnMouseDown()
    buffs_frame:SetWidth(200)
    buffs_frame.resizer.__scripts.OnMouseUp()
    h.eq(M.db.width_combined, 200, "managed frame resize saves the shell width")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__width, 188,
            "managed frame resize reapplies the saved inner width to Buff bars")
    end

    M.db.bar_mode_combined = false
    M.db.width_combined = 180
    M.db.spacing_combined = 2
    M.db.growth_icon_combined = "RIGHT"
    M.db.move_combined = true
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    h.eq(buffs_backend.presentation_mode, "icon", "OOC Bar Mode change activates icon presentation")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, 0,
        "combined Buff bar group is parked after switching")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, M.AURA_FRAME_LIMIT,
        "combined Buff icon group activates after switching")
    h.eq(buffs_backend.move_outline.BOTTOM:IsShown(), true,
        "wrapped combined Buffs use the native-container outline")
    local _, top_relative_to = buffs_backend.move_outline.TOP:GetPoint(2)
    h.eq(top_relative_to, buffs_frame,
        "managed outline width remains connected to the resizable shell")
    local _, _, _, bottom_right_x = buffs_backend.move_outline.BOTTOM:GetPoint(2)
    h.eq(bottom_right_x, 181, "managed bottom outline overlaps the saved shell corner")
    buffs_frame.__scripts.OnSizeChanged(buffs_frame, 240)
    _, _, _, bottom_right_x = buffs_backend.move_outline.BOTTOM:GetPoint(2)
    h.eq(bottom_right_x, 241, "managed bottom outline follows width changes before mouse release")
    local combined_resize_point = buffs_frame.resizer:GetPoint(1)
    h.eq(combined_resize_point, "TOPRIGHT",
        "downward managed growth keeps resize grip on the outlined top edge")
    h.ok(buffs_backend.duration_font,
        "combined Buff managed presentations share an addon-owned duration font")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:icon"].buttons) do
        h.eq(aura_button.__height, 46,
            "combined Buff icon cells reserve a row below the icon for duration text")
        h.ok(aura_button.__duration_text_region,
            "combined Buff icons bind native duration text")
        h.eq(aura_button.__duration_text_region.__points[1][1], "TOP",
            "combined Buff icon duration text anchors below the icon")
        h.eq(aura_button.__duration_text_region:GetFontObject(), buffs_backend.duration_font,
            "combined Buff icon duration text uses the managed duration font")
        h.ok(aura_button.__application_count_region,
            "combined Buff icons bind native stack text")
        h.eq(aura_button.__application_count_region:GetFontObject(), buffs_backend.stack_font,
            "combined Buff icon stack text uses the managed stack font")
        h.eq(aura_button.__application_count_region.__points[1][1], "BOTTOMRIGHT",
            "combined Buff icon stack text remains anchored to the icon")
        h.eq(aura_button.__application_count_region.__points[1][4], -M.ICON_STACK_INSET.right,
            "combined Buff icon stack text uses the shared right inset")
        h.eq(aura_button.__application_count_region.__points[1][5], M.ICON_STACK_INSET.bottom,
            "combined Buff icon stack text uses the shared bottom inset")
    end
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Horizontal,
        "wrapped combined Buff icons retain horizontal growth")
    h.eq(M.get_managed_aura_backend("preset:combined"), buffs_backend,
        "Bar Mode switching reuses the original managed backend")

    M.db.move_combined = false
    M.update_managed_preset_frame(buffs_frame, "show_combined", "move_combined")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_combined_presentation")

--#endregion FILE CONTENTS ===================================================
