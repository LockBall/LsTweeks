-- Shared button helpers for text-fit sizing and simple UIPanel buttons.


local _, addon = ...


--#region CONSTANTS ============================================================

local DEFAULT_TEXT_PADDING_X = 24
local DEFAULT_BUTTON_HEIGHT = 22

local STANDARD_BUTTON_STYLE = {
    normal_font_object = GameFontNormalSmall,
    highlight_font_object = GameFontHighlightSmall,
    disabled_font_object = GameFontDisableSmall,
}

--#endregion CONSTANTS =========================================================


--#region TEXT MEASUREMENT =====================================================

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

--#endregion TEXT MEASUREMENT ==================================================


--#region STANDARD STYLE =======================================================

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

--#endregion STANDARD STYLE ====================================================


--#region TEXT BUTTONS =========================================================

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

--#endregion TEXT BUTTONS ======================================================


--#region PLAY / PAUSE BUTTONS ================================================

function addon.CreatePlayPauseButton(parent, on_click, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(opts.width or 32, opts.height or 32)

    -- This is the native square play button used by Blizzard's Options UI.
    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    -- WoW has no matching pause button texture.  Cover the integral play
    -- triangle only while running, keeping the native square button surround.
    local pause_mask = button:CreateTexture(nil, "OVERLAY")
    pause_mask:SetSize(opts.pause_mask_width or 14, opts.pause_mask_height or 14)
    pause_mask:SetTexture("Interface\\Buttons\\WHITE8x8")
    pause_mask:SetVertexColor(0.03, 0.03, 0.03, 0.96)

    local pause_left = button:CreateTexture(nil, "OVERLAY")
    pause_left:SetSize(opts.pause_bar_width or 3, opts.pause_bar_height or 14)
    pause_left:SetTexture("Interface\\Buttons\\WHITE8x8")

    local pause_right = button:CreateTexture(nil, "OVERLAY")
    pause_right:SetSize(opts.pause_bar_width or 3, opts.pause_bar_height or 14)
    pause_right:SetTexture("Interface\\Buttons\\WHITE8x8")

    local supports_pause = opts.show_pause ~= false
    local pressed = false

    local function refresh_visuals()
        local enabled = button._media_enabled ~= false
        local paused = button._media_paused == true
        local icon_alpha = enabled and 1 or 0.4

        pause_mask:SetShown(supports_pause and not paused)
        pause_left:SetShown(supports_pause and not paused)
        pause_right:SetShown(supports_pause and not paused)
        pause_mask:SetAlpha(icon_alpha)
        pause_left:SetVertexColor(1, 0.82, 0, icon_alpha)
        pause_right:SetVertexColor(1, 0.82, 0, icon_alpha)

        pause_mask:ClearAllPoints()
        pause_mask:SetPoint("CENTER", button, "CENTER", pressed and 1 or 0, pressed and -1 or 0)
        pause_left:ClearAllPoints()
        pause_left:SetPoint("CENTER", button, "CENTER", pressed and -4 or -3, pressed and -1 or 0)
        pause_right:ClearAllPoints()
        pause_right:SetPoint("CENTER", button, "CENTER", pressed and 2 or 3, pressed and -1 or 0)
    end

    function button:SetPaused(is_paused)
        self._media_paused = is_paused == true
        refresh_visuals()
    end

    local set_enabled = button.SetEnabled
    function button:SetEnabled(enabled)
        set_enabled(self, enabled)
        self._media_enabled = enabled ~= false
        refresh_visuals()
    end

    button:SetScript("OnLeave", function()
        pressed = false
        refresh_visuals()
    end)
    button:SetScript("OnMouseDown", function()
        pressed = true
        refresh_visuals()
    end)
    button:SetScript("OnMouseUp", function()
        pressed = false
        refresh_visuals()
    end)
    if type(on_click) == "function" then
        button:SetScript("OnClick", on_click)
    end

    button._media_enabled = true
    button.pause_mask = pause_mask
    button.pause_left = pause_left
    button.pause_right = pause_right
    button:SetPaused(opts.paused == true)
    return button
end

--#endregion PLAY / PAUSE BUTTONS =============================================


--#region MOVE RESET BUTTONS ===================================================

function addon.CreateMoveResetButton(parent, anchor_to, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(opts.width or 110, opts.height or DEFAULT_BUTTON_HEIGHT)
    if anchor_to then
        button:SetPoint("TOPLEFT", anchor_to, "BOTTOMLEFT", opts.x or 0, opts.y or -6)
    end
    button:SetText("Move Reset")
    addon.ApplyStandardButtonStyle(button)
    if type(opts.on_click) == "function" then
        button:SetScript("OnClick", opts.on_click)
    end
    return button
end

--#endregion MOVE RESET BUTTONS ===============================================
