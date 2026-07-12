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
h.load_file("functions/slider_with_box.lua")

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

h.test("immediate slider callbacks do not queue drag updates", function()
    local calls = 0
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
        function() calls = calls + 1 end,
        { immediate_callback = true }
    )

    container.slider.__scripts.OnValueChanged(container.slider, 1)
    h.eq(calls, 1, "first drag value applies immediately")
    container.slider.__scripts.OnValueChanged(container.slider, 2)
    h.eq(calls, 2, "later drag value does not wait for debounce")
    h.eq(h.stub.ActiveTimerCount(), 0, "immediate drag updates do not queue timers")
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
