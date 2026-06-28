-- Slider widget paired with a numeric text input and a reset button: addon.CreateSliderWithBox(name, parent, label, min, max, step, db, key, defaults, cb, opts).
-- Changes from either the slider or the box are synced to each other and written to the DB; uses addon.UPDATE_INTERVALS.tenth_sec for debounce.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local UPDATE_INTERVALS = addon.UPDATE_INTERVALS

function addon.CreateSliderWithBox(name, parent, label_text, min_v, max_v, step, db_table, db_key, defaults_table, callback, opts)
    opts = opts or {}
    local container = addon.CreateControlPanel(parent, 130, 95)

    local control_gap = 5

    local eb_font_size = 12
    local eb_width = 35
    local eb_height = 12

    local reset_width = 42
    local reset_height = 20

    local slider_width = 120
    local button_size = 24
    local slider_inset = 3
    local step_button_font = "GameFontNormalLarge"
    local step_button_highlight_font = "GameFontHighlightLarge"
    local reset_button_font = "GameFontNormalSmall"
    local reset_button_highlight_font = "GameFontHighlightSmall"

    local function style_slider_button(button, normal_font, highlight_font)
        if not button then return end
        if addon.ApplyStandardButtonStyle then
            addon.ApplyStandardButtonStyle(button, {
                normal_font_object = normal_font,
                highlight_font_object = highlight_font or normal_font,
            })
        else
            button:SetNormalFontObject(normal_font)
            button:SetHighlightFontObject(highlight_font or normal_font)
        end
    end

    local slider = CreateFrame("Slider", name, container, "MinimalSliderTemplate")
    slider:SetSize(slider_width, 16)
    slider:SetPoint("CENTER", container, "CENTER", 0, -control_gap/2)
    slider:SetMinMaxValues(min_v, max_v)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue((db_table and db_table[db_key]) or min_v)

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", container, "TOP", 0, -control_gap)
    title:SetText(label_text)

    -- Min/Max labels
    local min_lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    min_lbl:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", slider_inset, control_gap)
    local function format_display_value(v)
        if opts.display_decimals then
            return format("%." .. opts.display_decimals .. "f", v)
        end
        if step >= 1 then
            return tostring(math.floor(v + 0.5))
        end
        if step >= 0.1 then
            return format("%.1f", v)
        end
        return format("%.2f", v)
    end

    min_lbl:SetText(format_display_value(min_v))

    local max_lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    max_lbl:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", -slider_inset, control_gap)
    max_lbl:SetText(format_display_value(max_v))

    -- Edit box
    local eb = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    eb:SetSize(eb_width, eb_height)
    eb:SetPoint("TOP", title, "BOTTOM", 0, -1.5*control_gap)
    eb:SetAutoFocus(false)
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(-4, 0, 0, 0)
    local font, _, flags = eb:GetFont()
    eb:SetFont(font, eb_font_size, flags)

    -- Minus and plus buttons under the slider, left and right
    local minus_btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    minus_btn:SetSize(button_size, button_size)
    minus_btn:SetText("-")
    style_slider_button(minus_btn, step_button_font, step_button_highlight_font)
    minus_btn:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", slider_inset, -control_gap)

    local plus_btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    plus_btn:SetSize(button_size, button_size)
    plus_btn:SetText("+")
    style_slider_button(plus_btn, step_button_font, step_button_highlight_font)
    plus_btn:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -slider_inset, -control_gap)

    local reset = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    reset:SetSize(reset_width, reset_height)
    reset:SetPoint("TOP", slider, "BOTTOM", 0, -control_gap)
    reset:SetText("Reset")
    style_slider_button(reset, reset_button_font, reset_button_highlight_font)


    eb:SetText(format_display_value((db_table and db_table[db_key]) or min_v))


    local function run_callback(value)
        if type(callback) == "function" then
            callback(value)
        end
    end

    local debounce_timer = nil
    local function debounced_callback(value)
        if debounce_timer then debounce_timer:Cancel() end
        debounce_timer = C_Timer.NewTimer(UPDATE_INTERVALS.tenth_sec, function()
            debounce_timer = nil
            run_callback(value)
        end)
    end

    container:SetScript("OnHide", function()
        if debounce_timer then debounce_timer:Cancel(); debounce_timer = nil end
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        if db_table then
            db_table[db_key] = value
        end
        eb:SetText(format_display_value(value))
        if not container._suppress_callback then
            debounced_callback(value)
        end
    end)

    eb:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(min_v, math.min(max_v, val))
            slider:SetValue(val)
        end
        self:ClearFocus()
    end)

    minus_btn:SetScript("OnClick", function()
        local v = slider:GetValue() - step
        slider:SetValue(math.max(min_v, v))
    end)

    plus_btn:SetScript("OnClick", function()
        local v = slider:GetValue() + step
        slider:SetValue(math.min(max_v, v))
    end)

    reset:SetScript("OnClick", function()
        local default_value = nil
        if defaults_table then
            -- Accept both table.key and table["key"] for Lua flexibility
            default_value = defaults_table[db_key]
        end
        if default_value == nil then
            default_value = min_v
        end
        if db_table then
            db_table[db_key] = default_value
        end
        eb:SetText(format_display_value(default_value))
        if slider:GetValue() ~= default_value then
            slider:SetValue(default_value)
        else
            run_callback(default_value)
        end
    end)

    if opts.tooltip then
        title:EnableMouse(true)
        addon.AttachTooltip(title, nil, opts.tooltip)
    end

    -- Expose inner slider so callers can call SetValue to update the display.
    container.slider = slider
    container.SetEnabled = function(_, enabled)
        enabled = enabled and true or false
        slider:SetEnabled(enabled)
        eb:SetEnabled(enabled)
        minus_btn:SetEnabled(enabled)
        plus_btn:SetEnabled(enabled)
        reset:SetEnabled(enabled)
        container:SetAlpha(enabled and 1 or 0.45)
    end

    return container
end

--#endregion FILE CONTENTS ===================================================
