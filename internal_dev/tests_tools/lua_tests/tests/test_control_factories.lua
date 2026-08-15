-- Tests for shared silent control setters so a widget error cannot mute later callbacks.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local addon = h.addon

addon.UPDATE_INTERVALS = { tenth_sec = 0.1 }
addon.CreateControlPanel = function(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width or 1, height or 1)
    return panel
end

h.load_file("functions/checkbox.lua")
h.load_file("functions/buttons.lua")
h.load_file("functions/slider_with_box.lua")
h.load_file("functions/dropdown.lua")
h.load_file("functions/font_catalog.lua")
h.load_file("functions/growth_direction.lua")

h.test("font catalog shares role-aware selection across modules", function()
    h.eq(addon.GetGameDefaultFontObject("timer"), GameFontNormalSmall,
        "timer role resolves Blizzard's timer font")
    h.eq(addon.GetGameDefaultFontObject("stack"), NumberFontNormal,
        "stack role resolves Blizzard's number font")
    h.ok(addon.IsFontBoldAvailable(addon.DEFAULT_FONT_KEY),
        "bundled default exposes its registered bold face")
    h.ok(not addon.IsFontBoldAvailable("game_default"),
        "semantic Game Default does not claim an unavailable bold face")

    local selected = "game_default"
    local control = addon.CreateFontDropdown("FontFactoryTest", UIParent, {
        role = "stack",
        get_value = function() return selected end,
        on_select = function(value) selected = value end,
    })
    h.eq(control.button:GetFontString():GetFontObject(), NumberFontNormal,
        "shared font dropdown previews the requested semantic role")

    local target = UIParent:CreateFontString(nil, "OVERLAY")
    addon.ApplySelectedFont(target, {
        key = "game_default",
        role = "stack",
        size = 13.5,
        outline = true,
    })
    local font_call = h.stub.FrameMethods.GetLastCall(target, "SetFont")
    h.eq(font_call[1], "Fonts\\ARIALN.TTF", "shared application uses the role's native face")
    h.eq(font_call[2], 13.5, "shared application preserves a requested half-step size")
    h.eq(font_call[3], "OUTLINE", "shared application composes the requested outline")
end)

h.test("growth direction factory shares canonical metadata and control options", function()
    h.eq(addon.GetGrowthDirection("LEFT").anchor, "TOPRIGHT", "LEFT resolves its canonical anchor")
    h.eq(addon.GetGrowthDirection("UP").vertical_direction, "UP", "UP resolves its canonical flow")
    h.eq(addon.GetGrowthDirection("invalid").value, "DOWN", "unknown directions fall back to DOWN")

    local selected = "RIGHT"
    local vertical_only = false
    local control = addon.CreateGrowthDirectionDropdown("GrowthDirectionFactoryTest", UIParent, {
        get_value = function() return selected end,
        on_select = function(value) selected = value end,
        vertical_only = function() return vertical_only end,
    })
    h.eq(control:GetValue(), "RIGHT", "growth dropdown reads the shared selected value")
    h.eq(control:GetVisibleOptionCount(), 4, "normal growth dropdown exposes all four directions")
    vertical_only = true
    control:RefreshOptions()
    h.eq(control:GetVisibleOptionCount(), 2, "vertical-only growth dropdown exposes only DOWN and UP")
end)

h.test("play pause button swaps native texture states", function()
    local button = addon.CreatePlayPauseButton(UIParent, nil)

    h.eq(button.current_glyph, "pause", "running button offers the native pause glyph")
    button:SetPaused(true)
    h.eq(button.current_glyph, "play", "paused button offers the native play triangle")
    button:SetEnabled(false)
    h.ok(not button:IsEnabled(), "media button retains normal disabled behavior")

    local play_only = addon.CreatePlayPauseButton(UIParent, nil, { show_pause = false })
    h.eq(play_only.current_glyph, "play", "play-only button always shows the play triangle")
end)

h.test("test Aura control synchronizes its checkbox and play button", function()
    local checked_value
    local play_clicks = 0
    local control, button = addon.CreateTestAuraControl(
        UIParent,
        false,
        function(checked) checked_value = checked end,
        function() play_clicks = play_clicks + 1 end
    )

    h.ok(not button:IsEnabled(), "unchecked test Aura disables playback")
    control.checkbox:SetChecked(true)
    control.checkbox:Click()
    h.eq(checked_value, true, "checkbox callback receives enabled state")
    h.ok(button:IsEnabled(), "checked test Aura enables playback")

    control:SetState(true, false, true)
    h.eq(button.current_glyph, "pause", "playing state offers Pause")
    button:Click()
    h.eq(play_clicks, 1, "playback callback is forwarded")

    control:SetState(false, true, true)
    h.eq(control:GetChecked(), false, "silent state sync updates checkbox")
    h.ok(not button:IsEnabled(), "state sync disables playback when unchecked")
    h.eq(button.current_glyph, "play", "paused state offers Play")
end)

h.test("cycling dropdown uses page arrows, wraparound, and Custom entry points", function()
    local selected = "custom"
    local options = {
        { value = "red", text = "Red" },
        { value = "green", text = "Green" },
        { value = "grey", text = "Grey" },
    }
    local control = addon.CreateCyclingDropdown("CyclingDropdownTest", UIParent, "Preset", options, {
        get_value = function() return selected end,
        get_unknown_text = function() return "Custom" end,
        on_select = function(value) selected = value end,
    })

    h.eq(control:GetValue(), "custom", "unknown initial value remains Custom")
    h.eq(control.previous_button.direction, "previous", "left button uses previous-page direction")
    h.eq(control.next_button.direction, "next", "right button uses next-page direction")

    control.next_button:Click()
    h.eq(selected, "red", "right from Custom starts at first rainbow color")
    control.previous_button:Click()
    h.eq(selected, "grey", "left wraps from first to last preset")

    control:SetValue("custom")
    control.previous_button:Click()
    h.eq(selected, "grey", "left from Custom starts at last preset")

    control:SetEnabled(false)
    h.ok(not control.dropdown.button:IsEnabled(), "dropdown disables with composite control")
    h.ok(not control.previous_button:IsEnabled(), "previous button disables with composite control")
    h.ok(not control.next_button:IsEnabled(), "next button disables with composite control")
end)

h.test("silent checkbox setter restores callback state after an error", function()
    local callback_calls = 0
    local container, checkbox = addon.CreateCheckbox(UIParent, "Test", false, function()
        callback_calls = callback_calls + 1
    end)
    local original_set_checked = checkbox.SetChecked
    checkbox.SetChecked = function() error("checkbox setter failure") end

    h.ok(not pcall(container.SetCheckedSilently, container, true), "setter error propagates")
    checkbox.SetChecked = original_set_checked
    checkbox:Click()
    h.eq(callback_calls, 1, "later checkbox callback is not muted")
end)

h.test("silent slider setter restores callback state after an error", function()
    local container = addon.CreateSliderWithBox("LsTweaksControlFactoryTest", UIParent, "Test", 0, 10, 1, {}, "value", { value = 0 })
    local slider = container.slider
    local original_set_value = slider.SetValue
    slider.SetValue = function() error("slider setter failure") end

    h.ok(not pcall(container.SetValueSilently, container, 5), "setter error propagates")
    h.is_nil(container._suppress_callback, "slider callback suppression clears after an error")
    slider.SetValue = original_set_value
    container:SetValueSilently(5)
    h.is_nil(container._suppress_callback, "successful silent update leaves no suppression")
end)

h.test("immediate slider callbacks throttle drag updates", function()
    local calls = {}
    local container = addon.CreateSliderWithBox(
        "LsTweaksImmediateControlFactoryTest",
        UIParent,
        "Test",
        0,
        10,
        1,
        {},
        "value",
        { value = 0 },
        function(value) calls[#calls + 1] = value end,
        { immediate_callback = true }
    )

    container.slider.__scripts.OnValueChanged(container.slider, 1)
    h.eq(#calls, 1, "first drag value applies immediately")
    h.eq(calls[1], 1, "first callback receives the first value")
    container.slider.__scripts.OnValueChanged(container.slider, 2)
    h.eq(#calls, 1, "rapid later values wait for the live update interval")
    h.eq(h.stub.ActiveTimerCount(), 1, "rapid updates queue one live timer")
    h.stub.Advance(0.1)
    h.eq(#calls, 2, "latest drag value applies after the live update interval")
    h.eq(calls[2], 2, "throttled callback retains the latest value")
end)

h.test("slider bindings without callbacks do not queue empty timers", function()
    local container = addon.CreateSliderWithBox(
        "LsTweaksCallbackFreeControlFactoryTest",
        UIParent,
        "Test",
        0,
        10,
        1,
        {},
        "value",
        { value = 0 }
    )

    container.slider.__scripts.OnValueChanged(container.slider, 1)
    h.eq(h.stub.ActiveTimerCount(), 0, "callback-free slider writes without an empty debounce timer")
end)

h.run("control_factories")

--#endregion FILE CONTENTS ===================================================
