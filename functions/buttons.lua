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

-- Native play art is Blizzard's Options-UI square triangle button; the pause
-- glyph is the stopwatch pause texture tinted to the same gold, the pairing
-- retail AddonProfiler ships.
local PLAY_PAUSE_TEXTURES = {
    play = {
        normal = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
        pushed = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down",
        disabled = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled",
        color = { 1, 1, 1 },
    },
    pause = {
        normal = "Interface\\TimeManager\\PauseButton",
        pushed = "Interface\\TimeManager\\PauseButton",
        disabled = "Interface\\TimeManager\\PauseButton",
        color = { 0.84, 0.81, 0.52 },
    },
}

function addon.CreatePlayPauseButton(parent, on_click, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(opts.width or 32, opts.height or 32)


    local supports_pause = opts.show_pause ~= false

    local function refresh_visuals()
        -- Paused preview offers Play; running preview offers Pause.
        local paused = button._media_paused == true
        local glyph = (supports_pause and not paused) and "pause" or "play"
        local art = PLAY_PAUSE_TEXTURES[glyph]

        button:SetNormalTexture(art.normal)
        button:SetPushedTexture(art.pushed)
        button:SetDisabledTexture(art.disabled)

        local r, g, b = art.color[1], art.color[2], art.color[3]
        local normal = button:GetNormalTexture()
        if normal then normal:SetVertexColor(r, g, b) end
        local pushed = button:GetPushedTexture()
        if pushed then pushed:SetVertexColor(r * 0.8, g * 0.8, b * 0.8) end
        local disabled = button:GetDisabledTexture()
        if disabled then
            disabled:SetVertexColor(r, g, b, 0.4)
            disabled:SetDesaturated(true)
        end

        -- Hover glow: the button art added onto itself. Gold border and glyph
        -- brighten while the dark plate stays dark, so the highlight always
        -- matches the art with no separate overlay asset.
        button:SetHighlightTexture(art.normal, "ADD")
        local highlight = button:GetHighlightTexture()
        if highlight then highlight:SetVertexColor(r, g, b, 0.7) end

        button.current_glyph = glyph
    end

    function button:SetPaused(is_paused)
        self._media_paused = is_paused == true
        refresh_visuals()
    end

    local set_enabled = button.SetEnabled
    function button:SetEnabled(enabled)
        set_enabled(self, enabled)
        self._media_enabled = enabled ~= false
    end

    if type(on_click) == "function" then
        button:SetScript("OnClick", on_click)
    end

    button._media_enabled = true
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
