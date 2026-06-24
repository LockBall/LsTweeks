-- Custom dropdown widget (NOT UIDropDownMenu): addon.CreateDropdown(name, parent, label, options, cfg).
-- Uses a shared click-blocker frame to close the open popup when the user clicks outside it
-- one blocker instance is reused by all dropdowns on the page.

local addon_name, addon = ...

local _dropdown_blocker = CreateFrame("Frame", nil, UIParent)
_dropdown_blocker:SetAllPoints(UIParent)
_dropdown_blocker:SetFrameStrata("FULLSCREEN")
_dropdown_blocker:SetFrameLevel(98)
_dropdown_blocker:EnableMouse(true)
_dropdown_blocker:Hide()
_dropdown_blocker._active = nil
_dropdown_blocker:SetScript("OnMouseDown", function(self)
    if self._active then self._active:Hide() end
    self._active = nil
    self:Hide()
end)

local function _show_dropdown(popup, btn)
    if _dropdown_blocker._active and _dropdown_blocker._active ~= popup then
        _dropdown_blocker._active:Hide()
    end
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    popup:Show()
    _dropdown_blocker._active = popup
    _dropdown_blocker:Show()
end

local function _hide_dropdown(popup)
    popup:Hide()
    if _dropdown_blocker._active == popup then
        _dropdown_blocker._active = nil
        _dropdown_blocker:Hide()
    end
end

local function create_hover_arrow(container, cfg)
    local arrow = CreateFrame("Frame", nil, container)
    local width = cfg.hover_arrow_width or 7
    local height = cfg.hover_arrow_height or 4
    arrow:SetSize(width, height)
    arrow:SetPoint("TOP", container, "BOTTOM", 0, cfg.hover_arrow_offset_y or -2)
    arrow:Hide()

    for i = 1, height do
        local line = arrow:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.82, 0, 0.95)
        line:SetSize(width - ((i - 1) * 2), 1)
        line:SetPoint("TOP", arrow, "TOP", 0, -(i - 1))
    end

    return arrow
end

-- Shared dropdown constructor used by module UIs.
function addon.CreateDropdown(name, parent, label_text, options, cfg)
    cfg = cfg or {}
    options = options or {}

    local row_h = cfg.row_height or 22
    local selected = (cfg.get_value and cfg.get_value()) or (options[1] and options[1].value)

    local function get_option_text(option)
        if cfg.get_option_text then
            return cfg.get_option_text(option)
        end
        return option.text or tostring(option.value or "")
    end

    local width = cfg.width or 180
    if (cfg.fit_to_text or cfg.fit_width_to_text) and addon.GetTextFitWidth then
        local text_values = { label_text }
        for i, option in ipairs(options) do
            text_values[#text_values + 1] = get_option_text(option)
        end
        width = addon.GetTextFitWidth(
            text_values,
            cfg.text_padding_x,
            cfg.min_width,
            cfg.max_width,
            cfg.font_object
        )
    end

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 22)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", container, "TOP", 0, 2)
    label:SetText(label_text)

    local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    btn:SetAllPoints(container)
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(btn)
    end
    local btn_text = btn:GetFontString()
    local hover_arrow = cfg.show_hover_arrow == false and nil or create_hover_arrow(container, cfg)

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(width, #options * row_h + 4)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(100)
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.96)
    popup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    popup:Hide()

    local function apply_button_style(option)
        if cfg.apply_button_style then
            cfg.apply_button_style(btn_text, option)
            return
        end
        if btn_text then
            btn_text:SetFontObject(GameFontNormalSmall)
        end
    end

    local function set_button_text(value)
        for _, option in ipairs(options) do
            if option.value == value then
                btn:SetText(get_option_text(option))
                apply_button_style(option)
                return
            end
        end

        local fallback = options[1]
        btn:SetText(fallback and get_option_text(fallback) or "")
        if fallback then
            apply_button_style(fallback)
        elseif btn_text then
            btn_text:SetFontObject(GameFontNormalSmall)
        end
    end

    for i, option in ipairs(options) do
        local row = CreateFrame("Button", nil, popup)
        row:SetSize(width - 4, row_h)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 2, -(2 + (i - 1) * row_h))

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)

        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", row, "LEFT", 8, 0)
        txt:SetText(get_option_text(option))
        if cfg.apply_row_style then
            cfg.apply_row_style(txt, option)
        end

        row:SetScript("OnClick", function()
            selected = option.value
            set_button_text(selected)
            _hide_dropdown(popup)
            if cfg.on_select then
                cfg.on_select(selected, option)
            end
        end)
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then
            _hide_dropdown(popup)
        else
            _show_dropdown(popup, btn)
        end
        if hover_arrow then
            hover_arrow:Hide()
        end
    end)

    if hover_arrow then
        btn:HookScript("OnEnter", function()
            if btn:IsEnabled() and not popup:IsShown() then
                hover_arrow:Show()
            end
        end)
        btn:HookScript("OnLeave", function()
            hover_arrow:Hide()
        end)
    end

    container.SetValue = function(_, value)
        selected = value
        set_button_text(selected)
    end

    container.GetValue = function()
        return selected
    end

    container.SetEnabled = function(_, enabled)
        enabled = enabled and true or false
        btn:SetEnabled(enabled)
        container:SetAlpha(enabled and 1 or 0.45)
        if not enabled then
            if hover_arrow then
                hover_arrow:Hide()
            end
            _hide_dropdown(popup)
        end
    end

    set_button_text(selected)
    return container
end
