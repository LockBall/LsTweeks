-- Objectives Auto-Collapse: startup collapse controls for Blizzard tracker sections.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

M.controls = M.controls or {}

--#region SETTINGS AND DEFAULTS ================================================

local UI_CONFIG = {
    group_offset_x = 20,
    group_offset_y = -340,
    group_width = 1,
    group_height = 158,
    group_padding_x = 12,
    grid_offset_x = 12,
    grid_offset_y = -37,
    grid_col_width = 220,
    grid_col_gap = 220,
    child_gap_y = -8,
    child_indent_x = 18,
}

local TRACKER_DEFS = {
    {
        key = "all",
        db_key = "collapse_all",
        control_key = "collapse_all_checkbox",
        label = "All Objectives",
        frame_name = "ObjectiveTrackerFrame",
        help = "Collapses the All Objectives tracker when LsTweeks applies settings. You can still open and close it manually afterward.",
    },
    {
        key = "campaign",
        db_key = "collapse_campaign",
        control_key = "collapse_campaign_checkbox",
        label = "Campaign",
        frame_name = "CampaignQuestObjectiveTracker",
        help = "Collapses the Campaign section when LsTweeks applies settings. You can still open and close it manually afterward.",
    },
    {
        key = "quests",
        db_key = "collapse_quests",
        control_key = "collapse_quests_checkbox",
        label = "Quests",
        frame_name = "QuestObjectiveTracker",
        help = "Collapses the Quests section when LsTweeks applies settings. You can still open and close it manually afterward.",
    },
    {
        key = "achievements",
        db_key = "collapse_achievements",
        control_key = "collapse_achievements_checkbox",
        label = "Achievements",
        frame_name = "AchievementObjectiveTracker",
        help = "Collapses the Achievements section when LsTweeks applies settings. You can still open and close it manually afterward.",
    },
}

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local collapse_queued = {}
local collapse_attempts = {}
local deferred_tracker_updates = {}
local last_apply_reason = {}

--#endregion RUNTIME STATE =====================================================


--#region DATABASE HELPERS =====================================================

local function should_auto_collapse(def)
    local db = M.get_db()
    return M.is_runtime_enabled() and db and def and db[def.db_key] == true
end

--#endregion DATABASE HELPERS ==================================================


--#region TRACKER RUNTIME ======================================================

local function get_tracker(def)
    local frame = def and _G[def.frame_name]
    if frame and frame.SetCollapsed then
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

    if tracker.IsCollapsed and tracker:IsCollapsed() then
        return
    end

    tracker:SetCollapsed(true)
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

    if tracker.IsCollapsed and not tracker:IsCollapsed() then
        return
    end

    tracker:SetCollapsed(false)
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
        fields[#fields + 1] = prefix .. "auto_collapse=" .. tostring(should_auto_collapse(def) == true)
        fields[#fields + 1] = prefix .. "collapsed=" .. tostring(tracker and tracker.IsCollapsed and tracker:IsCollapsed() or false)
        fields[#fields + 1] = prefix .. "queued=" .. tostring(collapse_queued[def.key] == true)
        fields[#fields + 1] = prefix .. "deferred=" .. tostring(deferred_tracker_updates[def.key] and deferred_tracker_updates[def.key].action or "none")
        fields[#fields + 1] = prefix .. "attempts=" .. tostring(collapse_attempts[def.key] or 0)
        fields[#fields + 1] = prefix .. "last_reason=" .. tostring(last_apply_reason[def.key] or "none")
    end
    return fields
end

--#endregion PUBLIC API =========================================================


--#region GUI ==================================================================

local function set_auto_collapse_setting(key, value)
    local db = M.get_db()
    if not db then return end
    db[key] = value == true
    for _, def in ipairs(TRACKER_DEFS) do
        if key == def.db_key then
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
    local cfg = UI_CONFIG
    local db = M.get_db()

    local group = addon.CreateSettingsGroup(
        parent,
        "Auto-Collapse",
        cfg.group_width,
        cfg.group_height,
        cfg.group_offset_x,
        cfg.group_offset_y
    )

    local grid = addon.CreateSettingsGrid(group, {
        column_count = 1,
        col_offset = cfg.grid_offset_x,
        row_start = cfg.grid_offset_y,
        col_width = cfg.grid_col_width,
        col_gap = cfg.grid_col_gap,
        row_heights = { 100 },
        col_align = { "left" },
        offsets = { default = 0 },
    })

    local widest_content = 0
    local previous_container
    local previous_indent_x = 0
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
        local indent_x = row_def.key == "all" and 0 or cfg.child_indent_x
        if index == 1 then
            grid:place_at(collapse_container, 1, 1)
        else
            grid:stack_below(collapse_container, previous_container, { x = indent_x - previous_indent_x, y = cfg.child_gap_y })
        end
        addon.AttachTooltip(collapse_label, nil, row_def.help)
        widest_content = math.max(widest_content, indent_x + (collapse_container:GetWidth() or 0))
        previous_container = collapse_container
        previous_indent_x = indent_x
    end

    group:SetWidth(math.ceil(widest_content + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================
