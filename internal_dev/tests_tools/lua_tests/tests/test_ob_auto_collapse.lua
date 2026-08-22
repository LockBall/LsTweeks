-- Behavioral tests for Objectives Auto-Collapse combat deferral.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.load_addon("modules/objectives")

local M = h.addon.objectives

---@class TestObjectiveTrackerHeader : Frame
---@field MinimizeButton Button

---@class TestObjectiveTracker : ObjectiveTrackerFrame
---@field __collapsed boolean
---@field __calls table<string, table[]>
---@field Header TestObjectiveTrackerHeader
---@field GetCalls fun(self: TestObjectiveTracker, method: string): table[]?
---@field GetLastCall fun(self: TestObjectiveTracker, method: string): table?
local TRACKERS = {
    ObjectiveTrackerFrame,
    CampaignQuestObjectiveTracker,
    QuestObjectiveTracker,
    AchievementObjectiveTracker,
}

local function fresh_db(overrides)
    local db = {
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
        ---@cast tracker TestObjectiveTracker
        tracker.__collapsed = false
        tracker.__calls = {}
    end
    ObjectiveTrackerManager.__calls = {}
end

local function call_count(frame, method)
    local calls = frame:GetCalls(method)
    return calls and #calls or 0
end

h.test("auto-collapse apply defers tracker mutation while in combat", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })

    stub.in_combat = true
    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "native collapse is deferred in combat")
    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), false, "tracker unchanged in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true, "tracker collapsed after regen")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 1, "one deferred native collapse call")
end)

h.test("auto-collapse uses native securecall only on configured section trackers", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true, collapse_quests = true, collapse_achievements = true })

    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "parent tracker is never collapsed")
    for index = 2, #TRACKERS do
        local tracker = TRACKERS[index]
        h.eq(call_count(tracker, "SetCollapsed"), 1,
            "one native collapse on " .. (tracker.GetName and tracker:GetName() or "?"))
        h.eq(tracker:IsCollapsed(), true, "configured section reaches native collapsed state")
    end
end)

h.test("manual native expansion stays open until manual collapse rearms auto-collapse", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })

    M.apply_auto_collapse()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true, "section starts natively collapsed")
    CampaignQuestObjectiveTracker.__collapsed = false
    CampaignQuestObjectiveTracker.Header.MinimizeButton:Click()

    M.apply_auto_collapse()
    h.advance(1)
    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), false,
        "later apply passes preserve a manual expansion")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 1,
        "manual-open override prevents another native collapse")

    CampaignQuestObjectiveTracker.__collapsed = true
    CampaignQuestObjectiveTracker.Header.MinimizeButton:Click()
    CampaignQuestObjectiveTracker.__collapsed = false
    M.apply_auto_collapse()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true,
        "a manual Blizzard collapse rearms auto-collapse")
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
    local db = fresh_db({ collapse_campaign = true })
    CampaignQuestObjectiveTracker.__collapsed = true

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildAutoCollapseSettings(parent)

    stub.in_combat = true
    local control = M.controls.collapse_campaign_checkbox
    control:SetChecked(false)
    control.checkbox:Click()

    h.eq(db.collapse_campaign, false, "setting saved immediately")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "no in-combat expand call")
    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true, "tracker still collapsed in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), false, "tracker expanded after regen")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 1, "one deferred native expand call")
end)

h.test("already-satisfied auto-collapse state skips redundant native collapse", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })
    CampaignQuestObjectiveTracker.__collapsed = true

    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "no redundant native collapse call")
end)

h.test("already-expanded disabled setting skips redundant show", function()
    reset_runtime()
    local db = fresh_db({ collapse_campaign = true })

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildAutoCollapseSettings(parent)

    db.collapse_campaign = true
    local control = M.controls.collapse_campaign_checkbox
    control:SetChecked(false)
    control.checkbox:Click()

    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "no redundant native expand call")
end)

h.test("module-disable restore expands sections owned by Auto-Collapse", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true, collapse_quests = true })

    M.apply_auto_collapse()
    h.advance(1)
    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true, "campaign starts collapsed")
    h.eq(QuestObjectiveTracker:IsCollapsed(), true, "quests start collapsed")

    M.restore_auto_collapse("module disabled")

    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), false, "campaign expands on module disable")
    h.eq(QuestObjectiveTracker:IsCollapsed(), false, "quests expand on module disable")
end)

h.test("native collapse experiment is manual, deferred, and isolated from Auto-Collapse", function()
    reset_runtime()
    fresh_db()

    local queued, message = M.run_native_collapse_experiment("collapse")
    h.eq(queued, true, message)
    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 0, "native experiment waits until the next frame")

    h.advance(1)

    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 1, "native experiment makes one explicit collapse call")
    h.eq(QuestObjectiveTracker:IsCollapsed(), true, "native experiment reaches Blizzard collapsed state")

    local status = table.concat(M.get_auto_collapse_status(), ",")
    h.ok(status:find("native_experiment_result=applied", 1, true), "native result is visible in status")
    h.ok(status:find("native_experiment_requests=1", 1, true), "native request count is visible in status")
end)

h.test("native collapse experiment refuses combat", function()
    reset_runtime()
    fresh_db()
    stub.in_combat = true

    local queued = M.run_native_collapse_experiment("expand")

    h.eq(queued, false, "native experiment is not queued in combat")
    h.advance(1)
    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 0, "native experiment never calls collapse in combat")
end)

h.run("ob_auto_collapse")

--#endregion FILE CONTENTS ===================================================
