-- Shared selectable-font catalog, semantic Blizzard defaults, and dropdown factory.
-- Modules own saved settings; this file owns the available fonts and how a
-- selection is resolved, previewed, and applied.

local addon_name, addon = ...

--#region FONT CATALOG ========================================================

addon.DEFAULT_FONT_KEY = "source_code_pro"

local FONT_DEFINITIONS = {
    {
        key = addon.DEFAULT_FONT_KEY,
        label = "Source Code Pro",
        path = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Regular.ttf",
        bold_path = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Bold.ttf",
        preview_size = 9,
        flags = "",
    },
    {
        key = "game_default",
        label = "Game Default",
    },
}

local FONT_DEFINITIONS_BY_KEY = {}
for _, definition in ipairs(FONT_DEFINITIONS) do
    FONT_DEFINITIONS_BY_KEY[definition.key] = definition
end

-- "Game Default" is semantic: different text roles use different Blizzard fonts.
local GAME_DEFAULT_FONT_OBJECTS = {
    body = "GameFontNormal",
    timer = "GameFontNormalSmall",
    stack = "NumberFontNormal",
}

function addon.GetFontDefinition(key)
    return FONT_DEFINITIONS_BY_KEY[key] or FONT_DEFINITIONS_BY_KEY[addon.DEFAULT_FONT_KEY]
end

function addon.GetGameDefaultFontObject(role)
    local global_name = GAME_DEFAULT_FONT_OBJECTS[role] or GAME_DEFAULT_FONT_OBJECTS.body
    return _G[global_name]
end

function addon.IsFontBoldAvailable(key)
    local definition = addon.GetFontDefinition(key)
    return definition and definition.bold_path ~= nil
end

function addon.GetFontDropdownOptions(role)
    local options = {}
    for _, definition in ipairs(FONT_DEFINITIONS) do
        options[#options + 1] = {
            value = definition.key,
            text = definition.label,
            font_path = definition.path,
            font_size = definition.preview_size,
            font_flags = definition.flags,
            font_object = not definition.path and addon.GetGameDefaultFontObject(role) or nil,
        }
    end
    return options
end

--#endregion FONT CATALOG =====================================================

--#region FONT APPLICATION ===================================================

function addon.ApplySelectedFont(font_target, config)
    if not font_target or not font_target.SetFont then return end
    config = config or {}

    local definition = addon.GetFontDefinition(config.key)
    local flags = definition.flags or ""
    if config.outline and not flags:find("OUTLINE", 1, true) then
        flags = flags == "" and "OUTLINE" or (flags .. ",OUTLINE")
    end

    -- Preserve fractional sizes offered by consumers; FontInstance:SetFont accepts
    -- numeric heights, and a 0.5-step control must not silently become whole steps.
    local size = config.size or definition.preview_size or 11
    if config.min_size and size < config.min_size then size = config.min_size end
    if config.max_size and size > config.max_size then size = config.max_size end

    if definition.path then
        local path = config.bold and definition.bold_path or definition.path
        font_target:SetFont(path or definition.path, size, flags)
        return
    end

    local font_object = addon.GetGameDefaultFontObject(config.role)
    local font_path = font_object and font_object.GetFont and font_object:GetFont()
    if font_path then
        font_target:SetFont(font_path, size, flags)
    elseif STANDARD_TEXT_FONT then
        font_target:SetFont(STANDARD_TEXT_FONT, size, flags)
    else
        font_target:SetFontObject(font_object or GameFontNormal)
    end
end

--#endregion FONT APPLICATION ================================================

--#region FONT DROPDOWN =======================================================

local function apply_option_style(font_string, option)
    if not font_string then return end
    if option.font_path then
        font_string:SetFont(option.font_path, option.font_size or 9, option.font_flags or "")
    elseif option.font_object then
        font_string:SetFontObject(option.font_object)
    else
        font_string:SetFontObject(GameFontNormalSmall)
    end
end

function addon.CreateFontDropdown(name, parent, config)
    config = config or {}
    return addon.CreateDropdown(name, parent, config.label or "Font", addon.GetFontDropdownOptions(config.role), {
        width = config.width or 180,
        get_value = config.get_value,
        on_select = config.on_select,
        apply_button_style = apply_option_style,
        apply_row_style = apply_option_style,
    })
end

--#endregion FONT DROPDOWN ====================================================
