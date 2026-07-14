-- Behavioral tests for Objectives background opacity restore paths.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/objectives")

local M = h.addon.objectives
local edit_mode_test_calls = {}

local function frame_calls(frame, method)
    return frame:GetCalls(method) or {}
end

local function fresh_db(overrides)
    local db = {
        customize_background = false,
        background_color_enabled = false,
        background_alpha = 0.5,
        background_color = { r = 0.25, g = 0.25, b = 0.25, a = 0.75 },
    }
    for k, v in pairs(overrides or {}) do db[k] = v end
    Ls_Tweeks_DB = { objectives = db, modules = { objectives = true } }
    return db
end

local function reset_runtime()
    h.stub.in_combat = false
    ObjectiveTrackerFrame.NineSlice.__calls = {}
    ObjectiveTrackerManager.__calls = {}
    ObjectiveTrackerManager.__opacity = 100
    ObjectiveTrackerFrame.HasSetting = nil
    ObjectiveTrackerFrame.UpdateSystemSettingValue = nil
    ObjectiveTrackerFrame.__system_setting_calls = nil
    EditModeManagerFrame = nil
    edit_mode_test_calls = {}
    Enum = nil
end

local function edit_mode_calls()
    return edit_mode_test_calls
end

local function install_color_picker_frame()
    ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame", UIParent)
    ColorPickerFrame.Footer = {
        OkayButton = CreateFrame("Button", nil, ColorPickerFrame),
        CancelButton = CreateFrame("Button", nil, ColorPickerFrame),
    }
    local color_picker = CreateFrame("Frame", nil, ColorPickerFrame)
    color_picker.GetColorHSV = function() return 0, 0 end
    color_picker.SetColorHSV = function() end
    local opacity_slider = CreateFrame("Slider", nil, ColorPickerFrame)
    ColorPickerFrame.Content = {
        ColorPicker = color_picker,
        OpacitySlider = opacity_slider,
    }
    ColorPickerFrame.__r = 0.25
    ColorPickerFrame.__g = 0.25
    ColorPickerFrame.__b = 0.25
    ColorPickerFrame.__alpha = 0.75
    ColorPickerFrame.GetColorRGB = function() return ColorPickerFrame.__r, ColorPickerFrame.__g, ColorPickerFrame.__b end
    ColorPickerFrame.GetColorAlpha = function() return ColorPickerFrame.__alpha end
    ColorPickerFrame.SetColorAlpha = function(_, alpha) ColorPickerFrame.__alpha = alpha end
    ColorPickerFrame.SetupColorPickerAndShow = function(_, opts)
        ColorPickerFrame.__opts = opts
    end
end

local function background_picker_buttons()
    local picker = M.controls.background_color_picker
    local color_button, reset_button
    local function visit(frame)
        if not frame then return end
        if frame.__kind == "Button" then
            if frame:GetText() == "Reset" then
                reset_button = frame
            else
                color_button = color_button or frame
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            visit(child)
        end
    end
    visit(picker)
    return color_button, reset_button
end

local function objective_border_frame()
    for _, child in ipairs({ ObjectiveTrackerFrame:GetChildren() }) do
        if #frame_calls(child, "SetBackdropBorderColor") > 0 then
            return child
        end
    end
    return nil
end

h.test("disabled border does not create an unused frame", function()
    reset_runtime()
    fresh_db()

    M.apply_background()

    h.is_nil(objective_border_frame(), "disabled border does not create a frame")
    Ls_Tweeks_DB.objectives.customize_background = true
    M.apply_background()
    h.advance(h.addon.UPDATE_INTERVALS.next_frame)
end)

h.test("module disable restores objective opacity through Edit Mode", function()
    reset_runtime()
    fresh_db({ customize_background = false })

    Enum = { EditModeObjectiveTrackerSetting = { Opacity = 99 } }
    ObjectiveTrackerFrame.HasSetting = function(_, setting) return setting == 99 end
    EditModeManagerFrame = {
        OnSystemSettingChange = function(_self, tracker, setting, percent)
            edit_mode_test_calls[#edit_mode_test_calls + 1] = { tracker = tracker, setting = setting, percent = percent }
            ObjectiveTrackerManager.__opacity = percent
        end,
    }

    M.apply_background()
    h.eq(ObjectiveTrackerManager:GetOpacity(), 0, "disabled WoW BG applies hidden live opacity")
    h.eq(edit_mode_calls()[1].percent, 0, "disabled WoW BG writes hidden Edit Mode opacity")

    h.addon.set_module_enabled("objectives", false)

    h.eq(ObjectiveTrackerManager:GetOpacity(), 100, "module disable restores full live opacity")
    h.eq(edit_mode_calls()[2].percent, 100, "module disable restores full Edit Mode opacity")
    h.eq(#(ObjectiveTrackerManager:GetCalls("SetOpacity") or {}), 0, "Edit Mode path skips duplicate manager writes")
end)

h.test("queued background sync rejects a disabled module before combat deferral", function()
    reset_runtime()
    fresh_db({ customize_background = true })

    M.apply_background()
    ObjectiveTrackerFrame:Update()
    h.addon.set_module_enabled("objectives", false)
    h.stub.in_combat = true
    h.advance(h.addon.UPDATE_INTERVALS.next_frame)

    local fields = M.get_background_status()
    h.ok(tContains(fields, "bg_state=module_disabled"), "queued sync skips combat defer after module disable")

    h.stub.in_combat = false
    h.addon.set_module_enabled("objectives", true)
end)

h.test("system setting opacity fallback skips duplicate manager write", function()
    reset_runtime()
    fresh_db({ customize_background = false })

    Enum = { EditModeObjectiveTrackerSetting = { Opacity = 99 } }
    ObjectiveTrackerFrame.HasSetting = function(_, setting) return setting == 99 end
    ObjectiveTrackerFrame.UpdateSystemSettingValue = function(self, setting, percent)
        self.__system_setting_calls = self.__system_setting_calls or {}
        self.__system_setting_calls[#self.__system_setting_calls + 1] = { setting = setting, percent = percent }
        ObjectiveTrackerManager.__opacity = percent
    end

    M.apply_background()

    h.eq(ObjectiveTrackerManager:GetOpacity(), 0, "system setting path applies live opacity")
    h.eq(ObjectiveTrackerFrame.__system_setting_calls[1].percent, 0, "system setting path writes opacity")
    h.eq(#(ObjectiveTrackerManager:GetCalls("SetOpacity") or {}), 0, "system setting path skips duplicate manager write")
end)

h.test("accepted color reset does not let later cancel clear border", function()
    reset_runtime()
    local db = fresh_db({ background_color_enabled = true, objective_tracker_border = nil })
    install_color_picker_frame()

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildBackgroundSettings(parent)
    local color_button, reset_button = background_picker_buttons()

    reset_button:Click()
    h.eq(db.objective_tracker_border, true, "reset auto-enables border")

    color_button:Click()
    h.ok(ColorPickerFrame.__opts and ColorPickerFrame.__opts.cancelFunc, "picker opened")
    ColorPickerFrame.__opts.cancelFunc()

    h.eq(db.objective_tracker_border, true, "later cancel keeps accepted reset border")
end)

h.test("color picker clears live callbacks after its session closes", function()
    reset_runtime()
    local db = fresh_db({ background_color_enabled = true })
    install_color_picker_frame()

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildBackgroundSettings(parent)
    local color_button = background_picker_buttons()

    color_button:Click()
    h.ok(ColorPickerFrame._lstweeks_live_swatch_func, "open session installs swatch callback")
    ColorPickerFrame.__opts.cancelFunc()
    h.is_nil(ColorPickerFrame._lstweeks_live_swatch_func, "cancel clears swatch callback")
    h.is_nil(ColorPickerFrame._lstweeks_live_opacity_func, "cancel clears opacity callback")

    ColorPickerFrame.__r = 0.8
    local on_color_select = ColorPickerFrame.Content.ColorPicker:GetScript("OnColorSelect")
    on_color_select()
    h.eq(db.background_color.r, 0.25, "closed session ignores later color events")

    color_button:Click()
    ColorPickerFrame:Show()
    ColorPickerFrame:Hide()
    h.is_nil(ColorPickerFrame._lstweeks_live_swatch_func, "hide clears accepted-session callback")
end)

h.test("background color picker live preview is debounced", function()
    reset_runtime()
    local db = fresh_db({ background_color_enabled = true })
    install_color_picker_frame()

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildBackgroundSettings(parent)
    local color_button = background_picker_buttons()

    color_button:Click()
    h.ok(ColorPickerFrame.__opts and ColorPickerFrame.__opts.swatchFunc, "picker opened")
    local overlay = ObjectiveTrackerFrame.NineSlice._lstweeks_center_color_overlay
    h.ok(overlay, "overlay created on open")
    local vertex_calls = #(overlay:GetCalls("SetVertexColor") or {})

    ColorPickerFrame.__r = 0.8
    ColorPickerFrame.__g = 0.4
    ColorPickerFrame.__b = 0.2
    ColorPickerFrame.__alpha = 0.6
    ColorPickerFrame.Content.ColorPicker:GetScript("OnColorSelect")()

    h.eq(db.background_color.r, 0.8, "swatch writes DB immediately")
    h.eq(#(overlay:GetCalls("SetVertexColor") or {}), vertex_calls, "swatch defers runtime preview")

    h.advance(h.addon.UPDATE_INTERVALS.tenth_sec)

    local calls = overlay:GetCalls("SetVertexColor") or {}
    h.eq(#calls, vertex_calls + 1, "debounced swatch applies one runtime preview")
    h.eq(calls[#calls][1], 0.8, "preview red applied")
    h.eq(calls[#calls][2], 0.4, "preview green applied")
    h.eq(calls[#calls][3], 0.2, "preview blue applied")
    h.eq(calls[#calls][4], 0.6, "preview alpha applied")

    ColorPickerFrame.__alpha = 0.35
    ColorPickerFrame.Content.OpacitySlider:GetScript("OnValueChanged")()
    ColorPickerFrame.__alpha = 0.45
    ColorPickerFrame.Content.OpacitySlider:GetScript("OnValueChanged")()
    h.eq(#(overlay:GetCalls("SetVertexColor") or {}), vertex_calls + 1, "alpha changes coalesce before debounce")

    h.advance(h.addon.UPDATE_INTERVALS.tenth_sec)

    calls = overlay:GetCalls("SetVertexColor") or {}
    h.eq(#calls, vertex_calls + 2, "debounced alpha applies one runtime preview")
    h.eq(calls[#calls][4], 0.45, "latest alpha applied")
end)

h.test("region diagnostics preserve explicit false values", function()
    reset_runtime()
    fresh_db()
    local region = ObjectiveTrackerFrame.NineSlice:CreateTexture(nil, "ARTWORK")
    region.GetBlendMode = function() return false end
    region.IsDesaturated = function() return false end
    region:SetTexture(false)
    region.GetAtlas = function() return false end

    local fields = M.get_background_status()
    h.ok(tContains(fields, "bg_region_1_blend=false"), "false blend status")
    h.ok(tContains(fields, "bg_region_1_desaturated=false"), "false desaturated status")
    h.ok(tContains(fields, "bg_region_1_texture=false"), "false texture status")
    h.ok(tContains(fields, "bg_region_1_atlas=false"), "false atlas status")
end)

h.test("border sync skips redundant anchoring and visibility calls", function()
    reset_runtime()
    fresh_db({ objective_tracker_border = true })

    M.apply_background()
    local border_shown = tContains(M.get_background_status(), "objective_border_shown=true")
    h.ok(border_shown, "border shown after apply")

    local border = assert(objective_border_frame(), "border frame found")
    local anchor_calls = #frame_calls(border, "SetPoint")
    local show_calls = #frame_calls(border, "Show")
    h.ok(anchor_calls >= 2, "initial border anchors")
    h.ok(show_calls >= 1, "initial border show")

    M.apply_background()
    h.eq(#frame_calls(border, "SetPoint"), anchor_calls, "second apply skips re-anchor")
    h.eq(#frame_calls(border, "Show"), show_calls, "second apply skips repeated show")
end)

h.test("background color sync skips unchanged overlay writes", function()
    reset_runtime()
    fresh_db({
        background_color_enabled = true,
        background_color = { r = 0.31, g = 0.41, b = 0.51, a = 0.61 },
    })

    M.apply_background()
    local overlay = ObjectiveTrackerFrame.NineSlice._lstweeks_center_color_overlay
    h.ok(overlay, "color overlay created")
    h.ok(
        tContains(M.get_background_status(), "bg_color_signature=0.31:0.41:0.51:0.61:bg_alpha=0:color_alpha=0.61:overlay=true"),
        "status keeps the background color signature"
    )

    local vertex_calls = #(overlay:GetCalls("SetVertexColor") or {})
    local show_calls = #(overlay:GetCalls("Show") or {})

    M.apply_background()

    h.eq(#(overlay:GetCalls("SetVertexColor") or {}), vertex_calls, "second apply skips overlay color write")
    h.eq(#(overlay:GetCalls("Show") or {}), show_calls, "second apply skips overlay show")
end)

h.test("background color overlay renders behind Blizzard line art", function()
    reset_runtime()
    fresh_db({ background_color_enabled = true })
    ObjectiveTrackerFrame:SetFrameLevel(2)
    ObjectiveTrackerFrame.NineSlice:SetFrameLevel(4)
    ObjectiveTrackerFrame.NineSlice.Center = ObjectiveTrackerFrame.NineSlice:CreateTexture(nil, "ARTWORK")

    M.apply_background()

    local overlay_frame = ObjectiveTrackerFrame.NineSlice._lstweeks_center_color_overlay_frame
    local overlay = ObjectiveTrackerFrame.NineSlice._lstweeks_center_color_overlay
    h.ok(overlay_frame, "overlay frame created")
    h.ok(overlay, "overlay texture created")
    h.eq(overlay_frame:GetParent(), ObjectiveTrackerFrame, "overlay frame stays independent of NineSlice alpha")
    h.ok(
        overlay_frame:GetFrameLevel() < ObjectiveTrackerFrame.NineSlice:GetFrameLevel(),
        "overlay frame is behind Blizzard line art"
    )
    h.eq(ObjectiveTrackerFrame.NineSlice.Center:GetAlpha(), 0, "Blizzard center fill lets custom color show through")

    Ls_Tweeks_DB.objectives.background_color_enabled = false
    M.apply_background()

    h.eq(ObjectiveTrackerFrame.NineSlice.Center:GetAlpha(), 1, "Blizzard center fill restores when custom color is disabled")
end)

h.test("priority background anchors force-expand without scratch state", function()
    reset_runtime()
    fresh_db()
    ObjectiveTrackerFrame.__collapsed = true
    ObjectiveTrackerFrame.ForceExpand = function(self)
        self.__collapsed = false
        self.__calls.ForceExpand = self.__calls.ForceExpand or {}
        table.insert(self.__calls.ForceExpand, {})
    end

    local priority_module = CreateFrame("Frame", "PriorityObjectiveModule", ObjectiveTrackerFrame)
    priority_module.hasDisplayPriority = true
    local priority_child = CreateFrame("Frame", "PriorityObjectiveChild", priority_module)
    ObjectiveTrackerFrame.modules = { priority_module }

    M.apply_background()
    ObjectiveTrackerFrame.NineSlice:SetPoint("BOTTOM", priority_child, "BOTTOM")

    local fields = M.get_background_status()
    h.ok(tContains(fields, "bg_force_expand=background:PriorityObjectiveModule"), "priority force-expand status")
    h.eq(#(ObjectiveTrackerFrame:GetCalls("ForceExpand") or {}), 1, "force expand called")
end)

h.test("background collapse followups coalesce", function()
    reset_runtime()
    fresh_db()
    h.advance(h.addon.UPDATE_INTERVALS.fifth_sec)
    h.stub.timers = {}

    ObjectiveTrackerFrame:SetCollapsed(true)
    ObjectiveTrackerFrame:SetCollapsed(false)
    ObjectiveTrackerFrame:SetCollapsed(true)

    h.eq(h.stub.ActiveTimerCount(), 2, "collapse burst queues one sync and one followup")
    h.advance(h.addon.UPDATE_INTERVALS.fifth_sec)
    h.eq(h.stub.ActiveTimerCount(), 0, "coalesced collapse timers complete")

    ObjectiveTrackerFrame.__collapsed = false
end)

h.run("ob_background")

--#endregion FILE CONTENTS ===================================================
