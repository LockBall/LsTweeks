-- ChatCopySghetti settings and lazy manual-copy popup; shared factories own chrome.
local addon_name, addon = ...
local M = addon.chat_copy_sghetti
local min, max = math.min, math.max
local COLLAPSED_HEIGHT = 40

--#region WINDOW GEOMETRY ======================================================
local function save_window_geometry(popup)
    local window = M.get_db().window
    local x, y = popup:GetCenter()
    local parent_x, parent_y = UIParent:GetCenter()
    window.width = popup:GetWidth()
    if not popup.is_minimized then window.height = popup:GetHeight() end
    if popup.is_minimized then
        y = y - (window.height - popup:GetHeight()) / 2
    end
    window.x, window.y = x - parent_x, y - parent_y
end

local function finish_positioning(popup)
    if not popup.is_positioning then return end
    popup:StopMovingOrSizing()
    popup.is_positioning = false
    save_window_geometry(popup)
end

local function restore_window_geometry(popup)
    local window, defaults = M.get_db().window, M.defaults.chat_copy_sghetti.window
    local screen_width, screen_height = UIParent:GetSize()
    local min_width = min(M.WINDOW_MINIMUM.width, screen_width)
    local min_height = min(M.WINDOW_MINIMUM.height, screen_height)
    window.width = addon.clamp_number(window.width, defaults.width, { min = min_width, max = screen_width })
    window.height = addon.clamp_number(window.height, defaults.height, { min = min_height, max = screen_height })
    local x_bound, y_bound = (screen_width - window.width) / 2, (screen_height - window.height) / 2
    window.x = addon.clamp_number(window.x, defaults.x, { min = -x_bound, max = x_bound })
    window.y = addon.clamp_number(window.y, defaults.y, { min = -y_bound, max = y_bound })
    popup:SetResizeBounds(min_width, min_height, screen_width, screen_height)
    popup:SetSize(window.width, window.height)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "CENTER", window.x, window.y)
    return window.width
end
--#endregion WINDOW GEOMETRY ===================================================

--#region EXPORT WINDOW =======================================================
function M.apply_popup_background()
    -- The popup is lazy; changing settings must not create an export window.
    if not M.popup then return end
    local color = M.get_db().background_color
    M.popup.background:SetColorTexture(color.r, color.g, color.b, color.a)
end

local function create_export_window()
    local defaults = M.defaults.chat_copy_sghetti.window
    local popup = addon.CreatePopupFrame(addon_name .. "ChatCopySghettiExport", UIParent, {
        width = defaults.width, height = defaults.height, strata = "DIALOG", clamped = true,
    })
    popup:SetMovable(true)
    popup:SetResizable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self)
        self.is_positioning = true
        self:StartMoving()
    end)
    popup:SetScript("OnDragStop", finish_positioning)
    local title = popup:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("CENTER", popup, "TOP", 0, -20)
    title:SetText("ChatCopySghetti")
    title:SetTextColor(1, 0.82, 0)
    local settings = addon.CreateTextButton(popup, "", function()
        addon.main_frame:OpenCategory(M.CATEGORY_NAME)
    end, { width = 25, height = 25, fit_to_text = false })
    settings:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -8)
    local gear = settings:CreateTexture(nil, "ARTWORK")
    gear:SetSize(18, 18)
    gear:SetPoint("CENTER")
    gear:SetTexture(addon.SETTINGS_ICON_TEXTURE)
    addon.AttachTooltip(settings, "ChatCopySghetti Settings", "Open LsTweeks to the ChatCopySghetti settings page.")
    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelInputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -46)
    scroll:SetPoint("BOTTOMRIGHT", -40, 78)
    -- Blizzard's input template owns multiline sizing, cursor scrolling, and selection.
    local edit = scroll.EditBox
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetMaxLetters(0)
    local function resize_content(_, width)
        edit:SetWidth(max(1, width - 78)) -- Popup insets (20 + 40), native edit inset (18).
        edit.Instructions:SetWidth(max(1, width - 60))
    end
    popup:SetScript("OnSizeChanged", resize_content)
    resize_content(popup, restore_window_geometry(popup))
    scroll.CharCount:Hide()
    edit.Instructions:SetText("")
    edit:SetScript("OnEscapePressed", function() popup:Hide() end)
    local summary = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("BOTTOMLEFT", 20, 52)
    summary:SetText("")
    local select_all = addon.CreateTextButton(popup, "Select All", function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    select_all:SetPoint("BOTTOMLEFT", 20, 16)
    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() popup:Hide() end)
    local minimize = addon.CreateTextButton(popup, "_", function()
        popup:SetMinimized(not popup.is_minimized)
    end, { width = 25, height = 25, fit_to_text = false, font_object = GameFontNormalLarge })
    minimize:SetPoint("RIGHT", close, "LEFT", -5, 0)
    addon.AttachTooltip(minimize, "Minimize / Restore", "Collapse the copy window to its title bar, or restore it.")
    local resize = CreateFrame("Button", nil, popup)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        popup.is_positioning = true
        popup:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function() finish_positioning(popup) end)
    popup.resize_handle = resize
    addon.AttachTooltip(resize, "Resize", "Drag to resize. The window remembers its size and position.")
    local help = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("LEFT", select_all, "RIGHT", 16, 0)
    help:SetText("Select text, then Ctrl+C. Escape closes.")
    function popup:SetMinimized(value)
        if self.is_minimized == value then return end
        finish_positioning(self)
        self.is_minimized = value
        self:SetResizable(not value)
        scroll:SetShown(not value)
        summary:SetShown(not value)
        select_all:SetShown(not value)
        help:SetShown(not value)
        resize:SetShown(not value)
        minimize:SetText(value and "□" or "_")
        if value then
            edit:ClearFocus()
            local window = M.get_db().window
            self:SetResizeBounds(min(M.WINDOW_MINIMUM.width, UIParent:GetWidth()), COLLAPSED_HEIGHT)
            self:SetHeight(COLLAPSED_HEIGHT)
            self:ClearAllPoints()
            self:SetPoint("TOP", UIParent, "CENTER", window.x, window.y + window.height / 2)
        else
            restore_window_geometry(self)
        end
    end
    popup:SetScript("OnHide", function()
        finish_positioning(popup)
        edit:ClearFocus()
        edit:SetText("") -- Chat text is never persisted and is released on close.
    end)
    popup.edit, popup.summary = edit, summary
    popup:Hide()
    return popup
end

function M.show_export(text, report)
    if not M.popup then M.popup = create_export_window() end
    M.popup:SetMinimized(false)
    M.apply_popup_background()
    restore_window_geometry(M.popup)
    M.popup:Show()
    M.popup.edit:SetText(text)
    M.popup.edit:SetCursorPosition(0)
    M.popup.edit:SetFocus()
    local detail = report.unavailable and "History unavailable" or
        (report.exported .. " lines; " .. report.skipped .. " skipped lines")
    M.popup.summary:SetText(detail)
end
--#endregion EXPORT WINDOW ====================================================

--#region SETTINGS ============================================================
function M.sync_controls()
    local db, controls = M.get_db(), M.controls
    -- Settings are lazy; callbacks exist only after their page is constructed.
    if controls.keep_brackets then
        controls.keep_brackets:SetCheckedSilently(db.keep_brackets)
        controls.max_messages:SetValueSilently(db.max_messages)
        controls.background_color:SetValue(db.background_color)
    end
    M.apply_popup_background()
end

function M.build_options_panel(parent)
    local db = M.get_db()
    local slider_size = addon.SLIDER_WITH_BOX_SIZE
    local section_gap = addon.CONTROL_STACK_SPACING.section
    local grid = addon.CreateSettingsGrid(parent, {
        column_count = 2,
        col_width = slider_size.width,
        col_gap = slider_size.width + 18,
        col_offset = 20,
        col_align = { "left", "left" },
        row_start = -20,
        row_heights = { 24 + section_gap, slider_size.height + section_gap, 180 },
        row_gap = section_gap,
        offsets = { default = 0 },
        content_rows = 3,
        separator_left = 20,
        separator_right_pad = 20,
        separator_stretch = true,
        row_separators = { 1, 2 },
    })
    local brackets, bracket_checkbox = addon.CreateCheckbox(parent, "Keep Link Brackets", db.keep_brackets, function(value)
        db.keep_brackets = value
    end)
    M.controls.keep_brackets = brackets
    grid:place_at(brackets, 1, 1)
    addon.AttachTooltipToTargets("Helps distinguish linked items, spells, or player names from ordinary chat text.", brackets, bracket_checkbox)
    local range = M.MESSAGE_RANGE
    local slider = addon.CreateSliderWithBox(addon_name .. "ChatCopySghettiMessages", parent,
        "Recent Lines", range.min, range.max, range.step, db, "max_messages", M.defaults.chat_copy_sghetti)
    addon.AttachTooltip(slider, "Recent Lines", "Counts stored chat lines, not visual word wrapping. Lines excluded for any reason, including this limit, count as skipped lines.")
    M.controls.max_messages = slider
    grid:place_at(slider, 2, 1)
    local background = addon.CreateColorPicker(parent, db, "background_color", true,
        "Popup BG", M.defaults.chat_copy_sghetti, M.apply_popup_background)
    M.controls.background_color = background
    grid:place_at(background, 2, 2)
    addon.AttachTooltip(background, "Popup BG", "Tints the popup background and adjusts its transparency. Chat text colors are preserved.")
    local reset = addon.CreateModuleReset(parent, db, M.defaults.chat_copy_sghetti, { after_reset = M.on_reset_complete })
    grid:place_at(reset, 3, 1)
end
--#endregion SETTINGS =========================================================
