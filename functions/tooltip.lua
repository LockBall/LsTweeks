-- Centralized tooltip helpers: a plain addon-owned renderer for guarded line data, plus a
-- lightweight native renderer for secret Aura and spell content.


local addon_name, addon = ...


--#region OWNED TOOLTIP FACTORY ================================================

local owned_tooltip
local native_tooltip
local native_tooltip_owner
local opaque_aura_tooltip
local opaque_aura_tooltip_owner

local TOOLTIP_MAX_TEXT_WIDTH = 224
local TOOLTIP_MIN_WIDTH = 120
local TOOLTIP_TEXT_INSET = 8
local TOOLTIP_COLUMN_GAP = 10
local TOOLTIP_MIN_COLUMN_WIDTH = 40

local function get_safe_string_width(font_string)
    local width = font_string.GetStringWidth and font_string:GetStringWidth()
    if type(width) ~= "number"
        or (issecretvalue and issecretvalue(width))
        or width < 0
    then
        return TOOLTIP_MAX_TEXT_WIDTH, true
    end
    if width > TOOLTIP_MAX_TEXT_WIDTH then
        return TOOLTIP_MAX_TEXT_WIDTH, true
    end
    return width, false
end

local function get_safe_string_height(font_string)
    local height = font_string.GetStringHeight and font_string:GetStringHeight()
    if type(height) ~= "number"
        or (issecretvalue and issecretvalue(height))
        or height < 16
    then
        return 16
    end
    return height
end

-- General addon-authored tooltip content intentionally uses a plain frame rather than a GameTooltip. Retail's
-- GameTooltip now manages Blizzard widget sets whose layout values can be
-- secret.  Giving addon data to that shared path can taint later Blizzard
-- tooltips (map POIs, unit frames, and others).  TooltipBackdropTemplate is
-- taint-safe here: it is a plain Frame plus a NineSlicePanelTemplate child
-- carrying the native tooltip art and default colors, with no tooltip logic.
function addon.CreateOwnedTooltip(name, parent)
    local tooltip = CreateFrame("Frame", name or (addon_name .. "Tooltip"), parent or UIParent, "TooltipBackdropTemplate")
    tooltip:SetSize(240, 1)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip.lines = {}
    tooltip.right_lines = {}
    tooltip.row_offsets = {}

    function tooltip:ClearLines()
        for _, line in ipairs(self.lines) do
            line:Hide()
        end
        for _, line in ipairs(self.right_lines) do
            line:Hide()
        end
        self.line_count = 0
        self.content_height = 0
        self.content_width = 0
        self:SetHeight(1)
    end

    -- Quadrant-aware placement from readable owner/screen centers always wins;
    -- the anchor argument only applies in the secret-coordinate fallback.
    function tooltip:SetOwner(owner, anchor)
        self.owner = owner
        self:ClearAllPoints()

        local relative_to = owner or UIParent
        local owner_x, owner_y = relative_to:GetCenter()
        local screen_x, screen_y = UIParent:GetCenter()
        local coordinates_are_safe = type(owner_x) == "number"
            and type(owner_y) == "number"
            and type(screen_x) == "number"
            and type(screen_y) == "number"
            and not (issecretvalue and (
                issecretvalue(owner_x)
                or issecretvalue(owner_y)
                or issecretvalue(screen_x)
                or issecretvalue(screen_y)
            ))

        if coordinates_are_safe then
            local show_left = owner_x >= screen_x
            local show_above = owner_y <= screen_y
            local point = (show_above and "BOTTOM" or "TOP") .. (show_left and "RIGHT" or "LEFT")
            local relative_point = (show_above and "TOP" or "BOTTOM") .. (show_left and "LEFT" or "RIGHT")
            self:SetPoint(point, relative_to, relative_point, show_left and -8 or 8, show_above and 8 or -8)
            return
        end

        local point = anchor == "ANCHOR_BOTTOMRIGHT" and "TOPRIGHT" or "TOPLEFT"
        local relative_point = anchor == "ANCHOR_BOTTOMRIGHT" and "BOTTOMRIGHT" or "TOPRIGHT"
        local x = anchor == "ANCHOR_BOTTOMRIGHT" and 0 or 8
        self:SetPoint(point, relative_to, relative_point, x, 0)
    end

    -- The wrap argument is accepted for caller compatibility but sizing is
    -- measurement-driven: lines whose natural width fits the cap size to it,
    -- and only cap-exceeding lines take the full width and wrap.
    function tooltip:AddLine(text, r, g, b, _wrap)
        local index = (self.line_count or 0) + 1
        local line = self.lines[index]
        if not line then
            line = self:CreateFontString(nil, "OVERLAY", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
            line:SetJustifyH("LEFT")
            self.lines[index] = line
        end
        local right_line = self.right_lines[index]
        if right_line then
            right_line:Hide()
        end
        local offset_y = self.content_height or 0
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self, "TOPLEFT", TOOLTIP_TEXT_INSET, -(offset_y + 7))
        line:SetWordWrap(false)
        line:SetWidth(0)
        line:SetText(text or "")
        line:SetTextColor(r or 1, g or 1, b or 1)
        line:Show()

        local line_width, width_was_bounded = get_safe_string_width(line)
        line:SetWidth(line_width)
        if width_was_bounded then
            line:SetWordWrap(true)
        end
        if line_width > (self.content_width or 0) then
            self.content_width = line_width
        end

        local line_height = get_safe_string_height(line)
        self.row_offsets[index] = offset_y
        self.line_count = index
        self.content_height = offset_y + line_height
        self:SetHeight(self.content_height + 12)
    end

    function tooltip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
        self:AddLine(left or "", lr, lg, lb)
        local index = self.line_count
        local left_line = self.lines[index]

        local right_line = self.right_lines[index]
        if not right_line then
            right_line = self:CreateFontString(nil, "OVERLAY", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
            right_line:SetJustifyH("RIGHT")
            self.right_lines[index] = right_line
        end
        right_line:ClearAllPoints()
        right_line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -TOOLTIP_TEXT_INSET, -((self.row_offsets[index] or 0) + 7))
        right_line:SetWidth(0)
        right_line:SetText(right or "")
        right_line:SetTextColor(rr or 1, rg or 1, rb or 1)
        right_line:Show()

        local has_left = left ~= nil and left ~= ""
        local has_right = right ~= nil and right ~= ""
        local left_width, left_was_bounded = 0, false
        local right_width, right_was_bounded = 0, false
        if has_left then
            left_width, left_was_bounded = get_safe_string_width(left_line)
        end
        if has_right then
            right_width, right_was_bounded = get_safe_string_width(right_line)
        end

        local gap = has_left and has_right and TOOLTIP_COLUMN_GAP or 0
        local available_width = TOOLTIP_MAX_TEXT_WIDTH - gap
        local left_layout_width = left_width
        local right_layout_width = right_width
        if left_layout_width + right_layout_width > available_width then
            if left_layout_width <= available_width - TOOLTIP_MIN_COLUMN_WIDTH then
                right_layout_width = available_width - left_layout_width
            elseif right_layout_width <= available_width - TOOLTIP_MIN_COLUMN_WIDTH then
                left_layout_width = available_width - right_layout_width
            else
                left_layout_width = math.floor(available_width / 2)
                right_layout_width = available_width - left_layout_width
            end
        end

        left_line:SetWidth(left_layout_width)
        left_line:SetWordWrap(left_was_bounded or left_layout_width < left_width)
        right_line:SetWidth(right_layout_width)
        right_line:SetWordWrap(right_was_bounded or right_layout_width < right_width)

        local row_width = left_layout_width + gap + right_layout_width
        if row_width > (self.content_width or 0) then
            self.content_width = row_width
        end

        local row_height = math.max(get_safe_string_height(left_line), get_safe_string_height(right_line))
        local offset_y = self.row_offsets[index] or 0
        self.content_height = offset_y + row_height
        self:SetHeight(self.content_height + 12)
    end

    function tooltip:ApplyContentWidth()
        local width = (self.content_width or 0) + TOOLTIP_TEXT_INSET * 2
        if width < TOOLTIP_MIN_WIDTH then
            width = TOOLTIP_MIN_WIDTH
        end
        self:SetWidth(width)
    end

    function tooltip:SetText(text, r, g, b)
        self:ClearLines()
        self:AddLine(text, r, g, b, true)
        self:ApplyContentWidth()
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

--#endregion OWNED TOOLTIP FACTORY =============================================


--#region NATIVE TOOLTIP DELEGATES =============================================

-- Aura data can contain secret values that only native GameTooltip setters can
-- render. Keep that state on one dedicated tooltip so addon-tainted Aura data
-- never enters Blizzard's shared GameTooltip and cannot contaminate later map
-- POI widget layout. The lightweight art template retains native line rendering
-- without inheriting GameTooltipTemplate's widget container and OnHide cleanup
-- path. Do not inspect or measure the rendered native lines.
function addon.GetNativeTooltip()
    if not native_tooltip then
        native_tooltip = CreateFrame(
            "GameTooltip",
            addon_name .. "NativeTooltip",
            UIParent,
            "SharedTooltipArtTemplate"
        )
        Mixin(native_tooltip, GameTooltipDataMixin)
        native_tooltip.supportsDataRefresh = true
        GameTooltip_OnLoad(native_tooltip)
        native_tooltip:SetScript("OnShow", GameTooltip_OnShow)
        native_tooltip:SetScript("OnHide", SharedTooltip_OnHide)
        native_tooltip:SetScript("OnTooltipCleared", SharedTooltip_ClearInsertedFrames)
        native_tooltip:SetScript("OnEvent", native_tooltip.OnEvent)
        native_tooltip:Hide()
    end
    return native_tooltip
end

-- Secret TooltipData line text may be passed to tooltip controls but cannot be
-- inspected or combined in addon Lua. Render it on a data-mixin-free tooltip;
-- only previously copied safe colors may replace its neutral defaults.
local function get_opaque_aura_tooltip()
    if not opaque_aura_tooltip then
        opaque_aura_tooltip = CreateFrame(
            "GameTooltip",
            addon_name .. "OpaqueAuraTooltip",
            UIParent,
            "SharedTooltipArtTemplate"
        )
        SharedTooltip_OnLoad(opaque_aura_tooltip)
        opaque_aura_tooltip:SetScript("OnHide", SharedTooltip_OnHide)
        opaque_aura_tooltip:SetScript("OnTooltipCleared", SharedTooltip_ClearInsertedFrames)
        opaque_aura_tooltip:SetPadding(6, 6, 6, 6)
        opaque_aura_tooltip:SetMinimumWidth(240, true)
        opaque_aura_tooltip:Hide()
    end
    return opaque_aura_tooltip
end

local function show_native_tooltip(owner, anchor, method_name, ...)
    if not owner then return false end

    local tooltip = addon.GetNativeTooltip()
    local method = tooltip and tooltip[method_name]
    if not method then return false end

    addon.HideOwnedTooltip()
    if opaque_aura_tooltip then
        opaque_aura_tooltip:Hide()
        opaque_aura_tooltip_owner = nil
    end
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    local ok = pcall(method, tooltip, ...)
    if not ok then
        tooltip:Hide()
        native_tooltip_owner = nil
        return false
    end

    native_tooltip_owner = owner
    tooltip:Show()
    return true
end

function addon.ShowNativeAuraTooltip(owner, unit, aura_instance_id, anchor)
    unit = unit or "player"
    local secret_check = C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret
    if not secret_check then return false end

    local checked, should_be_secret = pcall(secret_check, unit, aura_instance_id)
    if not checked or should_be_secret ~= false then return false end

    return show_native_tooltip(
        owner,
        anchor,
        "SetUnitAuraByAuraInstanceID",
        unit,
        aura_instance_id
    )
end

function addon.ShowNativeSpellTooltip(owner, spell_id, anchor)
    local secret_check = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    if not secret_check then return false end

    local checked, should_be_secret = pcall(secret_check, spell_id)
    if not checked or should_be_secret ~= false then return false end

    return show_native_tooltip(owner, anchor, "SetSpellByID", spell_id)
end

local function get_known_opaque_color(known_line, key, default_r, default_g, default_b)
    if type(known_line) ~= "table" or (issecrettable and issecrettable(known_line)) then
        return default_r, default_g, default_b
    end

    local color = known_line[key]
    if type(color) ~= "table" or (issecrettable and issecrettable(color)) then
        return default_r, default_g, default_b
    end

    local r, g, b = color.r, color.g, color.b
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)))
    then
        return default_r, default_g, default_b
    end
    return r, g, b
end

function addon.ShowOpaqueAuraTooltip(owner, unit, aura_instance_id, anchor, known_lines)
    local getter = C_TooltipInfo and C_TooltipInfo.GetUnitAuraByAuraInstanceID
    if not owner or not getter then return false end

    local ok, data = pcall(getter, unit or "player", aura_instance_id)
    if not ok
        or type(data) ~= "table"
        or (issecrettable and issecrettable(data))
    then
        return false
    end

    local lines = data.lines
    if type(lines) ~= "table"
        or (issecrettable and issecrettable(lines))
        or #lines == 0
    then
        return false
    end

    addon.HideOwnedTooltip()
    if native_tooltip then
        native_tooltip:Hide()
        native_tooltip_owner = nil
    end

    local tooltip = get_opaque_aura_tooltip()
    tooltip:ClearLines()
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")

    local known_palette = type(known_lines) == "table"
        and not (issecrettable and issecrettable(known_lines))
        and known_lines
        or nil
    local added = false
    for i = 1, #lines do
        local line = lines[i]
        if type(line) == "table" and not (issecrettable and issecrettable(line)) then
            local left_text = line.leftText
            local right_text = line.rightText
            local left_is_text = type(left_text) == "string"
            local right_is_text = type(right_text) == "string"
            local line_ok = true
            local known_line = known_palette and known_palette[i] or nil
            local left_r, left_g, left_b = get_known_opaque_color(
                known_line,
                "left_color",
                i == 1 and 1 or 0.95,
                i == 1 and 0.82 or 0.95,
                i == 1 and 0 or 0.95
            )
            local right_r, right_g, right_b = get_known_opaque_color(
                known_line,
                "right_color",
                0.95,
                0.95,
                0.95
            )

            if left_is_text and right_is_text then
                line_ok = pcall(
                    tooltip.AddDoubleLine,
                    tooltip,
                    left_text,
                    right_text,
                    left_r,
                    left_g,
                    left_b,
                    right_r,
                    right_g,
                    right_b
                )
            elseif left_is_text then
                line_ok = pcall(
                    tooltip.AddLine,
                    tooltip,
                    left_text,
                    left_r,
                    left_g,
                    left_b,
                    true
                )
            elseif right_is_text then
                line_ok = pcall(
                    tooltip.AddDoubleLine,
                    tooltip,
                    "",
                    right_text,
                    1,
                    1,
                    1,
                    right_r,
                    right_g,
                    right_b
                )
            end

            if not line_ok then
                tooltip:Hide()
                opaque_aura_tooltip_owner = nil
                return false
            end
            added = added or left_is_text or right_is_text
        end
    end

    if not added then
        tooltip:Hide()
        return false
    end

    opaque_aura_tooltip_owner = owner
    tooltip:Show()
    return true
end

local function hide_tooltip_for_owner(tooltip, current_owner, leaving_owner)
    if not leaving_owner or current_owner ~= leaving_owner then
        return current_owner
    end
    if tooltip and tooltip:GetOwner() == current_owner then
        tooltip:Hide()
    end
    return nil
end

function addon.HideNativeTooltip(owner)
    native_tooltip_owner = hide_tooltip_for_owner(native_tooltip, native_tooltip_owner, owner)
    opaque_aura_tooltip_owner = hide_tooltip_for_owner(opaque_aura_tooltip, opaque_aura_tooltip_owner, owner)
end

--#endregion NATIVE TOOLTIP DELEGATES ==========================================


--#region GUARDED TOOLTIP DATA =================================================

local function get_safe_tooltip_text(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
        return nil
    end
    return value
end

local function get_safe_tooltip_color_components(color)
    if type(color) ~= "table" or (issecrettable and issecrettable(color)) then
        return nil
    end

    local r, g, b = color.r, color.g, color.b
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)))
    then
        return nil
    end
    return r, g, b
end

local function copy_safe_tooltip_color(color)
    local r, g, b = get_safe_tooltip_color_components(color)
    if r == nil then return nil end
    return { r = r, g = g, b = b }
end

local function get_owned_tooltip_color_components(color)
    local r, g, b = get_safe_tooltip_color_components(color)
    if r ~= nil then return r, g, b end

    local fallback = NORMAL_FONT_COLOR or {}
    return fallback.r or 1, fallback.g or 1, fallback.b or 1
end

function addon.CopySafeTooltipDataLines(data)
    if type(data) ~= "table" or (issecrettable and issecrettable(data)) then
        return nil
    end

    local lines = data.lines
    if type(lines) ~= "table"
        or (issecrettable and issecrettable(lines))
        or #lines == 0
    then
        return nil
    end

    local copied = {}
    for i = 1, #lines do
        local line = lines[i]
        if type(line) == "table" and not (issecrettable and issecrettable(line)) then
            local left_text = get_safe_tooltip_text(line.leftText)
            local right_text = get_safe_tooltip_text(line.rightText)
            if left_text or right_text then
                local wrap_text = line.wrapText
                copied[#copied + 1] = {
                    left_text = left_text,
                    right_text = right_text,
                    left_color = copy_safe_tooltip_color(line.leftColor),
                    right_color = copy_safe_tooltip_color(line.rightColor),
                    wrap_text = not (issecretvalue and issecretvalue(wrap_text)) and wrap_text == true,
                }
            end
        end
    end

    return #copied > 0 and copied or nil
end

--#endregion GUARDED TOOLTIP DATA ==============================================


--#region OWNED TOOLTIP DISPLAY ================================================

function addon.AddOwnedTooltipLines(tooltip, lines)
    if not tooltip
        or type(lines) ~= "table"
        or (issecrettable and issecrettable(lines))
    then
        return false
    end
    local added = false
    for i = 1, #lines do
        local line = lines[i]
        if type(line) == "table" and not (issecrettable and issecrettable(line)) then
            local left_text = get_safe_tooltip_text(line.left_text)
            local right_text = get_safe_tooltip_text(line.right_text)
            local has_left = left_text and left_text ~= ""
            local has_right = right_text and right_text ~= ""
            if has_left or has_right then
                local left_r, left_g, left_b = get_owned_tooltip_color_components(line.left_color)
                if has_right then
                    local right_r, right_g, right_b = get_owned_tooltip_color_components(line.right_color)
                    tooltip:AddDoubleLine(
                        left_text or "",
                        right_text,
                        left_r,
                        left_g,
                        left_b,
                        right_r,
                        right_g,
                        right_b
                    )
                else
                    local wrap_text = line.wrap_text
                    tooltip:AddLine(
                        left_text,
                        left_r,
                        left_g,
                        left_b,
                        not (issecretvalue and issecretvalue(wrap_text)) and wrap_text == true
                    )
                end
                added = true
            end
        end
    end
    return added
end

function addon.HideOwnedTooltip()
    if owned_tooltip then
        owned_tooltip:Hide()
        addon.ResetOwnedTooltip(owned_tooltip)
    end
end

function addon.ShowOwnedTooltipLines(owner, lines, anchor)
    if not owner
        or type(lines) ~= "table"
        or (issecrettable and issecrettable(lines))
        or #lines == 0
    then
        return
    end
    local tooltip = addon.GetOwnedTooltip()
    addon.ResetOwnedTooltip(tooltip)
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if addon.AddOwnedTooltipLines(tooltip, lines) then
        tooltip:ApplyContentWidth()
        tooltip:Show()
    else
        tooltip:Hide()
    end
end

function addon.ShowOwnedTooltip(owner, title, body, anchor)
    if not owner or ((not title or title == "") and (not body or body == "")) then return end

    local lines = {}
    if title and title ~= "" then
        lines[#lines + 1] = {
            left_text = title,
            left_color = { r = 1, g = 0.82, b = 0 },
        }
    end
    if body and body ~= "" then
        lines[#lines + 1] = {
            left_text = body,
            left_color = { r = 0.95, g = 0.95, b = 0.95 },
            wrap_text = true,
        }
    end
    addon.ShowOwnedTooltipLines(owner, lines, anchor)
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

--#endregion OWNED TOOLTIP DISPLAY =============================================
