-- Generic participant registry, policy resolution, presets, and consumer refresh
-- for the Background Colors module.


local _, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync


--#region COLOR NORMALIZATION ==================================================

local COLOR_RANGE = { min = 0, max = 1 }
local PRESET_TOLERANCE = 0.001
local FALLBACK_COLOR = { r = 0, g = 0, b = 0, a = 0.5 }

local function copy_color(color)
    color = type(color) == "table" and color or FALLBACK_COLOR
    return {
        r = color.r,
        g = color.g,
        b = color.b,
        a = color.a,
    }
end

local function normalize_color(color, defaults)
    if type(color) ~= "table" then
        color = {}
    end
    defaults = defaults or FALLBACK_COLOR
    color.r = addon.clamp_number(color.r, defaults.r, COLOR_RANGE)
    color.g = addon.clamp_number(color.g, defaults.g, COLOR_RANGE)
    color.b = addon.clamp_number(color.b, defaults.b, COLOR_RANGE)
    color.a = addon.clamp_number(color.a, defaults.a or 1, COLOR_RANGE)
    return color
end

local function sort_by_order(left, right)
    local left_order = left.order or 100
    local right_order = right.order or 100
    if left_order == right_order then
        return (left._registered_index or 0) < (right._registered_index or 0)
    end
    return left_order < right_order
end

--#endregion COLOR NORMALIZATION ===============================================


--#region PARTICIPANT REGISTRY =================================================

function M.get_registered_consumers()
    local consumers = {}
    for _, module_key in ipairs(M.consumer_order) do
        local consumer = M.consumers[module_key]
        if consumer then
            consumers[#consumers + 1] = consumer
        end
    end
    table.sort(consumers, sort_by_order)
    return consumers
end

function M.get_registered_targets(module_key)
    local consumer = M.consumers[module_key]
    if not consumer then return {} end
    local targets = {}
    for _, target_key in ipairs(consumer.target_order) do
        local target = consumer.targets[target_key]
        if target then
            targets[#targets + 1] = target
        end
    end
    table.sort(targets, sort_by_order)
    return targets
end

function M.ensure_consumer_db(module_key)
    local db = M.get_db()
    local consumer = M.consumers[module_key]
    if not db or not consumer then return nil end

    db.consumers = db.consumers or {}
    local consumer_db = db.consumers[module_key]
    if type(consumer_db) ~= "table" then
        consumer_db = {}
        db.consumers[module_key] = consumer_db
    end
    if consumer_db.global_enabled == nil then
        consumer_db.global_enabled = consumer.default_global_enabled == true
    end
    consumer_db.color = normalize_color(consumer_db.color, consumer.default_color)
    consumer_db.targets = consumer_db.targets or {}
    for _, target in ipairs(M.get_registered_targets(module_key)) do
        if consumer_db.targets[target.key] == nil then
            consumer_db.targets[target.key] = target.default_enabled == true
        end
    end
    return consumer_db
end

local function notify_registry_changed()
    if M.on_registry_changed then
        M.on_registry_changed()
    end
end

function M.register_consumer(module_key, opts)
    if type(module_key) ~= "string" or module_key == "" then return nil end
    opts = opts or {}

    local consumer = M.consumers[module_key]
    if not consumer then
        consumer = {
            key = module_key,
            targets = {},
            target_order = {},
            _registered_index = #M.consumer_order + 1,
        }
        M.consumers[module_key] = consumer
        M.consumer_order[#M.consumer_order + 1] = module_key
    end
    consumer.label = opts.label or consumer.label or module_key
    consumer.order = opts.order or consumer.order or 100
    consumer.default_color = copy_color(opts.default_color or consumer.default_color)
    consumer.refresh = opts.refresh or consumer.refresh
    consumer.supports_ooc_fade = opts.supports_ooc_fade == true
    if opts.global_toggle ~= nil then
        consumer.global_toggle = opts.global_toggle == true
    elseif consumer.global_toggle == nil then
        consumer.global_toggle = false
    end
    consumer.global_order = opts.global_order or consumer.global_order or consumer.order
    if opts.default_global_enabled ~= nil then
        consumer.default_global_enabled = opts.default_global_enabled == true
    elseif consumer.default_global_enabled == nil then
        consumer.default_global_enabled = true
    end
    if opts.global_only ~= nil then
        consumer.global_only = opts.global_only == true
    elseif consumer.global_only == nil then
        consumer.global_only = false
    end
    M.ensure_consumer_db(module_key)
    notify_registry_changed()
    return consumer
end

function M.register_target(module_key, target_key, opts)
    if type(target_key) ~= "string" or target_key == "" then return nil end
    opts = opts or {}
    local consumer = M.consumers[module_key] or M.register_consumer(module_key)
    if not consumer then return nil end

    local target = consumer.targets[target_key]
    if not target then
        target = {
            key = target_key,
            _registered_index = #consumer.target_order + 1,
        }
        consumer.targets[target_key] = target
        consumer.target_order[#consumer.target_order + 1] = target_key
    end
    target.label = opts.label or target.label or target_key
    target.order = opts.order or target.order or 100
    target.row_key = opts.row_key or target.row_key or target_key
    target.row_label = opts.row_label or target.row_label or target.label
    target.column = opts.column or target.column or 2
    target.column_label = opts.column_label or target.column_label or "Background"
    target.supports_visibility = opts.supports_visibility == true
    if opts.default_enabled ~= nil then
        target.default_enabled = opts.default_enabled == true
    elseif target.default_enabled == nil then
        target.default_enabled = true
    end

    M.ensure_consumer_db(module_key)
    if opts.defer_notify ~= true then
        notify_registry_changed()
    end
    return target
end

function M.unregister_target(module_key, target_key, defer_notify)
    local consumer = M.consumers[module_key]
    if not consumer or not consumer.targets[target_key] then return end
    consumer.targets[target_key] = nil
    for index, registered_key in ipairs(consumer.target_order) do
        if registered_key == target_key then
            table.remove(consumer.target_order, index)
            break
        end
    end

    local db = M.get_db()
    local consumer_db = db and db.consumers and db.consumers[module_key]
    if consumer_db and consumer_db.targets then
        consumer_db.targets[target_key] = nil
    end
    if defer_notify ~= true then
        notify_registry_changed()
    end
end

function M.normalize_db()
    local db = M.get_db()
    if not db then return end
    local defaults = M.defaults.background_color_sync
    db.global_color = normalize_color(db.global_color, defaults.global_color)
    db.consumers = db.consumers or {}
    for _, consumer in ipairs(M.get_registered_consumers()) do
        M.ensure_consumer_db(consumer.key)
    end
end

--#endregion PARTICIPANT REGISTRY ==============================================


--#region POLICY RESOLUTION ====================================================

local function get_target_state(module_key, target_key)
    local db = M.get_db()
    local consumer = M.consumers[module_key]
    local target = consumer and consumer.targets[target_key]
    local consumer_db = target and db and db.consumers and db.consumers[module_key]
    if not target or not consumer_db or not consumer_db.targets then
        return db, consumer, target, nil
    end
    if consumer.global_only ~= true and consumer_db.targets[target_key] ~= true then
        return db, consumer, target, nil
    end
    return db, consumer, target, consumer_db
end

function M.resolve_color(module_key, target_key, local_color)
    if not M.is_runtime_enabled() then
        return local_color, "local"
    end

    local db, consumer, _, consumer_db = get_target_state(module_key, target_key)
    if not db or not consumer_db then
        return local_color, "local"
    end
    if db.global_enabled == true and consumer_db.global_enabled == true then
        return db.global_color or local_color, "global"
    end
    if consumer.global_only ~= true then
        return consumer_db.color or local_color, "module"
    end
    return local_color, "local"
end

function M.resolve_visibility(module_key, target_key, local_enabled)
    if local_enabled == true or not M.is_runtime_enabled() then
        return local_enabled == true
    end

    local db = M.get_db()
    local consumer = M.consumers[module_key]
    local target = consumer and consumer.targets[target_key]
    return db ~= nil
        and target ~= nil
        and target.supports_visibility == true
        and db.global_enable_all_backgrounds == true
end

function M.resolve_ooc_fade(module_key, local_enabled)
    if local_enabled ~= true or not M.is_runtime_enabled() then
        return local_enabled == true
    end
    local db = M.get_db()
    local consumer = M.consumers[module_key]
    if db
        and consumer
        and consumer.supports_ooc_fade == true
        and db.global_enable_all_backgrounds == true
        and db.global_disable_ooc_fade == true
    then
        return false
    end
    return true
end

--#endregion POLICY RESOLUTION =================================================


--#region PRESET HELPERS =======================================================

local function component_matches(left, right)
    return math.abs((left or 0) - (right or 0)) <= PRESET_TOLERANCE
end

function M.get_color_preset(color)
    if type(color) ~= "table" then return "custom" end
    for _, option in ipairs(M.PRESET_OPTIONS) do
        local preset = M.COLOR_PRESETS[option.value]
        if component_matches(color.r, preset.r)
            and component_matches(color.g, preset.g)
            and component_matches(color.b, preset.b)
        then
            return option.value
        end
    end
    return "custom"
end

function M.get_color_binding(module_key)
    if not module_key then
        local db = M.get_db()
        return db, "global_color", M.defaults.background_color_sync
    end

    local consumer = M.consumers[module_key]
    local consumer_db = M.ensure_consumer_db(module_key)
    if not consumer or not consumer_db then return nil, nil, nil end
    consumer.color_defaults = consumer.color_defaults or {
        color = copy_color(consumer.default_color),
    }
    return consumer_db, "color", consumer.color_defaults
end

function M.set_color_preset(module_key, preset_key)
    local preset = M.COLOR_PRESETS[preset_key]
    local db_table, color_key, defaults = M.get_color_binding(module_key)
    if not preset or not db_table or not color_key or not defaults then return false end

    local current = db_table[color_key]
    local default_color = defaults[color_key]
    if type(default_color) ~= "table" then return false end
    local alpha = type(current) == "table" and current.a or default_color.a
    db_table[color_key] = {
        r = preset.r,
        g = preset.g,
        b = preset.b,
        a = addon.clamp_number(alpha, default_color.a or 1, COLOR_RANGE),
    }
    return true
end

--#endregion PRESET HELPERS ====================================================


--#region CONSUMER REFRESH ====================================================

function M.refresh_consumers()
    for _, consumer in ipairs(M.get_registered_consumers()) do
        if type(consumer.refresh) == "function" then
            consumer.refresh()
        end
    end
end

--#endregion CONSUMER REFRESH =================================================
