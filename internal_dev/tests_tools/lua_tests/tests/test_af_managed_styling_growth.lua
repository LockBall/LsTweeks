-- Managed Static / Long Buff typography, timer-row, and growth-mode tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Static / Long Buff styling and growth remain independently configurable", function()
    local M = fixture.boot_managed_presets()
    local buffs_frame = M.frames.show_static_long
    local buffs_backend = buffs_frame._managed_aura_backend
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__duration_text_region:GetCalls("SetTextColor"), nil,
            "Static / Long Buff bar duration text inherits the managed timer font color")
    end
    M.db.bar_mode_static_long = false
    M.db.width_static_long = 180
    M.db.spacing_static_long = 2
    M.db.growth_icon_static_long = "RIGHT"
    M.db.move_static_long = true
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    M.db.timer_static_long = false
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.container.__groups["buffs:icon"].layout.elementHeight, 32,
        "disabling managed icon timer text removes its layout row")
    h.eq(buffs_backend.duration_font:GetLastCall("SetTextColor")[4], 0,
        "disabling managed timer text hides the shared duration font")

    M.db.timer_static_long = true
    M.db.timer_number_font_size_static_long = 14
    M.db.timer_number_font_bold_static_long = true
    M.db.timer_color_static_long = { r = 0.2, g = 0.3, b = 0.4 }
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    local font_call = buffs_backend.duration_font:GetLastCall("SetFont")
    local color_call = buffs_backend.duration_font:GetLastCall("SetTextColor")
    h.eq(font_call[1], h.addon.GetFontDefinition(h.addon.DEFAULT_FONT_KEY).bold_path,
        "managed timer font applies the saved bold face")
    h.eq(font_call[2], 14, "managed timer font applies the saved size")
    h.eq(font_call[3], "OUTLINE", "managed timer font applies the default outline")
    h.eq(color_call[1], 0.2, "managed timer font applies the saved red component")
    h.eq(color_call[2], 0.3, "managed timer font applies the saved green component")
    h.eq(color_call[3], 0.4, "managed timer font applies the saved blue component")
    h.eq(color_call[4], 1, "enabling managed timer text restores its opacity")

    M.db.stack_number_font_size_static_long = 13.5
    M.db.stack_number_font_bold_static_long = true
    M.db.stack_color_static_long = { r = 0.7, g = 0.6, b = 0.5 }
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    local stack_font_call = buffs_backend.stack_font:GetLastCall("SetFont")
    local stack_color_call = buffs_backend.stack_font:GetLastCall("SetTextColor")
    h.eq(stack_font_call[1], h.addon.GetFontDefinition(h.addon.DEFAULT_FONT_KEY).bold_path,
        "managed stack font applies the saved bold face")
    h.eq(stack_font_call[2], 13.5, "managed stack font preserves the saved half-step size")
    h.eq(stack_font_call[3], "OUTLINE", "managed stack font applies the default outline")
    h.eq(stack_color_call[1], 0.7, "managed stack font applies the saved red component")
    h.eq(stack_color_call[2], 0.6, "managed stack font applies the saved green component")
    h.eq(stack_color_call[3], 0.5, "managed stack font applies the saved blue component")

    M.db.timer_number_font_outline_static_long = false
    M.db.stack_number_font_outline_static_long = false
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.duration_font:GetLastCall("SetFont")[3], "",
        "managed timer font removes its outline when disabled")
    h.eq(buffs_backend.stack_font:GetLastCall("SetFont")[3], "",
        "managed stack font removes its outline when disabled")

    M.db.stack_number_font_static_long = "game_default"
    M.db.stack_number_font_outline_static_long = true
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    stack_font_call = buffs_backend.stack_font:GetLastCall("SetFont")
    h.eq(stack_font_call[1], "Fonts\\ARIALN.TTF",
        "managed Game Default stack text uses Blizzard NumberFontNormal's face")
    h.eq(stack_font_call[2], 13.5,
        "managed Game Default stack text preserves the configured size")
    h.eq(stack_font_call[3], "OUTLINE",
        "managed Game Default stack text preserves the configured outline")

    M.db.timer_number_font_static_long = "game_default"
    M.db.timer_number_font_outline_static_long = true
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    font_call = buffs_backend.duration_font:GetLastCall("SetFont")
    h.eq(h.addon.GetGameDefaultFontObject("timer"), GameFontNormalSmall,
        "Timer Game Default maps to Blizzard GameFontNormalSmall")
    h.eq(h.addon.GetGameDefaultFontObject("stack"), NumberFontNormal,
        "Stack Game Default maps to Blizzard NumberFontNormal")
    h.eq(font_call[1], "Fonts\\FRIZQT__.TTF",
        "managed Game Default timer text uses Blizzard GameFontNormalSmall's face")
    h.eq(font_call[2], 14,
        "managed Game Default timer text preserves the configured size")
    h.eq(font_call[3], "OUTLINE",
        "managed Game Default timer text preserves the configured outline")

    local growth_cases = {
        RIGHT = { AnchorUtil.FlowLayoutAxis.Horizontal, "TOPLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down },
        LEFT = { AnchorUtil.FlowLayoutAxis.Horizontal, "TOPRIGHT", AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down },
        DOWN = { AnchorUtil.FlowLayoutAxis.Vertical, "TOPLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down },
        UP = { AnchorUtil.FlowLayoutAxis.Vertical, "BOTTOMLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up },
    }
    for growth, expected in pairs(growth_cases) do
        M.db.growth_icon_static_long = growth
        M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
            "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
        h.eq(buffs_backend.container.__flow_axis, expected[1], growth .. " uses its canonical flow axis")
        h.eq(buffs_backend.container.__flow_anchor, expected[2], growth .. " uses its canonical anchor")
        h.eq(buffs_backend.container.__flow_growth[1], expected[3], growth .. " uses its horizontal direction")
        h.eq(buffs_backend.container.__flow_growth[2], expected[4], growth .. " uses its vertical direction")
    end

    M.db.growth_icon_static_long = "LEFT"
    M.db.growth_bar_static_long = "UP"
    M.db.bar_mode_static_long = false
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.container.__flow_anchor, "TOPRIGHT",
        "Icon Mode restores its remembered LEFT growth")
    h.eq(buffs_backend.frame_background_anchor.__width, M.MIN_FRAME_WIDTH,
        "empty Icon Mode background uses the effective configured frame width")
    h.eq(buffs_backend.frame_background_anchor.__height, 46,
        "empty Icon Mode background uses one icon-and-timer row")
    M.db.bar_mode_static_long = true
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.container.__flow_anchor, "BOTTOMLEFT",
        "Bar Mode restores its independently remembered UP growth")
    h.eq(buffs_backend.frame_background_anchor.__height, 30,
        "empty Bar Mode background returns to one inset bar-row footprint")
    M.db.bar_mode_static_long = false
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.container.__flow_anchor, "TOPRIGHT",
        "returning to Icon Mode does not inherit Bar Mode growth")

    M.db.bar_mode_static_long = true
    M.db.growth_bar_static_long = "LEFT"
    M.update_auras(buffs_frame, "show_static_long", "move_static_long", "timer_static_long",
        "bg_static_long", "scale_static_long", "spacing_static_long", "HELPFUL")
    h.eq(buffs_backend.presentation_mode, "bar", "Static / Long Buffs return to bar presentation")
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "malformed horizontal Bar growth normalizes to vertical flow")
    h.eq(buffs_backend.container.__flow_anchor, "TOPLEFT",
        "malformed horizontal Bar growth falls back to the DOWN anchor")
    h.eq(buffs_backend.container.__flow_growth[2], AnchorUtil.FlowDirection.Down,
        "malformed horizontal Bar growth falls back to DOWN")
    M.db.move_static_long = false
    M.update_managed_preset_frame(buffs_frame, "show_static_long", "move_static_long")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_styling_growth")

--#endregion FILE CONTENTS ===================================================
