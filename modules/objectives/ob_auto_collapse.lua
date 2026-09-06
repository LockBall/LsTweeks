-- Objectives Auto-Collapse: startup collapse controls for Blizzard tracker sections.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

M.controls = M.controls or {}

--#region SETTINGS AND DEFAULTS ================================================

local UI_LAYOUT = M.SETTINGS_LAYOUT
local UI_GROUP = UI_LAYOUT.groups.auto_collapse

M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_TITLE = "Activate Auto-Hide"
M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_TEXT =
    "After each login or reload, click every enabled section button twice to activate Auto-Hide."
M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_DISABLE_LABEL = "Activation Reminder"
M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_DISABLE_TEXT =
    "Uncheck this option in Objectives settings to hide this message in the future."

local TRACKER_DEFS = {
    {
        key = "campaign",
        db_key = "collapse_campaign",
        control_key = "collapse_campaign_checkbox",
        label = "Campaign",
        frame_name = "CampaignQuestObjectiveTracker",
        help = "Starts the Campaign contents hidden. A manual expansion stays open until you collapse the section again. Blizzard may retain the section's original layout space.",
    },
    {
        key = "quests",
        db_key = "collapse_quests",
        control_key = "collapse_quests_checkbox",
        label = "Quests",
        frame_name = "QuestObjectiveTracker",
        help = "Starts the Quests contents hidden. A manual expansion stays open until you collapse the section again. Blizzard may retain the section's original layout space.",
    },
    {
        key = "achievements",
        db_key = "collapse_achievements",
        control_key = "collapse_achievements_checkbox",
        label = "Achievements",
        frame_name = "AchievementObjectiveTracker",
        help = "Starts the Achievements contents hidden. A manual expansion stays open until you collapse the section again. Blizzard may retain the section's original layout space.",
    },
}

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local collapse_queued = {}
local collapse_attempts = {}
local deferred_tracker_updates = {}
local last_apply_reason = {}
local manual_expand_buttons = setmetatable({}, { __mode = "k" })
local hooked_minimize_buttons = setmetatable({}, { __mode = "k" })
local manual_open_overrides = {}
local addon_hidden_contents = setmetatable({}, { __mode = "k" })
local activation_tooltip
local activation_tooltip_shown = false

--#endregion RUNTIME STATE =====================================================


--#region DATABASE HELPERS =====================================================

local function is_auto_collapse_enabled(def)
    local db = M.get_db()
    return M.is_runtime_enabled() and db and def and db[def.db_key] == true
end

local function should_auto_collapse(def)
    return is_auto_collapse_enabled(def) and manual_open_overrides[def.key] ~= true
end

--#endregion DATABASE HELPERS ==================================================


--#region TRACKER RUNTIME ======================================================

local function hide_activation_tooltip()
    if not activation_tooltip then return end
    activation_tooltip:Hide()
    addon.ResetOwnedTooltip(activation_tooltip)
end

local function show_activation_tooltip(button)
    if activation_tooltip_shown or not button then return end
    local db = M.get_db()
    if db and db.show_auto_collapse_activation_tooltip == false then return end
    activation_tooltip_shown = true
    activation_tooltip = activation_tooltip or addon.CreateOwnedTooltip(
        addon_name .. "ObjectivesAutoCollapseActivationTooltip"
    )
    addon.ResetOwnedTooltip(activation_tooltip)
    activation_tooltip:SetOwner(button, "ANCHOR_LEFT")
    activation_tooltip:AddLine(M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_TITLE, 1, 0.82, 0)
    activation_tooltip:AddLine(M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_TEXT, 0.95, 0.95, 0.95, true)
    activation_tooltip:AddLine(" ", 0.95, 0.95, 0.95)
    activation_tooltip:AddLine(
        M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_DISABLE_LABEL,
        1, 0.82, 0, false, GameTooltipHeaderText
    )
    activation_tooltip:AddLine(M.AUTO_COLLAPSE_ACTIVATION_TOOLTIP_DISABLE_TEXT, 0.95, 0.95, 0.95, true)
    activation_tooltip:ApplyContentWidth()
    activation_tooltip:Show()
end

local function get_tracker(def)
    local frame = def and _G[def.frame_name]
    if frame and frame.ContentsFrame then
        return frame
    end
    return nil
end

local function show_available_activation_tooltip()
    activation_tooltip_shown = false
    for _, def in ipairs(TRACKER_DEFS) do
        local tracker = get_tracker(def)
        local button = tracker and manual_expand_buttons[tracker]
        if button and button:IsShown() and is_auto_collapse_enabled(def) then
            show_activation_tooltip(button)
            return
        end
    end
end

local function defer_tracker_update(def, action, reason)
    if not def then return end
    collapse_queued[def.key] = false
    deferred_tracker_updates[def.key] = { action = action, reason = reason }
    if M.defer_objectives_combat_update then
        M.defer_objectives_combat_update()
    end
end

local function ensure_manual_toggle_hook(tracker, def)
    local minimize_button = tracker and tracker.Header and tracker.Header.MinimizeButton
    if not minimize_button or hooked_minimize_buttons[minimize_button] then return end

    hooked_minimize_buttons[minimize_button] = true
    minimize_button:HookScript("OnClick", function()
        if get_tracker(def) ~= tracker then return end
        hide_activation_tooltip()

        local is_collapsed = tracker.IsCollapsed and tracker:IsCollapsed() == true
        manual_open_overrides[def.key] = not is_collapsed
        last_apply_reason[def.key] = is_collapsed and "manual collapse" or "manual expand"
    end)
end

local function set_manual_expand_button_shown(tracker, def, shown)
    local button = tracker and manual_expand_buttons[tracker]
    if not shown then
        if button then
            button:Hide()
        end
        return
    end

    local minimize_button = tracker.Header and tracker.Header.MinimizeButton
    if not minimize_button then return end
    ensure_manual_toggle_hook(tracker, def)

    if not button then
        button = CreateFrame("Button", nil, minimize_button, "ObjectiveTrackerModuleMinimizeButtonTemplate")
        button:SetAllPoints(minimize_button)
        button:SetFrameLevel(minimize_button:GetFrameLevel() + 1)
        button:GetNormalTexture():SetAtlas("ui-questtrackerbutton-secondary-expand", true)
        button:GetPushedTexture():SetAtlas("ui-questtrackerbutton-secondary-expand-pressed", true)
        button:SetScript("OnClick", function()
            hide_activation_tooltip()
            local current_tracker = get_tracker(def)
            if current_tracker ~= tracker then
                button:Hide()
                return
            end

            collapse_queued[def.key] = false
            deferred_tracker_updates[def.key] = nil
            manual_open_overrides[def.key] = true
            last_apply_reason[def.key] = "manual expand"
            if addon_hidden_contents[tracker] then
                tracker.ContentsFrame:Show()
                addon_hidden_contents[tracker] = nil
            end
            button:Hide()
        end)
        manual_expand_buttons[tracker] = button
    end

    button:Show()
    show_activation_tooltip(button)
end

local function collapse_tracker(def, reason)
    if not def then return end
    collapse_queued[def.key] = false
    if not should_auto_collapse(def) then return end

    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        defer_tracker_update(def, "collapse", reason)
        return
    end

    local tracker = get_tracker(def)
    if not tracker then return end

    last_apply_reason[def.key] = reason or "unknown"
    ensure_manual_toggle_hook(tracker, def)

    if addon_hidden_contents[tracker] then
        set_manual_expand_button_shown(tracker, def, true)
        return
    end

    if not tracker.ContentsFrame:IsShown() then return end

    tracker.ContentsFrame:Hide()
    addon_hidden_contents[tracker] = true
    set_manual_expand_button_shown(tracker, def, true)
    collapse_attempts[def.key] = (collapse_attempts[def.key] or 0) + 1
end

local function expand_tracker(def, reason)
    if not def then return end
    collapse_queued[def.key] = false

    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        defer_tracker_update(def, "expand", reason)
        return
    end

    local tracker = get_tracker(def)
    if not tracker then return end

    last_apply_reason[def.key] = reason or "unknown"
    set_manual_expand_button_shown(tracker, def, false)

    if addon_hidden_contents[tracker] then
        tracker.ContentsFrame:Show()
        addon_hidden_contents[tracker] = nil
    end
end

local function queue_collapse(def, reason)
    if not def or collapse_queued[def.key] then return end
    if not should_auto_collapse(def) then return end
    collapse_queued[def.key] = true
    local delay = addon.UPDATE_INTERVALS.next_frame
    C_Timer.After(delay, function()
        collapse_tracker(def, reason)
    end)
end

--#endregion TRACKER RUNTIME ===================================================


--#region PUBLIC API ============================================================

function M.apply_auto_collapse()
    for _, def in ipairs(TRACKER_DEFS) do
        local deferred = deferred_tracker_updates[def.key]
        deferred_tracker_updates[def.key] = nil
        if should_auto_collapse(def) then
            local reason = deferred and deferred.reason or "apply"
            queue_collapse(def, reason)
        elseif deferred and deferred.action == "expand" then
            expand_tracker(def, deferred.reason)
        end
    end
end

function M.get_auto_collapse_status()
    local fields = {}
    for _, def in ipairs(TRACKER_DEFS) do
        local tracker = get_tracker(def)
        local prefix = def.key .. "_"
        fields[#fields + 1] = prefix .. "available=" .. tostring(tracker ~= nil)
        fields[#fields + 1] = prefix .. "auto_collapse=" .. tostring(is_auto_collapse_enabled(def) == true)
        fields[#fields + 1] = prefix .. "manual_open=" .. tostring(manual_open_overrides[def.key] == true)
        fields[#fields + 1] = prefix .. "addon_hidden=" .. tostring(tracker ~= nil and addon_hidden_contents[tracker] == true)
        fields[#fields + 1] = prefix .. "contents_shown=" .. tostring(tracker ~= nil and tracker.ContentsFrame:IsShown() == true)
        fields[#fields + 1] = prefix .. "queued=" .. tostring(collapse_queued[def.key] == true)
        fields[#fields + 1] = prefix .. "deferred=" .. tostring(deferred_tracker_updates[def.key] and deferred_tracker_updates[def.key].action or "none")
        fields[#fields + 1] = prefix .. "attempts=" .. tostring(collapse_attempts[def.key] or 0)
        fields[#fields + 1] = prefix .. "last_reason=" .. tostring(last_apply_reason[def.key] or "none")
    end
    return fields
end

function M.get_auto_collapse_activation_tooltip()
    return activation_tooltip
end

function M.restore_auto_collapse(reason)
    hide_activation_tooltip()
    for _, def in ipairs(TRACKER_DEFS) do
        collapse_queued[def.key] = false
        deferred_tracker_updates[def.key] = nil
        manual_open_overrides[def.key] = false
        expand_tracker(def, reason or "module disabled")
    end
end

--#endregion PUBLIC API =========================================================


--#region GUI ==================================================================

local function set_auto_collapse_setting(key, value)
    local db = M.get_db()
    if not db then return end
    db[key] = value == true
    for _, def in ipairs(TRACKER_DEFS) do
        if key == def.db_key then
            manual_open_overrides[def.key] = false
            if db[key] then
                queue_collapse(def, "setting enabled")
            else
                expand_tracker(def, "setting disabled")
            end
            return
        end
    end
end

function M.BuildAutoCollapseSettings(parent)
    local cfg = UI_LAYOUT
    local db = M.get_db()

    local group = addon.CreateSettingsGroup(
        parent,
        "Auto-Collapse",
        UI_GROUP.width,
        UI_GROUP.height,
        cfg.group_offset_x,
        UI_GROUP.offset_y
    )

    local grid = addon.CreateSettingsGrid(group, {
        column_count = 1,
        col_offset = cfg.grid_offset_x,
        row_start = cfg.grid_offset_y,
        col_width = UI_GROUP.grid_col_width,
        col_gap = UI_GROUP.grid_col_gap,
        row_heights = { 100 },
        col_align = { "left" },
        offsets = { default = 0 },
    })

    local widest_content = 0
    local previous_container
    for index, def in ipairs(TRACKER_DEFS) do
        local row_def = def
        local collapse_container, collapse_cb, collapse_label = addon.CreateCheckbox(
            group,
            row_def.label,
            db and db[row_def.db_key] == true,
            function(is_checked)
                set_auto_collapse_setting(row_def.db_key, is_checked)
            end
        )
        M.controls[row_def.control_key] = collapse_container
        if index == 1 then
            grid:place_at(collapse_container, 1, 1)
        else
            grid:stack_below(collapse_container, previous_container, { y = UI_GROUP.child_gap_y })
        end
        addon.AttachTooltip(collapse_label, nil, row_def.help)
        widest_content = math.max(widest_content, collapse_container:GetWidth() or 0)
        previous_container = collapse_container
    end

    local reminder_container, _, reminder_label = addon.CreateCheckbox(
        group,
        "Activation Reminder",
        not db or db.show_auto_collapse_activation_tooltip ~= false,
        function(is_checked)
            local current_db = M.get_db()
            if not current_db then return end
            current_db.show_auto_collapse_activation_tooltip = is_checked == true
            if is_checked then
                show_available_activation_tooltip()
            else
                hide_activation_tooltip()
            end
        end
    )
    grid:stack_below(reminder_container, previous_container, { y = UI_GROUP.child_gap_y })
    addon.AttachTooltip(
        reminder_label,
        nil,
        "Shows the login/reload reminder to click every enabled section button twice to activate Auto-Hide."
    )
    M.controls.show_auto_collapse_activation_tooltip = reminder_container
    widest_content = math.max(widest_content, reminder_container:GetWidth() or 0)

    group:SetWidth(math.ceil(widest_content + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================
