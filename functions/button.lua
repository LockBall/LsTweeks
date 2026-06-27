-- Shared button helpers for text-fit sizing and simple UIPanel buttons.


--#region FILE CONTENTS ======================================================

local _, addon = ...

local DEFAULT_TEXT_PADDING_X = 24
local DEFAULT_BUTTON_HEIGHT = 22

local STANDARD_BUTTON_STYLE = {
    normal_font_object = GameFontNormalSmall,
    highlight_font_object = GameFontHighlightSmall,
    disabled_font_object = GameFontDisableSmall,
}

local function get_measure_string()
    if addon._button_measure_string then
        return addon._button_measure_string
    end

    local frame = CreateFrame("Frame")
    frame:Hide()
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addon._button_measure_string = text
    return text
end

function addon.GetTextFitWidth(text_or_list, padding_x, min_width, max_width, font_object)
    local measure = get_measure_string()
    measure:SetFontObject(font_object or GameFontNormalSmall)

    local text_width = 0
    if type(text_or_list) == "table" then
        for i = 1, #text_or_list do
            measure:SetText(text_or_list[i] or "")
            text_width = math.max(text_width, measure:GetStringWidth() or 0)
        end
    else
        measure:SetText(text_or_list or "")
        text_width = measure:GetStringWidth() or 0
    end

    local width = text_width + (padding_x or DEFAULT_TEXT_PADDING_X)
    if min_width and width < min_width then width = min_width end
    if max_width and width > max_width then width = max_width end
    return width
end

function addon.ApplyStandardButtonStyle(button, opts)
    if not button then return end

    opts = opts or {}
    local normal_font_object = opts.normal_font_object or opts.font_object or STANDARD_BUTTON_STYLE.normal_font_object
    local highlight_font_object = opts.highlight_font_object or STANDARD_BUTTON_STYLE.highlight_font_object
    local disabled_font_object = opts.disabled_font_object or STANDARD_BUTTON_STYLE.disabled_font_object

    if button.SetNormalFontObject then
        button:SetNormalFontObject(normal_font_object)
    end
    if button.SetHighlightFontObject then
        button:SetHighlightFontObject(highlight_font_object)
    end
    if button.SetDisabledFontObject then
        button:SetDisabledFontObject(disabled_font_object)
    end
end

function addon.SizeButtonToText(button, text, opts)
    if not button then return 0 end

    opts = opts or {}
    button:SetText(text or "")
    local width = addon.GetTextFitWidth(
        opts.fit_texts or text,
        opts.padding_x,
        opts.min_width,
        opts.max_width,
        opts.font_object
    )
    button:SetWidth(width)
    return width
end

function addon.CreateTextButton(parent, text, on_click, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent, opts.template or "UIPanelButtonTemplate")
    button:SetHeight(opts.height or DEFAULT_BUTTON_HEIGHT)
    local normal_font_object = opts.font_object or GameFontNormalSmall
    addon.ApplyStandardButtonStyle(button, opts)

    button.SetTextToFit = function(self, value)
        return addon.SizeButtonToText(self, value, {
            fit_texts = opts.fit_texts,
            padding_x = opts.padding_x,
            min_width = opts.min_width,
            max_width = opts.max_width,
            font_object = normal_font_object,
        })
    end

    if opts.fit_to_text == false then
        button:SetText(text or "")
        button:SetWidth(opts.width or addon.GetTextFitWidth(text, opts.padding_x, opts.min_width, opts.max_width, normal_font_object))
    else
        button:SetTextToFit(text)
    end

    if type(on_click) == "function" then
        button:SetScript("OnClick", on_click)
    end

    return button
end

--#endregion FILE CONTENTS ===================================================
