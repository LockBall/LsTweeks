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

function addon.AttachTooltip(target, title, body)
    if not target or ((not title or title == "") and (not body or body == "")) then return end

    target:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:SetText(title, 1, 0.82, 0)
        else
            GameTooltip:ClearLines()
        end
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.95, 0.95, 0.95, true)
        end
        GameTooltip:Show()
    end)

    target:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function addon.AttachTooltipToTargets(body, ...)
    if not body or body == "" then return end

    for i = 1, select("#", ...) do
        addon.AttachTooltip(select(i, ...), nil, body)
    end
end

--#endregion TOOLTIPS ==========================================================
