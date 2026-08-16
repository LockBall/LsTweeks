-- Shared UI helpers for texture-backed runtime backgrounds and common settings-panel
-- chrome: control panel backdrops and gold-outlined settings groups.


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


--#region BACKGROUND REGIONS ==================================================

-- Creates one texture-backed background controller whose geometry follows its
-- parent or an optional separate anchor target without reading dimensions.
-- Callers own color/visibility policy and parent-specific combat restrictions.
function addon.CreateBackgroundRegion(parent, opts)
    if not (parent and parent.CreateTexture) then return nil end
    opts = opts or {}
    local anchor_to = opts.anchor_to or parent

    local texture = parent:CreateTexture(
        nil,
        opts.layer or "BACKGROUND",
        opts.template,
        opts.sublevel or -8
    )
    local controller = { texture = texture }
    local inset_left, inset_right, inset_top, inset_bottom
    local color_r, color_g, color_b, color_a
    local shown

    function controller:SetInsets(insets)
        insets = insets or {}
        local left = tonumber(insets.left) or 0
        local right = tonumber(insets.right) or 0
        local top = tonumber(insets.top) or 0
        local bottom = tonumber(insets.bottom) or 0
        if inset_left == left and inset_right == right
            and inset_top == top and inset_bottom == bottom
        then
            return
        end
        inset_left, inset_right, inset_top, inset_bottom = left, right, top, bottom
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", anchor_to, "TOPLEFT", -left, top)
        texture:SetPoint("BOTTOMRIGHT", anchor_to, "BOTTOMRIGHT", right, -bottom)
    end

    function controller:SetColor(color)
        if type(color) ~= "table" then return end
        local r = tonumber(color.r or color[1]) or 0
        local g = tonumber(color.g or color[2]) or 0
        local b = tonumber(color.b or color[3]) or 0
        local a = tonumber(color.a or color[4]) or 1
        if color_r == r and color_g == g and color_b == b and color_a == a then return end
        color_r, color_g, color_b, color_a = r, g, b, a
        texture:SetColorTexture(r, g, b, a)
    end

    function controller:SetShown(is_shown)
        is_shown = is_shown == true
        if shown == is_shown then return end
        shown = is_shown
        texture:SetShown(is_shown)
    end

    function controller:Apply(is_shown, color, insets)
        self:SetInsets(insets)
        self:SetColor(color)
        self:SetShown(is_shown)
    end

    controller:SetInsets(opts.insets)
    if opts.color then controller:SetColor(opts.color) end
    controller:SetShown(opts.shown == true)
    return controller
end

--#endregion BACKGROUND REGIONS ===============================================


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
