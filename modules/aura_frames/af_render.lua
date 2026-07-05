-- Renders aura maps into pooled icon/bar frames.
-- render_aura_map() orchestrates list ordering, metadata assignment, visual setup,
-- timer/bar updates, and unused-icon cleanup through focused helpers.
-- set_timer_text() formats countdown strings; merge_aura_info() combines pending
-- UNIT_AURA payloads before the deferred scan.

local addon_name, addon = ...

local floor      = math.floor
local math_max   = math.max
local math_min   = math.min
local GetTime    = GetTime
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local format        = format
local table_sort    = table.sort
local table_concat  = table.concat
local wipe          = wipe
local SORT_RULE_DEFAULT    = Enum.UnitAuraSortRule.Default
local SORT_RULE_EXPIRATION = Enum.UnitAuraSortRule.ExpirationOnly
local SORT_RULE_NAME       = Enum.UnitAuraSortRule.NameOnly
local SORT_DIR_NORMAL      = Enum.UnitAuraSortDirection.Normal
local TIMER_DIR_REMAINING  = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames
local clear_timer_text = M.clear_timer_text
local set_shown_if_changed = M.set_shown_if_changed

-- Scratch tables reused every render_aura_map call to avoid per-frame allocation.
local _scratch_list      = {}
local _scratch_seen      = {}
local _scratch_seen_keys = {}
local _scratch_timer_behaviors = {}
local _scratch_render_signature = {}
local _sorted_aura_ids_cache = {}

function M.clear_sorted_aura_ids_cache()
    wipe(_sorted_aura_ids_cache)
end

--#region TIME FORMATTING ======================================================

-- Logic for converting seconds into readable text strings
local function format_time(s)
    if s >= 3600 then return format("%d h", floor(s/3600)) end
    if s >= 60 then return format("%d m", floor(s/60)) end
    if s >= 5 then return format("%d s", floor(s)) end
    return format("%.1f s", s)
end

--#endregion TIME FORMATTING ===================================================

--#region SORT HELPERS =========================================================

local function get_entry_sort_id(entry)
    if type(entry.instance_id) == "number" then
        return entry.instance_id
    end
    return entry.preview_sort_id or 0
end

--#endregion SORT HELPERS ======================================================

--#region TIMER TEXT ===========================================================

-- Single timer text renderer for all aura timers (live + test).
-- Keep behavior changes here so all timer displays stay consistent.
function M.set_timer_text(font_string, category, seconds, behavior)
    if not font_string then return end

    if seconds == nil then
        clear_timer_text(font_string)
        return
    end

    behavior = behavior or M.get_timer_behavior(category)
    if behavior.enabled == false then
        clear_timer_text(font_string)
        return
    end

    font_string:Show()

    if issecretvalue(seconds) then
        font_string:SetFormattedText("%.1f", seconds)
        font_string._last_text = nil  -- secret value, can't cache
        return
    end

    if seconds <= 0 then
        clear_timer_text(font_string)
        return
    end

    local text
    if behavior.format == "decimal" then
        local rounded = floor((seconds * 10) + 0.5) / 10
        text = format("%.1f", rounded)
    else
        text = format_time(seconds)
    end
    if font_string._last_text ~= text then
        font_string:SetText(text)
        font_string._last_text = text
    end
end

local function get_timer_category(frame, entry)
    if frame.is_custom and entry and entry.category then
        return entry.category
    end
    return frame.category
end

local function get_duration_object_remaining(duration_object)
    if not duration_object or type(duration_object.GetRemainingDuration) ~= "function" then
        return nil
    end
    local ok, remaining = pcall(function()
        return duration_object:GetRemainingDuration()
    end)
    if ok then
        return remaining
    end
    return nil
end

local function apply_cooldown_overlay(obj, duration_object, expiration, duration)
    local cooldown = obj and obj.cooldown
    if not cooldown then return end

    if duration_object and cooldown.SetCooldownFromDurationObject then
        if cooldown._lstweeks_cd_kind == "duration_object"
            and cooldown._lstweeks_cd_duration_object == duration_object
            and cooldown:IsShown() then
            return
        end
        set_shown_if_changed(cooldown, true)
        local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration_object, true)
        if ok then
            cooldown._lstweeks_cd_kind = "duration_object"
            cooldown._lstweeks_cd_duration_object = duration_object
            return
        end
        ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration_object)
        if ok then
            cooldown._lstweeks_cd_kind = "duration_object"
            cooldown._lstweeks_cd_duration_object = duration_object
            return
        end
    end

    if expiration and duration and duration > 0 then
        local start_time = expiration - duration
        if cooldown._lstweeks_cd_kind == "cooldown"
            and cooldown._lstweeks_cd_start == start_time
            and cooldown._lstweeks_cd_duration == duration
            and cooldown:IsShown() then
            return
        end
        set_shown_if_changed(cooldown, true)
        cooldown:SetCooldown(start_time, duration)
        cooldown._lstweeks_cd_kind = "cooldown"
        cooldown._lstweeks_cd_duration_object = nil
        cooldown._lstweeks_cd_start = start_time
        cooldown._lstweeks_cd_duration = duration
    elseif cooldown.Clear then
        if cooldown._lstweeks_cd_kind == "clear" and cooldown:IsShown() then
            return
        end
        set_shown_if_changed(cooldown, true)
        cooldown:Clear()
        cooldown._lstweeks_cd_kind = "clear"
        cooldown._lstweeks_cd_duration_object = nil
        cooldown._lstweeks_cd_start = nil
        cooldown._lstweeks_cd_duration = nil
    end
end

local function set_icon_greyed(texture, greyed)
    if not texture then return end
    greyed = greyed and true or false
    if texture._lstweeks_greyed == greyed then return end
    texture._lstweeks_greyed = greyed
    if texture.SetDesaturated then
        texture:SetDesaturated(greyed)
    elseif texture.SetDesaturation then
        texture:SetDesaturation(greyed and 1 or 0)
    end
    if texture.SetVertexColor then
        if greyed then
            texture:SetVertexColor(0.75, 0.75, 0.75, 1)
        else
            texture:SetVertexColor(1, 1, 1, 1)
        end
    end
end

local function set_texture_if_changed(texture, value)
    if not texture then return end
    if issecretvalue(value) then
        texture._lstweeks_texture = nil
        texture:SetTexture(value)
        return
    end
    if texture._lstweeks_texture == value then return end
    texture._lstweeks_texture = value
    texture:SetTexture(value)
end

local function set_name_text_if_changed(font_string, value)
    if not font_string then return end
    if issecretvalue(value) then
        font_string._lstweeks_name_text = nil
        font_string:SetText(value)
        return
    end
    if font_string._lstweeks_name_text == value then return end
    font_string._lstweeks_name_text = value
    font_string:SetText(value)
end

local function set_font_color_if_changed(font_string, r, g, b, a)
    if not font_string then return end
    a = a or 1
    if font_string._lstweeks_color_r == r
        and font_string._lstweeks_color_g == g
        and font_string._lstweeks_color_b == b
        and font_string._lstweeks_color_a == a then
        return
    end
    font_string._lstweeks_color_r = r
    font_string._lstweeks_color_g = g
    font_string._lstweeks_color_b = b
    font_string._lstweeks_color_a = a
    font_string:SetTextColor(r, g, b, a)
end

local function set_status_bar_color_if_changed(bar, r, g, b, a)
    if not bar then return end
    a = a or 1
    if bar._lstweeks_status_r == r
        and bar._lstweeks_status_g == g
        and bar._lstweeks_status_b == b
        and bar._lstweeks_status_a == a then
        return
    end
    bar._lstweeks_status_r = r
    bar._lstweeks_status_g = g
    bar._lstweeks_status_b = b
    bar._lstweeks_status_a = a
    bar:SetStatusBarColor(r, g, b, a)
end

local function set_texture_color_if_changed(texture, r, g, b, a)
    if not texture then return end
    a = a or 1
    if texture._lstweeks_color_r == r
        and texture._lstweeks_color_g == g
        and texture._lstweeks_color_b == b
        and texture._lstweeks_color_a == a then
        return
    end
    texture._lstweeks_color_r = r
    texture._lstweeks_color_g = g
    texture._lstweeks_color_b = b
    texture._lstweeks_color_a = a
    texture:SetColorTexture(r, g, b, a)
end

local function set_bar_minmax_if_changed(bar, min_value, max_value)
    if not bar then return end
    if bar._lstweeks_min_value == min_value and bar._lstweeks_max_value == max_value then return end
    bar._lstweeks_min_value = min_value
    bar._lstweeks_max_value = max_value
    bar:SetMinMaxValues(min_value, max_value)
end

local function set_count_point_if_changed(obj, point, relative_to, relative_point, x, y)
    if not point then return end
    if obj._lstweeks_count_point == point
        and obj._lstweeks_count_relative_to == relative_to
        and obj._lstweeks_count_relative_point == relative_point
        and obj._lstweeks_count_x == x
        and obj._lstweeks_count_y == y then
        return
    end

    obj._lstweeks_count_point = point
    obj._lstweeks_count_relative_to = relative_to
    obj._lstweeks_count_relative_point = relative_point
    obj._lstweeks_count_x = x
    obj._lstweeks_count_y = y
    obj.count_text:SetPoint(point, relative_to, relative_point, x, y)
end

local function set_count_text(obj, text, point, relative_to, relative_point, x, y)
    if issecretvalue(text) then
        obj._lstweeks_count_text = nil
        obj.count_text:SetText(text)
        set_count_point_if_changed(obj, point, relative_to, relative_point, x, y)
        if not obj.count_text:IsShown() then
            obj.count_text:Show()
        end
        return
    end
    if text ~= nil then
        local cached = obj._lstweeks_count_text
        if issecretvalue(cached) or cached ~= text then
            obj.count_text:SetText(text)
            obj._lstweeks_count_text = text
        end
        set_count_point_if_changed(obj, point, relative_to, relative_point, x, y)
        if not obj.count_text:IsShown() then
            obj.count_text:Show()
        end
    else
        if obj.count_text:IsShown() then
            obj.count_text:Hide()
        end
    end
end

local function resolve_stack_text(entry, live_count)
    if entry.count and not issecretvalue(entry.count) and entry.count > 1 then
        return entry.count
    end

    if live_count ~= nil and not issecretvalue(live_count) then
        if type(live_count) == "number" then
            if live_count > 1 then return live_count end
        elseif type(live_count) == "string" then
            if live_count ~= "" and live_count ~= "1" then return live_count end
        else
            return live_count
        end
        return nil
    end

    -- Secret live_count is safe to display, but we cannot compare it.
    -- Preserve combat behavior by showing it only when no safe fallback exists.
    return live_count
end

local function append_signature_value(parts, value)
    if value ~= nil and issecretvalue(value) then
        return false
    end
    parts[#parts + 1] = tostring(value or "")
    return true
end

local function build_display_signature(
    frame,
    list,
    display_count,
    bar_mode,
    color,
    bar_bg_color,
    bar_text_color,
    max_limit,
    sort_mode,
    show_render_timer_text,
    show_timer_swipe,
    show_cooldown_overlay,
    tooltip_enabled
)
    local parts = _scratch_render_signature
    wipe(parts)

    parts[#parts + 1] = frame.category or ""
    parts[#parts + 1] = frame.is_custom and "custom" or "preset"
    parts[#parts + 1] = bar_mode and "bar" or "icon"
    parts[#parts + 1] = show_render_timer_text and "timer" or "notimer"
    parts[#parts + 1] = show_timer_swipe and "swipe" or "noswipe"
    parts[#parts + 1] = show_cooldown_overlay and "overlay" or "nooverlay"
    parts[#parts + 1] = tooltip_enabled and "tooltip" or "notooltip"
    parts[#parts + 1] = tostring(max_limit or "")
    parts[#parts + 1] = sort_mode or ""
    parts[#parts + 1] = tostring(display_count)

    if not append_signature_value(parts, color and color.r) then return nil end
    if not append_signature_value(parts, color and color.g) then return nil end
    if not append_signature_value(parts, color and color.b) then return nil end
    if not append_signature_value(parts, color and color.a) then return nil end
    if not append_signature_value(parts, bar_bg_color and bar_bg_color.r) then return nil end
    if not append_signature_value(parts, bar_bg_color and bar_bg_color.g) then return nil end
    if not append_signature_value(parts, bar_bg_color and bar_bg_color.b) then return nil end
    if not append_signature_value(parts, bar_bg_color and bar_bg_color.a) then return nil end
    if not append_signature_value(parts, bar_text_color and bar_text_color.r) then return nil end
    if not append_signature_value(parts, bar_text_color and bar_text_color.g) then return nil end
    if not append_signature_value(parts, bar_text_color and bar_text_color.b) then return nil end

    for i = 1, display_count do
        local entry = list[i]
        if not entry or entry.is_test_preview or entry.scan_remaining ~= nil then return nil end

        local is_spell_cooldown = entry.is_spell_cooldown == true
        local has_stable_timing = is_spell_cooldown
            or frame.category == "static"
            or (entry.expiration ~= nil and not issecretvalue(entry.expiration))
        if not has_stable_timing then return nil end

        parts[#parts + 1] = "#"
        if not append_signature_value(parts, entry.instance_id) then return nil end
        if not append_signature_value(parts, entry.category) then return nil end
        if not append_signature_value(parts, entry.spell_id) then return nil end
        if not append_signature_value(parts, entry.name) then return nil end
        if not append_signature_value(parts, entry.icon) then return nil end
        if not append_signature_value(parts, entry.count) then return nil end
        if not append_signature_value(parts, entry.live_count) then return nil end
        if not append_signature_value(parts, entry.duration) then return nil end
        if not append_signature_value(parts, entry.expiration) then return nil end
        if not append_signature_value(parts, entry.cdm_order) then return nil end
        if not append_signature_value(parts, entry.custom_order) then return nil end
        if not append_signature_value(parts, entry.order_key) then return nil end
        if not append_signature_value(parts, entry.grey_cooldown) then return nil end
        if not append_signature_value(parts, entry.duration_object) then return nil end
        parts[#parts + 1] = is_spell_cooldown and "spellcd" or "aura"
    end

    return table_concat(parts, "|")
end

local function assign_aura_object_metadata(obj, entry, live_remaining, live_duration, is_spell_cooldown, is_static_entry, now, timer_category, timer_behavior, tooltip_enabled)
    obj.aura_index      = (not is_spell_cooldown and type(entry.instance_id) == "number") and entry.instance_id or nil
    obj.aura_name       = entry.name
    obj.aura_duration   = entry.duration
    obj.aura_remaining  = entry.remaining
    obj.aura_expiration = (live_remaining and not issecretvalue(live_remaining) and live_remaining > 0)
                          and (now + live_remaining)
                          or entry.expiration
    obj.aura_live_duration = (not is_spell_cooldown) and live_duration or nil
    obj.aura_scan_time  = now
    obj.aura_spell_id   = entry.spell_id
    obj.aura_category   = timer_category
    obj.aura_timer_behavior = timer_behavior
    obj.tooltip_enabled = tooltip_enabled
    obj.is_test_preview = entry.is_test_preview or false
    obj.is_spell_cooldown = is_spell_cooldown
    obj.aura_is_static = is_static_entry == true
    obj.grey_cooldown = entry.grey_cooldown == true
end

local function configure_aura_visual(
    obj,
    entry,
    bar_mode,
    color,
    bar_bg_color,
    bar_text_color,
    stack_text,
    show_cooldown_overlay,
    cooldown_is_active,
    live_duration,
    cooldown_duration,
    is_spell_cooldown
)
    set_texture_if_changed(obj.texture, entry.icon)  -- secret icon OK for SetTexture
    set_icon_greyed(obj.texture, show_cooldown_overlay and cooldown_is_active)
    if obj.cooldown then
        set_shown_if_changed(obj.cooldown, false)
    end

    if bar_mode then
        set_shown_if_changed(obj.bar, true)
        set_status_bar_color_if_changed(obj.bar, color.r, color.g, color.b, color.a or 1)
        if obj.bar_bg then
            local bg = bar_bg_color or M.get_bar_bg_color(nil, nil, color)
            set_texture_color_if_changed(obj.bar_bg, bg.r, bg.g, bg.b, bg.a or 1)
        end
        set_name_text_if_changed(obj.name_text, entry.name)  -- name may be secret; SetText is safe
        set_font_color_if_changed(obj.name_text, bar_text_color.r or 1, bar_text_color.g or 1, bar_text_color.b or 1, 1)
        set_shown_if_changed(obj.name_text, true)
        set_count_text(obj, stack_text, "LEFT", obj.bar, "LEFT", 4, 0)
    else
        set_shown_if_changed(obj.bar, false)
        set_shown_if_changed(obj.name_text, false)
        if show_cooldown_overlay and live_duration then
            apply_cooldown_overlay(obj, live_duration, entry.expiration, entry.duration)
        elseif is_spell_cooldown then
            apply_cooldown_overlay(obj, cooldown_duration, entry.expiration, entry.duration)
        end
        set_count_text(obj, stack_text)
    end
end

local function clear_timer_and_fill_bar(obj, bar_mode)
    clear_timer_text(obj.time_text)
    if bar_mode then
        set_bar_minmax_if_changed(obj.bar, 0, 1)
        obj.bar:SetValue(1)
    end
end

local function set_render_timer_text(show_render_timer_text, obj, timer_category, timer_behavior, seconds)
    if show_render_timer_text then
        M.set_timer_text(obj.time_text, timer_category, seconds, timer_behavior)
    else
        clear_timer_text(obj.time_text)
    end
end

local function set_duration_object_bar(obj, duration_object)
    if obj.bar and obj.bar.SetTimerDuration and TIMER_DIR_REMAINING then
        obj.bar:SetTimerDuration(duration_object, nil, TIMER_DIR_REMAINING)
        return true
    end
    return false
end

local function update_aura_timer_and_bar(
    obj,
    entry,
    timer_category,
    timer_behavior,
    bar_mode,
    show_render_timer_text,
    show_timer_swipe,
    is_static_frame,
    live_remaining,
    live_duration,
    cooldown_duration,
    now
)
    -- Static frame buffs are effectively permanent; never display a timer string.
    if is_static_frame then
        clear_timer_and_fill_bar(obj, bar_mode)
        return
    end

    -- Prefer live duration by auraInstanceID; fall back to cached values.
    local remaining = live_remaining
    if remaining ~= nil then
        if issecretvalue(remaining) then
            local display_remaining = nil
            if entry.expiration and entry.expiration > 0 then
                display_remaining = math_max(0, entry.expiration - now)
            elseif entry.remaining and entry.remaining > 0 then
                display_remaining = entry.remaining
            end

            if display_remaining and display_remaining > 0 then
                set_render_timer_text(show_render_timer_text, obj, timer_category, timer_behavior, display_remaining)
            else
                set_render_timer_text(show_render_timer_text, obj, timer_category, timer_behavior, remaining)
            end
            if bar_mode then
                set_duration_object_bar(obj, live_duration)
            end
        elseif remaining > 0 then
            set_render_timer_text(show_render_timer_text, obj, timer_category, timer_behavior, remaining)
            if bar_mode then
                if not set_duration_object_bar(obj, live_duration) then
                    set_bar_minmax_if_changed(obj.bar, 0, entry.duration > 0 and entry.duration or remaining)
                    obj.bar:SetValue(remaining)
                end
            end
        else
            clear_timer_and_fill_bar(obj, bar_mode)
        end
    elseif cooldown_duration then
        clear_timer_text(obj.time_text)
        if bar_mode and not set_duration_object_bar(obj, cooldown_duration) then
            set_bar_minmax_if_changed(obj.bar, 0, 1)
            obj.bar:SetValue(1)
        end
    elseif entry.duration > 0 then
        remaining = entry.expiration > 0 and math_max(0, entry.expiration - now) or entry.remaining
        if remaining > 0 then
            set_render_timer_text(show_render_timer_text, obj, timer_category, timer_behavior, remaining)
            if bar_mode then
                set_bar_minmax_if_changed(obj.bar, 0, entry.duration)
                obj.bar:SetValue(remaining)
            elseif show_timer_swipe then
                apply_cooldown_overlay(obj, nil, entry.expiration, entry.duration)
            end
        else
            clear_timer_and_fill_bar(obj, bar_mode)
        end
    end
end

local function resolve_entry_live_timing(entry, show_timer_text, bar_mode, is_static_frame, is_spell_cooldown)
    local has_cached_timing = entry.duration and not issecretvalue(entry.duration) and entry.duration > 0
        and entry.expiration and not issecretvalue(entry.expiration) and entry.expiration > 0
    local need_live_duration = (not is_static_frame)
        and (not is_spell_cooldown)
        and (show_timer_text or bar_mode)
        and type(entry.instance_id) == "number"
        and ((not has_cached_timing) or entry.scan_remaining ~= nil)
    local live_duration = nil
    if need_live_duration then
        local ok, result = pcall(C_UnitAuras.GetAuraDuration, "player", entry.instance_id)
        if ok then live_duration = result end
    end

    local cooldown_duration = is_spell_cooldown and entry.duration_object or nil
    if cooldown_duration then
        live_duration = cooldown_duration
    end

    return live_duration, get_duration_object_remaining(live_duration) or entry.scan_remaining, cooldown_duration
end

local function add_custom_entries_to_render_list(list, aura_map)
    for _, entry in pairs(aura_map) do
        list[#list + 1] = entry
    end
    table_sort(list, function(a, b)
        local aa = a.custom_order or 9999
        local bb = b.custom_order or 9999
        if aa == bb then
            return get_entry_sort_id(a) < get_entry_sort_id(b)
        end
        return aa < bb
    end)
end

local function add_preset_entries_to_render_list(frame, list, aura_map, aura_filter, sort_mode)
    -- Resolve sort parameters for GetUnitAuraInstanceIDs.
    local sort_rule = SORT_RULE_DEFAULT
    local sort_dir  = SORT_DIR_NORMAL
    if sort_mode == "timeleft" then
        sort_rule = SORT_RULE_EXPIRATION
        -- Normal = ascending expiration time = soonest to expire first (most urgent).
    elseif sort_mode == "name" then
        sort_rule = SORT_RULE_NAME
    end

    local wow_filter = (aura_filter and aura_filter:find("HARMFUL", 1, true)) and "HARMFUL" or "HELPFUL"
    local cache_key = wow_filter .. sort_rule .. (sort_dir or 0)
    local sorted_ids = _sorted_aura_ids_cache[cache_key]
    if sorted_ids == nil then
        sorted_ids = C_UnitAuras.GetUnitAuraInstanceIDs("player", wow_filter, nil, sort_rule, sort_dir)
        _sorted_aura_ids_cache[cache_key] = sorted_ids or false
    elseif sorted_ids == false then
        sorted_ids = nil
    end

    -- Build display list in game-sorted order, filtered to entries in this frame's map.
    if sorted_ids then
        local seen = _scratch_seen
        wipe(seen)
        for _, iid in ipairs(sorted_ids) do
            local entry = aura_map[iid]
            if entry then
                list[#list + 1] = entry
                seen[iid] = true
            end
        end
        for key, entry in pairs(aura_map) do
            if not seen[key] then
                list[#list + 1] = entry
            end
        end
    else
        -- Fallback: iterate map directly (sorted_ids nil = API unavailable).
        for _, entry in pairs(aura_map) do list[#list + 1] = entry end
        table_sort(list, function(a, b) return get_entry_sort_id(a) < get_entry_sort_id(b) end)
    end
end

local function apply_short_frame_render_order(frame, list)
    frame._short_order_map = frame._short_order_map or {}
    frame._short_order_next = frame._short_order_next or 1

    local seen_keys = _scratch_seen_keys
    wipe(seen_keys)
    for _, entry in ipairs(list) do
        local key = entry.order_key or ("iid:" .. tostring(entry.instance_id))

        if not frame._short_order_map[key] then
            frame._short_order_map[key] = frame._short_order_next
            frame._short_order_next = frame._short_order_next + 1
        end

        entry._short_order = frame._short_order_map[key]
        seen_keys[key] = true
    end

    -- Cleanup removed keys so re-applied buffs are treated as new entries.
    for key in pairs(frame._short_order_map) do
        if not seen_keys[key] then
            frame._short_order_map[key] = nil
        end
    end

    table_sort(list, function(a, b)
        local aa = a._short_order or 0
        local bb = b._short_order or 0
        if aa == bb then
            return get_entry_sort_id(a) < get_entry_sort_id(b)
        end
        return aa < bb
    end)
end

local function apply_cdm_frame_render_order(list)
    table_sort(list, function(a, b)
        local aa = a.cdm_order or 9999
        local bb = b.cdm_order or 9999
        if aa == bb then
            return get_entry_sort_id(a) < get_entry_sort_id(b)
        end
        return aa < bb
    end)
end

local function build_render_list(frame, aura_map, aura_filter, sort_mode)
    local list = _scratch_list
    wipe(list)

    if frame.is_custom then
        add_custom_entries_to_render_list(list, aura_map)
    else
        add_preset_entries_to_render_list(frame, list, aura_map, aura_filter, sort_mode)
    end

    if frame.category == "short" then
        apply_short_frame_render_order(frame, list)
    elseif M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[frame.category] then
        apply_cdm_frame_render_order(list)
    end

    return list
end

local function hide_unused_icons(icons, first_unused_index)
    for i = first_unused_index, #icons do
        local obj = icons[i]
        obj.is_spell_cooldown = false
        obj.grey_cooldown = false
        obj.aura_index = nil
        obj.aura_live_duration = nil
        obj.aura_timer_behavior = nil
        obj.tooltip_enabled = false
        obj._lstweeks_count_text = nil
        set_icon_greyed(obj.texture, false)
        if obj.cooldown then
            obj.cooldown:Hide()
        end
        obj:Hide()
    end
end

--#endregion TIMER TEXT ========================================================

--#region AURA INFO MERGING ====================================================

-- Merge UNIT_AURA payloads while a deferred scan is pending.
-- Blizzard can fire multiple UNIT_AURA events inside the shared aura bucket window;
-- we need to union their added/updated/removed IDs so no aura changes are lost.
function M.merge_aura_info(dst, src)
    if not src then return dst end
    dst = dst or {}

    local function merge_id_list(key, list)
        if not list then return end
        dst[key] = dst[key] or {}
        dst[key.."_set"] = dst[key.."_set"] or {}
        for _, iid in ipairs(list) do
            if iid and not dst[key.."_set"][iid] then
                dst[key.."_set"][iid] = true
                dst[key][#dst[key] + 1] = iid
            end
        end
    end

    merge_id_list("removedAuraInstanceIDs", src.removedAuraInstanceIDs)
    merge_id_list("updatedAuraInstanceIDs", src.updatedAuraInstanceIDs)

    -- Modern payload: addedAuras = array of aura tables with auraInstanceID.
    if src.addedAuras then
        dst.addedAuras = dst.addedAuras or {}
        dst.addedAuras_set = dst.addedAuras_set or {}
        for _, aura in ipairs(src.addedAuras) do
            local iid = aura and aura.auraInstanceID
            if iid and not dst.addedAuras_set[iid] then
                dst.addedAuras_set[iid] = true
                dst.addedAuras[#dst.addedAuras + 1] = aura
            end
        end
    end

    -- Backward/alternate payload support.
    merge_id_list("addedAuraInstanceIDs", src.addedAuraInstanceIDs)

    if src.isFullUpdate then
        dst.isFullUpdate = true
    end

    return dst
end

--#endregion AURA INFO MERGING =================================================

--#region AURA MAP RENDERER ====================================================

-- Main render orchestrator for one aura frame.
-- Order is intentional: build/sort the display list, resolve per-entry live timing,
-- assign tooltip/ticker metadata, configure icon/bar visuals,
-- update timer text/bar progress, then hide unused pooled icons.
-- Keep source-specific decisions inside the helpers so this function remains a readable control flow.
function M.render_aura_map(self, aura_map, bar_mode, color, bar_bg_color, max_limit, aura_filter, sort_mode, show_timer_text, bar_text_color)
    local list = build_render_list(self, aura_map, aura_filter, sort_mode)
    local display_count = math_min(#list, math_min(max_limit, #self.icons))
    local now = GetTime()
    local is_static_frame = (self.category == "static")
    local show_cooldown_overlay = self._show_cooldown_overlay == true
    local show_render_timer_text = show_timer_text and not show_cooldown_overlay
    local show_timer_swipe = self._show_timer_swipe ~= false
    local tooltip_enabled = self._show_tooltip ~= false
    local frame_timer_category = self.category
    local frame_timer_behavior = (not self.is_custom) and M.get_timer_behavior(frame_timer_category) or nil
    local timer_behaviors = nil
    local display_signature = build_display_signature(
        self,
        list,
        display_count,
        bar_mode,
        color,
        bar_bg_color,
        bar_text_color,
        max_limit,
        sort_mode,
        show_render_timer_text,
        show_timer_swipe,
        show_cooldown_overlay,
        tooltip_enabled
    )
    if display_signature and self._render_display_signature == display_signature then
        self._display_count = display_count
        if tooltip_enabled and M.prewarm_aura_tooltip_cache then
            M.prewarm_aura_tooltip_cache(self)
        end
        return display_count
    end
    self._render_display_signature = display_signature
    self._tooltip_cache_retry_count = 0

    if self.is_custom then
        timer_behaviors = _scratch_timer_behaviors
        wipe(timer_behaviors)
    end

    for i = 1, display_count do
        local obj   = self.icons[i]
        local entry = list[i]
        local timer_category = frame_timer_category
        local timer_behavior = frame_timer_behavior
        if timer_behaviors then
            timer_category = get_timer_category(self, entry)
            timer_behavior = timer_behaviors[timer_category]
            if not timer_behavior then
                timer_behavior = M.get_timer_behavior(timer_category)
                timer_behaviors[timer_category] = timer_behavior
            end
        end
        local live_count = entry.live_count
        local is_spell_cooldown = entry.is_spell_cooldown == true
        local is_static_entry = is_static_frame or (self.is_custom and entry.category == "static")
        local live_duration, live_remaining, cooldown_duration =
            resolve_entry_live_timing(entry, show_timer_text, bar_mode, is_static_entry, is_spell_cooldown)

        assign_aura_object_metadata(obj, entry, live_remaining, live_duration, is_spell_cooldown, is_static_entry, now, timer_category, timer_behavior, tooltip_enabled)

        local cooldown_is_active = is_spell_cooldown and obj.grey_cooldown
        local stack_text = resolve_stack_text(entry, live_count)
        configure_aura_visual(
            obj,
            entry,
            bar_mode,
            color,
            bar_bg_color,
            bar_text_color,
            stack_text,
            show_cooldown_overlay,
            cooldown_is_active,
            live_duration,
            cooldown_duration,
            is_spell_cooldown
        )

        update_aura_timer_and_bar(
            obj,
            entry,
            timer_category,
            timer_behavior,
            bar_mode,
            show_render_timer_text,
            show_timer_swipe,
            is_static_entry,
            live_remaining,
            live_duration,
            cooldown_duration,
            now
        )

        set_shown_if_changed(obj, true)
    end

    hide_unused_icons(self.icons, display_count + 1)
    self._display_count = display_count
    if tooltip_enabled and M.prewarm_aura_tooltip_cache then
        M.prewarm_aura_tooltip_cache(self)
    end

    return display_count
end

--#endregion AURA MAP RENDERER =================================================
