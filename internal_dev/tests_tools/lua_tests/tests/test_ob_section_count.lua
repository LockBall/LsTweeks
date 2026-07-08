-- Behavioral tests for Objectives section-count helper contracts.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/objectives")

local M = h.addon.objectives

local function reset_runtime()
    h.stub.timers = {}
    QuestObjectiveTracker.Header = CreateFrame("Frame", nil, QuestObjectiveTracker)
    QuestObjectiveTracker.Header.Text = QuestObjectiveTracker.Header:CreateFontString()
    QuestObjectiveTracker.Header.Text:SetText("Quests")
    QuestObjectiveTracker.headerText = "Quests"
end

local function find_upvalue(fn, wanted_name)
    local index = 1
    while true do
        local name, value = debug.getupvalue(fn, index)
        if not name then return nil end
        if name == wanted_name then return value end
        index = index + 1
    end
end

h.test("disabled count settings return four explicit false values", function()
    Ls_Tweeks_DB = { objectives = {}, modules = { objectives = false } }
    local get_count_settings = find_upvalue(M.get_section_count_status, "get_count_settings")
    h.ok(type(get_count_settings) == "function", "get_count_settings upvalue found")

    h.eq(select("#", get_count_settings()), 4, "disabled arity")
    local quest, achievement, quest_hover, achievement_hover = get_count_settings()
    h.eq(quest, false, "quest count disabled")
    h.eq(achievement, false, "achievement count disabled")
    h.eq(quest_hover, false, "quest hover disabled")
    h.eq(achievement_hover, false, "achievement hover disabled")
end)

h.test("quest log event bursts coalesce before scanning", function()
    reset_runtime()
    Ls_Tweeks_DB = {
        objectives = { show_quest_log_count = true },
        modules = { objectives = true },
    }

    local get_info_calls = 0
    C_QuestLog = {
        GetNumQuestLogEntries = function() return 2 end,
        GetInfo = function(index)
            get_info_calls = get_info_calls + 1
            return { questID = index, isHeader = false, isHidden = false, isTask = false, isBounty = false }
        end,
        GetMaxNumQuestsCanAccept = function() return 35 end,
        IsWorldQuest = function() return false end,
    }

    M.apply_section_count()
    h.advance(h.addon.UPDATE_INTERVALS.next_frame)
    get_info_calls = 0

    h.fire_event("QUEST_LOG_UPDATE")
    h.fire_event("QUEST_LOG_UPDATE")
    h.fire_event("QUEST_LOG_UPDATE")
    h.advance(h.addon.UPDATE_INTERVALS.next_frame)
    h.eq(get_info_calls, 0, "event bucket has not scanned at next frame")

    h.advance(h.addon.UPDATE_INTERVALS.objectives_title_event_bucket)
    h.eq(get_info_calls, 2, "one coalesced quest scan")
    h.eq(QuestObjectiveTracker.Header.Text:GetText(), "Quests  (2 / 35)", "quest count updated")
end)

h.run("ob_section_count")

--#endregion FILE CONTENTS ===================================================
