-- Objectives Section Count: optional low-cost counters in Blizzard tracker titles.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

M.controls = M.controls or {}

--#region SETTINGS AND DEFAULTS ================================================

local UI_CONFIG = {
    group_offset_x = 20,
    group_offset_y = -194,
    group_height = 112,
    group_padding_x = 12,
    group_title_offset_y = -8,
    first_checkbox_offset_y = -32,
    sub_checkbox_offset_y = -24,
    second_column_offset_x = 122,
    sub_checkbox_indent_x = 18,
}

local TITLE_COUNT_DEFS = {
    {
        key = "quests",
        frame_name = "QuestObjectiveTracker",
        base_label = "Quests",
    },
    {
        key = "achievements",
        frame_name = "AchievementObjectiveTracker",
        base_label = "Achievements",
    },
}

local COUNT_TEXT_FORMAT = "%d / %d"
local TITLE_COUNT_FORMAT = "%s  (%s)"

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local title_sync_queued = false
local title_event_frame
local title_last_reason = "none"
local title_last_state = "unavailable"
local title_applied_counts = {}
local title_hovered = {}
local title_hover_hooks = setmetatable({}, { __mode = "k" })
local title_last_text = {}
local title_last_signature = {}
local title_events_registered = {
    quests = false,
    achievements = false,
}

--#endregion RUNTIME STATE =====================================================


--#region DATABASE HELPERS =====================================================

local function get_count_settings()
    local db = M.get_db()
    if not M.is_runtime_enabled() or not db then
        return false, false
    end

    local show_quest_log = db.show_quest_log_count == true
    local quest_log_on_hover = db.show_quest_log_count_on_hover == true
    local show_tracked_achievements = db.show_tracked_achievement_count == true
    local tracked_achievements_on_hover = db.show_tracked_achievement_count_on_hover == true

    return show_quest_log, show_tracked_achievements, quest_log_on_hover, tracked_achievements_on_hover
end

local function should_show_section_counts()
    local show_quest_log, show_tracked_achievements = get_count_settings()
    return show_quest_log or show_tracked_achievements
end

local function has_applied_counts()
    for _, applied in pairs(title_applied_counts) do
        if applied then return true end
    end
    return false
end

--#endregion DATABASE HELPERS ==================================================


--#region COUNTS AND TITLE SYNC ================================================

local queue_title_sync

local function get_title_module(def)
    local module = def and _G[def.frame_name]
    if module and module.Header and module.Header.Text then
        return module
    end
    return nil
end

local function get_title_base_text(def, module)
    if module and module.headerText then
        return module.headerText
    end
    return def.base_label
end

local function get_quest_log_counts()
    if not C_QuestLog then return nil, nil end

    local count
    if C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local num_entries = C_QuestLog.GetNumQuestLogEntries()
        count = 0
        for index = 1, num_entries do
            local info = C_QuestLog.GetInfo(index)
            if info and info.questID and not info.isHeader and not info.isHidden and not info.isTask
                and not info.isBounty and not info.isInternalOnly
                and (not C_QuestLog.IsWorldQuest or not C_QuestLog.IsWorldQuest(info.questID)) then
                count = count + 1
            end
        end
    end

    local max_count
    if C_QuestLog.GetMaxNumQuestsCanAccept then
        max_count = C_QuestLog.GetMaxNumQuestsCanAccept()
    end

    return count, max_count
end

local function get_tracked_achievement_counts()
    local count
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs and Enum and Enum.ContentTrackingType then
        local tracked = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
        count = tracked and #tracked or 0
    end

    local max_count = Constants and Constants.ContentTrackingConsts and Constants.ContentTrackingConsts.MaxTrackedAchievements
    return count, max_count
end

local function format_count_text(count, max_count)
    if type(count) == "number" and type(max_count) == "number" and max_count > 0 then
        return string.format(COUNT_TEXT_FORMAT, count, max_count)
    elseif type(count) == "number" then
        return tostring(count)
    end
    return nil
end

local function format_count_title(base_text, count_parts)
    if count_parts and #count_parts > 0 then
        return string.format(TITLE_COUNT_FORMAT, base_text, table.concat(count_parts, ", "))
    end
    return base_text
end

local function is_count_enabled(def, show_quest_log, show_tracked_achievements)
    if def.key == "quests" then
        return show_quest_log
    elseif def.key == "achievements" then
        return show_tracked_achievements
    end
    return false
end

local function is_hover_only(def, quest_log_on_hover, tracked_achievements_on_hover)
    if def.key == "quests" then
        return quest_log_on_hover
    elseif def.key == "achievements" then
        return tracked_achievements_on_hover
    end
    return false
end

local function is_count_hover_only(def)
    local show_quest_log, show_tracked_achievements, quest_log_on_hover, tracked_achievements_on_hover = get_count_settings()
    return is_count_enabled(def, show_quest_log, show_tracked_achievements)
        and is_hover_only(def, quest_log_on_hover, tracked_achievements_on_hover)
end

local function is_title_hovered(def, module)
    local header = module and module.Header
    return title_hovered[def.key] == true or (header and header.IsMouseOver and header:IsMouseOver()) == true
end

local function hook_title_hover(def, module)
    local header = module and module.Header
    if not header or title_hover_hooks[header] or not header.HookScript then return end

    title_hover_hooks[header] = true
    header:HookScript("OnEnter", function()
        if not M.is_runtime_enabled() or not is_count_hover_only(def) then return end
        title_hovered[def.key] = true
        queue_title_sync("title hover")
    end)
    header:HookScript("OnLeave", function()
        title_hovered[def.key] = false
        if not M.is_runtime_enabled() or (not is_count_hover_only(def) and not title_applied_counts[def.key]) then return end
        queue_title_sync("title leave")
    end)
end

local function sync_section_titles(reason)
    title_sync_queued = false
    title_last_reason = reason or "unknown"

    local updated = 0
    local missing = 0
    local shown = 0

    local show_quest_log, show_tracked_achievements, quest_log_on_hover, tracked_achievements_on_hover = get_count_settings()

    for _, def in ipairs(TITLE_COUNT_DEFS) do
        local module = get_title_module(def)
        if module then
            hook_title_hover(def, module)

            local base_text = get_title_base_text(def, module)
            local count_parts = {}
            local show_count = is_count_enabled(def, show_quest_log, show_tracked_achievements)
            local hover_only = is_hover_only(def, quest_log_on_hover, tracked_achievements_on_hover)
            local should_show_count = show_count and (not hover_only or is_title_hovered(def, module))
            if should_show_count and def.key == "quests" then
                if show_quest_log then
                    local count, max_count = get_quest_log_counts()
                    local text = format_count_text(count, max_count)
                    if text then count_parts[#count_parts + 1] = text end
                end
            elseif should_show_count and def.key == "achievements" then
                if show_tracked_achievements then
                    local count, max_count = get_tracked_achievement_counts()
                    local text = format_count_text(count, max_count)
                    if text then count_parts[#count_parts + 1] = text end
                end
            end

            local text = format_count_title(base_text, count_parts)
            local signature = table.concat(count_parts, "|")
            if #count_parts > 0 then
                local current_text = module.Header.Text:GetText()
                if title_last_signature[def.key] ~= signature or title_last_text[def.key] ~= text or current_text ~= text then
                    module.Header.Text:SetText(text)
                    title_last_signature[def.key] = signature
                    title_last_text[def.key] = text
                end
                title_applied_counts[def.key] = true
                shown = shown + 1
            elseif title_applied_counts[def.key] then
                module.Header.Text:SetText(text)
                title_applied_counts[def.key] = false
                title_last_signature[def.key] = nil
                title_last_text[def.key] = nil
            end

            updated = updated + 1
        else
            missing = missing + 1
        end
    end

    if not M.is_runtime_enabled() then
        title_last_state = "module_disabled"
    elseif updated > 0 and missing > 0 then
        title_last_state = "partial"
    elseif updated > 0 then
        title_last_state = shown > 0 and "shown" or "restored"
    else
        title_last_state = "unavailable"
    end
end

queue_title_sync = function(reason)
    if title_sync_queued then return end
    title_sync_queued = true
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.next_frame or 0
    C_Timer.After(delay, function()
        sync_section_titles(reason)
    end)
end

--#endregion COUNTS AND TITLE SYNC =============================================


--#region EVENT REGISTRATION ===================================================

local function ensure_title_event_frame()
    if title_event_frame then return end

    title_event_frame = CreateFrame("Frame")
    title_event_frame:SetScript("OnEvent", function(_, event)
        queue_title_sync(event)
    end)
end

local function set_title_events(group, register, events)
    if title_events_registered[group] == register then return end

    for _, event in ipairs(events) do
        if register then
            title_event_frame:RegisterEvent(event)
        else
            title_event_frame:UnregisterEvent(event)
        end
    end

    title_events_registered[group] = register
end

local function update_title_event_registrations()
    ensure_title_event_frame()

    local show_quest_log, show_tracked_achievements = get_count_settings()
    set_title_events("quests", show_quest_log, {
        "QUEST_ACCEPTED",
        "QUEST_LOG_UPDATE",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
    })
    set_title_events("achievements", show_tracked_achievements, {
        "CONTENT_TRACKING_UPDATE",
        "TRACKED_ACHIEVEMENT_LIST_CHANGED",
        "ACHIEVEMENT_EARNED",
    })
end

--#endregion EVENT REGISTRATION ================================================


--#region PUBLIC API ============================================================

function M.apply_section_count()
    update_title_event_registrations()
    if should_show_section_counts() or has_applied_counts() then
        queue_title_sync("section count apply")
    end
end

function M.set_section_count_module_enabled(enabled)
    update_title_event_registrations()
    if not enabled and has_applied_counts() then
        queue_title_sync("module disabled")
    end
end

function M.get_section_count_status()
    return {
        "title_counts=" .. tostring(should_show_section_counts() == true),
        "title_quest_events=" .. tostring(title_events_registered.quests == true),
        "title_achievement_events=" .. tostring(title_events_registered.achievements == true),
        "title_quest_hover_only=" .. tostring(select(3, get_count_settings()) == true),
        "title_achievement_hover_only=" .. tostring(select(4, get_count_settings()) == true),
        "title_quest_hovered=" .. tostring(title_hovered.quests == true),
        "title_achievement_hovered=" .. tostring(title_hovered.achievements == true),
        "title_state=" .. tostring(title_last_state),
        "title_last_reason=" .. tostring(title_last_reason),
    }
end

--#endregion PUBLIC API =========================================================


--#region GUI ==================================================================

local function set_count_setting(key, value)
    local db = M.get_db()
    if not db then return end
    db[key] = value == true
    ensure_title_event_frame()
    update_title_event_registrations()
    queue_title_sync("count setting changed")
end

function M.BuildSectionCountSettings(parent)
    local cfg = UI_CONFIG
    local count_group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    count_group:SetSize(1, cfg.group_height)
    count_group:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.group_offset_x, cfg.group_offset_y)
    count_group:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    count_group:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    count_group:SetBackdropColor(0, 0, 0, 0)

    local count_title = count_group:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    count_title:SetPoint("TOP", count_group, "TOP", 0, cfg.group_title_offset_y)
    count_title:SetText("Section Count")
    count_title:SetTextColor(1, 0.82, 0, 1)

    local show_quest_log, show_tracked_achievements, quest_log_on_hover, tracked_achievements_on_hover = get_count_settings()
    local quest_log_container, quest_log_cb, quest_log_label = addon.CreateCheckbox(
        count_group,
        "Quests",
        show_quest_log,
        function(is_checked)
            set_count_setting("show_quest_log_count", is_checked)
        end
    )
    M.controls.show_quest_log_count_checkbox = quest_log_cb
    quest_log_container:SetPoint("TOPLEFT", count_group, "TOPLEFT", cfg.group_padding_x, cfg.first_checkbox_offset_y)
    addon.AttachTooltip(quest_log_label, nil, "Shows accepted quest log count and capacity in the Quests section title.")

    local quest_hover_container, quest_hover_cb, quest_hover_label = addon.CreateCheckbox(
        count_group,
        "On Hover",
        quest_log_on_hover,
        function(is_checked)
            set_count_setting("show_quest_log_count_on_hover", is_checked)
        end
    )
    M.controls.show_quest_log_count_on_hover_checkbox = quest_hover_cb
    quest_hover_container:SetPoint("TOPLEFT", count_group, "TOPLEFT", cfg.group_padding_x + cfg.sub_checkbox_indent_x, cfg.first_checkbox_offset_y + cfg.sub_checkbox_offset_y)
    addon.AttachTooltip(quest_hover_label, nil, "Shows the Quests count only while hovering the Quests section title.")

    local tracked_achievement_container, tracked_achievement_cb, tracked_achievement_label = addon.CreateCheckbox(
        count_group,
        "Achievements",
        show_tracked_achievements,
        function(is_checked)
            set_count_setting("show_tracked_achievement_count", is_checked)
        end
    )
    M.controls.show_tracked_achievement_count_checkbox = tracked_achievement_cb
    tracked_achievement_container:SetPoint("TOPLEFT", count_group, "TOPLEFT", cfg.group_padding_x + cfg.second_column_offset_x, cfg.first_checkbox_offset_y)
    addon.AttachTooltip(tracked_achievement_label, nil, "Shows tracked achievement count and capacity in the Achievements section title.")

    local achievement_hover_container, achievement_hover_cb, achievement_hover_label = addon.CreateCheckbox(
        count_group,
        "On Hover",
        tracked_achievements_on_hover,
        function(is_checked)
            set_count_setting("show_tracked_achievement_count_on_hover", is_checked)
        end
    )
    M.controls.show_tracked_achievement_count_on_hover_checkbox = achievement_hover_cb
    achievement_hover_container:SetPoint("TOPLEFT", count_group, "TOPLEFT", cfg.group_padding_x + cfg.second_column_offset_x + cfg.sub_checkbox_indent_x, cfg.first_checkbox_offset_y + cfg.sub_checkbox_offset_y)
    addon.AttachTooltip(achievement_hover_label, nil, "Shows the Achievements count only while hovering the Achievements section title.")

    local count_width = math.max(
        count_title:GetStringWidth() or 0,
        cfg.second_column_offset_x + (tracked_achievement_container:GetWidth() or 0),
        cfg.second_column_offset_x + cfg.sub_checkbox_indent_x + (achievement_hover_container:GetWidth() or 0),
        cfg.sub_checkbox_indent_x + (quest_hover_container:GetWidth() or 0),
        quest_log_container:GetWidth() or 0
    )
    count_group:SetWidth(math.ceil(count_width + cfg.group_padding_x * 2))
end

--#endregion GUI ===============================================================
