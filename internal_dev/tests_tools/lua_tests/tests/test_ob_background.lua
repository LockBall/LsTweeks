-- Behavioral tests for Objectives background opacity restore paths.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/objectives")

local M = h.addon.objectives

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
    EditModeManagerFrame = nil
    Enum = nil
end

local function edit_mode_calls()
    return EditModeManagerFrame and EditModeManagerFrame.calls or {}
end

local function install_color_picker_frame()
    ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame", UIParent)
    ColorPickerFrame.Footer = {
        OkayButton = CreateFrame("Button", nil, ColorPickerFrame),
        CancelButton = CreateFrame("Button", nil, ColorPickerFrame),
    }
    ColorPickerFrame.Content = {
        ColorPicker = {
            GetColorHSV = function() return 0, 0 end,
            SetColorHSV = function() end,
        },
    }
    ColorPickerFrame.GetColorRGB = function() return 0.25, 0.25, 0.25 end
    ColorPickerFrame.GetColorAlpha = function() return 0.75 end
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
        if child:GetCalls("SetBackdropBorderColor") then
            return child
        end
    end
    return nil
end

h.test("module disable restores objective opacity through Edit Mode", function()
    reset_runtime()
    fresh_db({ customize_background = false })

    Enum = { EditModeObjectiveTrackerSetting = { Opacity = 99 } }
    ObjectiveTrackerFrame.HasSetting = function(_, setting) return setting == 99 end
    EditModeManagerFrame = {
        calls = {},
        OnSystemSettingChange = function(self, tracker, setting, percent)
            self.calls[#self.calls + 1] = { tracker = tracker, setting = setting, percent = percent }
        end,
    }

    M.apply_background()
    h.eq(ObjectiveTrackerManager:GetOpacity(), 0, "disabled WoW BG applies hidden live opacity")
    h.eq(edit_mode_calls()[1].percent, 0, "disabled WoW BG writes hidden Edit Mode opacity")

    h.addon.set_module_enabled("objectives", false)

    h.eq(ObjectiveTrackerManager:GetOpacity(), 100, "module disable restores full live opacity")
    h.eq(edit_mode_calls()[2].percent, 100, "module disable restores full Edit Mode opacity")
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

h.test("region diagnostics preserve explicit false values", function()
    reset_runtime()
    fresh_db()
    local region = ObjectiveTrackerFrame.NineSlice:CreateTexture(nil, "ARTWORK")
    region.GetBlendMode = function() return false end
    region.IsDesaturated = function() return false end
    region.GetTexture = function() return false end
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

    local border = objective_border_frame()
    h.ok(border, "border frame found")
    local anchor_calls = #(border:GetCalls("SetPoint") or {})
    local show_calls = #(border:GetCalls("Show") or {})
    h.ok(anchor_calls >= 2, "initial border anchors")
    h.ok(show_calls >= 1, "initial border show")

    M.apply_background()
    h.eq(#(border:GetCalls("SetPoint") or {}), anchor_calls, "second apply skips re-anchor")
    h.eq(#(border:GetCalls("Show") or {}), show_calls, "second apply skips repeated show")
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

h.run("ob_background")

--#endregion FILE CONTENTS ===================================================
