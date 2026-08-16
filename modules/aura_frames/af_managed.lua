-- Combat-safe managed AuraContainer lifecycle for Aura Frames.
-- Individual capabilities call Blizzard's AuraContainer APIs directly; this
-- file owns only availability, creation, initialization tracking, accessibility,
-- and the module runtime visibility gate.

local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local CreateFrame = CreateFrame
local C_AddOns = C_AddOns
local C_XMLUtil = C_XMLUtil
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local type = type

local MANAGED_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local MANAGED_CONTAINER_ADDON = "Blizzard_AuraContainer"

M._managed_aura_backends = M._managed_aura_backends or {}
if M._managed_aura_runtime_enabled == nil then
    M._managed_aura_runtime_enabled = false
end

--#region AVAILABILITY =========================================================

function M.is_managed_aura_supported()
    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, MANAGED_CONTAINER_ADDON)
    end
    if not (C_XMLUtil and type(C_XMLUtil.GetTemplateInfo) == "function") then
        return false
    end

    local ok, template_info = pcall(C_XMLUtil.GetTemplateInfo, MANAGED_CONTAINER_TEMPLATE)
    return ok and template_info ~= nil
end

--#endregion AVAILABILITY ======================================================

--#region BACKEND, GROUP, AND SLOT CREATION ===================================

local function apply_backend_visibility(backend)
    local shown = backend.feature_enabled and M._managed_aura_runtime_enabled
    -- AuraContainer visibility and processing are separate. A shown but
    -- disabled container never evaluates its unit and therefore produces no
    -- AuraButtons.
    backend.container:SetEnabled(shown == true)
    backend.container:SetShown(shown == true)
end

function M.create_managed_aura_backend(owner, key, unit, enabled)
    if not owner then return nil, "managed Aura backend requires an owner frame" end
    if type(key) ~= "string" or key == "" then
        return nil, "managed Aura backend requires a non-empty key"
    end
    if M._managed_aura_backends[key] then
        return nil, "managed Aura backend key is already registered: " .. key
    end
    if not M.is_managed_aura_supported() then
        return nil, "managed AuraContainer API is unavailable"
    end

    local container = CreateFrame("AuraContainer", nil, owner, MANAGED_CONTAINER_TEMPLATE)
    if not (container and type(container.AddAuraGroup) == "function") then
        return nil, "managed AuraContainer could not be created"
    end

    -- AuraContainer owns its content size through FlowLayout. Seed it at one
    -- point and one pixel; stretching it across the owner conflicts with the
    -- layout mixin's resize pass.
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", owner, "TOPLEFT")
    container:SetUnit(unit or "player")

    local backend = {
        key = key,
        owner = owner,
        unit = unit or "player",
        container = container,
        feature_enabled = enabled ~= false,
        groups = {},
        slots = {},
        aura_buttons = setmetatable({}, { __mode = "k" }),
    }
    M._managed_aura_backends[key] = backend
    apply_backend_visibility(backend)
    return backend
end

function M.add_managed_aura_group(backend, key, filter_string, options, layout)
    if not (backend and backend.container) then
        return nil, "managed Aura group requires a backend"
    end
    if type(key) ~= "string" or key == "" then
        return nil, "managed Aura group requires a non-empty key"
    end
    if backend.groups[key] then
        return nil, "managed Aura group key is already registered: " .. key
    end
    if type(filter_string) ~= "string" or filter_string == "" then
        return nil, "managed Aura group requires a filter string"
    end
    if type(options) ~= "table" or type(options.maxFrameCount) ~= "number" or options.maxFrameCount < 1 then
        return nil, "managed Aura group requires options.maxFrameCount of at least 1"
    end
    if options.initializeFrame ~= nil and type(options.initializeFrame) ~= "function" then
        return nil, "managed Aura group options.initializeFrame must be a function"
    end

    local initialize_frame = options.initializeFrame
    local managed_options = {}
    for option_key, value in pairs(options) do
        managed_options[option_key] = value
    end

    local group = { key = key, aura_button_count = 0 }
    backend.groups[key] = group
    managed_options.initializeFrame = function(aura_button)
        backend.aura_buttons[aura_button] = key
        group.aura_button_count = group.aura_button_count + 1
        if initialize_frame then
            -- This callback is the only unconditional write window. Blizzard
            -- applies the AuraButton access constraints after it returns.
            initialize_frame(aura_button, group.aura_button_count)
        end
    end

    backend.container:AddAuraGroup(key, filter_string, managed_options)
    if layout then
        backend.container:SetAuraGroupLayout(key, layout)
    end
    return group
end

function M.add_managed_aura_slot(backend, key, filter_string, options)
    if not (backend and backend.container) then
        return nil, "managed Aura slot requires a backend"
    end
    if type(backend.container.AddAuraSlot) ~= "function" then
        return nil, "managed Aura slot API is unavailable"
    end
    if type(key) ~= "string" or key == "" then
        return nil, "managed Aura slot requires a non-empty key"
    end
    if backend.slots[key] then
        return nil, "managed Aura slot key is already registered: " .. key
    end
    if type(filter_string) ~= "string" or filter_string == "" then
        return nil, "managed Aura slot requires a filter string"
    end
    if type(options) ~= "table" then
        return nil, "managed Aura slot requires an options table"
    end
    if options.initializeFrame ~= nil and type(options.initializeFrame) ~= "function" then
        return nil, "managed Aura slot options.initializeFrame must be a function"
    end

    local initialize_frame = options.initializeFrame
    local managed_options = {}
    for option_key, value in pairs(options) do
        managed_options[option_key] = value
    end

    local slot = { key = key }
    backend.slots[key] = slot
    managed_options.initializeFrame = function(aura_button)
        backend.aura_buttons[aura_button] = key
        slot.aura_button = aura_button
        if initialize_frame then
            -- This is the only unconditional write window before Blizzard
            -- applies the AuraButton access constraints.
            initialize_frame(aura_button)
        end
    end

    slot.aura_button = backend.container:AddAuraSlot(key, filter_string, managed_options)
    return slot
end

--#endregion BACKEND, GROUP, AND SLOT CREATION ================================

--#region ACCESSIBILITY ========================================================

function M.is_managed_aura_button_accessible(aura_button)
    if not (aura_button and type(aura_button.CanBeAccessedInContext) == "function") then
        return false
    end
    local ok, accessible = pcall(aura_button.CanBeAccessedInContext, aura_button)
    return ok and accessible == true
end

function M.for_each_accessible_managed_aura_button(backend, callback)
    if not (backend and type(callback) == "function") then return false end
    local all_accessible = true
    for aura_button, group_key in pairs(backend.aura_buttons) do
        if M.is_managed_aura_button_accessible(aura_button) then
            callback(aura_button, group_key)
        else
            all_accessible = false
        end
    end
    return all_accessible
end

function M.get_managed_aura_status_fields()
    local fields = {}
    for key, backend in pairs(M._managed_aura_backends) do
        local total_count = 0
        local accessible_count = 0
        for aura_button in pairs(backend.aura_buttons) do
            total_count = total_count + 1
            if M.is_managed_aura_button_accessible(aura_button) then
                accessible_count = accessible_count + 1
            end
        end

        local group_count = 0
        for _ in pairs(backend.groups) do
            group_count = group_count + 1
        end
        local slot_count = 0
        for _ in pairs(backend.slots) do
            slot_count = slot_count + 1
        end
        local container_shown = backend.container:IsShown() == true
        local container_enabled = "unknown"
        if type(backend.container.IsEnabled) == "function" then
            local ok, enabled = pcall(backend.container.IsEnabled, backend.container)
            if ok then
                container_enabled = tostring(enabled == true)
            end
        end
        fields[#fields + 1] = "managed=" .. tostring(key)
            .. ":unit=" .. tostring(backend.unit)
            .. ":feature=" .. tostring(backend.feature_enabled == true)
            .. ":enabled=" .. container_enabled
            .. ":shown=" .. tostring(container_shown)
            .. ":groups=" .. tostring(group_count)
            .. ":slots=" .. tostring(slot_count)
            .. ":buttons=" .. tostring(total_count)
            .. ":accessible=" .. tostring(accessible_count)
    end
    if #fields == 0 then
        fields[1] = "managed=none"
    end
    return fields
end

--#endregion ACCESSIBILITY =====================================================

--#region RUNTIME LIFECYCLE ====================================================

function M.get_managed_aura_backend(key)
    return M._managed_aura_backends[key]
end

function M.set_managed_aura_backend_enabled(backend, enabled)
    if not backend then return end
    backend.feature_enabled = enabled == true
    apply_backend_visibility(backend)
end

function M.set_managed_aura_runtime_enabled(enabled)
    M._managed_aura_runtime_enabled = enabled == true
    for _, backend in pairs(M._managed_aura_backends) do
        apply_backend_visibility(backend)
    end
end

function M.release_managed_aura_backend(backend)
    if not backend then return end
    backend.feature_enabled = false
    apply_backend_visibility(backend)
    if M._managed_aura_backends[backend.key] == backend then
        M._managed_aura_backends[backend.key] = nil
    end
end

--#endregion RUNTIME LIFECYCLE =================================================
