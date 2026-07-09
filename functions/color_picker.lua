-- Color picker widget that wraps the system ColorPickerFrame with an integrated reset button.
-- addon.CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb) returns a 95x45 container;
-- the reset button restores the default color from the defaults table.
-- The callback reason is one of open/reset/swatch/alpha/cancel.


local addon_name, addon = ...

--#region COLOR PICKER CONSTANTS =============================================

local control_gap = 5
local CONTAINER_W  = 95
local CONTAINER_H  = 45
local BTN_SIZE     = 18
local RESET_W      = 45
local RESET_H      = 16
local GROUP_W      = BTN_SIZE + control_gap + RESET_W
local POPUP_ALPHA_BOX_W = 40
local POPUP_ALPHA_BOX_H = 16
local POPUP_BUTTON_W = 64
local POPUP_BUTTON_GAP = 8
local AUTO_VISIBLE_DEFAULT = 0.75
local PREVIEW_DEBOUNCE = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.tenth_sec or 0.1

--#endregion COLOR PICKER CONSTANTS ===========================================

--#region COLOR VALUE HELPERS =================================================

local function format_alpha_percent(a)
    if a == nil then a = 1 end
    return tostring(math.floor((a * 100) + 0.5))
end

local function color_alpha_or_default(a, default)
    if a == nil then return default end
    return a
end

--#endregion COLOR VALUE HELPERS ==============================================

--#region POPUP FRAME HELPERS =================================================

local function resize_popup_action_buttons()
    local footer = ColorPickerFrame and ColorPickerFrame["Footer"]
    local okay = (footer and footer["OkayButton"])
        or (ColorPickerFrame and ColorPickerFrame["OkayButton"])
        or _G["ColorPickerOkayButton"]
    local cancel = (footer and footer["CancelButton"])
        or (ColorPickerFrame and ColorPickerFrame["CancelButton"])
        or _G["ColorPickerCancelButton"]

    local candidates = { okay, cancel }

    for _, button in ipairs(candidates) do
        if button and button.SetWidth then
            button:SetWidth(POPUP_BUTTON_W)
        end
    end

    if okay and cancel and okay.ClearAllPoints and cancel.ClearAllPoints then
        okay:ClearAllPoints()
        cancel:ClearAllPoints()
        okay:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOM", -(POPUP_BUTTON_GAP / 2), 16)
        cancel:SetPoint("LEFT", okay, "RIGHT", POPUP_BUTTON_GAP, 0)
    end
end

local function find_color_picker_hex_box()
    local function valid_edit_box(candidate)
        if candidate and candidate.GetObjectType and candidate:GetObjectType() == "EditBox" then
            return candidate
        end
        return nil
    end

    local content = ColorPickerFrame and ColorPickerFrame["Content"]
    return valid_edit_box(ColorPickerFrame and ColorPickerFrame["HexBox"])
        or valid_edit_box(content and content["HexBox"])
        or valid_edit_box(content and content["HexBoxEditBox"])
        or valid_edit_box(_G["ColorPickerFrameHexBox"])
end

local get_color_picker_alpha_slider

local function set_color_picker_alpha(alpha)
    local set_frame_alpha = ColorPickerFrame and ColorPickerFrame["SetColorAlpha"]
    if set_frame_alpha then
        set_frame_alpha(ColorPickerFrame, alpha)
        return
    end

    local content = ColorPickerFrame and ColorPickerFrame["Content"]
    local picker = content and content["ColorPicker"]
    local set_picker_alpha = picker and picker["SetColorAlpha"]
    if set_picker_alpha then
        set_picker_alpha(picker, alpha)
        return
    end

    local opacity_slider = get_color_picker_alpha_slider()
    if opacity_slider and opacity_slider.SetValue then
        opacity_slider:SetValue(alpha)
    end
end

get_color_picker_alpha_slider = function()
    local content = ColorPickerFrame and ColorPickerFrame["Content"]
    return ColorPickerFrame["OpacitySlider"]
        or (content and content["OpacitySlider"])
        or _G["ColorPickerFrameOpacitySlider"]
end

local function get_color_picker_widget()
    local content = ColorPickerFrame and ColorPickerFrame["Content"]
    return content and content["ColorPicker"]
end

local function ensure_live_picker_hooks()
    local picker = get_color_picker_widget()
    if picker and picker.HookScript and not picker._lstweeks_live_color_hooked then
        picker:HookScript("OnColorSelect", function()
            local handler = ColorPickerFrame and ColorPickerFrame._lstweeks_live_swatch_func
            if handler then
                handler()
            end
        end)
        picker._lstweeks_live_color_hooked = true
    end

    local opacity_slider = get_color_picker_alpha_slider()
    if opacity_slider and opacity_slider.HookScript and not opacity_slider._lstweeks_live_alpha_hooked then
        opacity_slider:HookScript("OnValueChanged", function()
            local handler = ColorPickerFrame and ColorPickerFrame._lstweeks_live_opacity_func
            if handler then
                handler()
            end
        end)
        opacity_slider._lstweeks_live_alpha_hooked = true
    end
end

local function set_color_picker_value_midpoint()
    local picker = get_color_picker_widget()
    if picker and picker.GetColorHSV and picker.SetColorHSV then
        local h, s = picker:GetColorHSV()
        picker:SetColorHSV(h or 0, s or 0, AUTO_VISIBLE_DEFAULT)
        return true
    end

    return false
end

--#endregion POPUP FRAME HELPERS ==============================================

--#region POPUP ALPHA INPUT ===================================================

local function ensure_popup_alpha_percent()
    if ColorPickerFrame._lstweeks_alpha_percent then
        return ColorPickerFrame._lstweeks_alpha_percent
    end

    local frame = CreateFrame("Frame", nil, ColorPickerFrame)
    frame:SetSize(90, 20)
    frame:SetFrameLevel((ColorPickerFrame:GetFrameLevel() or 1) + 10)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetText("Alpha %")

    local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    box:SetSize(POPUP_ALPHA_BOX_W, POPUP_ALPHA_BOX_H)
    box:SetPoint("LEFT", label, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(-3, 0, 0, 0)

    frame.box = box
    ColorPickerFrame._lstweeks_alpha_percent = frame
    return frame
end

local function place_popup_alpha_percent(frame)
    local hex_box = find_color_picker_hex_box()
    frame:ClearAllPoints()
    if hex_box then
        frame:SetPoint("TOPRIGHT", hex_box, "BOTTOMRIGHT", 0, -6)
    else
        frame:SetPoint("BOTTOM", ColorPickerFrame, "BOTTOM", 0, 72)
    end
end

local function hide_popup_alpha_percent()
    local frame = ColorPickerFrame and ColorPickerFrame._lstweeks_alpha_percent
    if frame then
        frame:Hide()
    end
end

local function set_popup_alpha_percent_text(alpha)
    local frame = ColorPickerFrame and ColorPickerFrame._lstweeks_alpha_percent
    if frame and frame.box then
        frame.box:SetText(format_alpha_percent(alpha))
    end
end

local function show_popup_alpha_percent(get_current, set_alpha)
    local frame = ensure_popup_alpha_percent()
    local box = frame.box

    place_popup_alpha_percent(frame)
    box:SetText(format_alpha_percent(get_current()))

    local function commit_alpha()
        local value = tonumber(box:GetText())
        if not value then
            box:SetText(format_alpha_percent(get_current()))
            box:ClearFocus()
            return
        end

        local alpha = math.max(0, math.min(100, value)) / 100
        set_color_picker_alpha(alpha)
        set_alpha(alpha)
        box:SetText(format_alpha_percent(alpha))
        box:ClearFocus()
    end

    box:SetScript("OnEnterPressed", commit_alpha)
    box:SetScript("OnEditFocusLost", commit_alpha)
    frame:Show()
end

--#endregion POPUP ALPHA INPUT ================================================

--#region COLOR PICKER FACTORY ===============================================

function addon.CreateColorPicker(parent, db_table, db_key, has_alpha, label_text, defaults_table, callback)
    local container = addon.CreateControlPanel(parent, CONTAINER_W, CONTAINER_H)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", container, "TOP", 0, -control_gap)
    label:SetJustifyH("CENTER")
    label:SetText(label_text)

    -- Group centers button + reset as a unit below the label
    local group = CreateFrame("Frame", nil, container)
    group:SetSize(GROUP_W, BTN_SIZE)
    group:SetPoint("TOP", label, "BOTTOM", 0, -control_gap)

    -- Color Picker Button
    local button = CreateFrame("Button", nil, group, "BackdropTemplate")
    button:SetSize(BTN_SIZE, BTN_SIZE)
    button:SetPoint("LEFT", group, "LEFT", 0, 0)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameColorSwatch",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8
    })

    -- Reset Button
    local reset = CreateFrame("Button", nil, group, "UIPanelButtonTemplate")
    reset:SetSize(RESET_W, RESET_H)
    reset:SetText("Reset")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(reset)
    end
    reset:SetPoint("LEFT", button, "RIGHT", control_gap, 0)

    local preview_timer = nil
    local preview_reason = nil
    local function cancel_preview_timer()
        if preview_timer then
            preview_timer:Cancel()
            preview_timer = nil
        end
    end
    local function run_callback(reason)
        if type(callback) == "function" then callback(reason) end
    end
    local function queue_callback(reason)
        preview_reason = reason
        if preview_timer then return end
        if C_Timer and C_Timer.NewTimer then
            preview_timer = C_Timer.NewTimer(PREVIEW_DEBOUNCE, function()
                local queued_reason = preview_reason
                preview_timer = nil
                preview_reason = nil
                run_callback(queued_reason)
            end)
        else
            run_callback(reason)
        end
    end

    -- Local update helper
    local function apply_and_refresh(r, g, b, a, reason, immediate)
        button:SetBackdropColor(r, g, b, color_alpha_or_default(a, 1))
        if immediate then
            cancel_preview_timer()
            run_callback(reason)
        else
            queue_callback(reason)
        end
    end

    -- Setup Initial Color
    local c = db_table[db_key]
    if c then
        button:SetBackdropColor(c.r, c.g, c.b, color_alpha_or_default(c.a, 1))
    end

    -- Reset Logic with Type Check
    reset:SetScript("OnClick", function()
        -- Defensive check to ensure defaults_table is actually a table
        if type(defaults_table) ~= "table" then
            print("|cFFFF0000LsTweaks Error:|r Invalid defaults table in ColorPicker.")
            return
        end

        local dc = defaults_table[db_key]
        if dc then
            db_table[db_key] = has_alpha and {r=dc.r, g=dc.g, b=dc.b, a=dc.a} or {r=dc.r, g=dc.g, b=dc.b}
            apply_and_refresh(dc.r, dc.g, dc.b, dc.a, "reset", true)
        end
    end)

    -- Color Picker Dialog
    button:SetScript("OnClick", function()
        local current = db_table[db_key]
        if type(callback) == "function" then callback("open") end
        local auto_visible_from_transparent = has_alpha and current and (current.a or 0) == 0
        local auto_visible_done = false
        local auto_visible_applying = false
        local auto_visible_ready = false
        local function update_alpha(alpha, immediate)
            local r, g, b = ColorPickerFrame:GetColorRGB()
            db_table[db_key] = { r = r, g = g, b = b, a = alpha }
            apply_and_refresh(r, g, b, alpha, "alpha", immediate)
        end
        local function update_swatch()
            if auto_visible_applying then return end

            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = has_alpha and ColorPickerFrame:GetColorAlpha() or 1

            if auto_visible_from_transparent and auto_visible_ready and not auto_visible_done and not auto_visible_applying then
                auto_visible_done = true
                auto_visible_applying = true
                set_color_picker_alpha(AUTO_VISIBLE_DEFAULT)
                set_color_picker_value_midpoint()
                set_popup_alpha_percent_text(AUTO_VISIBLE_DEFAULT)
                r, g, b = ColorPickerFrame:GetColorRGB()
                a = AUTO_VISIBLE_DEFAULT
                auto_visible_applying = false
            end

            db_table[db_key] = has_alpha and {r=r, g=g, b=b, a=a} or {r=r, g=g, b=b}
            apply_and_refresh(r, g, b, a, "swatch", false)
            if has_alpha and ColorPickerFrame._lstweeks_alpha_percent and ColorPickerFrame._lstweeks_alpha_percent:IsShown() then
                ColorPickerFrame._lstweeks_alpha_percent.box:SetText(format_alpha_percent(a))
            end
        end
        local function update_opacity()
            local alpha = ColorPickerFrame:GetColorAlpha()
            update_alpha(alpha, false)
            set_popup_alpha_percent_text(alpha)
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = current.r, g = current.g, b = current.b,
            hasOpacity = has_alpha,
            opacity = color_alpha_or_default(current.a, 1),
            swatchFunc = update_swatch,
            opacityFunc = has_alpha and update_opacity or nil,
            cancelFunc = function()
                db_table[db_key] = current
                apply_and_refresh(current.r, current.g, current.b, current.a, "cancel", true)
                hide_popup_alpha_percent()
            end
        })
        ColorPickerFrame._lstweeks_live_swatch_func = update_swatch
        ColorPickerFrame._lstweeks_live_opacity_func = has_alpha and update_opacity or nil
        ensure_live_picker_hooks()
        resize_popup_action_buttons()
        if has_alpha then
            show_popup_alpha_percent(function()
                return color_alpha_or_default(db_table[db_key].a, 1)
            end, function(alpha)
                update_alpha(alpha, true)
            end)
        else
            hide_popup_alpha_percent()
        end
        C_Timer.After(0, function()
            auto_visible_ready = true
        end)
    end)

    container.SetValue = function(_, color)
        if color then
            button:SetBackdropColor(color.r or 1, color.g or 1, color.b or 1, color_alpha_or_default(color.a, 1))
        end
    end

    container.GetValue = function()
        return db_table[db_key]
    end

    container.SetEnabled = function(_, enabled)
        button:SetEnabled(enabled)
        reset:SetEnabled(enabled)
        button:SetAlpha(enabled and 1 or 0.45)
        reset:SetAlpha(enabled and 1 or 0.65)
        if label.SetFontObject then
            label:SetFontObject(enabled and GameFontNormalSmall or GameFontDisableSmall)
        end
    end

    return container
end

--#endregion COLOR PICKER FACTORY =============================================
