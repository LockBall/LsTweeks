-- Managed Debuff presentation, movement, lifecycle, and native-binding tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Debuff presentation uses native HARMFUL groups and safe shell behavior", function()
    local M = fixture.boot_managed_presets()
    local frame = M.frames.show_debuff
    local backend = frame._managed_aura_backend

    h.ok(backend, "Debuff frame owns a managed backend")
    h.ok(backend.frame_background, "managed Debuff backend owns its frame background")
    h.ok(backend.frame_background.texture:IsShown(), "enabled Debuff Frame BG is visible")
    h.eq(backend.frame_background_anchor.__width, M.MIN_FRAME_WIDTH,
        "empty Debuff background uses the effective configured frame width")
    h.eq(backend.frame_background_anchor.__height, 30,
        "empty Debuff background uses one inset bar-row footprint")
    h.eq(backend.frame_background_anchor:GetPoint(1), "BOTTOMLEFT",
        "empty Debuff background follows upward growth anchoring")
    local debuff_bg_color = backend.frame_background.texture:GetLastCall("SetColorTexture")
    h.eq(debuff_bg_color[1], 0.1, "managed Debuff Frame BG applies saved red")
    h.eq(debuff_bg_color[2], 0.2, "managed Debuff Frame BG applies saved green")
    h.eq(debuff_bg_color[3], 0.3, "managed Debuff Frame BG applies saved blue")
    h.eq(debuff_bg_color[4], 0.4, "managed Debuff Frame BG applies saved alpha")
    h.eq(backend.container.__groups["debuffs:bar"].filter_string, "HARMFUL", "Debuff groups use HARMFUL")
    h.eq(backend.container.__groups["debuffs:bar"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "Debuff bar pool uses the fixed Aura limit")
    h.eq(backend.container.__groups["debuffs:icon"].options.maxFrameCount, M.AURA_FRAME_LIMIT,
        "Debuff icon pool uses the fixed Aura limit")
    h.eq(backend.container.__width, 1, "managed container retains its auto-layout seed width")
    h.eq(backend.container.__height, 1, "managed container retains its auto-layout seed height")
    h.eq(backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "bar-mode Debuffs lay out vertically")
    h.eq(backend.container.__flow_anchor, "BOTTOMLEFT", "upward Debuff flow starts at the bottom corner")
    h.eq(backend.container.__flow_growth[1], AnchorUtil.FlowDirection.Right,
        "additional Debuff columns grow right")
    h.eq(backend.container.__flow_growth[2], AnchorUtil.FlowDirection.Up,
        "Debuff rows grow up")
    h.eq(backend.container.__flow_line_size, M.AURA_FRAME_LIMIT * 19,
        "Debuff flow reserves one vertical line for every allowed row")
    h.eq(backend.container.__groups["debuffs:bar"].layout.elementSpacing, 1,
        "Debuff bar group receives explicit element spacing")
    h.eq(frame.icons, nil, "managed Debuff frame creates no legacy icon pool")
    h.ok(frame:GetScript("OnEvent"), "managed Debuff shell owns its combat-state handler")
    h.eq(frame.__events.UNIT_AURA, nil, "managed Debuff frame does not register UNIT_AURA")
    h.eq(frame.__events.PLAYER_REGEN_DISABLED, true, "managed Debuff shell watches combat entry")
    h.eq(frame.__events.PLAYER_REGEN_ENABLED, true, "managed Debuff shell watches combat exit")

    for _, aura_button in ipairs(backend.container.__groups["debuffs:bar"].buttons) do
        h.eq(aura_button.__width, 108, "managed Debuff bar uses the saved inner frame width")
        h.eq(aura_button.__height, 18, "managed Debuff bar uses the legacy row height")
        h.eq(#(aura_button:GetCalls("SetIcon") or {}), 1, "managed Debuff AuraButton binds one native icon")
        h.ok(aura_button.__spell_name_region, "managed Debuff AuraButton binds native spell text")
        h.ok(aura_button.__duration_text_region, "managed Debuff AuraButton binds native duration text")
        h.ok(aura_button.__application_count_region, "managed Debuff AuraButton binds native stack text")
        h.ok(aura_button.__duration_bar_region, "managed Debuff AuraButton binds a native duration bar")
        h.eq(aura_button.__mouse_motion_enabled, true, "managed Debuff AuraButton enables native hover")
        h.eq(aura_button.__hide_tooltip_in_combat, false,
            "managed Debuff AuraButton allows its native tooltip in combat")
    end
    local debuff_bar_buttons = backend.container.__groups["debuffs:bar"].buttons
    h.eq(backend.frame_background_rows[debuff_bar_buttons[1]].background.texture:IsShown(), false,
        "fixed empty row replaces the first native row background without overlap")
    h.ok(backend.frame_background_rows[debuff_bar_buttons[2]].background.texture:IsShown(),
        "later native rows extend the frame background")

    h.ok(frame:IsShown(), "runtime startup shows the enabled managed Debuff shell")
    h.eq(frame.move_handle:IsShown(), false, "move controls follow saved off state")
    M.db.move_debuff = true
    M.update_managed_preset_frame(frame, "show_debuff", "move_debuff")
    h.eq(frame.move_handle:IsShown(), true, "managed Move Mode shows its mover border")
    h.eq(backend.container.__flow_padding[3], 0,
        "managed Move Mode does not alter native AuraContainer layout")
    h.eq(frame.move_handle:GetParent(), frame,
        "addon mover remains parented to its safe shell, never the managed AuraContainer")
    local resize_point, resize_relative_to = frame.resizer:GetPoint(1)
    h.eq(resize_point, "BOTTOMRIGHT", "upward managed growth keeps resize grip on its anchored edge")
    h.eq(resize_relative_to, frame, "managed resize grip overlays the shell border corner")
    h.eq(frame.resizer:IsMouseEnabled(), true, "managed resize grip accepts mouse input")
    h.eq(#frame.resizer.grip_marks, 3, "resize grip uses three explicit overlay marks")
    local grip_color = frame.resizer.grip_marks[1]:GetLastCall("SetColorTexture")
    h.eq(grip_color[1], M.MOVE_BORDER_COLOR.r, "resize grip uses the mover border red")
    h.eq(grip_color[2], M.MOVE_BORDER_COLOR.g, "resize grip uses the mover border green")
    h.eq(grip_color[3], M.MOVE_BORDER_COLOR.b, "resize grip uses the mover border blue")
    h.eq(grip_color[4], M.MOVE_BORDER_COLOR.a, "resize grip uses the mover border alpha")
    local grip_background = frame.resizer:GetLastCall("SetBackdropColor")
    h.eq(grip_background[1], 0.03, "resize grip uses a dark contrast background")
    h.eq(grip_background[4], 0.95, "resize grip contrast background remains visible")
    h.eq(frame.move_handle.hit_areas[2]:IsShown(), true,
        "upward managed growth keeps one compact bottom drag edge")
    local _, _, _, _, bottom_mover_y = frame.move_handle.hit_areas[2]:GetPoint(1)
    h.eq(bottom_mover_y, -4, "managed drag strip extends across the visible bottom border")
    h.eq(frame.move_handle.hit_areas[2]:GetHeight(), 12,
        "managed drag strip provides a practical grab target")
    for _, index in ipairs({ 1, 3, 4 }) do
        h.eq(frame.move_handle.hit_areas[index]:IsShown(), false,
            "managed mover hides shell edges that cannot follow secret content height")
    end
    h.eq(backend.move_outline.TOP:IsShown(), true,
        "managed Move Mode shows the native-container outline")
    local _, outline_relative_to = backend.move_outline.TOP:GetPoint(1)
    h.eq(outline_relative_to, backend.container,
        "managed outline follows native container geometry without reading it")
    M.db.move_debuff = false
    M.update_managed_preset_frame(frame, "show_debuff", "move_debuff")
    h.eq(backend.move_outline.TOP:IsShown(), false,
        "leaving managed Move Mode hides the native-container outline")
    h.eq(frame:GetAlpha(), 0.35, "managed Debuff shell applies its saved out-of-combat alpha")
    h.eq(backend.container:GetAlpha(), 0.35,
        "managed Debuff container applies its saved out-of-combat alpha")
    h.fire_event("PLAYER_REGEN_DISABLED")
    h.eq(frame:GetAlpha(), 1, "combat-entry event makes the managed Debuff shell fully visible")
    h.eq(backend.container:GetAlpha(), 1,
        "combat-entry event makes the managed Debuff container fully visible")
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.eq(frame:GetAlpha(), 0.35, "combat-exit event restores the managed Debuff shell OOC alpha")
    h.eq(backend.container:GetAlpha(), 0.35,
        "combat-exit event restores the managed Debuff container OOC alpha")

    local long_frame = M.frames.show_long
    h.eq(long_frame._managed_aura_backend, nil, "legacy Long remains separate from the Static / Long managed capability")
    h.ok(long_frame.icons, "Long retains its existing frame implementation")
    h.eq(long_frame.__events.UNIT_AURA, true, "Long retains its existing event route while disabled")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_debuff_presentation")

--#endregion FILE CONTENTS ===================================================
