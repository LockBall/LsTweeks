-- Shared transactional Text Options launcher and singleton popup.
-- Callers provide dynamic bindings; this file owns popup lifecycle and controls.

local addon_name, addon = ...

--#region POPUP LAYOUT CONSTANTS ==============================================

local POPUP_WIDTH = 300
local POPUP_HEIGHT = 300
local POPUP_NOTICE_HEIGHT = 18
local POPUP_INSET = 16
local POPUP_TITLE_Y = 14
local POPUP_CONTENT_Y = 42
local POPUP_COLUMN_GAP = 20
local POPUP_COLOR_COLUMN_WIDTH = 120
local POPUP_FONT_WIDTH = 140
local POPUP_CONTROL_GAP = 12
local POPUP_FIRST_CHECKBOX_GAP = 10
local POPUP_CHECKBOX_GAP = 4
local POPUP_FONT_SIZE_MIN = 6
local POPUP_FONT_SIZE_MAX = 18
local POPUP_FONT_SIZE_STEP = 0.5
local LAUNCHER_FONT_SIZE = 10
local POPUP_FOOTER_BUTTON_WIDTH = 80
local POPUP_FOOTER_BUTTON_GAP = 8
local POPUP_FOOTER_Y = 14
local POPUP_FOOTER_GROUP_WIDTH = (POPUP_FOOTER_BUTTON_WIDTH * 3) + (POPUP_FOOTER_BUTTON_GAP * 2)
local POPUP_FOOTER_X = (POPUP_WIDTH - POPUP_FOOTER_GROUP_WIDTH) / 2

--#endregion POPUP LAYOUT CONSTANTS ===========================================

--#region BINDING HELPERS ======================================================

local function read(binding)
    return binding and binding.get and binding.get()
end

local function write(binding, value)
    if binding and binding.set then binding.set(value) end
end

local function read_default(binding)
    return binding and binding.get_default and binding.get_default()
end

local function copy_color(value)
    if type(value) ~= "table" then return value end
    return { r = value.r, g = value.g, b = value.b, a = value.a }
end

local function snapshot_config(config)
    local snapshot = {}
    for _, key in ipairs({ "color", "font", "size", "bold", "outline" }) do
        snapshot[key] = key == "color" and copy_color(read(config[key])) or read(config[key])
    end
    return snapshot
end

local function apply_values(config, values)
    for _, key in ipairs({ "color", "font", "size", "bold", "outline" }) do
        if config[key] then
            write(config[key], key == "color" and copy_color(values[key]) or values[key])
        end
    end
end

--#endregion BINDING HELPERS ===================================================

--#region SINGLETON POPUP ======================================================

local popup
local launcher_serial = 0

local function set_launcher_open(launcher, is_open)
    if launcher and launcher.SetButtonState then
        launcher:SetButtonState(is_open and "PUSHED" or "NORMAL", is_open == true)
    end
end

local function request_preview()
    if popup and popup.active and popup.active.config.on_preview then
        popup.active.config.on_preview()
    end
    if popup and popup.active then
        popup.active:Refresh()
        if popup.active.config.font then
            popup.font:SetValue(read(popup.active.config.font))
        end
    end
end

local function close_popup(commit)
    if not (popup and popup.active) then return end
    local launcher = popup.active
    popup.active = nil
    set_launcher_open(launcher, false)
    if not commit then
        apply_values(launcher.config, popup.snapshot or {})
        if launcher.config.on_preview then launcher.config.on_preview() end
    end
    popup.snapshot = nil
    popup:Hide()
    launcher:Refresh()
end

local function ensure_popup()
    if popup then return popup end

    popup = addon.CreatePopupFrame(addon_name .. "FontOptionsPopup", UIParent, {
        width = POPUP_WIDTH,
        height = POPUP_HEIGHT,
        strata = "DIALOG",
        clamped = true,
    })
    popup:Hide()

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOP", popup, "TOP", 0, -POPUP_TITLE_Y)
    popup.title:SetJustifyH("CENTER")

    popup.notice = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.notice:SetPoint("TOP", popup.title, "BOTTOM", 0, -5)
    popup.notice:SetWidth(POPUP_WIDTH - (POPUP_INSET * 2))
    popup.notice:SetJustifyH("CENTER")
    popup.notice:SetTextColor(1, 0, 0, 1)

    local color_proxy, color_defaults = {}, {}
    setmetatable(color_proxy, {
        __index = function(_, key)
            if key ~= "value" or not popup.active then return nil end
            return read(popup.active.config.color)
        end,
        __newindex = function(_, key, value)
            if key == "value" and popup.active then write(popup.active.config.color, copy_color(value)) end
        end,
    })
    setmetatable(color_defaults, {
        __index = function(_, key)
            if key ~= "value" or not popup.active then return nil end
            return read_default(popup.active.config.color)
        end,
    })
    popup.color = addon.CreateColorPicker(popup, color_proxy, "value", false, "Text Color", color_defaults,
        request_preview)
    popup.color:SetPoint("TOP", popup, "TOPLEFT", POPUP_COLOR_COLUMN_WIDTH / 2, -POPUP_CONTENT_Y)

    popup.font = addon.CreateFontDropdown(addon_name .. "FontOptionsFamily", popup, {
        label = "Font",
        get_role = function()
            return popup.active and popup.active.config.role or "body"
        end,
        get_text_color = function()
            return popup.active and read(popup.active.config.color) or nil
        end,
        width = POPUP_FONT_WIDTH,
        get_value = function()
            return popup.active and read(popup.active.config.font) or addon.DEFAULT_FONT_KEY
        end,
        on_select = function(value)
            if popup.active then write(popup.active.config.font, value) end
            popup:RefreshControls()
            request_preview()
        end,
    })

    local size_proxy, size_defaults = {}, {}
    setmetatable(size_proxy, {
        __index = function(_, key)
            return key == "value" and popup.active and read(popup.active.config.size) or nil
        end,
        __newindex = function(_, key, value)
            if key == "value" and popup.active then write(popup.active.config.size, value) end
        end,
    })
    setmetatable(size_defaults, {
        __index = function(_, key)
            return key == "value" and popup.active and read_default(popup.active.config.size) or nil
        end,
    })
    popup.size = addon.CreateSliderWithBox(
        addon_name .. "FontOptionsSize", popup, "Font Size",
        POPUP_FONT_SIZE_MIN, POPUP_FONT_SIZE_MAX, POPUP_FONT_SIZE_STEP,
        size_proxy, "value", size_defaults, request_preview,
        { immediate_callback = true })

    popup.bold = addon.CreateCheckbox(popup, "Bold", false, function(value)
        if popup.active then write(popup.active.config.bold, value == true) end
        request_preview()
    end)
    popup.outline = addon.CreateCheckbox(popup, "Outline", false, function(value)
        if popup.active then write(popup.active.config.outline, value == true) end
        request_preview()
    end)
    popup.outline:SetPoint("TOPLEFT", popup.color, "BOTTOMLEFT", 0, -POPUP_FIRST_CHECKBOX_GAP)
    popup.bold:SetPoint("TOPLEFT", popup.outline, "BOTTOMLEFT", 0, -POPUP_CHECKBOX_GAP)

    popup.size:SetPoint("TOPLEFT", popup.bold, "BOTTOMLEFT", 0, -POPUP_CONTROL_GAP)

    popup.reset = addon.CreateTextButton(popup, "Reset", function()
        if not popup.active then return end
        local defaults = {}
        for _, key in ipairs({ "color", "font", "size", "bold", "outline" }) do
            defaults[key] = key == "color"
                and copy_color(read_default(popup.active.config[key]))
                or read_default(popup.active.config[key])
        end
        apply_values(popup.active.config, defaults)
        popup:RefreshControls()
        request_preview()
    end, { width = POPUP_FOOTER_BUTTON_WIDTH, fit_to_text = false })
    popup.reset:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT",
        POPUP_FOOTER_X + ((POPUP_FOOTER_BUTTON_WIDTH + POPUP_FOOTER_BUTTON_GAP) * 2), POPUP_FOOTER_Y)
    popup.cancel = addon.CreateTextButton(popup, "Cancel", function() close_popup(false) end,
        { width = POPUP_FOOTER_BUTTON_WIDTH, fit_to_text = false })
    popup.cancel:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT",
        POPUP_FOOTER_X + POPUP_FOOTER_BUTTON_WIDTH + POPUP_FOOTER_BUTTON_GAP, POPUP_FOOTER_Y)
    popup.save = addon.CreateTextButton(popup, "Save", function() close_popup(true) end,
        { width = POPUP_FOOTER_BUTTON_WIDTH, fit_to_text = false })
    popup.save:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", POPUP_FOOTER_X, POPUP_FOOTER_Y)

    function popup:RefreshControls()
        local config = self.active and self.active.config
        if not config then return end
        self.title:SetText(config.popup_label or config.label or "Text Options")
        local notice = type(config.get_notice) == "function" and config.get_notice() or config.notice
        self.notice:SetText(notice or "")
        self.notice:SetShown(notice ~= nil and notice ~= "")
        local notice_offset = self.notice:IsShown() and POPUP_NOTICE_HEIGHT or 0
        self:SetHeight(POPUP_HEIGHT + notice_offset)
        self.color:ClearAllPoints()
        self.color:SetPoint(
            "TOP",
            self,
            "TOPLEFT",
            POPUP_COLOR_COLUMN_WIDTH / 2,
            -(POPUP_CONTENT_Y + notice_offset)
        )
        self.color:SetShown(config.color ~= nil)
        self.font:SetShown(config.font ~= nil)
        self.size:SetShown(config.size ~= nil)
        self.bold:SetShown(config.bold ~= nil)
        self.outline:SetShown(config.outline ~= nil)
        self.font:ClearAllPoints()
        local column_gap = config.column_gap or POPUP_COLUMN_GAP
        local font_column_width = POPUP_WIDTH - POPUP_COLOR_COLUMN_WIDTH - column_gap
        self.font:SetPoint(
            "TOPLEFT",
            self,
            "TOPLEFT",
            POPUP_COLOR_COLUMN_WIDTH + column_gap + ((font_column_width - POPUP_FONT_WIDTH) / 2),
            -(POPUP_CONTENT_Y + notice_offset)
        )
        if config.color then self.color:SetValue(copy_color(read(config.color))) end
        if config.font then self.font:SetValue(read(config.font)) end
        if config.size then self.size:SetValueSilently(read(config.size)) end
        if config.bold then self.bold:SetCheckedSilently(read(config.bold) == true) end
        if config.outline then self.outline:SetCheckedSilently(read(config.outline) == true) end
        if config.bold then
            local available = addon.IsFontBoldAvailable(read(config.font))
            self.bold:SetEnabled(available)
            self.bold:SetAlpha(available and 1 or 0.45)
        end
    end

    popup:SetScript("OnHide", function()
        if popup.active then close_popup(false) end
    end)
    return popup
end

function addon.CloseFontOptionsPopup(commit)
    close_popup(commit == true)
end

function addon.GetFontOptionsPopup()
    return popup
end

--#endregion SINGLETON POPUP ===================================================

--#region LAUNCHER =============================================================

function addon.CreateFontPicker(parent, config)
    config = config or {}
    launcher_serial = launcher_serial + 1
    local launcher = addon.CreateTextButton(parent, config.label or "Text Options", nil, {
        width = config.width or 150,
        fit_to_text = false,
    })
    launcher.config = config
    launcher.preview_font = CreateFont and CreateFont(addon_name .. "FontPickerLauncher" .. launcher_serial) or nil

    function launcher:Refresh()
        self:SetText(self.config.label or "Text Options")
        local color = read(self.config.color) or { r = 1, g = 1, b = 1 }
        local r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
        local font_target = self.preview_font or self:GetFontString()
        addon.ApplySelectedFont(font_target, {
            key = read(self.config.font),
            role = self.config.role,
            size = LAUNCHER_FONT_SIZE,
            bold = read(self.config.bold) == true,
            outline = read(self.config.outline) == true,
        })
        if font_target and font_target.SetTextColor then
            font_target:SetTextColor(r, g, b, a)
        end
        if self.preview_font then
            self:SetNormalFontObject(self.preview_font)
            self:SetHighlightFontObject(self.preview_font)
        end
        -- UIPanelButtonTemplate can reapply the FontObject's inherited color when
        -- its state changes. Set the live FontString last so the picker value,
        -- rather than a role-specific Blizzard default, owns the launcher color.
        local button_text = self:GetFontString()
        if button_text and button_text.SetTextColor then
            button_text:SetTextColor(r, g, b, a)
        end
    end
    function launcher:GetValue() return read(self.config.font) end
    function launcher:SetValue(value)
        write(self.config.font, value)
        self:Refresh()
    end
    local set_enabled = launcher.SetEnabled
    function launcher:SetEnabled(enabled)
        if not enabled and popup and popup.active == self then close_popup(false) end
        set_enabled(self, enabled)
    end
    launcher:SetScript("OnClick", function(self)
        local owned_popup = ensure_popup()
        if owned_popup.active == self then
            close_popup(false)
            return
        end
        if owned_popup.active and owned_popup.active ~= self then close_popup(false) end
        if not owned_popup.active then
            owned_popup.active = self
            owned_popup.snapshot = snapshot_config(self.config)
        end
        set_launcher_open(self, true)
        owned_popup:ClearAllPoints()
        owned_popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
        owned_popup:RefreshControls()
        owned_popup:Show()
    end)
    launcher:HookScript("OnHide", function(self)
        if popup and popup.active == self then close_popup(false) end
    end)
    launcher:Refresh()
    return launcher
end

--#endregion LAUNCHER ==========================================================
