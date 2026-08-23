-- Objectives Auto-Collapse: startup collapse controls for Blizzard tracker sections.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

M.controls = M.controls or {}

--#region SETTINGS AND DEFAULTS ================================================

local UI_LAYOUT = M.SETTINGS_LAYOUT
local UI_GROUP = UI_LAYOUT.groups.auto_collapse

local TRACKER_DEFS = {
    {
        key = "campaign",
        db_key = "collapse_campaign",
        control_key = "collapse_campaign_checkbox",
        label = "Campaign",
        frame_name = "CampaignQuestObjectiveTracker",
        help = "Starts the Campaign section hidden. A manual expansion stays open until you collapse the section again.",
    },
    {
        key = "quests",
        db_key = "collapse_quests",
        control_key = "collapse_quests_checkbox",
        label = "Quests",
        frame_name = "QuestObjectiveTracker",
        help = "Starts the Quests section hidden. A manual expansion stays open until you collapse the section again.",
    },
    {
        key = "achievements",
        db_key = "collapse_achievements",
        control_key = "collapse_achievements_checkbox",
        label = "Achievements",
        frame_name = "AchievementObjectiveTracker",
        help = "Starts the Achievements section hidden. A manual expansion stays open until you collapse the section again.",
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
local native_experiment = {
    pending = false,
    requests = 0,
    last_action = "none",
    result = "idle",
}

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

local function get_tracker(def)
    local frame = def and _G[def.frame_name]
    if frame and frame.ContentsFrame then
        return frame
    end
    return nil
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
            local current_tracker = get_tracker(def)
            if current_tracker ~= tracker then
                button:Hide()
                return
            end

            collapse_queued[def.key] = false
            deferred_tracker_updates[def.key] = nil
            manual_open_overrides[def.key] = true
            last_apply_reason[def.key] = "manual expand"
            if not tracker.ContentsFrame:IsShown() then
                tracker.ContentsFrame:Show()
            end
            button:Hide()
        end)
        manual_expand_buttons[tracker] = button
    end

    button:Show()
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
    set_manual_expand_button_shown(tracker, def, true)

    if not tracker.ContentsFrame:IsShown() then
        return
    end

    tracker.ContentsFrame:Hide()
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

    if tracker.ContentsFrame:IsShown() then
        return
    end

    tracker.ContentsFrame:Show()
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
        local is_collapsed = tracker ~= nil and not tracker.ContentsFrame:IsShown()
        fields[#fields + 1] = prefix .. "collapsed=" .. tostring(is_collapsed)
        fields[#fields + 1] = prefix .. "queued=" .. tostring(collapse_queued[def.key] == true)
        fields[#fields + 1] = prefix .. "deferred=" .. tostring(deferred_tracker_updates[def.key] and deferred_tracker_updates[def.key].action or "none")
        fields[#fields + 1] = prefix .. "attempts=" .. tostring(collapse_attempts[def.key] or 0)
        fields[#fields + 1] = prefix .. "last_reason=" .. tostring(last_apply_reason[def.key] or "none")
    end
    local quest_tracker = get_tracker(TRACKER_DEFS[2])
    fields[#fields + 1] = "native_experiment_pending=" .. tostring(native_experiment.pending == true)
    fields[#fields + 1] = "native_experiment_requests=" .. tostring(native_experiment.requests)
    fields[#fields + 1] = "native_experiment_last_action=" .. native_experiment.last_action
    fields[#fields + 1] = "native_experiment_result=" .. native_experiment.result
    fields[#fields + 1] = "native_experiment_quest_collapsed="
        .. tostring(quest_tracker and quest_tracker.IsCollapsed and quest_tracker:IsCollapsed() == true or false)
    return fields
end

function M.run_native_collapse_experiment(action)
    action = type(action) == "string" and action:lower() or ""
    if action ~= "collapse" and action ~= "expand" then
        return false, "usage: /lst obnative collapse|expand"
    end

    local def = TRACKER_DEFS[2]
    native_experiment.last_action = action
    if native_experiment.pending then
        native_experiment.result = "already_pending"
        return false, "a native collapse experiment is already pending"
    end
    if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
        native_experiment.result = "combat_blocked"
        return false, "native collapse experiment refused during combat"
    end
    if is_auto_collapse_enabled(def) then
        native_experiment.result = "auto_collapse_enabled"
        return false, "turn off LsTweeks Quests Auto-Collapse before running this experiment"
    end

    local tracker = get_tracker(def)
    if not tracker or type(tracker.SetCollapsed) ~= "function" or type(securecall) ~= "function" then
        native_experiment.result = "unavailable"
        return false, "Quest tracker or securecall is unavailable"
    end

    native_experiment.pending = true
    native_experiment.result = "queued"
    C_Timer.After(addon.UPDATE_INTERVALS.next_frame, function()
        native_experiment.pending = false
        if M.is_objectives_combat_locked and M.is_objectives_combat_locked() then
            native_experiment.result = "combat_blocked"
            print("|cff33ff99LsTweeks Objectives experiment|r: refused because combat started")
            return
        end

        local current_tracker = get_tracker(def)
        if current_tracker ~= tracker or type(current_tracker.SetCollapsed) ~= "function" then
            native_experiment.result = "tracker_changed"
            print("|cff33ff99LsTweeks Objectives experiment|r: Quest tracker changed before execution")
            return
        end

        local desired_collapsed = action == "collapse"
        native_experiment.requests = native_experiment.requests + 1
        securecall(current_tracker.SetCollapsed, current_tracker, desired_collapsed)

        local actual_collapsed = current_tracker.IsCollapsed and current_tracker:IsCollapsed() == true
        native_experiment.result = actual_collapsed == desired_collapsed and "applied" or "state_mismatch"
        print(
            "|cff33ff99LsTweeks Objectives experiment|r: "
                .. action .. " result=" .. native_experiment.result
        )
    end)

    return true, "queued native " .. action .. " for Quests on the next frame"
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

    group:SetWidth(math.ceil(widest_content + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================
