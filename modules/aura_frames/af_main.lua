-- Bootstrap and frame construction for the aura frames module
-- loads last so all other af_* files have already populated M.
-- Creates preset and custom aura frames with their icon pools,
-- buckets UNIT_AURA events, starts the timer ticker, and registers the settings tab.

local addon_name, addon = ...
local M = addon.aura_frames

--#region MODULE STATE AND COOLDOWN REFRESH ====================================
-- Runtime state tables. The saved DB is attached during ADDON_LOADED.
M.frames = M.frames or {}
M.frames_list = M.frames_list or {}
M.controls = M.controls or {}

-- CACHED GLOBALS AND CONSTANTS
local format = string.format
local issecretvalue = issecretvalue
local issecrettable = issecrettable
local securecallfunction = securecallfunction
local WOW_COOLDOWN_CATEGORIES = M.CDM_CATEGORIES
local UPDATE_INTERVALS = M.UPDATE_INTERVALS

local WOW_COOLDOWN_REFRESH_PROFILES = {
    immediate = {
        delays = { UPDATE_INTERVALS.next_frame },
        prepare_viewers = false,
        clear_child_cache = true,
    },
    hook = {
        delays = { UPDATE_INTERVALS.next_frame },
        prepare_viewers = false,
        clear_child_cache = false,
        defer_zero = true,
    },
    combat_entry = {
        delays = {
            UPDATE_INTERVALS.tenth_sec,
            UPDATE_INTERVALS.fifth_sec,
            UPDATE_INTERVALS.six_tenths_sec,
        },
        prepare_viewers = false,
        clear_child_cache = false,
        mark_scan_dirty = true,
    },
    startup = {
        delays = {
            UPDATE_INTERVALS.fifth_sec,
            UPDATE_INTERVALS.six_tenths_sec,
            UPDATE_INTERVALS.one_point_two_sec,
            UPDATE_INTERVALS.two_point_five_sec,
            UPDATE_INTERVALS.five_sec,
        },
        prepare_viewers = true,
        clear_child_cache = true,
    },
    settings = {
        delays = {
            UPDATE_INTERVALS.next_frame,
            UPDATE_INTERVALS.fifth_sec,
            UPDATE_INTERVALS.six_tenths_sec,
            UPDATE_INTERVALS.one_point_two_sec,
        },
        prepare_viewers = true,
        clear_child_cache = true,
    },
}

local function remove_runtime_frame_from_list(frame)
    local frames_list = M.frames_list
    if not (frames_list and frame) then return end
    for i = #frames_list, 1, -1 do
        if frames_list[i] == frame then
            table.remove(frames_list, i)
        end
    end
end

local function register_runtime_frame(show_key, frame)
    local old_frame = M.frames[show_key]
    if old_frame and old_frame ~= frame then
        remove_runtime_frame_from_list(old_frame)
    end
    remove_runtime_frame_from_list(frame)
    M.frames[show_key] = frame
    M.frames_list[#M.frames_list + 1] = frame
end

local function unregister_runtime_frame(show_key)
    local frame = M.frames[show_key]
    if frame then
        remove_runtime_frame_from_list(frame)
    end
    M.frames[show_key] = nil
    return frame
end

M.NUMBER_FONT_OPTIONS = {
    {
        key = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
        label = "Source Code Pro",
        path = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Regular.ttf",
        size = 9,
        flags = "",
    },
    {
        key = "game_default",
        label = "Game Default",
        path = nil,
        size = nil,
        flags = nil,
    },
}

M.NUMBER_FONT_OPTIONS_BY_KEY = {}
for _, def in ipairs(M.NUMBER_FONT_OPTIONS) do
    M.NUMBER_FONT_OPTIONS_BY_KEY[def.key] = def
end

M.NUMBER_FONT_BOLD_PATHS = {
    [M.DEFAULT_TIMER_NUMBER_FONT_KEY] = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Bold.ttf",
}

local function get_number_font_def(key, category, cfg_db)
    local selected_key = key or M.get_setting(cfg_db, category, "timer_number_font", M.DEFAULT_TIMER_NUMBER_FONT_KEY)
    return M.NUMBER_FONT_OPTIONS_BY_KEY[selected_key] or M.NUMBER_FONT_OPTIONS[1]
end

function M.get_number_font_options()
    return M.NUMBER_FONT_OPTIONS
end

function M.apply_number_font_to_text(font_string, category, cfg_db)
    if not font_string or not font_string.SetFont then return end
    local def = get_number_font_def(nil, category, cfg_db)
    local size = M.get_timer_number_font_size(category, cfg_db) or def.size or 10
    local flags = def.flags or ""

    -- Always pass an integer size to SetFont. WoW/FreeType rounds fractional
    -- sizes inconsistently; doing it ourselves keeps rendering deterministic.
    size = math.floor(size + 0.5)

    if size < 6 then size = 6 end
    if size > 18 then size = 18 end

    if def.path then
        local use_bold = M.get_setting(cfg_db, category, "timer_number_font_bold", false) == true
        local bold_path = use_bold and M.NUMBER_FONT_BOLD_PATHS[def.key]
        font_string:SetFont(bold_path or def.path, size, flags)
    elseif STANDARD_TEXT_FONT then
        font_string:SetFont(STANDARD_TEXT_FONT, size, flags)
    else
        font_string:SetFontObject(GameFontHighlightSmall)
    end

    if cfg_db or M.db then
        -- Custom frames store timer_color directly; preset frames use timer_color_<cat>.
        local c = M.get_setting(cfg_db, category, "timer_color")
        if c then
            font_string:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
        end
    end
end

function M.apply_number_font_to_all()
    local frames_list = M.frames_list
    if not frames_list then return end
    for i = 1, #frames_list do
        local frame = frames_list[i]
        if frame and frame.icons then
            local category = frame.category
            local cfg_db = frame._cfg_db
            for _, obj in ipairs(frame.icons) do
                if obj and obj.time_text then
                    M.apply_number_font_to_text(obj.time_text, category, cfg_db)
                end
            end
        end
    end
end

local function run_wow_cooldown_refresh(refresh_config, category_filter)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then return end
    if not M.frames then return end

    if refresh_config.mark_scan_dirty and M.mark_aura_scan_dirty then
        M.mark_aura_scan_dirty()
    end

    if M.update_all_blizz_cdm_visibility then
        M.update_all_blizz_cdm_visibility()
    end

    local should_prepare_viewers = refresh_config.prepare_viewers and M.prepare_blizz_cdm_viewer
    local should_clear_child_cache = refresh_config.clear_child_cache and M.clear_cooldown_viewer_child_cache

    for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do
        if not category_filter or category == category_filter then
            local needs_viewer = M.cdm_category_needs_viewer(category)
            if should_prepare_viewers and needs_viewer then
                M.prepare_blizz_cdm_viewer(category)
            end

            if should_clear_child_cache and needs_viewer then
                M.clear_cooldown_viewer_child_cache(category)
            end

            local show_key = M.get_preset_keys(category).show_key
            local frame = M.frames[show_key]
            local p = frame and frame.update_params
            if p and (needs_viewer or frame:IsShown()) then
                M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
            end
        end
    end
end

local function schedule_wow_cooldown_refresh(delay, refresh_config, category_filter)
    delay = delay or 0
    M._cdm_refresh_pending = M._cdm_refresh_pending or {}
    local key = tostring(delay)
        .. "|" .. tostring(refresh_config.prepare_viewers == true)
        .. "|" .. tostring(refresh_config.clear_child_cache == true)
        .. "|" .. tostring(refresh_config.defer_zero == true)
        .. "|" .. tostring(refresh_config.mark_scan_dirty == true)
        .. "|" .. tostring(category_filter or "")
    if M._cdm_refresh_pending[key] then return end

    local function refresh()
        M._cdm_refresh_pending[key] = nil
        run_wow_cooldown_refresh(refresh_config, category_filter)
    end

    M._cdm_refresh_pending[key] = true
    if (delay > 0 or refresh_config.defer_zero) and C_Timer and C_Timer.After then
        C_Timer.After(delay, refresh)
    else
        refresh()
    end
end

function M.queue_wow_cooldown_refresh(profile, category_filter)
    local refresh_config = type(profile) == "table" and profile
        or WOW_COOLDOWN_REFRESH_PROFILES[profile or "immediate"]
        or WOW_COOLDOWN_REFRESH_PROFILES.immediate
    if category_filter and not M.WOW_COOLDOWN_CATEGORIES[category_filter] then
        category_filter = nil
    end
    local delays = refresh_config.delays or { refresh_config.delay or 0 }
    for _, delay in ipairs(delays) do
        schedule_wow_cooldown_refresh(delay, refresh_config, category_filter)
    end
end

--#endregion MODULE STATE AND COOLDOWN REFRESH =================================
--#region AURA ICON TOOLTIPS ===================================================

local function get_aura_tooltip()
    return addon.GetOwnedTooltip()
end

local function is_usable_tooltip_number(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function is_usable_tooltip_text(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

local function get_aura_tooltip_cache_keys(obj)
    local keys = {}
    if is_usable_tooltip_number(obj.aura_index) then
        keys[#keys + 1] = "aura:" .. tostring(obj.aura_index)
    end
    if is_usable_tooltip_number(obj.aura_spell_id) then
        keys[#keys + 1] = "spell:" .. tostring(obj.aura_spell_id)
    end
    return keys
end

local function has_cacheable_tooltip_identity(obj)
    return is_usable_tooltip_number(obj.aura_index) or is_usable_tooltip_number(obj.aura_spell_id)
end

local function get_safe_basic_aura_name(obj)
    if is_usable_tooltip_text(obj.aura_name) then
        return obj.aura_name
    end
    if is_usable_tooltip_number(obj.aura_spell_id) then
        return "Aura " .. tostring(obj.aura_spell_id)
    end
    return "Aura"
end

local function get_safe_color_component(value)
    if is_usable_tooltip_number(value) then
        return value
    end
    return nil
end

local function copy_tooltip_color(color)
    if type(color) ~= "table" then
        return nil
    end
    if issecrettable and issecrettable(color) then
        return nil
    end
    local r = get_safe_color_component(color.r)
    local g = get_safe_color_component(color.g)
    local b = get_safe_color_component(color.b)
    if not (r and g and b) then
        return nil
    end
    return {
        r = r,
        g = g,
        b = b,
    }
end

local function copy_tooltip_data_lines(data)
    local lines = data and data.lines
    if type(lines) ~= "table" or #lines == 0 then
        return nil
    end

    local copied = {}
    for i = 1, #lines do
        local line = lines[i]
        if line and not (issecrettable and issecrettable(line)) then
            local left_text = line.leftText
            local right_text = line.rightText
            if left_text and not is_usable_tooltip_text(left_text) then
                left_text = nil
            end
            if right_text and not is_usable_tooltip_text(right_text) then
                right_text = nil
            end
            if left_text or right_text then
                local wrap_text = line.wrapText
                copied[#copied + 1] = {
                    left_text = left_text,
                    right_text = right_text,
                    left_color = copy_tooltip_color(line.leftColor),
                    right_color = copy_tooltip_color(line.rightColor),
                    wrap_text = not (issecretvalue and issecretvalue(wrap_text)) and wrap_text == true,
                }
            end
        end
    end

    if #copied == 0 then
        return nil
    end
    return copied
end

local function get_safe_tooltip_data(obj)
    if not C_TooltipInfo then return nil end

    if is_usable_tooltip_number(obj.aura_index) and C_TooltipInfo.GetUnitAuraByAuraInstanceID then
        local ok, data = pcall(C_TooltipInfo.GetUnitAuraByAuraInstanceID, "player", obj.aura_index)
        if ok and data then
            return data
        end
    end

    if is_usable_tooltip_number(obj.aura_spell_id) and C_TooltipInfo.GetSpellByID then
        local ok, data = pcall(C_TooltipInfo.GetSpellByID, obj.aura_spell_id)
        if ok and data then
            return data
        end
    end
end

local function cache_tooltip_data_lines(obj)
    local cache_keys = get_aura_tooltip_cache_keys(obj)
    if #cache_keys == 0 then return nil end
    M._tooltip_data_lines_cache = M._tooltip_data_lines_cache or {}
    for i = 1, #cache_keys do
        local cached = M._tooltip_data_lines_cache[cache_keys[i]]
        if cached then
            return cached
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local lines = copy_tooltip_data_lines(get_safe_tooltip_data(obj))
    if lines then
        for i = 1, #cache_keys do
            M._tooltip_data_lines_cache[cache_keys[i]] = lines
        end
    end
    return lines
end

function M.prewarm_aura_tooltip_cache(frame)
    if InCombatLockdown and InCombatLockdown() then return end
    local icons = frame and frame.icons
    if not icons then return end

    local display_count = frame._display_count or 0
    if display_count > #icons then
        display_count = #icons
    end

    local missed = false
    for i = 1, display_count do
        local obj = icons[i]
        if obj
            and obj.tooltip_enabled ~= false
            and not obj.is_test_preview
            and has_cacheable_tooltip_identity(obj)
        then
            if not cache_tooltip_data_lines(obj) then
                missed = true
            end
        end
    end

    if not missed then
        frame._tooltip_cache_retry_count = 0
        return
    end
    if frame._tooltip_cache_retry_pending then return end
    if (frame._tooltip_cache_retry_count or 0) >= 2 then return end

    frame._tooltip_cache_retry_count = (frame._tooltip_cache_retry_count or 0) + 1
    frame._tooltip_cache_retry_pending = true
    local retry_frame = frame
    C_Timer.After(UPDATE_INTERVALS.fifth_sec, function()
        retry_frame._tooltip_cache_retry_pending = false
        if not (InCombatLockdown and InCombatLockdown()) and M.prewarm_aura_tooltip_cache then
            M.prewarm_aura_tooltip_cache(retry_frame)
        end
    end)
end

local function add_cached_tooltip_data_lines(tooltip, lines)
    if type(lines) ~= "table" or #lines == 0 then return false end

    local added = false
    for i = 1, #lines do
        local line = lines[i]
        local left_text = line and line.left_text
        local right_text = line and line.right_text
        if left_text and left_text ~= "" then
            local left_color = line.left_color or NORMAL_FONT_COLOR
            if right_text and right_text ~= "" then
                local right_color = line.right_color or NORMAL_FONT_COLOR
                tooltip:AddDoubleLine(
                    left_text,
                    right_text,
                    left_color.r or 1,
                    left_color.g or 1,
                    left_color.b or 1,
                    right_color.r or 1,
                    right_color.g or 1,
                    right_color.b or 1
                )
            else
                tooltip:AddLine(left_text, left_color.r or 1, left_color.g or 1, left_color.b or 1, line.wrap_text == true)
            end
            added = true
        end
    end

    return added
end

local function add_basic_aura_tooltip_lines(tooltip, obj)
    tooltip:AddLine(get_safe_basic_aura_name(obj), 1, 1, 1)
    if is_usable_tooltip_number(obj.aura_duration) and obj.aura_duration > 0 then
        local remaining_str = is_usable_tooltip_number(obj.aura_remaining) and format("%.1f", obj.aura_remaining) or "?"
        local duration_str = format("%.1f", obj.aura_duration)
        tooltip:AddLine(remaining_str .. "s / " .. duration_str .. "s", 0.7, 0.7, 1)
    else
        tooltip:AddLine("(Permanent)", 0.7, 0.7, 1)
    end
end

local function rich_tooltip_secure_call(method, tooltip, ...)
    method(tooltip, ...)
    return tooltip.NumLines and tooltip:NumLines() > 0
end

local function try_secure_rich_tooltip_call(method, tooltip, ...)
    if not (securecallfunction and method and tooltip) then
        return false
    end
    return securecallfunction(rich_tooltip_secure_call, method, tooltip, ...) == true
end

local function try_show_rich_aura_tooltip(tooltip, obj)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if is_usable_tooltip_number(obj.aura_index)
        and try_secure_rich_tooltip_call(tooltip.SetUnitAuraByAuraInstanceID, tooltip, "player", obj.aura_index)
    then
        return true
    end
    addon.ResetOwnedTooltip(tooltip)
    tooltip:SetOwner(obj, "ANCHOR_BOTTOMRIGHT")

    if is_usable_tooltip_number(obj.aura_spell_id)
        and try_secure_rich_tooltip_call(tooltip.SetSpellByID, tooltip, obj.aura_spell_id)
    then
        return true
    end
    addon.ResetOwnedTooltip(tooltip)
    tooltip:SetOwner(obj, "ANCHOR_BOTTOMRIGHT")

    return false
end

local function show_aura_icon_tooltip(obj)
    local tooltip = get_aura_tooltip()
    if not obj.aura_name then
        addon.HideOwnedTooltip()
        return
    end
    if obj.tooltip_enabled == false then
        addon.HideOwnedTooltip()
        return
    end

    addon.ResetOwnedTooltip(tooltip)
    tooltip:SetOwner(obj, "ANCHOR_BOTTOMRIGHT")

    local cached_lines = cache_tooltip_data_lines(obj)
    if not try_show_rich_aura_tooltip(tooltip, obj) then
        if not add_cached_tooltip_data_lines(tooltip, cached_lines) then
            add_basic_aura_tooltip_lines(tooltip, obj)
        end
    end
    tooltip:Show()
end

local function aura_frame_contains_mouse(frame)
    if not frame then return false end
    if frame.title_bar and frame.title_bar.IsMouseOver and frame.title_bar:IsMouseOver() then return true end
    if frame.bottom_title_bar and frame.bottom_title_bar.IsMouseOver and frame.bottom_title_bar:IsMouseOver() then return true end
    if frame.resizer and frame.resizer.IsMouseOver and frame.resizer:IsMouseOver() then return true end

    local icons = frame.icons
    if icons then
        local display_count = frame._display_count or #icons
        if display_count > #icons then display_count = #icons end
        for i = 1, display_count do
            local icon = icons[i]
            if icon and icon:IsShown() and icon.IsMouseOver and icon:IsMouseOver() then
                return true
            end
        end
    end
    return false
end

local function stop_frame_hover_check(frame)
    if frame and frame._hover_check_ticker then
        frame._hover_check_ticker:Cancel()
        frame._hover_check_ticker = nil
    end
end

local function frame_uses_ooc_fade(frame)
    if not frame then return false end
    local params = frame.update_params
    local cfg_db = M.get_frame_config_db and M.get_frame_config_db(frame)
    if not (params and cfg_db) then return false end

    local activity = M.get_frame_activity_state(frame, params.show_key, params.move_key)
    if not activity.enabled or activity.moving then return false end
    return M.get_setting(cfg_db, frame.category, "fade_ooc", false) == true
end

local function set_frame_hovered(frame, hovered)
    if hovered and not frame_uses_ooc_fade(frame) then return false end
    if M.set_aura_frame_hovered then
        M.set_aura_frame_hovered(frame, hovered)
    end
    if not hovered then
        stop_frame_hover_check(frame)
    end
    return true
end

local function handle_frame_mouse_enter(frame)
    if not set_frame_hovered(frame, true) then return end
    if frame and not frame._hover_check_ticker and C_Timer and C_Timer.NewTicker then
        frame._hover_check_ticker = C_Timer.NewTicker(M.UPDATE_INTERVALS.aura_hover_check, function()
            if not aura_frame_contains_mouse(frame) then
                set_frame_hovered(frame, false)
            end
        end)
    end
end

local function handle_frame_mouse_leave(frame)
    if not frame then return end
    C_Timer.After(0, function()
        if not aura_frame_contains_mouse(frame) then
            set_frame_hovered(frame, false)
        end
    end)
end

--#endregion AURA ICON TOOLTIPS ================================================

--#region AURA ICON POOL =======================================================

-- The icon pool is a fixed set of reusable icon/bar frame objects owned by one
-- aura frame. It is created up front because WoW combat lockdown makes runtime
-- frame creation unsafe; render code updates and shows/hides these pooled objects.
local function create_icon_cooldown(obj)
    local cooldown = CreateFrame("Cooldown", nil, obj, "CooldownFrameTemplate")
    cooldown:SetAllPoints(obj)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:Hide()
    return cooldown
end

local function create_icon_bar(obj, bar_bg_default)
    local bar = CreateFrame("StatusBar", nil, obj)
    bar:EnableMouse(false)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:Hide()

    obj.bar_bg = bar:CreateTexture(nil, "BACKGROUND")
    obj.bar_bg:SetAllPoints()
    obj.bar_bg:SetColorTexture(
        bar_bg_default.r,
        bar_bg_default.g,
        bar_bg_default.b,
        bar_bg_default.a or M.BAR_BG_ALPHA_DEFAULT
    )

    return bar
end

local function create_icon_text_regions(obj, category)
    -- Text overlay is created after the bar so labels render above bar fills.
    obj.text_overlay = CreateFrame("Frame", nil, obj)
    obj.text_overlay:EnableMouse(false)
    obj.text_overlay:SetFrameLevel(obj.bar:GetFrameLevel() + 1)

    obj.stack_slot = CreateFrame("Frame", nil, obj.text_overlay)
    M.add_debug_outline(obj.stack_slot, 1, 0.4, 0, 0.9)

    obj.name_slot = CreateFrame("Frame", nil, obj.text_overlay)
    M.add_debug_outline(obj.name_slot, 0, 0.6, 1, 0.9)

    obj.name_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj.name_text:SetJustifyH("LEFT")
    obj.name_text:SetWordWrap(false)
    if obj.name_text.SetMaxLines then
        obj.name_text:SetMaxLines(1)
    end

    obj.timer_slot = CreateFrame("Frame", nil, obj.text_overlay)
    M.add_debug_outline(obj.timer_slot, 0, 1, 0.3, 0.9)

    obj.time_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    M.apply_number_font_to_text(obj.time_text, category)
    obj.time_text:SetWordWrap(false)
    if obj.time_text.SetMaxLines then
        obj.time_text:SetMaxLines(1)
    end

    obj.count_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    obj.count_text:Hide()
end

local function bind_icon_tooltip(obj)
    obj:EnableMouse(true)
    obj:SetScript("OnEnter", function(self)
        handle_frame_mouse_enter(self:GetParent())
        show_aura_icon_tooltip(self)
    end)
    obj:SetScript("OnLeave", function()
        addon.HideOwnedTooltip()
        handle_frame_mouse_leave(obj:GetParent())
    end)
    obj:SetScript("OnMouseUp", function(self, button)
        if M.try_cancel_aura_icon then
            M.try_cancel_aura_icon(self, button)
        end
    end)
end

local function create_aura_icon(parent, category, bar_bg_default)
    local obj = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    obj:Hide()

    obj.texture = obj:CreateTexture(nil, "ARTWORK")
    obj.cooldown = create_icon_cooldown(obj)
    obj.bar = create_icon_bar(obj, bar_bg_default)
    create_icon_text_regions(obj, category)
    bind_icon_tooltip(obj)

    return obj
end

local function create_aura_icon_pool(frame, cfg_db, category)
    frame.icons = {}
    local pool_size = cfg_db["max_icons_"..category] or cfg_db["max_icons"] or M.DEFAULT_MAX_ICONS
    local bar_bg_default = M.get_bar_bg_color(cfg_db, category)

    for i = 1, pool_size do
        frame.icons[i] = create_aura_icon(frame, category, bar_bg_default)
    end
end

--#endregion AURA ICON POOL ====================================================

--#region AURA FRAME SHELL =====================================================

-- The frame shell is the user-facing container around an aura icon pool. It owns
-- the drag title bars, resize handle, saved width updates, and resize refresh so
-- icon creation/rendering can stay separate from frame interaction behavior.
local TITLEBAR_ANCHORS = {
    top =    { from = "BOTTOM", to = "TOP", offset = -2 },
    bottom = { from = "TOP",    to = "BOTTOM", offset = 2 },
}

local function create_title_bar(parent, label, scale_key, is_bottom)
    local cfg = is_bottom and TITLEBAR_ANCHORS.bottom or TITLEBAR_ANCHORS.top
    local tb = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tb:SetPoint(cfg.from.."LEFT",  parent, cfg.to.."LEFT",  0, cfg.offset)
    tb:SetPoint(cfg.from.."RIGHT", parent, cfg.to.."RIGHT", 0, cfg.offset)
    tb:SetHeight(20)
    M.apply_title_bar_backdrop(tb)

    local text = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    tb.label_text = text

    tb:EnableMouse(true)
    tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnEnter", function()
        handle_frame_mouse_enter(parent)
    end)
    tb:SetScript("OnLeave", function()
        handle_frame_mouse_leave(parent)
    end)
    tb:SetScript("OnDragStart", function()
        M.start_frame_drag(parent)
    end)
    tb:SetScript("OnDragStop", function()
        M.stop_frame_drag(parent, scale_key)
    end)

    return tb
end

local function create_aura_frame_title_bars(frame, display_name, scale_key)
    frame.title_bar = create_title_bar(frame, display_name, scale_key, false)
    frame.bottom_title_bar = create_title_bar(frame, display_name, scale_key, true)
end

local function save_aura_frame_width(frame, category, width)
    if frame.is_custom and frame.custom_entry then
        frame.custom_entry.width = width
    elseif M.db then
        M.db["width_"..category] = width
    end
end

local function get_width_slider_control(frame, category)
    if not M.controls then return nil end
    if frame.is_custom and frame.custom_entry and frame.custom_entry.id then
        return M.controls["custom_" .. frame.custom_entry.id .. "_width"]
    end
    return M.controls["width_slider_"..category]
end

local function refresh_aura_frame_after_resize(frame)
    local params = frame.update_params
    if not params then return end
    if M.invalidate_frame_runtime_config then
        M.invalidate_frame_runtime_config(frame)
    end
    M.update_auras(frame, params.show_key, params.move_key, params.timer_key,
        params.bg_key, params.scale_key, params.spacing_key, params.aura_filter)
end

local function clamp_aura_frame_width(frame)
    local width = frame:GetWidth()
    if width < M.MIN_FRAME_WIDTH then
        width = M.MIN_FRAME_WIDTH
        frame:SetWidth(width)
    end
    return width
end

local function create_aura_frame_resizer(frame, category)
    frame.resizer = CreateFrame("Button", nil, frame)
    frame.resizer:SetSize(16, 16)
    frame.resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resizer:SetScript("OnEnter", function()
        handle_frame_mouse_enter(frame)
    end)
    frame.resizer:SetScript("OnLeave", function()
        handle_frame_mouse_leave(frame)
    end)

    frame:SetScript("OnSizeChanged", function(s, w)
        if s._clamping_size then return end
        if w and w < M.MIN_FRAME_WIDTH then
            s._clamping_size = true
            s:SetWidth(M.MIN_FRAME_WIDTH)
            s._clamping_size = nil
        end
    end)

    frame.resizer:SetScript("OnMouseDown", function()
        frame._is_user_positioning = true
        frame:StartSizing("RIGHT")
    end)
    frame.resizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame._is_user_positioning = nil

        local clamped_width = clamp_aura_frame_width(frame)
        save_aura_frame_width(frame, category, clamped_width)

        local width_slider = get_width_slider_control(frame, category)
        if width_slider and width_slider.SetValueSilently then
            width_slider:SetValueSilently(clamped_width)
        end

        refresh_aura_frame_after_resize(frame)
    end)
end

--#endregion AURA FRAME SHELL ==================================================

--#region AURA FRAME EVENTS ====================================================

local function create_aura_frame_update_params(show_key, move_key, timer_key, bg_key, scale_key, spacing_key, category, aura_filter)
    return {
        show_key = show_key,
        move_key = move_key,
        timer_key = timer_key,
        bg_key = bg_key,
        scale_key = scale_key,
        spacing_key = spacing_key,
        category = category,
        aura_filter = aura_filter,
    }
end

local function register_aura_frame_events(frame, category)
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    if M.WOW_COOLDOWN_CATEGORIES[category] then
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    end
end

local function is_aura_frame_event_relevant(event, unit)
    return (event == "UNIT_AURA" and unit == "player")
        or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELL_UPDATE_COOLDOWN"
        or event == "SPELL_UPDATE_CHARGES"
end

local function queue_deferred_aura_scan(frame, params)
    if frame._scan_pending then return end

    frame._scan_pending = true
    local f = frame
    -- A short bucket matches ElkBuffBars' short UNIT_AURA bucket and coalesces
    -- noisy event bursts while ensuring scans run outside event-dispatch taint.
    C_Timer.After(UPDATE_INTERVALS.aura_event_bucket, function()
        f._scan_pending = false
        local event_info = f._pending_aura_info
        f._pending_aura_info = nil
        M.update_auras(f, params.show_key, params.move_key, params.timer_key,
            params.bg_key, params.scale_key, params.spacing_key, params.aura_filter, event_info)
    end)
end

local function handle_aura_frame_event(frame, event, unit, info)
    local params = frame.update_params
    if not params then return end
    if not is_aura_frame_event_relevant(event, unit) then return end

    local activity = M.get_frame_activity_state(frame, params.show_key, params.move_key)
    if not activity.enabled then
        frame._pending_aura_info = nil
        return
    end

    if event == "PLAYER_REGEN_DISABLED" and M.prewarm_aura_tooltip_cache then
        M.prewarm_aura_tooltip_cache(frame)
    end

    -- Do not scan inside the event handler. C_UnitAuras calls made directly
    -- during event dispatch can return secret values in combat, so every frame
    -- update is deferred through the short aura bucket below.
    if event == "UNIT_AURA" then
        frame._pending_aura_info = M.merge_aura_info(frame._pending_aura_info, info)
    end
    if event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "SPELL_UPDATE_CHARGES" then
        M.mark_aura_scan_dirty()
    end
    if event == "PLAYER_REGEN_DISABLED"
        and M.WOW_COOLDOWN_CATEGORIES[params.category] then
        M.queue_wow_cooldown_refresh("combat_entry")
    end

    queue_deferred_aura_scan(frame, params)
end

local function bind_aura_frame_events(frame, category)
    register_aura_frame_events(frame, category)
    frame:SetScript("OnEvent", handle_aura_frame_event)
end

-- AURA CONTAINER GENERATOR
function M.create_aura_frame(show_key, move_key, timer_key, bg_key, scale_key, spacing_key, display_name, is_debuff, frame_opts)
    local category = show_key:sub(6)
    frame_opts = frame_opts or {}
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.category = category
    frame.is_custom = frame_opts.is_custom == true
    frame.custom_entry = frame_opts.custom_entry
    frame._cfg_db = frame_opts.cfg_db

    M.apply_tooltip_panel_backdrop(frame)

    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnEnter", handle_frame_mouse_enter)
    frame:SetScript("OnLeave", handle_frame_mouse_leave)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(M.MIN_FRAME_WIDTH, M.MIN_FRAME_HEIGHT)
    end
    local cfg_db = frame._cfg_db or M.db
    local initial_width = cfg_db["width_"..category] or cfg_db["width"] or M.DEFAULT_FRAME_WIDTH
    if initial_width < M.MIN_FRAME_WIDTH then initial_width = M.MIN_FRAME_WIDTH end
    frame:SetSize(initial_width, 50)

    M.apply_saved_frame_position(frame, scale_key, is_debuff and -25 or 75)

    create_aura_frame_title_bars(frame, display_name, scale_key)
    create_aura_frame_resizer(frame, category)

    -- Pre-create icons/bars so combat updates never need to create frames.
    create_aura_icon_pool(frame, cfg_db, category)

    -- Map-based aura cache: auraInstanceID → entry table. Persists across events.
    frame._aura_map = {}

    -- Store parameters on frame itself for robust access during callbacks
    frame.update_params = create_aura_frame_update_params(
        show_key,
        move_key,
        timer_key,
        bg_key,
        scale_key,
        spacing_key,
        category,
        frame_opts.aura_filter or (is_debuff and "HARMFUL" or "HELPFUL")
    )
    bind_aura_frame_events(frame, category)

    register_runtime_frame(show_key, frame)
    return frame
end

--#endregion AURA FRAME EVENTS =================================================

--#region CUSTOM FRAME LIFECYCLE ===============================================

-- Builds the WoW frame for a custom entry. Called at load (for saved entries)
-- and at runtime (when user clicks + Custom). The frame is keyed by entry.id.
function M.create_custom_frame(entry)
    if not entry or not entry.id then return end
    local id       = entry.id
    local show_key = "show_" .. id  -- e.g. "show_custom_1"
    entry.aura_base_filter = (entry.aura_base_filter == "HARMFUL" or entry.filter == "HARMFUL") and "HARMFUL" or "HELPFUL"
    entry.aura_modifier = entry.aura_modifier or "NONE"
    if entry.fade_ooc == nil then entry.fade_ooc = false end
    if entry.ooc_alpha == nil then entry.ooc_alpha = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA end
    if entry.fade_delay == nil then entry.fade_delay = M.DEFAULT_OOC_FADE_DELAY end
    if entry.fade_length == nil then entry.fade_length = M.DEFAULT_OOC_FADE_LENGTH end
    local aura_filter = M.get_custom_aura_filter(entry)

    -- Custom frames use flat keys ("timer", "bg", etc.) inside the entry table,
    -- not the prefixed pattern used by preset frames ("timer_static", etc.).
    local frame = M.create_aura_frame(
        show_key,
        "move",
        "timer",
        "bg",
        "scale",
        "spacing",
        entry.name or id,
        aura_filter:find("HARMFUL", 1, true) ~= nil,
        {
            is_custom = true,
            custom_entry = entry,
            cfg_db = entry,
            aura_filter = aura_filter,
        }
    )

    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", aura_filter)

    return frame
end

-- Creates a new entry, persists it to DB, builds the WoW frame, and returns the entry.
function M.spawn_custom_frame()
    if not M.db then return nil end
    M.db.custom_frames = M.db.custom_frames or {}
    if #M.db.custom_frames >= M.MAX_CUSTOM_FRAMES then return nil end

    local entry = M.new_custom_entry()
    table.insert(M.db.custom_frames, entry)
    M.create_custom_frame(entry)
    return entry
end

-- Hides and fully removes a custom frame by id. Removes DB entry.
function M.destroy_custom_frame(id)
    if not id then return end
    local show_key = "show_" .. id
    local frame = unregister_runtime_frame(show_key)
    if frame then
        if M.cancel_frame_ooc_fade then M.cancel_frame_ooc_fade(frame) end
        stop_frame_hover_check(frame)
        frame:Hide()
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        if M.refresh_visible_icon_ticker then M.refresh_visible_icon_ticker() end
    end
    if M.db and M.db.custom_frames then
        for i, entry in ipairs(M.db.custom_frames) do
            if entry.id == id then
                table.remove(M.db.custom_frames, i)
                break
            end
        end
    end
    if M.controls then
        local prefix = "custom_" .. id .. "_"
        for key in pairs(M.controls) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                M.controls[key] = nil
            end
        end
    end
    if M.clear_custom_aura_scan_cache then
        M.clear_custom_aura_scan_cache()
    end
end

--#endregion CUSTOM FRAME LIFECYCLE ============================================

--#region STARTUP ORCHESTRATION ================================================

local function prepare_aura_frame_db()
    ---@diagnostic disable-next-line: undefined-global
    local saved_db = Ls_Tweeks_DB
    if not saved_db.aura_frames then saved_db.aura_frames = {} end
    M.db = saved_db.aura_frames
    M._aura_scan_dirty = true

    if M.refresh_cdm_default_positions then M.refresh_cdm_default_positions() end
    if M.migrate_legacy_cdm_fade_settings then M.migrate_legacy_cdm_fade_settings(M.db) end
    if M.defaults then addon.apply_defaults(M.defaults, M.db) end
    if M.normalize_saved_colors then M.normalize_saved_colors(M.db) end
    if M.apply_cdm_default_positions_to_db then M.apply_cdm_default_positions_to_db() end
end

local function create_startup_aura_frames()
    for _, frame_def in ipairs(M.FRAME_DEFS) do
        local keys = M.get_preset_keys(frame_def.key)
        M.create_aura_frame(
            keys.show_key,
            keys.move_key,
            keys.timer_key,
            keys.bg_key,
            keys.scale_key,
            keys.spacing_key,
            frame_def.frame_label or frame_def.label,
            frame_def.is_debuff
        )
    end

    if M.db.custom_frames then
        for _, entry in ipairs(M.db.custom_frames) do
            M.create_custom_frame(entry)
        end
    end
end

local function register_aura_frame_settings()
    if addon.register_category and M.BuildSettings then
        addon.register_category("Buffs & Debuffs", function(parent) M.BuildSettings(parent) end, {
            module_key = M.MODULE_KEY,
        })
    end
end

local function start_aura_frame_runtime_services()
    M._module_runtime_enabled = true
    M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
    M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
    if M.update_all_blizz_cdm_visibility then
        M.update_all_blizz_cdm_visibility()
    end
    M.queue_wow_cooldown_refresh("startup")

    if M.db.show_grid then
        M.create_grid_overlay()
    end
end

local function restore_cdm_viewer_visibility()
    if not M._cd_viewer_state then return end
    for frame, state in pairs(M._cd_viewer_state) do
        if frame and state and state.forced_hidden then
            state.forced_hidden = nil
            if frame.SetAlpha then frame:SetAlpha(1) end
            if frame.EnableMouse then frame:EnableMouse(true) end
            if (not InCombatLockdown or not InCombatLockdown()) and frame.Show then
                pcall(frame.Show, frame)
            end
        end
    end
end

local function stop_aura_frame_runtime_services()
    M._module_runtime_enabled = false
    if M.stop_visible_icon_ticker then M.stop_visible_icon_ticker() end
    if M.set_grid_visible then M.set_grid_visible(false) end
    if M.toggle_blizz_buffs then M.toggle_blizz_buffs(false) end
    if M.toggle_blizz_debuffs then M.toggle_blizz_debuffs(false) end
    if M.restore_blizz_cdm_viewer_settings then
        M.restore_blizz_cdm_viewer_settings()
    end
    restore_cdm_viewer_visibility()

    for _, frame in ipairs(M.frames_list or {}) do
        if frame then
            if M.cancel_frame_ooc_fade then M.cancel_frame_ooc_fade(frame) end
            stop_frame_hover_check(frame)
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
            frame:Hide()
            if frame.title_bar then frame.title_bar:Hide() end
            if frame.bottom_title_bar then frame.bottom_title_bar:Hide() end
            if frame.resizer then frame.resizer:Hide() end
            frame._display_count = 0
        end
    end
end

function M.stop_runtime()
    stop_aura_frame_runtime_services()
end

local function rebind_existing_aura_frames()
    for _, frame in ipairs(M.frames_list or {}) do
        if frame and frame.update_params then
            bind_aura_frame_events(frame, frame.category)
            local p = frame.update_params
            if M.invalidate_frame_runtime_config then
                M.invalidate_frame_runtime_config(frame)
            end
            M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
        end
    end
end

function M.set_module_enabled(enabled)
    if enabled then
        if M.mark_aura_scan_dirty then
            M.mark_aura_scan_dirty()
        else
            M._aura_scan_dirty = true
        end

        if not M._module_started then
            prepare_aura_frame_db()
            create_startup_aura_frames()
            M._module_started = true
        end
        start_aura_frame_runtime_services()
        rebind_existing_aura_frames()
        return
    end

    M.stop_runtime()
end

local function count_aura_runtime_status()
    local frame_count = 0
    local shown_count = 0
    local event_script_count = 0
    local scan_pending_count = 0
    local hover_ticker_count = 0
    for _, frame in ipairs(M.frames_list or {}) do
        if frame then
            frame_count = frame_count + 1
            if frame.IsShown and frame:IsShown() then
                shown_count = shown_count + 1
            end
            if frame.GetScript and frame:GetScript("OnEvent") then
                event_script_count = event_script_count + 1
            end
            if frame._scan_pending then
                scan_pending_count = scan_pending_count + 1
            end
            if frame._hover_check_ticker then
                hover_ticker_count = hover_ticker_count + 1
            end
        end
    end

    local cdm_forced_hidden_count = 0
    for _, state in pairs(M._cd_viewer_state or {}) do
        if state and state.forced_hidden then
            cdm_forced_hidden_count = cdm_forced_hidden_count + 1
        end
    end

    return frame_count, shown_count, event_script_count, scan_pending_count, hover_ticker_count, cdm_forced_hidden_count
end

if addon.register_module_status then
    addon.register_module_status(M.MODULE_KEY, function()
        local frame_count, shown_count, event_script_count, scan_pending_count, hover_ticker_count, cdm_forced_hidden_count =
            count_aura_runtime_status()
        return {
            "runtime=" .. tostring(M._module_runtime_enabled == true),
            "frames=" .. tostring(frame_count),
            "shown=" .. tostring(shown_count),
            "event_scripts=" .. tostring(event_script_count),
            "visible_icon_ticker=" .. tostring(M._visible_icon_ticker ~= nil),
            "scan_pending=" .. tostring(scan_pending_count),
            "hover_tickers=" .. tostring(hover_ticker_count),
            "cdm_forced_hidden=" .. tostring(cdm_forced_hidden_count),
            "grid=" .. tostring(M.grid_frame and M.grid_frame:IsShown() == true),
        }
    end)
end

-- Startup conductor: keep addon-loaded work in order while each step
-- owns one broad responsibility.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name == addon_name then
        register_aura_frame_settings()
        if M.is_runtime_enabled and M.is_runtime_enabled() then
            prepare_aura_frame_db()
            create_startup_aura_frames()
            M._module_started = true
            start_aura_frame_runtime_services()
        else
            M.stop_runtime()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

--#endregion STARTUP ORCHESTRATION =============================================

--#region RESET ORCHESTRATION ==================================================

local function apply_reset_runtime_state()
    M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
    M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
    if M.update_all_blizz_cdm_visibility then
        M.update_all_blizz_cdm_visibility()
    end
    M.apply_number_font_to_all()
    M.set_grid_visible(M.db.show_grid == true)
end

local function remove_orphan_custom_frames_after_reset()
    local valid_custom_ids = {}
    for _, entry in ipairs(M.db.custom_frames or {}) do
        if entry.id then valid_custom_ids[entry.id] = true end
    end
    local orphan_custom_ids = {}
    for show_key, frame in pairs(M.frames) do
        if frame.is_custom then
            local id = frame.custom_entry and frame.custom_entry.id or show_key:match("^show_(.+)$")
            if id and not valid_custom_ids[id] then
                orphan_custom_ids[#orphan_custom_ids + 1] = id
            end
        end
    end
    for _, id in ipairs(orphan_custom_ids) do
        M.destroy_custom_frame(id)
    end
end

local function find_saved_custom_entry(id)
    if not (id and M.db and M.db.custom_frames) then return nil end
    for _, entry in ipairs(M.db.custom_frames) do
        if entry.id == id then return entry end
    end
    return nil
end

local function refresh_frame_after_reset(frame)
    local p = frame.update_params
    if not p then return end

    if M.invalidate_frame_runtime_config then
        M.invalidate_frame_runtime_config(frame)
    else
        frame._layout_cache = nil
        frame._runtime_config_cache = nil
    end

    -- Re-link custom entry reference in case DB was replaced by reset.
    if frame.is_custom and frame.custom_entry then
        local entry = find_saved_custom_entry(frame.custom_entry.id)
        if entry then
            frame.custom_entry = entry
        end
        p.aura_filter = M.get_custom_aura_filter(frame.custom_entry)
    end

    M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
end

local function refresh_aura_frames_after_reset()
    local frames_list = M.frames_list
    if not frames_list then return end
    for i = 1, #frames_list do
        local frame = frames_list[i]
        refresh_frame_after_reset(frame)
    end
end

local function refresh_aura_frame_settings_after_reset()
    M.sync_general_controls_from_db()
    if M.refresh_profiles_tab then
        M.refresh_profiles_tab()
    end
    if M.refresh_frames_tree then
        M.refresh_frames_tree()
    end
end

-- RESET AND REFRESH: Restores UI states following an Aura Frames settings reset.
function M.on_reset_complete()
    -- Reset conductor: recover runtime state, reconcile frame ownership, then
    -- refresh visible frames and settings controls from the replaced DB.
    apply_reset_runtime_state()
    remove_orphan_custom_frames_after_reset()
    refresh_aura_frames_after_reset()
    refresh_aura_frame_settings_after_reset()
    if M.restart_visible_icon_ticker then
        M.restart_visible_icon_ticker()
    end
end

--#endregion RESET ORCHESTRATION ===============================================
