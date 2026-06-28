-- Objectives module: applies selected Blizzard Objective Tracker startup states.
local addon_name, addon = ...

addon.objectives = addon.objectives or {}
local M = addon.objectives

local MODULE_KEY = M.MODULE_KEY or "objectives"
local CATEGORY_NAME = "Objectives"

--#region SETTINGS AND DEFAULTS ================================================

local DEFAULTS = M.defaults

--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME STATE ========================================================

local background_hooks_installed = false
local background_sync_queued = false
local background_adjustments = 0
local background_last_reason = "none"
local background_last_state = "unavailable"
local background_hooked_modules = setmetatable({}, { __mode = "k" })

--#endregion RUNTIME STATE =====================================================


--#region OBJECTIVE TRACKER RUNTIME ============================================

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
        background:SetPoint("BOTTOM", header, "BOTTOM", 0, -(tracker.bottomModulePadding or 10))
        background:Show()
        background_last_state = state or "shown_header_only"
    else
        background:Hide()
        background_last_state = "hidden_no_visible_header"
    end

    background_adjustments = background_adjustments + 1
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

    if tracker.IsCollapsed and tracker:IsCollapsed() then
        show_background_to_header(tracker, background, "shown_container_collapsed")
        return
    end

    local last_visible_module
    for _, module in ipairs(tracker.modules or {}) do
        if module.IsShown and module:IsShown() and module.GetHeight and module:GetHeight() > 0 then
            last_visible_module = module
        end
    end

    if last_visible_module then
        background:SetPoint("BOTTOM", last_visible_module, "BOTTOM", 0, -(tracker.bottomModulePadding or 10))
        background:Show()
        background_last_state = "shown_to_visible_modules"
    else
        show_background_to_header(tracker, background, "shown_no_visible_modules")
        return
    end

    background_adjustments = background_adjustments + 1
end

local function queue_background_sync(reason)
    if background_sync_queued then return end
    background_sync_queued = true
    local delay = addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.next_frame or 0
    C_Timer.After(delay, function()
        sync_objective_background(reason)
    end)
end

local function hook_background_modules(tracker)
    if not M.is_runtime_enabled() then return end

    for _, module in ipairs(tracker.modules or {}) do
        if module.SetCollapsed and not background_hooked_modules[module] then
            background_hooked_modules[module] = true
            hooksecurefunc(module, "SetCollapsed", function()
                if not M.is_runtime_enabled() then return end
                queue_background_sync("module collapsed")
            end)
        end
    end
end

local function ensure_background_hooks()
    if background_hooks_installed then return end
    if not M.is_runtime_enabled() then return end

    local tracker = get_objective_tracker()
    if not tracker then return end

    hooksecurefunc(tracker, "Update", function()
        if not M.is_runtime_enabled() then return end
        hook_background_modules(tracker)
        queue_background_sync("tracker update")
    end)
    hooksecurefunc(tracker, "SetCollapsed", function()
        if not M.is_runtime_enabled() then return end
        queue_background_sync("tracker collapsed")
    end)

    hook_background_modules(tracker)
    background_hooks_installed = true
    queue_background_sync("hooks installed")
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
        fields[#fields + 1] = "background_state=" .. tostring(background_last_state)
        fields[#fields + 1] = "background_adjustments=" .. tostring(background_adjustments)
        fields[#fields + 1] = "background_last_reason=" .. tostring(background_last_reason)
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
