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

h.run("ob_background")

--#endregion FILE CONTENTS ===================================================
