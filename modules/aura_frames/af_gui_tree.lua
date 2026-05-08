-- Frames tree/sidebar for Aura Frames settings.
-- Owns the Buffs, WoW Cooldown, and Filters tree groups and routes selections to panel builders.

local addon_name, addon = ...

local GetTime = GetTime

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames
function M.build_frames_tab(p, frames_data)
    local UPDATE_INTERVALS = M.UPDATE_INTERVALS

    -- Left tree list sidebar
    local TREE_W         = 140
    local TREE_H         = 480
    local TREE_GAP_LEFT  = 10
    local TREE_GAP_RIGHT = 10
    local TREE_TOP_Y     = 10
    local PAD            = 10
    local ROW_H          = 15
    local ARROW_W        = 18
    local INDENT_CHILD   = 12
    local CD_GROUP_KEYS  = {
        essential = true,
        utility = true,
        tracked_buffs = true,
        tracked_bars = true,
    }
    local GROUP_BOX_INSET = PAD - 2
    local GROUP_INNER_PAD = 6
    local GROUP_ELEMENT_GAP = 1
    local GROUP_TITLE_H = 22
    local GROUP_TEXT_TITLE_H = 12
    local GROUP_TITLE_W = TREE_W - ((GROUP_BOX_INSET + GROUP_INNER_PAD) * 2)
    local GROUP_GAP = 10
    local SYNC_CDM_H = 20
    local CD_GROUP_LABEL_H = GROUP_INNER_PAD + GROUP_TITLE_H + GROUP_ELEMENT_GAP + SYNC_CDM_H + GROUP_ELEMENT_GAP

    local tree_frame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    tree_frame:SetPoint("TOPLEFT", p, "TOPLEFT", TREE_GAP_LEFT, TREE_TOP_Y)
    tree_frame:SetSize(TREE_W, TREE_H)
    M.frames_tree_frame  = tree_frame                             -- shared bottom anchor for child panels
    M.apply_thin_border_backdrop(tree_frame, { r = 0.08, g = 0.08, b = 0.08, a = 0.9 }, { r = 0.4, g = 0.4, b = 0.4, a = 0.8 })
    addon.alpha_affected_frames = addon.alpha_affected_frames or {}
    table.insert(addon.alpha_affected_frames, { frame = tree_frame, r = 0.08, g = 0.08, b = 0.08 })
    if addon.apply_interface_alpha then addon.apply_interface_alpha() end

    -- Right content area
    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT",     p, "TOPLEFT",     TREE_GAP_LEFT + TREE_W + TREE_GAP_RIGHT, 0)
    content:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    content:SetFrameLevel(p:GetFrameLevel() + 1)

    -- Lazy-built content panels keyed by node string
    local node_panels   = {}
    local current_panel = nil

    local function show_node(key, builder)
        if current_panel then current_panel:Hide() end
        if not node_panels[key] then
            local pnl = CreateFrame("Frame", nil, content)
            pnl:SetAllPoints(content)
            pnl:SetFrameLevel(content:GetFrameLevel() + 1)
            builder(pnl)
            node_panels[key] = pnl
        end
        node_panels[key]:Show()
        current_panel = node_panels[key]
        if M.db then M.db.last_frames_node = key end
    end

    -- Invalidate a cached panel so it is rebuilt next time it is shown.
    -- Used after a custom frame rename/delete to force fresh content.
    local function invalidate_node(key)
        local pnl = node_panels[key]
        if pnl then
            pnl:Hide()
            if current_panel == pnl then current_panel = nil end
            node_panels[key] = nil
        end
    end

    -- Selection tracking
    local selected_fs = nil
    local SEL_COLOR   = { 1, 0.82, 0 }
    local NORM_COLOR  = { 1, 1,    1 }
    local HOVER_COLOR = { 1, 1,  0.6 }

    local sel_highlight = tree_frame:CreateTexture(nil, "BACKGROUND")
    sel_highlight:SetColorTexture(0.75, 0.75, 0.75, 0.18)
    sel_highlight:Hide()

    local group_boxes = {}
    local function set_active_group_title(group_key)
        for key, frame in pairs(group_boxes) do
            if frame and frame.SetBackdropBorderColor then
                if key == group_key then
                    frame:SetBackdropBorderColor(1, 0.82, 0, 0.75)
                else
                    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.45)
                end
            end
        end
    end

    local function set_selected(fs)
        if selected_fs then selected_fs:SetTextColor(unpack(NORM_COLOR)) end
        selected_fs = fs
        if fs then
            fs:SetTextColor(unpack(SEL_COLOR))
            sel_highlight:ClearAllPoints()
            sel_highlight:SetPoint("TOPLEFT",     fs:GetParent(), "TOPLEFT",     0, 0)
            sel_highlight:SetPoint("BOTTOMRIGHT", fs:GetParent(), "BOTTOMRIGHT", 0, 0)
            sel_highlight:Show()
            set_active_group_title(fs._group_key)
        else
            sel_highlight:Hide()
            set_active_group_title(nil)
        end
    end

    -- Base tree button helper
    local function make_tree_btn(parent_f, label, x, y, w)
        local btn = CreateFrame("Button", nil, parent_f)
        btn:SetSize(w, ROW_H)
        btn:SetPoint("TOPLEFT", parent_f, "TOPLEFT", x, y)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
        fs:SetText(label)
        btn:SetScript("OnEnter", function()
            if fs ~= selected_fs then fs:SetTextColor(unpack(HOVER_COLOR)) end
        end)
        btn:SetScript("OnLeave", function()
            if fs ~= selected_fs then fs:SetTextColor(unpack(NORM_COLOR)) end
        end)
        return btn, fs
    end

    -- Reused row controls for custom frame tree entries.
    local custom_row_pool = {}
    -- Tracks the current y cursor so + Custom button can be repositioned.
    local add_btn_ref = nil  -- set after initial build

    local node_fs_map = {}
    local filters_group_box
    local filters_group_title
    local filters_group_top_y
    local update_filters_group_box

    local function hide_custom_tree_row(row)
        if not row then return end
        row.arrow:Hide()
        row.cat_btn:Hide()
        row.rename_box:Hide()
        row.del_btn:Hide()
        row.child_btn:Hide()
    end

    local function acquire_custom_tree_row(index)
        local row = custom_row_pool[index]
        if row then return row end

        row = {}

        row.arrow = CreateFrame("Button", nil, tree_frame, "UIPanelButtonTemplate")
        row.arrow:SetSize(ARROW_W, ARROW_W)
        row.arrow:SetNormalFontObject("GameFontNormalLarge")
        row.arrow_fs = row.arrow:GetFontString()

        row.cat_btn = CreateFrame("Button", nil, tree_frame)
        row.cat_fs = row.cat_btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.cat_fs:SetPoint("LEFT", row.cat_btn, "LEFT", 4, 0)
        row.cat_fs:SetFont(row.cat_fs:GetFont(), select(2, row.cat_fs:GetFont()) or 11, "OUTLINE")

        row.rename_box = CreateFrame("EditBox", nil, tree_frame, "InputBoxTemplate")
        row.rename_box:SetAutoFocus(true)
        row.rename_box:SetMaxLetters(32)

        row.del_btn = CreateFrame("Button", nil, tree_frame, "UIPanelCloseButton")
        row.del_btn:SetSize(16, 16)

        row.child_btn = CreateFrame("Button", nil, tree_frame)
        row.child_fs = row.child_btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.child_fs:SetPoint("LEFT", row.child_btn, "LEFT", 4, 0)
        row.child_fs:SetText("Filters")

        custom_row_pool[index] = row
        return row
    end

    -- ----------------------------------------------------------------
    -- Rebuild function: clears and redraws the entire tree contents.
    -- Called once at build time and again after add/delete/rename.
    -- ----------------------------------------------------------------
    local function rebuild_tree()
        for _, row in ipairs(custom_row_pool) do
            hide_custom_tree_row(row)
        end

        local add_y = M._filters_add_y or (-PAD - ROW_H)
        local y = add_y - (ROW_H + GROUP_ELEMENT_GAP)

        -- ---- Custom frame rows ----
        if M.db and M.db.custom_frames then
            for index, entry in ipairs(M.db.custom_frames) do
                local id        = entry.id
                local cat_key   = id           -- node key for settings panel
                local child_key = id .. "_filters"  -- node key for child filter panel
                local row       = acquire_custom_tree_row(index)
                if row.entry_id ~= id then
                    row.entry_id = id
                    row.last_click_time = 0
                end

                -- Track expand state per custom entry (ephemeral)
                M._custom_expanded = M._custom_expanded or {}
                if M._custom_expanded[id] == nil then M._custom_expanded[id] = true end

                -- Expand/collapse arrow
                local arrow = row.arrow
                local arrow_fs = row.arrow_fs
                arrow:ClearAllPoints()
                arrow:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", PAD, y)
                arrow_fs:SetText(M._custom_expanded[id] and "-" or "+")
                arrow:Show()

                -- Name button (with rename EditBox on click if already selected)
                local cat_x = PAD + ARROW_W + 2
                local cat_w = TREE_W - cat_x - PAD - 20  -- leave room for × button
                local cat_btn = row.cat_btn
                local cat_fs = row.cat_fs
                cat_btn:ClearAllPoints()
                cat_btn:SetSize(cat_w, ROW_H)
                cat_btn:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", cat_x, y)
                cat_fs:SetText(entry.name)
                cat_btn:SetScript("OnEnter", function()
                    if cat_fs ~= selected_fs then cat_fs:SetTextColor(unpack(HOVER_COLOR)) end
                    row.del_btn:SetAlpha(1)
                end)
                cat_btn:SetScript("OnLeave", function()
                    if cat_fs ~= selected_fs then cat_fs:SetTextColor(unpack(NORM_COLOR)) end
                    row.del_btn:SetAlpha(0)
                end)
                cat_btn:Show()
                cat_fs._group_key = "filters"
                node_fs_map[cat_key] = cat_fs

                -- Inline rename EditBox (hidden by default; shown on double-click or rename trigger)
                local rename_box = row.rename_box
                rename_box:ClearAllPoints()
                rename_box:SetSize(cat_w - 4, ROW_H - 2)
                rename_box:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", cat_x + 4, y - 1)
                rename_box:Hide()

                local function commit_rename()
                    if rename_box._suppress_commit then
                        rename_box._suppress_commit = nil
                        return
                    end
                    if not rename_box:IsShown() then return end
                    local new_name = rename_box:GetText():match("^%s*(.-)%s*$")
                    rename_box:Hide()
                    cat_btn:Show()
                    if new_name and new_name ~= "" then
                        entry.name = new_name
                        cat_fs:SetText(new_name)
                        -- Update the WoW frame title bars
                        local frame = M.frames["show_" .. id]
                        if frame then
                            if frame.title_bar and frame.title_bar.label_text then
                                frame.title_bar.label_text:SetText(new_name)
                            end
                            if frame.bottom_title_bar and frame.bottom_title_bar.label_text then
                                frame.bottom_title_bar.label_text:SetText(new_name)
                            end
                        end
                        -- Rebuild cached settings panel so its header reflects the new name
                        invalidate_node(cat_key)
                        show_node(cat_key, function(pnl) M.build_custom_settings_panel(pnl, entry) end)
                    end
                    rename_box:ClearFocus()
                end

                rename_box:SetScript("OnEnterPressed", commit_rename)
                rename_box:SetScript("OnEditFocusLost", commit_rename)
                rename_box:SetScript("OnEscapePressed", function()
                    rename_box._suppress_commit = true
                    rename_box:Hide()
                    cat_btn:Show()
                    rename_box:ClearFocus()
                end)

                -- Single-click: select; double-click: open rename
                cat_btn:SetScript("OnClick", function()
                    local now = GetTime()
                    if (now - (row.last_click_time or 0)) < 0.4 then
                        -- Double-click: open inline rename
                        rename_box:SetText(entry.name)
                        rename_box:Show()
                        rename_box:SetFocus()
                        cat_btn:Hide()
                    else
                        set_selected(cat_fs)
                        show_node(cat_key, function(pnl) M.build_custom_settings_panel(pnl, entry) end)
                    end
                    row.last_click_time = now
                end)

                -- × delete button (appears on hover of the row)
                local del_btn = row.del_btn
                del_btn:ClearAllPoints()
                del_btn:SetPoint("TOPRIGHT", tree_frame, "TOPLEFT", TREE_W - PAD, y - 3)
                del_btn:SetAlpha(0)
                del_btn:SetScript("OnEnter", function() del_btn:SetAlpha(1) end)
                del_btn:SetScript("OnLeave", function() del_btn:SetAlpha(0) end)
                del_btn:Show()

                local del_entry = entry
                del_btn:SetScript("OnClick", function()
                    StaticPopupDialogs["LSTWEEKS_DEL_CUSTOM"] = {
                        text         = 'Delete custom frame "' .. del_entry.name .. '"?',
                        button1      = "Delete",
                        button2      = "Cancel",
                        OnAccept     = function()
                            -- If it was selected, clear current panel
                            if current_panel then current_panel:Hide(); current_panel = nil end
                            invalidate_node(del_entry.id)
                            invalidate_node(del_entry.id .. "_filters")
                            M.destroy_custom_frame(del_entry.id)
                            rebuild_tree()
                            -- Select first preset as fallback
                            if #frames_data > 0 then
                                local d = frames_data[1]
                                local c = d.show_key:sub(6)
                                set_selected(node_fs_map[c])
                                show_node(c, function(pnl2) M.build_preset_frame_panel(pnl2, d) end)
                            end
                        end,
                        timeout      = 0,
                        whileDead    = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("LSTWEEKS_DEL_CUSTOM")
                end)

                y = y - (ROW_H + GROUP_ELEMENT_GAP)

                -- Child: Filters
                local child_x = PAD + ARROW_W + INDENT_CHILD
                local child_w = TREE_W - child_x - PAD
                local child_btn = row.child_btn
                local child_fs = row.child_fs
                child_btn:ClearAllPoints()
                child_btn:SetSize(child_w, ROW_H)
                child_btn:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", child_x, y)
                child_btn:SetScript("OnEnter", function()
                    if child_fs ~= selected_fs then child_fs:SetTextColor(unpack(HOVER_COLOR)) end
                end)
                child_btn:SetScript("OnLeave", function()
                    if child_fs ~= selected_fs then child_fs:SetTextColor(unpack(NORM_COLOR)) end
                end)
                child_btn:SetShown(M._custom_expanded[id])
                child_fs._group_key = "filters"
                node_fs_map[child_key] = child_fs

                local child_entry = entry
                child_btn:SetScript("OnClick", function()
                    set_selected(child_fs)
                    show_node(child_key, function(pnl) M.build_custom_child_panel(pnl, child_entry) end)
                end)

                if M._custom_expanded[id] then
                    y = y - (ROW_H + GROUP_ELEMENT_GAP)
                end

                -- Wire expand/collapse
                arrow:SetScript("OnClick", function()
                    M._custom_expanded[id] = not M._custom_expanded[id]
                    arrow_fs:SetText(M._custom_expanded[id] and "-" or "+")
                    child_btn:SetShown(M._custom_expanded[id])
                    if not M._custom_expanded[id] then
                        y = y + (ROW_H + GROUP_ELEMENT_GAP)
                    end
                    -- Reposition + Custom button
                    if add_btn_ref then
                        -- Full rebuild is simplest here to avoid offset drift
                        rebuild_tree()
                    end
                end)
            end
        end

        -- ---- + Custom button ----
        local max_reached = M.db and M.db.custom_frames
            and #M.db.custom_frames >= (M.MAX_CUSTOM_FRAMES or 4)

        if add_btn_ref then
            add_btn_ref:ClearAllPoints()
            add_btn_ref:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", PAD, add_y)
            add_btn_ref:SetEnabled(not max_reached)
            add_btn_ref:SetAlpha(max_reached and 0.4 or 1)
        else
            local add_btn = CreateFrame("Button", nil, tree_frame, "UIPanelButtonTemplate")
            add_btn:SetSize(TREE_W - PAD * 2, ROW_H)
            add_btn:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", PAD, add_y)
            add_btn:SetText("+ Custom")
            add_btn:SetEnabled(not max_reached)
            add_btn:SetAlpha(max_reached and 0.4 or 1)
            add_btn:SetScript("OnClick", function()
                if InCombatLockdown() then
                    print("|cFFFFFF00LsTweaks:|r Cannot create custom frames in combat.")
                    return
                end
                local new_entry = M.spawn_custom_frame()
                if not new_entry then return end
                rebuild_tree()
                -- Auto-select the new entry's settings panel
                local nk = new_entry.id
                local nfs = node_fs_map[nk]
                if nfs then set_selected(nfs) end
                show_node(nk, function(pnl) M.build_custom_settings_panel(pnl, new_entry) end)
            end)
            add_btn_ref = add_btn
        end

        if update_filters_group_box then
            update_filters_group_box(y)
        end
    end  -- rebuild_tree

    M.on_custom_frame_renamed = function(id, new_name)
        local fs = id and node_fs_map[id]
        if fs then fs:SetText(new_name) end
    end

    -- ----------------------------------------------------------------
    -- PRESET ROWS (static rows, built once above the custom section)
    -- ----------------------------------------------------------------
    local y = -PAD

    local function create_group_box(title, group_key)
        local box = CreateFrame("Frame", nil, tree_frame, "BackdropTemplate")
        M.apply_thin_border_backdrop(box, nil, { r = 0.5, g = 0.5, b = 0.5, a = 0.45 })
        box:Hide()
        if group_key then group_boxes[group_key] = box end

        local title_fs = tree_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title_fs:SetSize(GROUP_TITLE_W, GROUP_TEXT_TITLE_H)
        title_fs:SetJustifyH("CENTER")
        title_fs:SetText(title)
        title_fs:Hide()

        return box, title_fs
    end

    local buffs_group_box, buffs_group_title = create_group_box("Buffs", "buffs")
    local cooldown_group_box = CreateFrame("Frame", nil, tree_frame, "BackdropTemplate")
    M.apply_thin_border_backdrop(cooldown_group_box, nil, { r = 0.5, g = 0.5, b = 0.5, a = 0.45 })
    cooldown_group_box:Hide()
    group_boxes.cooldown = cooldown_group_box
    filters_group_box, filters_group_title = create_group_box("Filters", "filters")

    local function queue_cdm_refreshes()
        M.queue_wow_cooldown_refresh("settings")
    end

    local cooldown_group_title_btn = CreateFrame("Button", nil, tree_frame, "UIPanelButtonTemplate")
    cooldown_group_title_btn:SetSize(GROUP_TITLE_W, GROUP_TITLE_H)
    cooldown_group_title_btn:Hide()
    cooldown_group_title_btn:SetText("WoW Cooldown")
    cooldown_group_title_btn:SetNormalFontObject("GameFontNormalSmall")
    cooldown_group_title_btn:SetHighlightFontObject("GameFontHighlightSmall")
    cooldown_group_title_btn:SetScript("OnClick", function()
        local function hook_cdm_settings_panel(panel)
            if not panel or panel._lstweeks_refresh_hooked then return end
            panel._lstweeks_refresh_hooked = true
            if panel.HookScript then
                panel:HookScript("OnShow", queue_cdm_refreshes)
                panel:HookScript("OnHide", queue_cdm_refreshes)
            end
        end

        M.ensure_blizz_cdm_loaded()

        local panel = _G["CooldownViewerSettings"]
        hook_cdm_settings_panel(panel)
        queue_cdm_refreshes()
        if panel and panel.Show then
            panel:Show()
            if panel.Raise then panel:Raise() end
            return
        end

        if Settings and Settings.OpenToCategory then
            pcall(Settings.OpenToCategory, "Cooldown Viewer")
            -- Give Blizzard's settings panel one short frame-population window before hooking it.
            C_Timer.After(UPDATE_INTERVALS.fifth_sec, function()
                hook_cdm_settings_panel(_G["CooldownViewerSettings"])
                queue_cdm_refreshes()
            end)
        end
    end)

    local sync_cdm_btn = CreateFrame("Button", nil, tree_frame, "UIPanelButtonTemplate")
    sync_cdm_btn:SetSize(GROUP_TITLE_W, SYNC_CDM_H)
    sync_cdm_btn:Hide()
    sync_cdm_btn:SetText("Sync to CDM")
    sync_cdm_btn:SetNormalFontObject("GameFontNormalSmall")
    sync_cdm_btn:SetHighlightFontObject("GameFontHighlightSmall")
    sync_cdm_btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sync to CDM", 1, 1, 1)
        GameTooltip:AddLine("Rebuilds addon cooldown frames from the live WoW Cooldown Manager viewers.", nil, nil, nil, true)
        GameTooltip:AddLine("Use after reordering icons inside a CDM group; group changes usually update automatically.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    sync_cdm_btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    sync_cdm_btn:SetScript("OnClick", function()
        queue_cdm_refreshes()
    end)

    local cooldown_group_top_y
    local cooldown_group_bottom_y
    local buffs_group_top_y
    local buffs_group_bottom_y

    local function place_group_box(box, title_frame, top_y, bottom_y)
        if top_y and bottom_y then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", GROUP_BOX_INSET, top_y)
            box:SetPoint("BOTTOMRIGHT", tree_frame, "TOPLEFT", TREE_W - GROUP_BOX_INSET, bottom_y - GROUP_INNER_PAD)
            box:Show()
            title_frame:ClearAllPoints()
            title_frame:SetPoint("TOP", box, "TOP", 0, -GROUP_INNER_PAD)
            title_frame:Show()
        end
    end

    buffs_group_top_y = y
    y = y - (GROUP_INNER_PAD + GROUP_TEXT_TITLE_H + GROUP_ELEMENT_GAP)
    for _, data in ipairs(frames_data) do
        local cat = data.show_key:sub(6)
        if CD_GROUP_KEYS[cat] and not cooldown_group_top_y then
            buffs_group_bottom_y = y
            y = y - (GROUP_GAP + GROUP_INNER_PAD)
            y = y - CD_GROUP_LABEL_H
            cooldown_group_top_y = y + CD_GROUP_LABEL_H
            cooldown_group_title_btn:Show()
            sync_cdm_btn:Show()
        end
        local learned_key, expanded_key, learned_builder
        local has_learned_child = learned_key ~= nil
        if has_learned_child and M[expanded_key] == nil then M[expanded_key] = true end

        local arrow, arrow_fs
        if has_learned_child then
            arrow = CreateFrame("Button", nil, tree_frame, "UIPanelButtonTemplate")
            arrow:SetSize(ARROW_W, ARROW_W)
            arrow:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", PAD, y)
            arrow:SetNormalFontObject("GameFontNormalLarge")
            arrow_fs = arrow:GetFontString()
            arrow_fs:SetText(M[expanded_key] and "-" or "+")
        end

        local cat_x = has_learned_child and (PAD + ARROW_W + 2) or PAD
        local cat_w = TREE_W - cat_x - PAD
        local cat_btn, cat_fs = make_tree_btn(tree_frame, data.name, cat_x, y, cat_w)
        cat_fs:SetFont(cat_fs:GetFont(), select(2, cat_fs:GetFont()) or 11, "OUTLINE")
        cat_fs._group_key = CD_GROUP_KEYS[cat] and "cooldown" or "buffs"
        node_fs_map[cat] = cat_fs
        cat_btn:SetScript("OnClick", function()
            set_selected(cat_fs)
            show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
        end)

        y = y - (ROW_H + GROUP_ELEMENT_GAP)
        if CD_GROUP_KEYS[cat] then cooldown_group_bottom_y = y end

        if has_learned_child then
            local child_key = learned_key
            local child_btn, child_fs = make_tree_btn(tree_frame, "Learned", PAD + INDENT_CHILD, y, TREE_W - PAD - INDENT_CHILD - PAD)
            node_fs_map[child_key] = child_fs
            child_btn:SetShown(M[expanded_key])
            child_btn:SetScript("OnClick", function()
                set_selected(child_fs)
                invalidate_node(child_key)
                show_node(child_key, learned_builder)
            end)
            if M[expanded_key] then
                y = y - (ROW_H + GROUP_ELEMENT_GAP)
            end

            arrow:SetScript("OnClick", function()
                M[expanded_key] = not M[expanded_key]
                arrow_fs:SetText(M[expanded_key] and "-" or "+")
                child_btn:SetShown(M[expanded_key])

                if not M[expanded_key] and M.db and M.db.last_frames_node == child_key then
                    set_selected(cat_fs)
                    show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
                end

                rebuild_tree()
            end)
        end
    end

    place_group_box(buffs_group_box, buffs_group_title, buffs_group_top_y, buffs_group_bottom_y)

    if cooldown_group_top_y and cooldown_group_bottom_y then
        cooldown_group_box:SetPoint("TOPLEFT", tree_frame, "TOPLEFT", GROUP_BOX_INSET, cooldown_group_top_y)
        cooldown_group_box:SetPoint("BOTTOMRIGHT", tree_frame, "TOPLEFT", TREE_W - GROUP_BOX_INSET, cooldown_group_bottom_y - GROUP_INNER_PAD)
        cooldown_group_box:Show()
        cooldown_group_title_btn:ClearAllPoints()
        cooldown_group_title_btn:SetPoint("TOP", cooldown_group_box, "TOP", 0, -GROUP_INNER_PAD)
        sync_cdm_btn:ClearAllPoints()
        sync_cdm_btn:SetPoint("TOP", cooldown_group_title_btn, "BOTTOM", 0, -GROUP_ELEMENT_GAP)
    end

    y = y - (GROUP_GAP + GROUP_INNER_PAD)
    filters_group_top_y = y
    y = y - (GROUP_INNER_PAD + GROUP_TEXT_TITLE_H + GROUP_ELEMENT_GAP)
    M._filters_add_y = y
    update_filters_group_box = function(bottom_y)
        place_group_box(filters_group_box, filters_group_title, filters_group_top_y, bottom_y)
    end

    -- Build initial custom rows + + Custom button
    rebuild_tree()

    -- ----------------------------------------------------------------
    -- Restore last selected node
    -- ----------------------------------------------------------------
    local last    = (M.db and M.db.last_frames_node) or "static"
    local restored = false

    -- Check preset nodes
    for _, data in ipairs(frames_data) do
        local cat = data.show_key:sub(6)
        if last == cat then
            set_selected(node_fs_map[cat])
            show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
            restored = true
            break
        end
    end

    -- Check custom nodes
    if not restored and M.db and M.db.custom_frames then
        for _, entry in ipairs(M.db.custom_frames) do
            if last == entry.id then
                local fs = node_fs_map[entry.id]
                if fs then set_selected(fs) end
                show_node(entry.id, function(pnl) M.build_custom_settings_panel(pnl, entry) end)
                restored = true
                break
            elseif last == entry.id .. "_filters" then
                local node_key = entry.id .. "_filters"
                local fs = node_fs_map[node_key]
                if fs then set_selected(fs) end
                show_node(node_key, function(pnl) M.build_custom_child_panel(pnl, entry) end)
                restored = true
                break
            end
        end
    end

    -- Fallback to first preset
    if not restored and #frames_data > 0 then
        local data = frames_data[1]
        local cat  = data.show_key:sub(6)
        set_selected(node_fs_map[cat])
        show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
    end

    M.refresh_frames_tree = function()
        local valid_node_keys = {}
        for _, data in ipairs(frames_data) do
            valid_node_keys[data.show_key:sub(6)] = true
        end
        if M.db and M.db.custom_frames then
            for _, entry in ipairs(M.db.custom_frames) do
                if entry.id then
                    valid_node_keys[entry.id] = true
                    valid_node_keys[entry.id .. "_filters"] = true
                end
            end
        end
        for key, panel in pairs(node_panels) do
            if not valid_node_keys[key] then
                panel:Hide()
                if current_panel == panel then current_panel = nil end
                node_panels[key] = nil
            end
        end
        rebuild_tree()
        local last_key = (M.db and M.db.last_frames_node) or "static"
        for _, data in ipairs(frames_data) do
            local cat = data.show_key:sub(6)
            if last_key == cat then
                set_selected(node_fs_map[cat])
                show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
                return
            end
        end
        if M.db and M.db.custom_frames then
            for _, entry in ipairs(M.db.custom_frames) do
                if last_key == entry.id then
                    set_selected(node_fs_map[entry.id])
                    show_node(entry.id, function(pnl) M.build_custom_settings_panel(pnl, entry) end)
                    return
                elseif last_key == entry.id .. "_filters" then
                    local node_key = entry.id .. "_filters"
                    set_selected(node_fs_map[node_key])
                    show_node(node_key, function(pnl) M.build_custom_child_panel(pnl, entry) end)
                    return
                end
            end
        end
        if #frames_data > 0 then
            local data = frames_data[1]
            local cat = data.show_key:sub(6)
            set_selected(node_fs_map[cat])
            show_node(cat, function(pnl) M.build_preset_frame_panel(pnl, data) end)
        end
    end
end
