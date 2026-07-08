-- Behavioral tests for Objectives Auto-Collapse combat deferral.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.load_addon("modules/objectives")

local M = h.addon.objectives
local TRACKERS = {
    ObjectiveTrackerFrame,
    CampaignQuestObjectiveTracker,
    QuestObjectiveTracker,
    AchievementObjectiveTracker,
}

local function fresh_db(overrides)
    local db = {
        collapse_all = false,
        collapse_campaign = false,
        collapse_quests = false,
        collapse_achievements = false,
    }
    for k, v in pairs(overrides or {}) do db[k] = v end
    Ls_Tweeks_DB = { objectives = db, modules = { objectives = true } }
    return db
end

local function reset_runtime()
    stub.in_combat = false
    stub.timers = {}
    for _, tracker in ipairs(TRACKERS) do
        tracker.__collapsed = false
        tracker.__calls = {}
    end
    ObjectiveTrackerManager.__calls = {}
end

local function call_count(frame, method)
    local calls = frame:GetCalls(method)
    return calls and #calls or 0
end

local function manager_call_count(method)
    local calls = ObjectiveTrackerManager:GetCalls(method)
    return calls and #calls or 0
end

h.test("auto-collapse apply defers tracker mutation while in combat", function()
    reset_runtime()
    fresh_db({ collapse_all = true })

    stub.in_combat = true
    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "no in-combat collapse call")
    h.eq(ObjectiveTrackerFrame:IsCollapsed(), false, "tracker unchanged in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(ObjectiveTrackerFrame:IsCollapsed(), true, "tracker collapsed after regen")
    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 1, "one deferred collapse call")
end)

h.test("queued auto-collapse rechecks combat before timer fires", function()
    reset_runtime()
    fresh_db({ collapse_quests = true })

    M.apply_auto_collapse()
    stub.in_combat = true
    h.advance(1)

    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 0, "timer did not collapse in combat")
    h.eq(QuestObjectiveTracker:IsCollapsed(), false, "quest tracker unchanged in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(QuestObjectiveTracker:IsCollapsed(), true, "quest tracker collapsed after regen")
    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 1, "one deferred quest collapse call")
end)

h.test("disabling auto-collapse in combat defers tracker expansion", function()
    reset_runtime()
    local db = fresh_db({ collapse_all = true })
    ObjectiveTrackerFrame.__collapsed = true

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildAutoCollapseSettings(parent)

    stub.in_combat = true
    local control = M.controls.collapse_all_checkbox
    control:SetChecked(false)
    control.checkbox:Click()

    h.eq(db.collapse_all, false, "setting saved immediately")
    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "no in-combat expand call")
    h.eq(ObjectiveTrackerFrame:IsCollapsed(), true, "tracker still collapsed in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(ObjectiveTrackerFrame:IsCollapsed(), false, "tracker expanded after regen")
    local last_call = ObjectiveTrackerFrame:GetLastCall("SetCollapsed")
    h.eq(last_call and last_call[1], false, "deferred call expands")
end)

h.test("already-satisfied auto-collapse state skips dirty relayout", function()
    reset_runtime()
    fresh_db({ collapse_all = true })
    ObjectiveTrackerFrame.__collapsed = true

    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "no redundant collapse call")
    h.eq(call_count(ObjectiveTrackerFrame, "MarkDirty"), 0, "no dirty mark on already collapsed tracker")
    h.eq(manager_call_count("UpdateAll"), 0, "no manager relayout fallback")
end)

h.test("already-expanded disabled setting skips dirty relayout", function()
    reset_runtime()
    local db = fresh_db({ collapse_all = true })

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildAutoCollapseSettings(parent)

    db.collapse_all = true
    local control = M.controls.collapse_all_checkbox
    control:SetChecked(false)
    control.checkbox:Click()

    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "no redundant expand call")
    h.eq(call_count(ObjectiveTrackerFrame, "MarkDirty"), 0, "no dirty mark on already expanded tracker")
    h.eq(manager_call_count("UpdateAll"), 0, "no manager relayout fallback")
end)

h.run("ob_auto_collapse")

--#endregion FILE CONTENTS ===================================================
