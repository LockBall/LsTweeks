-- Objectives module: applies selected Blizzard Objective Tracker startup states.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

local MODULE_KEY = M.MODULE_KEY or "objectives"
local CATEGORY_NAME = "Objectives"

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = addon.module_defaults and addon.module_defaults.ob or {
    objectives = {
        collapse_all = false,
        collapse_campaign = false,
        collapse_quests = false,
        collapse_achievements = false,
    },
}

local UI_CONFIG = {
    group_offset_x = 20,
    group_offset_y = -20,
    group_height = 158,
    group_padding_x = 12,
    group_title_offset_y = -8,
    first_checkbox_offset_y = -32,
    checkbox_step_y = -32,
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

M.controls = M.controls or {}

local collapse_queued = {}
local collapse_attempts = {}
local last_apply_reason = {}

--#endregion RUNTIME STATE =====================================================


--#region DATABASE HELPERS =====================================================

local function get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.objectives = Ls_Tweeks_DB.objectives or {}
    return Ls_Tweeks_DB.objectives
end

local function is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(MODULE_KEY)
end

local function should_auto_collapse(def)
    local db = get_db()
    return is_runtime_enabled() and db and def and db[def.db_key] == true
end

--#endregion DATABASE HELPERS ==================================================


--#region OBJECTIVE TRACKER RUNTIME ============================================

local function get_tracker(def)
    local frame = def and _G[def.frame_name]
    if frame and frame.SetCollapsed then
        return frame
    end
    return nil
end

local function mark_tracker_dirty(tracker)
    if tracker and tracker.MarkDirty then
        tracker:MarkDirty()
    elseif ObjectiveTrackerManager and ObjectiveTrackerManager.UpdateAll then
        ObjectiveTrackerManager:UpdateAll()
    end
end

local function collapse_tracker(def, reason)
    if not def then return end
    collapse_queued[def.key] = false
    if not should_auto_collapse(def) then return end

    local tracker = get_tracker(def)
    if not tracker then return end

    last_apply_reason[def.key] = reason or "unknown"

    if tracker.IsCollapsed and tracker:IsCollapsed() then
        mark_tracker_dirty(tracker)
        return
    end

    tracker:SetCollapsed(true)
    collapse_attempts[def.key] = (collapse_attempts[def.key] or 0) + 1
end

local function expand_tracker(def, reason)
    if not def then return end
    collapse_queued[def.key] = false

    local tracker = get_tracker(def)
    if not tracker then return end

    last_apply_reason[def.key] = reason or "unknown"

    if tracker.IsCollapsed and not tracker:IsCollapsed() then
        mark_tracker_dirty(tracker)
        return
    end

    tracker:SetCollapsed(false)
end

local function queue_collapse(def, reason)
    if not def or collapse_queued[def.key] then return end
    collapse_queued[def.key] = true
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.next_frame or 0
    C_Timer.After(delay, function()
        collapse_tracker(def, reason)
    end)
end

function M.apply_objectives()
    for _, def in ipairs(TRACKER_DEFS) do
        if should_auto_collapse(def) then
            queue_collapse(def, "apply")
        end
    end
end

local function set_objectives_setting(key, value)
    local db = get_db()
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

--#endregion OBJECTIVE TRACKER RUNTIME =========================================


--#region GUI ==================================================================

function M.BuildSettings(parent)
    local cfg = UI_CONFIG
    local db = get_db()

    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(1, cfg.group_height)
    group:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.group_offset_x, cfg.group_offset_y)
    group:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    group:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    group:SetBackdropColor(0, 0, 0, 0)

    local title = group:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", group, "TOP", 0, cfg.group_title_offset_y)
    title:SetText("Auto-Collapse")
    title:SetTextColor(1, 0.82, 0, 1)

    local widest_content = title:GetStringWidth() or 0
    for index, def in ipairs(TRACKER_DEFS) do
        local row_def = def
        local collapse_container, collapse_cb, collapse_label = addon.CreateCheckbox(
            group,
            row_def.label,
            db and db[row_def.db_key] == true,
            function(is_checked)
                set_objectives_setting(row_def.db_key, is_checked)
            end
        )
        M.controls[row_def.control_key] = collapse_cb
        local indent_x = row_def.key == "all" and 0 or cfg.child_indent_x
        local offset_y = cfg.first_checkbox_offset_y + ((index - 1) * cfg.checkbox_step_y)
        collapse_container:SetPoint("TOPLEFT", group, "TOPLEFT", cfg.group_padding_x + indent_x, offset_y)
        addon.AttachTooltip(collapse_label, nil, row_def.help)
        widest_content = math.max(widest_content, indent_x + (collapse_container:GetWidth() or 0))
    end

    group:SetWidth(math.ceil(widest_content + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================


--#region PUBLIC MODULE HOOKS ==================================================

function M.set_module_enabled(enabled)
    if enabled then
        M.apply_objectives()
    end
end

if addon.register_module_status then
    addon.register_module_status(MODULE_KEY, function()
        local fields = {}
        for _, def in ipairs(TRACKER_DEFS) do
            local tracker = get_tracker(def)
            local prefix = def.key .. "_"
            fields[#fields + 1] = prefix .. "available=" .. tostring(tracker ~= nil)
            fields[#fields + 1] = prefix .. "auto_collapse=" .. tostring(should_auto_collapse(def) == true)
            fields[#fields + 1] = prefix .. "collapsed=" .. tostring(tracker and tracker.IsCollapsed and tracker:IsCollapsed() or false)
            fields[#fields + 1] = prefix .. "queued=" .. tostring(collapse_queued[def.key] == true)
            fields[#fields + 1] = prefix .. "attempts=" .. tostring(collapse_attempts[def.key] or 0)
            fields[#fields + 1] = prefix .. "last_reason=" .. tostring(last_apply_reason[def.key] or "none")
        end
        return fields
    end)
end

--#endregion PUBLIC MODULE HOOKS ===============================================


--#region EVENT BOOTSTRAP ======================================================

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == addon_name then
            Ls_Tweeks_DB = Ls_Tweeks_DB or {}
            addon.apply_defaults(DEFAULTS, Ls_Tweeks_DB)
            if addon.register_category then
                addon.register_category(CATEGORY_NAME, M.BuildSettings, { order = 600, module_key = MODULE_KEY })
            end
        elseif name == "Blizzard_ObjectiveTracker" then
            M.apply_objectives()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.apply_objectives()
        C_Timer.After(addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.fifth_sec or 0.2, function()
            M.apply_objectives()
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

--#endregion EVENT BOOTSTRAP ===================================================
