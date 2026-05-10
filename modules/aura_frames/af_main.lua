-- Bootstrap and frame construction for the aura frames module
-- loads last so all other af_* files have already populated M.
-- Creates preset and custom aura frames with their icon pools,
-- buckets UNIT_AURA events, starts the timer ticker, and registers the settings tab.

local addon_name, addon = ...
local M = addon.aura_frames

-- Runtime state tables. The saved DB is attached during ADDON_LOADED.
M.frames = M.frames or {}
M.controls = M.controls or {}

-- CACHED GLOBALS AND CONSTANTS
local format = string.format
local issecretvalue = issecretvalue
local WOW_COOLDOWN_CATEGORIES = M.CDM_CATEGORIES
local UPDATE_INTERVALS = M.UPDATE_INTERVALS
local NEXT_FRAME_INTERVAL = UPDATE_INTERVALS.next_frame

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

M.NUMBER_FONT_BOLD_PATHS = {
    [M.DEFAULT_TIMER_NUMBER_FONT_KEY] = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Bold.ttf",
}

local function get_number_font_def(key, category, cfg_db)
    local selected_key = key or M.get_setting(cfg_db, category, "timer_number_font", M.DEFAULT_TIMER_NUMBER_FONT_KEY)
    for _, def in ipairs(M.NUMBER_FONT_OPTIONS) do
        if def.key == selected_key then
            return def
        end
    end
    return M.NUMBER_FONT_OPTIONS[1]
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
    if not M.frames then return end
    for _, frame in pairs(M.frames) do
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

local function run_wow_cooldown_refresh(refresh_config)
    if not M.frames then return end

    local should_prepare_viewers = refresh_config.prepare_viewers and M.prepare_blizz_cdm_viewer
    local should_clear_child_cache = refresh_config.clear_child_cache and M.clear_cooldown_viewer_child_cache

    for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do
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
        if p then
            frame._sorted_ids_cache = nil
            M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
        end
    end
end

local function schedule_wow_cooldown_refresh(delay, refresh_config)
    delay = delay or 0
    M._cdm_refresh_pending = M._cdm_refresh_pending or {}
    local key = tostring(delay)
        .. "|" .. tostring(refresh_config.prepare_viewers == true)
        .. "|" .. tostring(refresh_config.clear_child_cache == true)
        .. "|" .. tostring(refresh_config.defer_zero == true)
    if M._cdm_refresh_pending[key] then return end

    local function refresh()
        M._cdm_refresh_pending[key] = nil
        run_wow_cooldown_refresh(refresh_config)
    end

    M._cdm_refresh_pending[key] = true
    if (delay > 0 or refresh_config.defer_zero) and C_Timer and C_Timer.After then
        C_Timer.After(delay, refresh)
    else
        refresh()
    end
end

function M.queue_wow_cooldown_refresh(profile)
    local refresh_config = type(profile) == "table" and profile
        or WOW_COOLDOWN_REFRESH_PROFILES[profile or "immediate"]
        or WOW_COOLDOWN_REFRESH_PROFILES.immediate
    local delays = refresh_config.delays or { refresh_config.delay or 0 }
    for _, delay in ipairs(delays) do
        schedule_wow_cooldown_refresh(delay, refresh_config)
    end
end

-- ============================================================================
-- AURA ICON TOOLTIPS

local function tooltip_has_lines()
    return (not GameTooltip.NumLines) or GameTooltip:NumLines() > 0
end

local function try_set_unit_aura_tooltip(obj)
    if not obj.aura_index then return false end
    if not GameTooltip.SetUnitAuraByAuraInstanceID then return false end

    -- Modern API (12.0.5+): stable auraInstanceID lookup, no index fragility.
    local ok = pcall(function()
        GameTooltip:SetUnitAuraByAuraInstanceID("player", obj.aura_index)
    end)
    return ok and tooltip_has_lines()
end

local function try_set_spell_tooltip(obj)
    local spell_id = obj.aura_spell_id
    if not spell_id then return false end
    if issecretvalue and issecretvalue(spell_id) then return false end
    if not GameTooltip.SetSpellByID then return false end

    local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spell_id)
    if not ok then return false end
    return tooltip_has_lines()
end

local function add_basic_aura_tooltip_lines(obj)
    GameTooltip:AddLine(obj.aura_name, 1, 1, 1)
    if obj.aura_duration and obj.aura_duration > 0 then
        local remaining_str = obj.aura_remaining and format("%.1f", obj.aura_remaining) or "?"
        local duration_str = format("%.1f", obj.aura_duration)
        GameTooltip:AddLine(remaining_str .. "s / " .. duration_str .. "s", 0.7, 0.7, 1)
    else
        GameTooltip:AddLine("(Permanent)", 0.7, 0.7, 1)
    end
end

local function show_aura_icon_tooltip(obj)
    if not obj.aura_name then
        GameTooltip:Hide()
        return
    end
    if obj.tooltip_enabled == false then
        GameTooltip:Hide()
        return
    end

    GameTooltip:SetOwner(obj, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:ClearLines()

    local updated = try_set_unit_aura_tooltip(obj) or try_set_spell_tooltip(obj)
    if not updated then
        add_basic_aura_tooltip_lines(obj)
    end

    GameTooltip:Show()
end

-- ============================================================================
-- AURA ICON POOL

-- The icon pool is a fixed set of reusable icon/bar frame objects owned by one
-- aura frame. It is created up front because WoW combat lockdown makes runtime
-- frame creation unsafe; render code updates and shows/hides these pooled objects.
local function get_icon_pool_bar_bg_default(cfg_db, category)
    return cfg_db["bar_bg_color_"..category]
        or cfg_db["bar_bg_color"]
        or cfg_db["color_"..category]
        or cfg_db["color"]
        or { r = 1, g = 1, b = 1, a = M.BAR_BG_ALPHA_DEFAULT }
end

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

    obj.name_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 7)
    obj.name_text:SetJustifyH("LEFT")
    obj.name_text:SetWordWrap(false)
    if obj.name_text.SetMaxLines then
        obj.name_text:SetMaxLines(1)
    end

    obj.timer_slot = CreateFrame("Frame", nil, obj.text_overlay)
    M.add_debug_outline(obj.timer_slot, 0, 1, 0.3, 0.9)

    obj.time_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 7)
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
    obj:SetScript("OnEnter", show_aura_icon_tooltip)
    obj:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
    local bar_bg_default = get_icon_pool_bar_bg_default(cfg_db, category)

    for i = 1, pool_size do
        frame.icons[i] = create_aura_icon(frame, category, bar_bg_default)
    end
end

-- ============================================================================
-- AURA FRAME SHELL

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
        if width_slider and width_slider.slider then
            width_slider.slider:SetValue(clamped_width)
        end

        refresh_aura_frame_after_resize(frame)
    end)
end

-- ============================================================================
-- AURA FRAME EVENTS

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

    if M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[category] then
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
    -- A tenth second matches ElkBuffBars' short UNIT_AURA bucket and coalesces
    -- noisy event bursts while ensuring scans run outside event-dispatch taint.
    C_Timer.After(UPDATE_INTERVALS.tenth_sec, function()
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

    -- Do not scan inside the event handler. C_UnitAuras calls made directly
    -- during event dispatch can return secret values in combat, so every frame
    -- update is deferred through the short aura bucket below.
    if event == "UNIT_AURA" then
        frame._pending_aura_info = M.merge_aura_info(frame._pending_aura_info, info)
    end
    if event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "SPELL_UPDATE_CHARGES" then
        M.mark_aura_scan_dirty()
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
    local frame = CreateFrame("Frame", "LsTweaksAuraFrame_"..show_key, UIParent, "BackdropTemplate")
    frame.category = category
    frame.is_custom = frame_opts.is_custom == true
    frame.custom_entry = frame_opts.custom_entry
    frame._cfg_db = frame_opts.cfg_db
    
    M.apply_tooltip_panel_backdrop(frame)

    frame:SetMovable(true) 
    frame:SetResizable(true) 
    frame:SetClampedToScreen(true)
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
    
    M.frames[show_key] = frame
    return frame
end

-- ============================================================================
-- CUSTOM FRAME LIFECYCLE

-- Builds the WoW frame for a custom entry. Called at load (for saved entries)
-- and at runtime (when user clicks + Custom). The frame is keyed by entry.id.
function M.create_custom_frame(entry)
    if not entry or not entry.id then return end
    local id       = entry.id
    local show_key = "show_" .. id  -- e.g. "show_custom_1"
    entry.aura_base_filter = (entry.aura_base_filter == "HARMFUL" or entry.filter == "HARMFUL") and "HARMFUL" or "HELPFUL"
    entry.aura_modifier = entry.aura_modifier or "NONE"
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

    -- Override update_params to use flat entry keys and the selected AuraFilters string.
    frame.update_params.show_key    = show_key
    frame.update_params.move_key    = "move"
    frame.update_params.timer_key   = "timer"
    frame.update_params.bg_key      = "bg"
    frame.update_params.scale_key   = "scale"
    frame.update_params.spacing_key = "spacing"
    frame.update_params.aura_filter = aura_filter

    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", aura_filter)

    return frame
end

-- Creates a new entry, persists it to DB, builds the WoW frame, and returns the entry.
function M.spawn_custom_frame()
    if not M.db then return nil end
    M.db.custom_frames = M.db.custom_frames or {}
    if #M.db.custom_frames >= (M.MAX_CUSTOM_FRAMES or 4) then return nil end

    local entry = M.new_custom_entry()
    table.insert(M.db.custom_frames, entry)
    M.create_custom_frame(entry)
    return entry
end

-- Hides and fully removes a custom frame by id. Removes DB entry.
function M.destroy_custom_frame(id)
    if not id then return end
    local show_key = "show_" .. id
    local frame    = M.frames[show_key]
    if frame then
        frame:Hide()
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        M.frames[show_key] = nil
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
end

-- ============================================================================
-- STARTUP ORCHESTRATION

local function is_legacy_bar_bg(c)
    return type(c) == "table"
        and c.r == 0.6 and c.g == 0.6 and c.b == 0.6
        and (c.a == 0.25 or c.a == nil)
end

local function migrate_timer_font_settings()
    if not M.db.timer_number_font then
        M.db.timer_number_font = M.DEFAULT_TIMER_NUMBER_FONT_KEY
    end
    if not M.db.timer_number_font_size then
        M.db.timer_number_font_size = M.get_timer_number_font_size() or 10
    end

    -- Static frame has no timer text, so it does not need per-category timer font settings.
    for _, cat in ipairs(M.TIMER_CATEGORIES) do
        local font_key = "timer_number_font_"..cat
        local size_key = "timer_number_font_size_"..cat
        if not M.db[font_key] then
            M.db[font_key] = M.db.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY
        end
        if not M.db[size_key] then
            M.db[size_key] = M.get_timer_number_font_size() or 10
        end
        local bold_key = "timer_number_font_bold_"..cat
        if M.db[bold_key] == nil then
            M.db[bold_key] = M.db.timer_number_font_bold or false
        end
    end
end

local function migrate_legacy_bar_bg_settings()
    for _, cat in ipairs(M.CATEGORIES) do
        local bg_key = "bar_bg_color_" .. cat
        if is_legacy_bar_bg(M.db[bg_key]) then
            local fill = M.db["color_" .. cat] or { r = 1, g = 1, b = 1 }
            M.db[bg_key] = { r = fill.r, g = fill.g, b = fill.b, a = M.BAR_BG_ALPHA_DEFAULT }
        end
    end
end

local function prepare_aura_frame_db()
    if not Ls_Tweeks_DB.aura_frames then Ls_Tweeks_DB.aura_frames = {} end
    M.db = Ls_Tweeks_DB.aura_frames
    M._aura_scan_dirty = true

    if M.refresh_cdm_default_positions then M.refresh_cdm_default_positions() end
    if M.defaults then addon.apply_defaults(M.defaults, M.db) end
    if M.apply_cdm_default_positions_to_db then M.apply_cdm_default_positions_to_db() end

    migrate_timer_font_settings()
    migrate_legacy_bar_bg_settings()
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

local function migrate_saved_frame_positions_next_frame()
    -- Defer one frame so GetLeft()/GetTop() return valid screen coordinates.
    C_Timer.After(NEXT_FRAME_INTERVAL, function()
        for _, frame in pairs(M.frames) do
            local pos = M.get_frame_position_table(frame)
            if pos and pos.point ~= "TOPLEFT" then
                local x, y = M.sync_frame_position_to_db(frame, pos)
                if x and y then
                    M.apply_saved_frame_position(frame)
                end
            end
        end
    end)
end

local function start_visible_icon_ticker()
    -- Timer text and bar fill need smooth tenths; heavier aura scans stay event-bucketed.
    C_Timer.NewTicker(UPDATE_INTERVALS.tenth_sec, function()
        M.tick_visible_icons()
    end)
end

local function register_aura_frame_settings()
    if addon.register_category and M.BuildSettings then
        addon.register_category("Buffs & Debuffs", function(parent) M.BuildSettings(parent) end)
    end
end

local function start_aura_frame_runtime_services()
    migrate_saved_frame_positions_next_frame()
    start_visible_icon_ticker()

    M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
    M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
    M.queue_wow_cooldown_refresh("startup")

    register_aura_frame_settings()
    M.create_grid_overlay()
end

-- Startup conductor: keep addon-loaded work in order while each step
-- owns one broad responsibility.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name == addon_name then
        prepare_aura_frame_db()
        create_startup_aura_frames()
        start_aura_frame_runtime_services()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ============================================================================
-- RESET ORCHESTRATION

local function apply_reset_runtime_state()
    M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
    M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
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

    frame._layout_cache = nil

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
    for _, frame in pairs(M.frames) do
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

-- RESET AND REFRESH: Restores UI states following a settings reset or global change
function M.on_reset_complete()
    -- Reset conductor: recover runtime state, reconcile frame ownership, then
    -- refresh visible frames and settings controls from the replaced DB.
    apply_reset_runtime_state()
    remove_orphan_custom_frames_after_reset()
    refresh_aura_frames_after_reset()
    refresh_aura_frame_settings_after_reset()
end
