-- Custom dropdown widgets (NOT UIDropDownMenu): addon.CreateDropdown() and the
-- native-style addon.CreateCyclingDropdown() wrapper with previous/next buttons.
-- A shared click-blocker closes the active popup when the user clicks outside it.


local addon_name, addon = ...

local CreateFrame = CreateFrame
local UIParent = UIParent

--#region DROPDOWN STATE ======================================================

local DROPDOWN_ICON_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local DROPDOWN_ICON_SIZE = 15
local DROPDOWN_ICON_TEX_COORDS = { 0, 0, 1, 0, 0, 1, 1, 1 }
local DROPDOWN_ICON_OFFSET_Y = 0

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

--#endregion DROPDOWN STATE ===================================================

--#region POPUP VISIBILITY ====================================================

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

--#endregion POPUP VISIBILITY =================================================

--#region DROPDOWN ICON =======================================================

local function create_dropdown_icon(container, cfg)
    if cfg.show_dropdown_icon == false then return nil end

    local icon = container:CreateTexture(nil, "OVERLAY")
    local size = cfg.dropdown_icon_size or DROPDOWN_ICON_SIZE
    icon:SetSize(size, size)
    icon:SetPoint("TOP", container, "BOTTOM", cfg.dropdown_icon_offset_x or 0, cfg.dropdown_icon_offset_y or DROPDOWN_ICON_OFFSET_Y)
    icon:SetAlpha(cfg.dropdown_icon_alpha or 0.95)
    icon:Hide()

    local texture_path = cfg.dropdown_icon_texture or DROPDOWN_ICON_TEXTURE
    if texture_path then
        icon:SetTexture(texture_path)
        if cfg.dropdown_icon_tex_coords then
            local tex_coords = cfg.dropdown_icon_tex_coords
            icon:SetTexCoord(tex_coords.left, tex_coords.right, tex_coords.top, tex_coords.bottom)
        else
            icon:SetTexCoord(
                DROPDOWN_ICON_TEX_COORDS[1],
                DROPDOWN_ICON_TEX_COORDS[2],
                DROPDOWN_ICON_TEX_COORDS[3],
                DROPDOWN_ICON_TEX_COORDS[4],
                DROPDOWN_ICON_TEX_COORDS[5],
                DROPDOWN_ICON_TEX_COORDS[6],
                DROPDOWN_ICON_TEX_COORDS[7],
                DROPDOWN_ICON_TEX_COORDS[8]
            )
        end
    end

    return icon
end

--#endregion DROPDOWN ICON ====================================================

--#region DROPDOWN FACTORY ====================================================

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
    if (cfg.fit_to_text or cfg.fit_width_to_text or cfg.fit_to_options) and addon.GetTextFitWidth then
        local text_values = cfg.fit_to_options and {} or { label_text }
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
    local dropdown_icon = create_dropdown_icon(container, cfg)

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

        if cfg.get_unknown_text then
            local unknown_text = cfg.get_unknown_text(value)
            if unknown_text ~= nil then
                btn:SetText(unknown_text)
                if btn_text then
                    btn_text:SetFontObject(GameFontNormalSmall)
                end
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
        if dropdown_icon then
            dropdown_icon:Hide()
        end
    end)

    if dropdown_icon then
        btn:HookScript("OnEnter", function()
            if btn:IsEnabled() and not popup:IsShown() then
                dropdown_icon:Show()
            end
        end)
        btn:HookScript("OnLeave", function()
            dropdown_icon:Hide()
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
            if dropdown_icon then
                dropdown_icon:Hide()
            end
            _hide_dropdown(popup)
        end
    end

    set_button_text(selected)
    container.button = btn
    return container
end

--#endregion DROPDOWN FACTORY =================================================


--#region CYCLING DROPDOWN FACTORY ============================================

function addon.CreateCyclingDropdown(name, parent, label_text, options, cfg)
    cfg = cfg or {}
    options = options or {}

    local arrow_size = cfg.arrow_size or 32
    local arrow_gap = cfg.arrow_gap or 4
    local dropdown_width = cfg.width or 180
    if (cfg.fit_to_text or cfg.fit_width_to_text or cfg.fit_to_options) and addon.GetTextFitWidth then
        local text_values = cfg.fit_to_options and {} or { label_text }
        for i, option in ipairs(options) do
            local option_text = cfg.get_option_text and cfg.get_option_text(option)
                or option.text
                or tostring(option.value or "")
            text_values[#text_values + 1] = option_text
        end
        dropdown_width = addon.GetTextFitWidth(
            text_values,
            cfg.text_padding_x,
            cfg.min_width,
            cfg.max_width,
            cfg.font_object
        )
    end
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(dropdown_width + ((arrow_size + arrow_gap) * 2), math.max(22, arrow_size))

    local dropdown_cfg = {}
    for key, value in pairs(cfg) do
        dropdown_cfg[key] = value
    end
    dropdown_cfg.width = dropdown_width

    local external_on_select = cfg.on_select
    local dropdown
    dropdown_cfg.on_select = function(value, option)
        if external_on_select then
            external_on_select(value, option)
        end
    end

    dropdown = addon.CreateDropdown(name, container, label_text, options, dropdown_cfg)
    dropdown:SetPoint("CENTER", container, "CENTER", 0, 0)

    local function find_selected_index()
        local selected = dropdown:GetValue()
        for index, option in ipairs(options) do
            if option.value == selected then
                return index
            end
        end
        return nil
    end

    local function cycle(step)
        if #options == 0 then return end
        local index = find_selected_index()
        if not index then
            index = step > 0 and 1 or #options
        else
            index = ((index - 1 + step) % #options) + 1
        end
        local option = options[index]
        dropdown:SetValue(option.value)
        if external_on_select then
            external_on_select(option.value, option)
        end
    end

    local previous_button = addon.CreatePageArrowButton(container, "previous", function()
        cycle(-1)
    end, {
        width = arrow_size,
        height = arrow_size,
    })
    previous_button:SetPoint("RIGHT", dropdown, "LEFT", -arrow_gap, 0)

    local next_button = addon.CreatePageArrowButton(container, "next", function()
        cycle(1)
    end, {
        width = arrow_size,
        height = arrow_size,
    })
    next_button:SetPoint("LEFT", dropdown, "RIGHT", arrow_gap, 0)

    container.SetValue = function(_, value)
        dropdown:SetValue(value)
    end
    container.GetValue = function()
        return dropdown:GetValue()
    end
    container.SetEnabled = function(_, enabled)
        enabled = enabled == true
        dropdown:SetEnabled(enabled)
        previous_button:SetEnabled(enabled)
        next_button:SetEnabled(enabled)
    end

    container.dropdown = dropdown
    container.previous_button = previous_button
    container.next_button = next_button
    return container
end

--#endregion CYCLING DROPDOWN FACTORY =========================================
