-- Shared UI helpers for common settings-panel chrome and simple tooltips.


local addon_name, addon = ...


--#region CONTROL PANELS =======================================================

function addon.ApplyControlPanelBackdrop(frame, opts)
    if not frame then return end
    opts = opts or {}
    local bg = opts.bg or { 0, 0, 0, 0.3 }
    local border = opts.border or { 0.5, 0.5, 0.5, 0.9 }

    frame:SetBackdrop({
        bgFile = opts.bgFile or "Interface\\Buttons\\WHITE8X8",
        edgeFile = opts.edgeFile or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = opts.tileSize or 16,
        edgeSize = opts.edgeSize or 12,
        insets = opts.insets or { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

function addon.CreateControlPanel(parent, width, height, opts)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width or 1, height or 1)
    addon.ApplyControlPanelBackdrop(panel, opts)
    return panel
end

--#endregion CONTROL PANELS ====================================================


--#region SETTINGS GROUPS ======================================================

local SETTINGS_GROUP_TITLE_BAR_HEIGHT = 24
local SETTINGS_GROUP_TITLE_BAR_INSET = 3

function addon.ApplySettingsGroupOutline(frame)
    if not frame then return end

    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    frame:SetBackdropColor(0, 0, 0, 0)
end

function addon.CreateSettingsGroupTitleBar(parent, title_text, opts)
    if not parent then return nil, nil end
    opts = opts or {}
    local inset = opts.inset or SETTINGS_GROUP_TITLE_BAR_INSET

    local title_bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    title_bar:SetHeight(opts.height or SETTINGS_GROUP_TITLE_BAR_HEIGHT)
    title_bar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    title_bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    title_bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    title_bar:SetBackdropColor(0.14, 0.14, 0.14, 0.65)

    local title = title_bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", title_bar, "CENTER", 0, 0)
    title:SetText(title_text)

    return title_bar, title
end

function addon.CreateSettingsGroup(parent, title_text, width, height, offset_x, offset_y)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(width or 1, height or 1)
    group:SetPoint("TOPLEFT", parent, "TOPLEFT", offset_x or 0, offset_y or 0)
    addon.ApplySettingsGroupOutline(group)

    local _, title = addon.CreateSettingsGroupTitleBar(group, title_text)

    return group, title
end

--#endregion SETTINGS GROUPS ===================================================


--#region TOOLTIPS =============================================================

local owned_tooltip

-- This is intentionally a plain frame, rather than a GameTooltip.  Retail's
-- GameTooltip now manages Blizzard widget sets whose layout values can be
-- secret.  Giving addon data to that shared path can taint later Blizzard
-- tooltips (map POIs, unit frames, and others).
function addon.CreateOwnedTooltip(name, parent)
    local tooltip = CreateFrame("Frame", name or (addon_name .. "Tooltip"), parent or UIParent, "BackdropTemplate")
    tooltip:SetSize(240, 1)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    tooltip:SetBackdropColor(0, 0, 0, 0.9)
    tooltip.lines = {}

    function tooltip:ClearLines()
        for _, line in ipairs(self.lines) do
            line:Hide()
        end
        self.line_count = 0
        self:SetHeight(1)
    end

    function tooltip:SetOwner(owner, anchor)
        self.owner = owner
        self:ClearAllPoints()
        local point = anchor == "ANCHOR_BOTTOMRIGHT" and "TOPRIGHT" or "TOPLEFT"
        local relative_point = anchor == "ANCHOR_BOTTOMRIGHT" and "BOTTOMRIGHT" or "TOPRIGHT"
        local x = anchor == "ANCHOR_BOTTOMRIGHT" and 0 or 8
        self:SetPoint(point, owner or UIParent, relative_point, x, 0)
    end

    function tooltip:AddLine(text, r, g, b, wrap)
        local index = (self.line_count or 0) + 1
        local line = self.lines[index]
        if not line then
            line = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetJustifyH("LEFT")
            self.lines[index] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -((index - 1) * 16 + 7))
        line:SetWidth(224)
        line:SetText(text or "")
        line:SetTextColor(r or 1, g or 1, b or 1)
        line:Show()
        self.line_count = index
        self:SetHeight(index * 16 + 12)
    end

    function tooltip:AddDoubleLine(left, right, lr, lg, lb)
        self:AddLine((left or "") .. "    " .. (right or ""), lr, lg, lb)
    end

    function tooltip:SetText(text, r, g, b)
        self:ClearLines()
        self:AddLine(text, r, g, b, true)
    end

    tooltip:Hide()
    return tooltip
end

function addon.ResetOwnedTooltip(tooltip)
    tooltip = tooltip or owned_tooltip
    if not tooltip then return end
    if tooltip.ClearLines then
        tooltip:ClearLines()
    end
end

function addon.GetOwnedTooltip()
    if not owned_tooltip then
        owned_tooltip = addon.CreateOwnedTooltip()
        addon.ResetOwnedTooltip(owned_tooltip)
    end
    return owned_tooltip
end

function addon.HideOwnedTooltip()
    if owned_tooltip then
        owned_tooltip:Hide()
        addon.ResetOwnedTooltip(owned_tooltip)
    end
end

function addon.ShowOwnedTooltip(owner, title, body, anchor)
    if not owner or ((not title or title == "") and (not body or body == "")) then return end

    local tooltip = addon.GetOwnedTooltip()
    addon.ResetOwnedTooltip(tooltip)
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if title and title ~= "" then
        tooltip:SetText(title, 1, 0.82, 0)
    else
        tooltip:ClearLines()
    end
    if body and body ~= "" then
        tooltip:AddLine(body, 0.95, 0.95, 0.95, true)
    end
    tooltip:Show()
end

function addon.AttachTooltip(target, title, body)
    if not target or ((not title or title == "") and (not body or body == "")) then return end

    target:HookScript("OnEnter", function(self)
        addon.ShowOwnedTooltip(self, title, body)
    end)

    target:HookScript("OnLeave", function()
        addon.HideOwnedTooltip()
    end)
end

function addon.AttachTooltipToTargets(body, ...)
    if not body or body == "" then return end

    for i = 1, select("#", ...) do
        addon.AttachTooltip(select(i, ...), nil, body)
    end
end

--#endregion TOOLTIPS ==========================================================
