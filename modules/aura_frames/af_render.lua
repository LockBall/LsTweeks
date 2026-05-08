-- Renders the current aura_map into visible icon frames for each category (static / short / long / debuff).
-- render_aura_map() assigns textures, counts, and timer text to pooled icon frames
-- set_timer_text() formats the countdown
-- merge_aura_info() combines pending UNIT_AURA payloads before the deferred scan.

local addon_name, addon = ...

local floor      = math.floor
local math_max   = math.max
local math_min   = math.min
local GetTime    = GetTime
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local format        = format
local table_sort    = table.sort
local SORT_RULE_DEFAULT    = Enum.UnitAuraSortRule.Default
local SORT_RULE_EXPIRATION = Enum.UnitAuraSortRule.ExpirationOnly
local SORT_RULE_NAME       = Enum.UnitAuraSortRule.NameOnly
local SORT_DIR_NORMAL      = Enum.UnitAuraSortDirection.Normal
local TIMER_DIR_REMAINING  = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

-- Scratch tables reused every render_aura_map call to avoid per-frame allocation.
local _scratch_list      = {}
local _scratch_seen      = {}
local _scratch_seen_keys = {}

-- ============================================================================
-- TIME FORMATTING

-- Logic for converting seconds into readable text strings
local function format_time(s)
    if s >= 3600 then return format("%d h", floor(s/3600)) end
    if s >= 60 then return format("%d m", floor(s/60)) end
    if s >= 5 then return format("%d s", floor(s)) end
    if s >= 1 then return format("%.1f s", s) end
    return format("%.1f s", s)
end

-- ============================================================================
-- SORT HELPERS

local function get_entry_sort_id(entry)
    if type(entry.instance_id) == "number" then
        return entry.instance_id
    end
    return entry.preview_sort_id or 0
end

-- ============================================================================
-- TIMER TEXT

-- Single timer text renderer for all aura timers (live + test).
-- Keep behavior changes here so all timer displays stay consistent.
function M.set_timer_text(font_string, category, seconds)
    if not font_string then return end

    if seconds == nil then
        if font_string._last_text ~= "" then
            font_string:SetText("")
            font_string._last_text = ""
        end
        return
    end

    font_string:Show()

    if issecretvalue(seconds) then
        font_string:SetFormattedText("%.1f", seconds)
        font_string._last_text = nil  -- secret value, can't cache
        return
    end

    if seconds <= 0 then
        if font_string._last_text ~= "" then
            font_string:SetText("")
            font_string._last_text = ""
        end
        return
    end

    local is_short = (category == "short" or category == "show_short")
    local text
    if is_short then
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

    cooldown:Show()
    if duration_object and cooldown.SetCooldownFromDurationObject then
        local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration_object, true)
        if ok then return end
        ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration_object)
        if ok then return end
    end

    if expiration and duration and duration > 0 then
        cooldown:SetCooldown(expiration - duration, duration)
    elseif cooldown.Clear then
        cooldown:Clear()
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

local function set_count_text(obj, text, point, relative_to, relative_point, x, y)
    if issecretvalue(text) then
        obj._lstweeks_count_text = nil
        obj.count_text:SetText(text)
        if point then
            obj.count_text:SetPoint(point, relative_to, relative_point, x, y)
        end
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
        if point then
            obj.count_text:SetPoint(point, relative_to, relative_point, x, y)
        end
        if not obj.count_text:IsShown() then
            obj.count_text:Show()
        end
    else
        obj._lstweeks_count_text = nil
        if obj.count_text:IsShown() then
            obj.count_text:Hide()
        end
    end
end

-- ============================================================================
-- AURA INFO MERGING

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

-- ============================================================================
-- AURA MAP RENDERER

-- Render the aura_map into the icon pool. Preset frames use C_UnitAuras.GetUnitAuraInstanceIDs
-- for game-provided sort order; custom frames keep the selected-filter scan order.
function M.render_aura_map(self, aura_map, bar_mode, color, bar_bg_color, max_limit, aura_filter, sort_mode, show_timer_text, bar_text_color)
    local bar_bg_alpha = M.BAR_BG_ALPHA_DEFAULT
    local list = _scratch_list
    wipe(list)

    if self.is_custom then
        for _, entry in pairs(aura_map) do list[#list + 1] = entry end
        table_sort(list, function(a, b)
            local aa = a.custom_order or 9999
            local bb = b.custom_order or 9999
            if aa == bb then
                return get_entry_sort_id(a) < get_entry_sort_id(b)
            end
            return aa < bb
        end)
    else
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
        local sorted_ids
        if self._sorted_ids_cache and self._sorted_ids_cache_key == cache_key then
            sorted_ids = self._sorted_ids_cache
        else
            sorted_ids = C_UnitAuras.GetUnitAuraInstanceIDs("player", wow_filter, nil, sort_rule, sort_dir)
            self._sorted_ids_cache = sorted_ids
            self._sorted_ids_cache_key = cache_key
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

    -- Short frame ordering: stable per-aura order key so stack updates don't
    -- reposition existing buffs. New keys get appended at the end.
    if self.category == "short" then
        self._short_order_map = self._short_order_map or {}
        self._short_order_next = self._short_order_next or 1

        local seen_keys = _scratch_seen_keys
        wipe(seen_keys)
        for _, entry in ipairs(list) do
            local key = entry.order_key or ("iid:" .. tostring(entry.instance_id))

            if not self._short_order_map[key] then
                self._short_order_map[key] = self._short_order_next
                self._short_order_next = self._short_order_next + 1
            end

            entry._short_order = self._short_order_map[key]
            seen_keys[key] = true
        end

        -- Cleanup removed keys so re-applied buffs are treated as new entries.
        for key in pairs(self._short_order_map) do
            if not seen_keys[key] then
                self._short_order_map[key] = nil
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
    elseif M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[self.category] then
        table_sort(list, function(a, b)
            local aa = a.cdm_order or 9999
            local bb = b.cdm_order or 9999
            if aa == bb then
                return get_entry_sort_id(a) < get_entry_sort_id(b)
            end
            return aa < bb
        end)
    end

    local display_count = math_min(#list, math_min(max_limit, #self.icons))
    local now = GetTime()
    local is_static_frame = (self.category == "static")

    for i = 1, display_count do
        local obj   = self.icons[i]
        local entry = list[i]
        local timer_category = get_timer_category(self, entry)
        local live_count = entry.live_count
        local is_spell_cooldown = entry.is_spell_cooldown == true
        local show_cooldown_overlay = M.uses_cooldown_icon_overlay(self.category, bar_mode, M.db)
        local has_cached_timing = entry.duration and not issecretvalue(entry.duration) and entry.duration > 0
            and entry.expiration and not issecretvalue(entry.expiration) and entry.expiration > 0
        local need_live_duration = (not is_static_frame)
            and (not is_spell_cooldown)
            and (show_timer_text or bar_mode)
            and type(entry.instance_id) == "number"
            and ((not has_cached_timing) or entry.live_remaining ~= nil)
        local live_duration = nil
        if need_live_duration then
            local ok, result = pcall(C_UnitAuras.GetAuraDuration, "player", entry.instance_id)
            if ok then live_duration = result end
        end
        local cooldown_duration = is_spell_cooldown and entry.duration_object or nil
        if cooldown_duration then
            live_duration = cooldown_duration
        end
        local live_remaining = get_duration_object_remaining(live_duration) or entry.live_remaining

        obj.aura_index      = (not is_spell_cooldown and type(entry.instance_id) == "number") and entry.instance_id or nil
        obj.filter_type     = entry.filter
        obj.aura_name       = entry.name
        obj.aura_icon       = entry.icon
        obj.aura_duration   = entry.duration
        obj.aura_remaining  = entry.remaining
        obj.aura_count      = entry.count
        obj.aura_expiration = (live_remaining and not issecretvalue(live_remaining) and live_remaining > 0)
                              and (now + live_remaining)
                              or entry.expiration
        obj.aura_scan_time  = now
        obj.aura_spell_id   = entry.spell_id
        obj.aura_category   = timer_category
        obj.is_test_preview = entry.is_test_preview or false
        obj.is_spell_cooldown = is_spell_cooldown
        obj.grey_cooldown = entry.grey_cooldown == true

        local cooldown_remaining = live_remaining
        if cooldown_remaining ~= nil and issecretvalue(cooldown_remaining) then
            cooldown_remaining = nil
        end
        local cooldown_is_active = is_spell_cooldown and obj.grey_cooldown
        obj.texture:SetTexture(entry.icon)  -- secret icon OK for SetTexture
        set_icon_greyed(obj.texture, show_cooldown_overlay and cooldown_is_active)
        if obj.cooldown then
            obj.cooldown:Hide()
        end

        local stack_text = nil
        if entry.count and not issecretvalue(entry.count) and entry.count > 1 then
            stack_text = entry.count
        elseif live_count ~= nil and not issecretvalue(live_count) then
            if type(live_count) == "number" then
                if live_count > 1 then
                    stack_text = live_count
                end
            elseif type(live_count) == "string" then
                if live_count ~= "" and live_count ~= "1" then
                    stack_text = live_count
                end
            else
                stack_text = live_count
            end
        else
            -- Secret live_count is safe to display, but we cannot compare it.
            -- Preserve combat behavior by showing it only when no safe fallback exists.
            stack_text = live_count
        end
        if bar_mode then
            obj.bar:Show()
            obj.bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
            if obj.bar_bg then
                local bg = bar_bg_color or { r = color.r, g = color.g, b = color.b, a = bar_bg_alpha }
                obj.bar_bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 1)
            end
            -- In bar mode: append stack count to name if present
            obj.name_text:SetText(entry.name)  -- name may be secret; SetText is safe
            obj.name_text:SetTextColor(bar_text_color.r or 1, bar_text_color.g or 1, bar_text_color.b or 1, 1)
            obj.name_text:Show()
            set_count_text(obj, stack_text, "LEFT", obj.bar, "LEFT", 4, 0)
        else
            obj.bar:Hide()
            obj.name_text:Hide()
            if show_cooldown_overlay and live_duration then
                apply_cooldown_overlay(obj, live_duration, entry.expiration, entry.duration)
            elseif is_spell_cooldown then
                apply_cooldown_overlay(obj, cooldown_duration, entry.expiration, entry.duration)
            end
            -- In icon mode: stack count at bottom-right of icon
            set_count_text(obj, stack_text)
        end

        -- Static frame buffs are effectively permanent; never display a timer string.
        if is_static_frame then
            obj.time_text:SetText("")
            if bar_mode then
                obj.bar:SetMinMaxValues(0, 1)
                obj.bar:SetValue(1)
            end
        else
        -- Prefer live duration by auraInstanceID; fall back to cached values.
        local rem = live_remaining
        if rem ~= nil then
            if issecretvalue(rem) then
                local display_remaining = nil
                if entry.expiration and entry.expiration > 0 then
                    display_remaining = math_max(0, entry.expiration - now)
                elseif entry.remaining and entry.remaining > 0 then
                    display_remaining = entry.remaining
                end

                if display_remaining and display_remaining > 0 then
                    if show_timer_text and not show_cooldown_overlay then
                        M.set_timer_text(obj.time_text, timer_category, display_remaining)
                    else
                        obj.time_text:SetText("")
                    end
                else
                    if show_timer_text and not show_cooldown_overlay then
                        M.set_timer_text(obj.time_text, timer_category, rem)
                    else
                        obj.time_text:SetText("")
                    end
                end
                if bar_mode and obj.bar and obj.bar.SetTimerDuration and TIMER_DIR_REMAINING then
                    obj.bar:SetTimerDuration(live_duration, nil, TIMER_DIR_REMAINING)
                end
            elseif rem > 0 then
                if show_timer_text and not show_cooldown_overlay then
                    M.set_timer_text(obj.time_text, timer_category, rem)
                else
                    obj.time_text:SetText("")
                end
                if bar_mode then
                    if obj.bar and obj.bar.SetTimerDuration and TIMER_DIR_REMAINING then
                        obj.bar:SetTimerDuration(live_duration, nil, TIMER_DIR_REMAINING)
                    else
                        obj.bar:SetMinMaxValues(0, entry.duration > 0 and entry.duration or rem)
                        obj.bar:SetValue(rem)
                    end
                end
            else
                obj.time_text:SetText("")
                if bar_mode then
                    obj.bar:SetMinMaxValues(0, 1)
                    obj.bar:SetValue(1)
                end
            end
        elseif cooldown_duration then
            obj.time_text:SetText("")
            if bar_mode then
                if obj.bar and obj.bar.SetTimerDuration and TIMER_DIR_REMAINING then
                    obj.bar:SetTimerDuration(cooldown_duration, nil, TIMER_DIR_REMAINING)
                else
                    obj.bar:SetMinMaxValues(0, 1)
                    obj.bar:SetValue(1)
                end
            end
        elseif entry.duration > 0 then
            rem = entry.expiration > 0 and math_max(0, entry.expiration - now) or entry.remaining
            if rem > 0 then
                if show_timer_text and not show_cooldown_overlay then
                    M.set_timer_text(obj.time_text, timer_category, rem)
                else
                    obj.time_text:SetText("")
                end
                if bar_mode then
                    obj.bar:SetMinMaxValues(0, entry.duration)
                    obj.bar:SetValue(rem)
                else
                    apply_cooldown_overlay(obj, nil, entry.expiration, entry.duration)
                end
            else
                obj.time_text:SetText("")
                if bar_mode then
                    obj.bar:SetMinMaxValues(0, 1)
                    obj.bar:SetValue(1)
                end
            end
        end
        end

        obj:Show()
    end

    for i = display_count + 1, #self.icons do
        self.icons[i].is_spell_cooldown = false
        self.icons[i].grey_cooldown = false
        self.icons[i].aura_index = nil
        self.icons[i].aura_count = nil
        self.icons[i]._lstweeks_count_text = nil
        set_icon_greyed(self.icons[i].texture, false)
        if self.icons[i].cooldown then
            self.icons[i].cooldown:Hide()
        end
        self.icons[i]:Hide()
    end

    return display_count
end
