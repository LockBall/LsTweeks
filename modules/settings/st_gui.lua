-- General addon settings panel.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

addon.st = addon.st or {}
local M = addon.st

M.controls = M.controls or {}
M.frames = M.frames or {}

local math_max = math.max
local math_ceil = math.ceil

local UI_CONFIG = {
    title_offset_x = 20,
    title_offset_y = -20,
    section_offset_y = -20,
    modules_group_offset_y = -28,
    modules_group_height = 190,
    modules_group_padding_x = 12,
    modules_group_title_offset_y = -8,
    modules_first_checkbox_offset_y = -32,
    modules_checkbox_step_y = -32,
}

local STRINGS = {
    category_name = "Settings",
    title = "Addon Main Interface Settings",
    minimap_icon_label = "Minimap Icon",
    open_on_reload_label = "Open on Reload",
    interface_alpha_label = "Interface Transparency",
    modules_title = "Module Enabler",
    minimap_caption = "(Type |cff00ff00/lst|r to access addon when disabled)",
}

M.CATEGORY_NAME = STRINGS.category_name

function M.build_settings_page(parent)
    local cfg = UI_CONFIG
    local theme = addon.UI_THEME
    local defaults = addon.module_defaults.st

    local title = parent:CreateFontString(nil, "OVERLAY", theme.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.title_offset_x, cfg.title_offset_y)
    title:SetText(STRINGS.title)

    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    Ls_Tweeks_DB.minimap = Ls_Tweeks_DB.minimap or {}

    local checkbox_container = addon.CreateCheckbox(
        parent,
        STRINGS.minimap_icon_label,
        not Ls_Tweeks_DB.minimap.hide,
        function(is_checked)
            addon.toggle_minimap_button(is_checked)
        end
    )
    M.controls.minimap_checkbox = checkbox_container
    checkbox_container:SetPoint("TOPLEFT", title, "BOTTOMLEFT", cfg.title_offset_x, cfg.section_offset_y)

    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("LEFT", checkbox_container, "RIGHT", 25, 0)
    caption:SetText(STRINGS.minimap_caption)
    caption:SetTextColor(0.8, 0.8, 0.8, 1)

    local reload_container = addon.CreateCheckbox(
        parent,
        STRINGS.open_on_reload_label,
        Ls_Tweeks_DB.open_on_reload or defaults.open_on_reload,
        function(is_checked)
            Ls_Tweeks_DB.open_on_reload = is_checked
        end
    )
    M.controls.open_on_reload_checkbox = reload_container
    reload_container:SetPoint("TOPLEFT", checkbox_container, "BOTTOMLEFT", 0, cfg.section_offset_y)

    local alpha_slider = addon.CreateSliderWithBox(
        addon_name .. "AlphaSlider",
        parent,
        STRINGS.interface_alpha_label,
        0.0,
        1,
        0.05,
        Ls_Tweeks_DB,
        "interface_alpha",
        defaults,
        addon.apply_interface_alpha,
        { immediate_callback = true }
    )
    M.controls.alpha_slider = alpha_slider
    alpha_slider:SetPoint("TOPLEFT", reload_container, "BOTTOMLEFT", 0, cfg.section_offset_y)

    local modules_group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local extra_module_rows = math_max(0, #addon.FEATURE_MODULES - 5)
    modules_group:SetSize(1, cfg.modules_group_height + (extra_module_rows * cfg.modules_checkbox_step_y))
    modules_group:SetPoint("TOPLEFT", alpha_slider, "BOTTOMLEFT", 0, cfg.modules_group_offset_y)
    modules_group:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    modules_group:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    modules_group:SetBackdropColor(0, 0, 0, 0)

    local modules_title = modules_group:CreateFontString(nil, "OVERLAY", theme.font_title)
    modules_title:SetPoint("TOP", modules_group, "TOP", 0, cfg.modules_group_title_offset_y)
    modules_title:SetText(STRINGS.modules_title)
    modules_title:SetTextColor(1, 0.82, 0, 1)
    modules_title:SetFontObject("GameFontNormalLarge")

    local widest_content = modules_title:GetStringWidth() or 0
    for index, module_def in ipairs(addon.FEATURE_MODULES) do
        local row_module_def = module_def
        local module_container = addon.CreateCheckbox(
            modules_group,
            row_module_def.label,
            addon.is_module_enabled and addon.is_module_enabled(row_module_def.key),
            function(is_checked)
                if addon.set_module_enabled then
                    addon.set_module_enabled(row_module_def.key, is_checked)
                end
            end
        )
        M.controls["module_" .. row_module_def.key] = module_container
        local offset_y = cfg.modules_first_checkbox_offset_y + ((index - 1) * cfg.modules_checkbox_step_y)
        module_container:SetPoint("TOPLEFT", modules_group, "TOPLEFT", cfg.modules_group_padding_x, offset_y)
        widest_content = math_max(widest_content, module_container:GetWidth() or 0)
    end

    modules_group:SetWidth(math_ceil(widest_content + cfg.modules_group_padding_x * 2))
end

function M.sync_settings_controls()
    if not Ls_Tweeks_DB then return end

    local defaults = addon.module_defaults.st
    local minimap_cb = M.controls.minimap_checkbox
    if minimap_cb and minimap_cb.SetCheckedSilently then
        minimap_cb:SetCheckedSilently(not Ls_Tweeks_DB.minimap.hide)
    end
    local reload_cb = M.controls.open_on_reload_checkbox
    if reload_cb and reload_cb.SetCheckedSilently then
        reload_cb:SetCheckedSilently(Ls_Tweeks_DB.open_on_reload or false)
    end
    local alpha_slider = M.controls.alpha_slider
    if alpha_slider and alpha_slider.SetValueSilently then
        alpha_slider:SetValueSilently(Ls_Tweeks_DB.interface_alpha or defaults.interface_alpha or 0.5)
    end
    for _, module_def in ipairs(addon.FEATURE_MODULES) do
        local module_cb = M.controls["module_" .. module_def.key]
        if module_cb and module_cb.SetCheckedSilently then
            module_cb:SetCheckedSilently(addon.is_module_enabled and addon.is_module_enabled(module_def.key))
        end
    end
end

return M

--#endregion FILE CONTENTS ===================================================
