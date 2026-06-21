-- Builds and manages the main LsTweeks settings window: a sidebar listing registered modules and a content area that swaps in each module's settings panel.
-- Modules self-register via addon.register_category(name, builder_fn), which adds them to the sidebar and on-demand builds their panel on first selection.

local addon_name, addon = ...

-- ============================================================================
-- CATEGORY REGISTRATION (modules use this)
-- ============================================================================
addon.categories = {}

function addon.register_category(name, builder, opts)
    opts = opts or {}
    table.insert(addon.categories, {
        name = name,
        builder = builder,
        order = opts.order or 100,
        module_key = opts.module_key,
        _registered_index = #addon.categories + 1,
    })
end

-- MAIN FRAME UI CREATION
local function create_main_frame()
    if addon.main_frame then return addon.main_frame end

    -- MAIN CONTAINER
    local frame = CreateFrame("Frame", "Ls_Tweeks_main_frame", UIParent, "BackdropTemplate")
    frame:SetSize(950, 805)
    frame:SetPoint("CENTER")
    frame:Hide()

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- B defines how far the border art visually occupies from each frame edge.
    -- The backdrop has two layers: bgFile fills the interior starting at the inset boundary,
    -- and edgeFile renders decorative border art at the outer edge — it is NOT a solid fill
    -- and has transparency between the outer ring and where bgFile takes over.
    -- B must always match the backdrop insets exactly. If they diverge, a transparent gap
    -- appears between the border art and any child frame positioned at the inset boundary
    -- (such as the title bar). Keeping them as one source of truth prevents this.
    local B = { t = 12, b = 11, l = 11, r = 12 }

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = B.l, right = B.r, top = B.t, bottom = B.b },
    })
    frame:SetBackdropColor(1, 1, 1, 0.95)

    -- Transparent drag handle — no backdrop so the frame border shows through
    local title_bar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    title_bar:SetHeight(26)
    title_bar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  B.l,  -B.t)
    title_bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -B.r, -B.t)
    title_bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    title_bar:SetBackdropColor(0.12, 0.12, 0.12, 0.5)

    local title_bar_line = title_bar:CreateTexture(nil, "BACKGROUND")
    title_bar_line:SetHeight(1)
    title_bar_line:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    title_bar_line:SetPoint("BOTTOMLEFT",  title_bar, "BOTTOMLEFT",  0, 0)
    title_bar_line:SetPoint("BOTTOMRIGHT", title_bar, "BOTTOMRIGHT", 0, 0)

    title_bar:EnableMouse(true)
    title_bar:RegisterForDrag("LeftButton")
    title_bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    title_bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Title label: floating box centered on the top border, high frame level
    local title_label = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    title_label:SetSize(120, 32)
    title_label:SetPoint("CENTER", frame, "TOP", 0, -6)
    title_label:SetFrameLevel(frame:GetFrameLevel() + 50)
    title_label:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    title_label:SetBackdropColor(0.10, 0.08, 0.02, 0.95)

    local title_text = title_label:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title_text:SetPoint("CENTER")
    title_text:SetText("L's Tweeks")
    title_text:SetTextColor(1, 0.82, 0)

    -- CLOSE BUTTON
    local close_button = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close_button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -B.r, -B.t)
    close_button:SetScript("OnClick", function() frame:Hide() end)

    -- SIDEBAR (Left)
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT",    frame, "TOPLEFT",  B.l, -(B.t + 26))
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", B.l, B.b)
    sidebar:SetWidth(140)
    sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    sidebar:SetBackdropColor(0.10, 0.10, 0.10, 0.9)

    local sidebar_line = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebar_line:SetWidth(1)
    sidebar_line:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    sidebar_line:SetPoint("TOPRIGHT",    sidebar, "TOPRIGHT",    0, 0)
    sidebar_line:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)

    frame.sidebar = sidebar

    -- CONTENT AREA (Right)
    local content_area = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content_area:SetPoint("TOPLEFT",     sidebar, "TOPRIGHT",    0,    0)
    content_area:SetPoint("BOTTOMRIGHT", frame,   "BOTTOMRIGHT", -B.r, B.b)
    content_area:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    content_area:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    content_area:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.content_area = content_area
    function frame:GetContentAreaSize()
        local width = frame:GetWidth() - 140 - B.l - B.r
        local height = frame:GetHeight() - B.t - 26 - B.b
        return width, height
    end

    -- COLLAPSE BUTTON
    local collapsed      = false
    local full_height    = select(2, frame:GetSize())
    local collapsed_height = B.t + 26 + B.b  -- border top + title bar + border bottom

    local collapse_btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    collapse_btn:SetFrameLevel(title_bar:GetFrameLevel() + 1)
    collapse_btn:SetSize(25, 25)
    collapse_btn:SetPoint("RIGHT", close_button, "LEFT", -5, 0)
    collapse_btn:SetNormalFontObject("GameFontNormalLarge")
    collapse_btn:GetFontString():SetText("_")
    if collapse_btn:GetNormalTexture()   then collapse_btn:GetNormalTexture():SetVertexColor(0.9, 0.9, 0.9) end
    if collapse_btn:GetPushedTexture()   then collapse_btn:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6) end
    if collapse_btn:GetHighlightTexture() then collapse_btn:GetHighlightTexture():SetVertexColor(0.8, 0.8, 0.8) end
    collapse_btn:SetScript("OnClick", function()
        collapsed = not collapsed
        if collapsed then
            full_height = select(2, frame:GetSize())
            frame:SetHeight(collapsed_height)
            sidebar:Hide()
            content_area:Hide()
            collapse_btn:GetFontString():SetText("□")
        else
            frame:SetHeight(full_height)
            sidebar:Show()
            content_area:Show()
            collapse_btn:GetFontString():SetText("_")
        end
    end)

    frame.title_bar = title_bar
    addon.main_frame = frame
    return frame
end

-- INITIALIZER (Dynamic Tab & Sidebar System)
function addon.init_main_frame()
    local frame = create_main_frame()
    local selected_button = nil
    local selected_category_name = nil
    
    frame.tabs = {}     -- Cache for tab frames
    frame.buttons = {}  -- Cache for sidebar buttons

    local function is_category_locked(cat)
        return cat
            and cat.module_key
            and addon.is_module_enabled
            and not addon.is_module_enabled(cat.module_key)
    end

    local function sync_tab_lock(tab, locked)
        if not tab then return end

        tab:SetAlpha(locked and 0.55 or 1)
        if not tab._module_lock_overlay then
            local overlay = CreateFrame("Frame", nil, tab)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(tab:GetFrameLevel() + 50)
            overlay:EnableMouse(true)
            if overlay.EnableMouseWheel then
                overlay:EnableMouseWheel(true)
                overlay:SetScript("OnMouseWheel", function() end)
            end
            tab._module_lock_overlay = overlay
        end
        tab._module_lock_overlay:SetShown(locked)
    end

    -- TAB SELECTION LOGIC
    local function select_tab(cat, btn)
        if not cat then return end
        if selected_button then selected_button:UnlockHighlight() end
        btn:LockHighlight()
        selected_button = btn
        selected_category_name = cat.name
        if Ls_Tweeks_DB then Ls_Tweeks_DB.last_open_module = cat.name end

        -- Hide all current tabs
        for _, tab in pairs(frame.tabs) do
            if tab then tab:Hide() end
        end

        -- Rebuild tab if it doesn't exist (or was cleared by reset)
        if not frame.tabs[cat.name] then
            local new_tab = CreateFrame("Frame", nil, frame.content_area)
            new_tab:SetAllPoints()
            new_tab:SetFrameLevel(frame.content_area:GetFrameLevel() + 2)
            cat.builder(new_tab)
            frame.tabs[cat.name] = new_tab
        end

        local tab = frame.tabs[cat.name]
        sync_tab_lock(tab, is_category_locked(cat))
        tab:Show()
    end

    -- SIDEBAR REFRESH LOGIC
    local function RefreshSidebar()
        local previous_category_name = selected_category_name
        selected_button = nil
        local previous_category = nil

        -- Hide and clear existing category buttons
        for _, btn in ipairs(frame.buttons) do btn:Hide() end
        wipe(frame.buttons)

        table.sort(addon.categories, function(a, b)
            if a.order == b.order then
                return (a._registered_index or 0) < (b._registered_index or 0)
            end
            return (a.order or 100) < (b.order or 100)
        end)

        local y = -10

        -- Build Category Buttons from registered modules (includes About module)
        for _, cat in ipairs(addon.categories) do
            local category_locked = is_category_locked(cat)
            local btn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
            btn:SetSize(120, 22)
            btn:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 10, y)
            btn:SetText(cat.name)
            btn:SetEnabled(true)
            btn:SetScript("OnClick", function()
                select_tab(cat, btn)
            end)
            local text = btn:GetFontString()
            if text and text.SetTextColor then
                if category_locked then
                    text:SetTextColor(0.45, 0.45, 0.45, 1)
                else
                    text:SetTextColor(1, 0.82, 0, 1)
                end
            end
            if cat.name == previous_category_name then
                btn:LockHighlight()
                selected_button = btn
                previous_category = cat
            end
            table.insert(frame.buttons, btn)
            y = y - 26
        end

        local selected_still_visible = false
        if selected_category_name then
            for _, cat in ipairs(addon.categories) do
                if cat.name == selected_category_name then
                    selected_still_visible = true
                    break
                end
            end
        end
        if not selected_still_visible then
            selected_button = nil
            selected_category_name = nil
        end

        -- If nothing is selected, restore last open module or default to first
        if not selected_button and #frame.buttons > 0 then
            local target_idx = 1
            local saved = Ls_Tweeks_DB and Ls_Tweeks_DB.last_open_module
            if saved then
                for i, cat in ipairs(addon.categories) do
                    if cat.name == saved then target_idx = i; break end
                end
            end
            local cat = addon.categories[target_idx]
            local button = frame.buttons[target_idx]
            if cat and button then
                select_tab(cat, button)
            end
        elseif selected_button and previous_category then
            select_tab(previous_category, selected_button)
        end
    end
    frame.RefreshSidebar = RefreshSidebar

    -- Every time the main frame is shown, refresh the sidebar and apply saved alpha
    frame:SetScript("OnShow", function()
        RefreshSidebar()
        if addon.apply_interface_alpha then addon.apply_interface_alpha() end
    end)
end
