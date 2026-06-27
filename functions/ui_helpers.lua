-- Shared UI helpers for common settings-panel chrome and simple tooltips.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

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

--#endregion FILE CONTENTS ===================================================
