-- Behavioral tests for Objectives visibility-only Auto-Collapse.
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
        collapse_campaign = false,
        collapse_quests = false,
        collapse_achievements = false,
    }
    for key, value in pairs(overrides or {}) do db[key] = value end
    Ls_Tweeks_DB = { objectives = db, modules = { objectives = true } }
    return db
end

local function reset_runtime()
    stub.in_combat = false
    stub.timers = {}
    M.restore_auto_collapse("test reset")
    stub.timers = {}
    for _, tracker in ipairs(TRACKERS) do
        tracker.__collapsed = false
        tracker.__calls = {}
    end
    CampaignQuestObjectiveTracker.ContentsFrame:Show()
    QuestObjectiveTracker.ContentsFrame:Show()
    AchievementObjectiveTracker.ContentsFrame:Show()
end

local function call_count(frame, method)
    local calls = frame:GetCalls(method)
    return calls and #calls or 0
end

local function get_expand_button(tracker)
    local children = { tracker.Header.MinimizeButton:GetChildren() }
    return children[#children]
end

h.test("auto-collapse hides only configured section contents", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true, collapse_quests = true, collapse_achievements = true })

    M.apply_auto_collapse()
    h.advance(1)

    h.eq(call_count(ObjectiveTrackerFrame, "SetCollapsed"), 0, "parent tracker is never collapsed")
    for index = 2, #TRACKERS do
        local tracker = TRACKERS[index]
        h.eq(call_count(tracker, "SetCollapsed"), 0, "section native collapse is never called")
        h.eq(tracker:IsCollapsed(), false, "Blizzard collapsed state remains untouched")
        h.eq(tracker.ContentsFrame:IsShown(), false, "configured section contents are hidden")
    end
end)

h.test("auto-collapse defers visibility mutation while in combat", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })

    stub.in_combat = true
    M.apply_auto_collapse()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), true, "contents remain shown in combat")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "no native collapse in combat")

    h.leave_combat()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), false, "contents hide after regen")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "no native collapse after regen")
end)

h.test("manual overlay expansion stays open across later apply passes", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })

    M.apply_auto_collapse()
    h.advance(1)
    local expand_button = get_expand_button(CampaignQuestObjectiveTracker)
    h.ok(expand_button and expand_button:IsShown(), "addon expand overlay is available")

    expand_button:Click()
    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), true, "manual overlay click shows contents")

    M.apply_auto_collapse()
    h.advance(1)
    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), true, "later apply preserves manual expansion")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "manual path never calls native collapse")
end)

h.test("manual Blizzard collapse rearms visibility Auto-Collapse", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })

    M.apply_auto_collapse()
    h.advance(1)
    get_expand_button(CampaignQuestObjectiveTracker):Click()

    CampaignQuestObjectiveTracker.__collapsed = true
    CampaignQuestObjectiveTracker.ContentsFrame:Hide()
    CampaignQuestObjectiveTracker.Header.MinimizeButton:Click()

    CampaignQuestObjectiveTracker.__collapsed = false
    CampaignQuestObjectiveTracker.ContentsFrame:Show()
    M.apply_auto_collapse()
    h.advance(1)

    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), false, "manual collapse rearms next visibility apply")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "rearmed path remains visibility-only")
end)

h.test("disabling a setting restores only addon-hidden contents", function()
    reset_runtime()
    local db = fresh_db({ collapse_campaign = true })
    M.apply_auto_collapse()
    h.advance(1)

    local parent = CreateFrame("Frame", nil, UIParent)
    M.BuildAutoCollapseSettings(parent)
    local control = M.controls.collapse_campaign_checkbox
    control:SetChecked(false)
    control.checkbox:Click()

    h.eq(db.collapse_campaign, false, "setting is disabled")
    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), true, "owned visibility is restored")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "setting change avoids native collapse")
end)

h.test("module disable restores visibility owned by Auto-Collapse", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true, collapse_quests = true })
    M.apply_auto_collapse()
    h.advance(1)

    M.restore_auto_collapse("module disabled")

    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), true, "campaign contents are restored")
    h.eq(QuestObjectiveTracker.ContentsFrame:IsShown(), true, "quest contents are restored")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "restore avoids native collapse")
    h.eq(call_count(QuestObjectiveTracker, "SetCollapsed"), 0, "restore avoids native collapse")
end)

h.test("module disable preserves preexisting hidden contents", function()
    reset_runtime()
    fresh_db({ collapse_campaign = true })
    CampaignQuestObjectiveTracker.__collapsed = true
    CampaignQuestObjectiveTracker.ContentsFrame:Hide()

    M.apply_auto_collapse()
    h.advance(1)
    M.restore_auto_collapse("module disabled")

    h.eq(CampaignQuestObjectiveTracker.ContentsFrame:IsShown(), false, "unowned hidden state is preserved")
    h.eq(CampaignQuestObjectiveTracker:IsCollapsed(), true, "preexisting native state is preserved")
    h.eq(call_count(CampaignQuestObjectiveTracker, "SetCollapsed"), 0, "unowned state is never written")
end)

h.test("status distinguishes visibility hiding from native collapse", function()
    reset_runtime()
    fresh_db({ collapse_quests = true })
    M.apply_auto_collapse()
    h.advance(1)

    local status = table.concat(M.get_auto_collapse_status(), ",")
    h.ok(status:find("quests_addon_hidden=true", 1, true), "status reports owned hiding")
    h.ok(status:find("quests_contents_shown=false", 1, true), "status reports hidden contents")
    h.ok(not status:find("native_result", 1, true), "rejected native status is absent")
end)

h.run("ob_auto_collapse")

--#endregion FILE CONTENTS ===================================================
