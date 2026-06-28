-- Objectives module: applies selected Blizzard Objective Tracker startup states.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

local MODULE_KEY = M.MODULE_KEY or "objectives"
local CATEGORY_NAME = "Objectives"

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults
local FORCE_EXPAND_GRACE_SECONDS = 2

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local background_hooks_installed = false
local background_sync_queued = false
local background_adjustments = 0
local background_last_reason = "none"
local background_last_state = "unavailable"
local background_last_anchor = "none"
local background_last_force_expand = "none"
local background_last_blocked_anchor = "none"
local background_last_container_collapse_time = nil
local background_hooked_frame
local background_adjusting = false

--#endregion RUNTIME STATE =====================================================


--#region OBJECTIVE TRACKER RUNTIME ============================================

local get_background_bottom_anchor
local background_points_to_header
local set_background_bottom_to_header

local function get_objective_tracker()
    local tracker = ObjectiveTrackerFrame
    if tracker and tracker.NineSlice then
        return tracker
    end
    return nil
end

local function show_background_to_header(tracker, background, state)
    local header = tracker and tracker.Header
    if header and header.IsShown and header:IsShown() then
        local changed = not background_points_to_header(tracker, background)
            or not (background.IsShown and background:IsShown())
        if not background_points_to_header(tracker, background) then
            set_background_bottom_to_header(tracker, background)
        end
        if background.Show and not (background.IsShown and background:IsShown()) then
            background:Show()
        end
        background_last_state = state or "shown_header_only"
        background_last_anchor = header.GetName and header:GetName() or "tracker_header"
        if changed then
            background_adjustments = background_adjustments + 1
        end
    else
        local changed = background.IsShown and background:IsShown()
        if background.Hide then
            background:Hide()
        end
        background_last_state = "hidden_no_visible_header"
        background_last_anchor = "none"
        if changed then
            background_adjustments = background_adjustments + 1
        end
    end
end

local function is_tracker_collapsed(tracker)
    if not tracker then return false end
    if tracker.IsCollapsed and tracker:IsCollapsed() then return true end
    return tracker.isCollapsed == true or tracker.collapsed == true
end

local function get_frame_name(frame, fallback)
    if frame and frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then
            return name
        end
    end
    return fallback
end

local function get_bool_state(frame, method_name)
    local method = frame and frame[method_name]
    if method then
        return method(frame) == true
    end
    return nil
end

get_background_bottom_anchor = function(background)
    if not background or not background.GetNumPoints or not background.GetPoint then return nil end

    for index = 1, background:GetNumPoints() do
        local point, relative_to = background:GetPoint(index)
        if point == "BOTTOM" then
            return relative_to
        end
    end

    return nil
end

background_points_to_header = function(tracker, background)
    return get_background_bottom_anchor(background) == (tracker and tracker.Header)
end

set_background_bottom_to_header = function(tracker, background)
    background_adjusting = true
    if background.ClearPoint then
        background:ClearPoint("BOTTOM")
    end
    background:SetPoint("BOTTOM", tracker.Header, "BOTTOM", 0, -(tracker.bottomModulePadding or 10))
    background_adjusting = false
end

local function is_in_force_expand_grace()
    if not background_last_container_collapse_time then return false end
    return (GetTime() - background_last_container_collapse_time) < FORCE_EXPAND_GRACE_SECONDS
end

local function get_priority_module_for_anchor(tracker, anchor)
    if not tracker or not anchor then return nil end

    local priority_modules = {}
    for _, module in ipairs(tracker.modules or {}) do
        if module.hasDisplayPriority == true then
            priority_modules[module] = true
        end
    end

    local frame = anchor
    while frame do
        if priority_modules[frame] then
            return frame
        end
        if not frame.GetParent then
            return nil
        end
        frame = frame:GetParent()
    end

    return nil
end

local function force_expand_for_background_anchor(tracker, anchor)
    local priority_module = get_priority_module_for_anchor(tracker, anchor)
    if not priority_module then
        background_last_blocked_anchor = get_frame_name(anchor, "unknown")
        return false
    end

    background_last_force_expand = "background:" .. get_frame_name(priority_module, "priority_module")
    background_last_blocked_anchor = "none"
    background_last_state = "force_expand_background_anchor"
    background_last_anchor = "blizzard"

    if tracker.ForceExpand then
        tracker:ForceExpand()
    elseif tracker.SetCollapsed then
        tracker:SetCollapsed(false)
    end

    return true
end

local function check_collapsed_background_anchor(reason)
    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not tracker or not background or not M.is_runtime_enabled() then return end
    if not is_tracker_collapsed(tracker) then return end

    local anchor = get_background_bottom_anchor(background)
    if anchor and anchor ~= tracker.Header then
        background_last_reason = reason or "background anchor changed"
        if not is_in_force_expand_grace() then
            if force_expand_for_background_anchor(tracker, anchor) then
                return
            end
        end
        show_background_to_header(tracker, background, "shown_container_collapsed_blocked_anchor")
    end
end

local function sync_objective_background(reason)
    background_sync_queued = false
    background_last_reason = reason or "unknown"

    local tracker = get_objective_tracker()
    local background = tracker and tracker.NineSlice
    if not tracker or not background then
        background_last_state = "unavailable"
        return
    end

    if not M.is_runtime_enabled() then
        background_last_state = "module_disabled"
        return
    end

    if is_tracker_collapsed(tracker) then
        if not background_points_to_header(tracker, background) and not is_in_force_expand_grace() then
            if force_expand_for_background_anchor(tracker, get_background_bottom_anchor(background)) then
                return
            end
            show_background_to_header(tracker, background, "shown_container_collapsed_blocked_anchor")
            return
        end

        show_background_to_header(tracker, background, "shown_container_collapsed")
        return
    end

    background_last_state = "blizzard_owned_expanded"
    background_last_anchor = "blizzard"
    background_last_force_expand = "none"
    background_last_blocked_anchor = "none"
end

local function queue_background_sync(reason)
    if background_sync_queued then return end
    background_sync_queued = true
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.next_frame or 0
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function queue_background_followup(reason)
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.fifth_sec or 0.2
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function ensure_background_hooks()
    if background_hooks_installed then return end
    if not M.is_runtime_enabled() then return end

    local tracker = get_objective_tracker()
    if not tracker then return end
    local background = tracker.NineSlice

    hooksecurefunc(tracker, "Update", function()
        if not M.is_runtime_enabled() then return end
        queue_background_sync("tracker update")
    end)
    hooksecurefunc(tracker, "SetCollapsed", function(_, collapsed)
        if not M.is_runtime_enabled() then return end
        if collapsed then
            background_last_container_collapse_time = GetTime()
        end
        queue_background_sync("tracker collapsed")
        queue_background_followup("tracker collapsed followup")
    end)
    if background and background.SetPoint then
        background_hooked_frame = background
        hooksecurefunc(background, "SetPoint", function()
            if not M.is_runtime_enabled() then return end
            if background_adjusting then return end
            check_collapsed_background_anchor("background SetPoint")
        end)
    end

    background_hooks_installed = true
    queue_background_sync("hooks installed")
end

local function append_background_module_status(fields)
    local tracker = get_objective_tracker()
    if not tracker then
        fields[#fields + 1] = "background_modules=unavailable"
        return
    end

    fields[#fields + 1] = "background_modules=" .. tostring(#(tracker.modules or {}))
    for index, module in ipairs(tracker.modules or {}) do
        local prefix = "background_module_" .. tostring(index) .. "_"
        local last_block = module.GetLastBlock and module:GetLastBlock() or nil
        local contents_height = module.GetContentsHeight and module:GetContentsHeight() or nil
        local module_height = module.GetHeight and module:GetHeight() or nil
        local last_block_height = last_block and last_block.GetHeight and last_block:GetHeight() or nil

        fields[#fields + 1] = prefix .. "name=" .. get_frame_name(module, "unnamed")
        fields[#fields + 1] = prefix .. "priority=" .. tostring(module.hasDisplayPriority == true)
        fields[#fields + 1] = prefix .. "shown=" .. tostring(get_bool_state(module, "IsShown"))
        fields[#fields + 1] = prefix .. "collapsed=" .. tostring(get_bool_state(module, "IsCollapsed"))
        fields[#fields + 1] = prefix .. "displayable=" .. tostring(get_bool_state(module, "IsDisplayable"))
        fields[#fields + 1] = prefix .. "height=" .. tostring(module_height)
        fields[#fields + 1] = prefix .. "contents_height=" .. tostring(contents_height)
        fields[#fields + 1] = prefix .. "raw_contents_height=" .. tostring(module.contentsHeight)
        fields[#fields + 1] = prefix .. "has_contents=" .. tostring(module.hasContents == true)
        fields[#fields + 1] = prefix .. "has_tried_blocks=" .. tostring(module.hasTriedBlocks == true)
        fields[#fields + 1] = prefix .. "has_skipped_blocks=" .. tostring(module.hasSkippedBlocks == true)
        fields[#fields + 1] = prefix .. "state=" .. tostring(module.state)
        fields[#fields + 1] = prefix .. "last_block=" .. get_frame_name(last_block, "none")
        fields[#fields + 1] = prefix .. "last_block_shown=" .. tostring(get_bool_state(last_block, "IsShown"))
        fields[#fields + 1] = prefix .. "last_block_height=" .. tostring(last_block_height)
    end
end

function M.apply_objectives()
    if not M.is_runtime_enabled() then return end

    ensure_background_hooks()
    if M.apply_auto_collapse then
        M.apply_auto_collapse()
    end
    if M.apply_section_count then
        M.apply_section_count()
    end
end

--#endregion OBJECTIVE TRACKER RUNTIME =========================================


--#region GUI ==================================================================

function M.BuildSettings(parent)
    if M.BuildAutoCollapseSettings then
        M.BuildAutoCollapseSettings(parent)
    end
    if M.BuildSectionCountSettings then
        M.BuildSectionCountSettings(parent)
    end
end

--#endregion GUI ===============================================================


--#region PUBLIC MODULE HOOKS ==================================================

function M.set_module_enabled(enabled)
    if enabled then
        M.apply_objectives()
    else
        if M.set_section_count_module_enabled then
            M.set_section_count_module_enabled(false)
        end
        local tracker = get_objective_tracker()
        if tracker and tracker.Update then
            tracker:Update()
        end
    end
end

if addon.register_module_status then
    addon.register_module_status(MODULE_KEY, function()
        local fields = {}
        if M.get_auto_collapse_status then
            for _, field in ipairs(M.get_auto_collapse_status()) do
                fields[#fields + 1] = field
            end
        end
        fields[#fields + 1] = "background_hooks=" .. tostring(background_hooks_installed)
        fields[#fields + 1] = "background_point_hook=" .. tostring(background_hooked_frame ~= nil)
        fields[#fields + 1] = "background_state=" .. tostring(background_last_state)
        fields[#fields + 1] = "background_anchor=" .. tostring(background_last_anchor)
        fields[#fields + 1] = "background_force_expand=" .. tostring(background_last_force_expand)
        fields[#fields + 1] = "background_blocked_anchor=" .. tostring(background_last_blocked_anchor)
        fields[#fields + 1] = "background_force_expand_grace=" .. tostring(is_in_force_expand_grace())
        fields[#fields + 1] = "background_adjustments=" .. tostring(background_adjustments)
        fields[#fields + 1] = "background_last_reason=" .. tostring(background_last_reason)
        append_background_module_status(fields)
        if M.get_section_count_status then
            for _, field in ipairs(M.get_section_count_status()) do
                fields[#fields + 1] = field
            end
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
