-- Managed learned Static / Long Buff presentation, background, resize, and mode-switch tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Static / Long Buff presentation preserves native groups and OOC reconfiguration", function()
    local M = fixture.boot_managed_presets()
    local buffs_frame = M.frames.show_static_long
    local buffs_backend = buffs_frame._managed_aura_backend
    h.ok(buffs_backend, "Static / Long Buffs frame owns a managed backend")
    h.ok(buffs_backend.frame_background, "Static / Long Buff backend owns its frame background")
    h.ok(buffs_backend.frame_background.texture:IsShown(), "enabled Static / Long Frame BG is visible")
    local static_long_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(static_long_bg_color[1], 0.4, "Static / Long Frame BG applies saved red")
    h.eq(static_long_bg_color[4], 0.1, "Static / Long Frame BG applies saved alpha")
    M.db.bg_static_long = false
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    h.eq(buffs_backend.frame_background.texture:IsShown(), false,
        "disabling Static / Long Frame BG hides the managed background")
    local static_long_bar_buttons = buffs_backend.container.__groups["buffs:bar"].buttons
    h.eq(buffs_backend.frame_background_rows[static_long_bar_buttons[2]].background.texture:IsShown(), false,
        "disabling Static / Long Frame BG hides native row extensions")

    local color_sync = h.addon.all_the_colors
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_bg_static_long = true
    M.db.shared_frame_background_color = { r = 0.6, g = 0.5, b = 0.4, a = 0.3 }
    color_sync.get_db().global_enabled = false
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    h.ok(buffs_backend.frame_background.texture:IsShown(),
        "Shared BG Colors can show a managed background when local Frame BG is off")
    static_long_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(static_long_bg_color[1], 0.6, "managed Frame BG receives the Aura shared color")

    color_sync.get_db().global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    color_sync.get_db().global_color = { r = 0.9, g = 0.8, b = 0.7, a = 0.6 }
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    static_long_bg_color = buffs_backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(static_long_bg_color[1], 0.9, "All the Colors globally overrides managed Frame BG")
    h.eq(static_long_bg_color[4], 0.6, "managed Frame BG receives global override alpha")

    color_sync.get_db().global_enabled = false
    M.db.shared_background_color_enabled = false
    M.db.bg_static_long = true
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    h.eq(buffs_backend.container.__groups["buffs:bar"].filter_string, "HELPFUL",
        "Static / Long Buff groups request helpful Auras")
    for _, group_key in ipairs({ "buffs:bar", "buffs:icon" }) do
        local group = buffs_backend.container.__groups[group_key]
        local included = group.options.candidateFilters.includeSpellIDs
        h.eq(included[9001], true, "learned permanent Aura is included natively")
        h.eq(included[9002], true, "learned Long Aura is included natively")
        h.eq(included[9003], nil, "learned Short Aura is absent from native inclusion")
        h.eq(group.buttons[1].__cancel_aura_buttons, "RightButtonUp",
            "Static / Long AuraButtons use native right-click cancellation")
    end
    h.ok(buffs_frame.move_handle.body:find("2 learned", 1, true),
        "mover tooltip reports the learned inclusion count")

    M.db.learned_helpful_durations[9004] = 900
    M.note_learned_buff_cache_replaced()
    for _, group_key in ipairs({ "buffs:bar", "buffs:icon" }) do
        local included = buffs_backend.container.__groups[group_key].options.candidateFilters.includeSpellIDs
        h.eq(included[9004], true, "learned cache changes refresh both native presentation groups")
    end
    h.eq(buffs_backend.container.__groups["buffs:bar"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "Static / Long Buff bar pool uses the fixed Aura limit")
    h.eq(buffs_backend.container.__groups["buffs:icon"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "Static / Long Buff icon pool uses the fixed Aura limit")
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "bar-mode Static / Long Buffs use vertical flow")
    h.eq(buffs_frame.icons, nil, "Static / Long Buffs frame creates no addon icon pool")
    h.eq(buffs_frame.__events.UNIT_AURA, nil, "Static / Long Buffs frame does not register UNIT_AURA")
    h.ok(buffs_frame:IsShown(), "runtime startup shows enabled Static / Long Buffs")
    h.eq(buffs_frame:GetAlpha(), 0.25,
        "Static / Long Buff shell applies its saved out-of-combat alpha")
    h.eq(buffs_backend.container:GetAlpha(), 0.25,
        "Static / Long Buff container applies its saved out-of-combat alpha")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__width, 128, "Static / Long Buff bars use the saved inner frame width")
        h.eq(aura_button.__height, 18, "Static / Long Buff bars use the shared native row height")
        h.eq(#(aura_button:GetCalls("SetIcon") or {}), 1,
            "Static / Long Buffs AuraButtons bind their native icon")
        h.ok(aura_button.__spell_name_region, "Static / Long Buff bars bind native spell text")
        h.ok(aura_button.__duration_text_region, "Static / Long Buff bars bind native duration text")
        h.ok(aura_button.__application_count_region, "Static / Long Buff bars bind native stack text")
        h.ok(aura_button.__duration_bar_region, "Static / Long Buff bars bind a native duration bar")
        h.eq(aura_button.__hide_tooltip_in_combat, false,
            "Static / Long Buffs AuraButtons allow native tooltips in combat")
    end
    h.eq(buffs_backend.presentation_mode, "bar", "saved Bar Mode activates the Static / Long Buff bar group")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, M.AURA_FRAME_LIMIT,
        "Static / Long Buff bar group is active")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, 0,
        "Static / Long Buff icon group is parked")

    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        aura_button.CanBeAccessedInContext = function() return true end
    end
    M.db.color_static_long = { r = 0.15, g = 0.25, b = 0.35, a = 0.45 }
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        local color_call = aura_button.__duration_bar_region:GetLastCall("SetStatusBarColor")
        h.eq(color_call[1], 0.15, "managed Buff bar applies an OOC red color change")
        h.eq(color_call[2], 0.25, "managed Buff bar applies an OOC green color change")
        h.eq(color_call[3], 0.35, "managed Buff bar applies an OOC blue color change")
        h.eq(color_call[4], 0.45, "managed Buff bar applies an OOC alpha change")
    end
    local unchanged_color_call_count = #buffs_backend.container.__groups["buffs:bar"].buttons[1]
        .__duration_bar_region:GetCalls("SetStatusBarColor")
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(#buffs_backend.container.__groups["buffs:bar"].buttons[1]
        .__duration_bar_region:GetCalls("SetStatusBarColor"), unchanged_color_call_count,
        "unchanged managed bar color does not write again")

    buffs_frame.resizer.__scripts.OnMouseDown()
    buffs_frame:SetWidth(200)
    buffs_frame.resizer.__scripts.OnMouseUp()
    h.eq(M.db.width_static_long, 200, "managed frame resize saves the shell width")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__width, 188,
            "managed frame resize reapplies the saved inner width to Buff bars")
    end

    M.db.bar_mode_static_long = false
    M.db.width_static_long = 180
    M.db.spacing_static_long = 2
    M.db.growth_icon_static_long = "RIGHT"
    M.db.move_static_long = true
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.presentation_mode, "icon", "OOC Bar Mode change activates icon presentation")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, 0,
        "Static / Long Buff bar group is parked after switching")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, M.AURA_FRAME_LIMIT,
        "Static / Long Buff icon group activates after switching")
    h.eq(buffs_backend.move_outline.BOTTOM:IsShown(), true,
        "wrapped Static / Long Buffs use the native-container outline")
    local _, top_relative_to = buffs_backend.move_outline.TOP:GetPoint(2)
    h.eq(top_relative_to, buffs_frame,
        "managed outline width remains connected to the resizable shell")
    local _, _, _, bottom_right_x = buffs_backend.move_outline.BOTTOM:GetPoint(2)
    h.eq(bottom_right_x, 181, "managed bottom outline overlaps the saved shell corner")
    buffs_frame.__scripts.OnSizeChanged(buffs_frame, 240)
    _, _, _, bottom_right_x = buffs_backend.move_outline.BOTTOM:GetPoint(2)
    h.eq(bottom_right_x, 241, "managed bottom outline follows width changes before mouse release")
    local static_long_resize_point = buffs_frame.resizer:GetPoint(1)
    h.eq(static_long_resize_point, "TOPRIGHT",
        "downward managed growth keeps resize grip on the outlined top edge")
    h.ok(buffs_backend.duration_font,
        "Static / Long Buff managed presentations share an addon-owned duration font")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:icon"].buttons) do
        h.eq(aura_button.__height, 46,
            "Static / Long Buff icon cells reserve a row below the icon for duration text")
        h.ok(aura_button.__duration_text_region,
            "Static / Long Buff icons bind native duration text")
        h.eq(aura_button.__duration_text_region.__points[1][1], "TOP",
            "Static / Long Buff icon duration text anchors below the icon")
        h.eq(aura_button.__duration_text_region:GetFontObject(), buffs_backend.duration_font,
            "Static / Long Buff icon duration text uses the managed duration font")
        h.ok(aura_button.__application_count_region,
            "Static / Long Buff icons bind native stack text")
        h.eq(aura_button.__application_count_region:GetFontObject(), buffs_backend.stack_font,
            "Static / Long Buff icon stack text uses the managed stack font")
        h.eq(aura_button.__application_count_region.__points[1][1], "BOTTOMRIGHT",
            "Static / Long Buff icon stack text remains anchored to the icon")
        h.eq(aura_button.__application_count_region.__points[1][4], -M.ICON_STACK_INSET.right,
            "Static / Long Buff icon stack text uses the shared right inset")
        h.eq(aura_button.__application_count_region.__points[1][5], M.ICON_STACK_INSET.bottom,
            "Static / Long Buff icon stack text uses the shared bottom inset")
    end
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Horizontal,
        "wrapped Static / Long Buff icons retain horizontal growth")
    h.eq(M.get_managed_aura_backend("preset:static_long"), buffs_backend,
        "Bar Mode switching reuses the original managed backend")
    M.db.move_static_long = false
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_static_long_presentation")

--#endregion FILE CONTENTS ===================================================
