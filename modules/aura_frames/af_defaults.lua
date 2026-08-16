-- Aura frame constants and default DB values.
-- Defines category lists, CDM frame mappings, and per-category defaults.
-- Runtime files should read these values instead of repeating category names
-- or default settings.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region FRAME DEFINITIONS AND DEFAULTS ======================================
M.MODULE_KEY = "aura_frames"
M.COLOR_CONSUMER_GROUPS = { buffs = "buffs", debuffs = "debuffs" }

function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

-- Single source for built-in Aura Frame categories. Derived tables below keep
-- older call sites stable while preventing separate category lists from drifting.
M.FRAME_DEFS = {
    {
        key = "short",
        label = "Short Buffs",
        timer = true,
        cdm = false,
        supports_test_aura = false,
        is_debuff = false,
        tree_order = 3,
        growth = { icon = "DOWN", bar = "DOWN" },
        test_label = "Test Short Buff",
        test_sort_id = 2,
    },
    {
        key = "static_long",
        label = "Static / Long Buffs",
        timer = true,
        cdm = false,
        supports_test_aura = false,
        is_debuff = false,
        tree_order = 4.5,
        growth = { icon = "RIGHT", bar = "DOWN" },
        test_label = "Test Static / Long Buff",
        test_sort_id = 4,
    },
    {
        key = "timed",
        label = "Timed Buffs",
        timer = true,
        cdm = false,
        supports_test_aura = false,
        is_debuff = false,
        tree_order = 4.6,
        growth = { icon = "DOWN", bar = "DOWN" },
        test_label = "Test Timed Buff",
        test_sort_id = 4.5,
    },
    {
        key = "essential",
        label = "Essential",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "EssentialCooldownViewer",
        cdm_category_enum = "Essential",
        tree_order = 5,
        growth = { icon = "RIGHT", bar = "DOWN" },
        test_label = "Test Essential Buff",
        test_sort_id = 5,
    },
    {
        key = "utility",
        label = "Utility",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "UtilityCooldownViewer",
        cdm_category_enum = "Utility",
        tree_order = 6,
        growth = { icon = "RIGHT", bar = "DOWN" },
        test_label = "Test Utility Buff",
        test_sort_id = 6,
    },
    {
        key = "tracked_buffs",
        label = "Tracked Buffs",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "BuffIconCooldownViewer",
        cdm_category_enum = "TrackedBuff",
        tree_order = 7,
        growth = { icon = "RIGHT", bar = "DOWN" },
        test_label = "Test Tracked Buff",
        test_sort_id = 7,
    },
    {
        key = "tracked_bars",
        label = "Tracked Bars",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "BuffBarCooldownViewer",
        cdm_category_enum = "TrackedBar",
        tree_order = 8,
        growth = { icon = "DOWN", bar = "DOWN" },
        test_label = "Test Tracked Bar",
        test_sort_id = 8,
    },
    {
        key = "debuff",
        label = "DeBuff",
        frame_label = "Debuffs",
        timer = true,
        cdm = false,
        supports_test_aura = false,
        is_debuff = true,
        tree_order = 2,
        growth = { icon = "UP", bar = "UP" },
        test_label = "Test DeBuff",
        test_sort_id = 9,
    },
}

M.FRAME_DEFS_BY_KEY = {}
M.CATEGORIES = {}
M.TIMER_CATEGORIES = {}
M.CDM_CATEGORIES = {}
M.WOW_COOLDOWN_CATEGORIES = {}
M.CDM_VIEWER_FRAMES = {}

for _, frame_def in ipairs(M.FRAME_DEFS) do
    M.FRAME_DEFS_BY_KEY[frame_def.key] = frame_def
    M.CATEGORIES[#M.CATEGORIES + 1] = frame_def.key
    if frame_def.timer then
        M.TIMER_CATEGORIES[#M.TIMER_CATEGORIES + 1] = frame_def.key
    end
    if frame_def.cdm then
        M.CDM_CATEGORIES[#M.CDM_CATEGORIES + 1] = frame_def.key
        M.WOW_COOLDOWN_CATEGORIES[frame_def.key] = true
    end
    if frame_def.cdm_viewer then
        M.CDM_VIEWER_FRAMES[frame_def.key] = frame_def.cdm_viewer
    end
end

local color_sync = addon.all_the_colors

function M.get_background_color_target_key(category, target_type)
    return tostring(target_type) .. ":" .. tostring(category)
end

local function get_custom_frame_entry(category)
    for _, entry in ipairs(M.db and M.db.custom_frames or {}) do
        if entry.id == category then return entry end
    end
    return nil
end

local function get_participation_setting(category, key)
    if M.FRAME_DEFS_BY_KEY[category] then
        return M.db and M.db[key .. "_" .. category]
    end
    local entry = get_custom_frame_entry(category)
    return entry and entry[key]
end

local function set_participation_setting(category, key, enabled)
    if M.FRAME_DEFS_BY_KEY[category] then
        if not M.db then return false end
        M.db[key .. "_" .. category] = enabled == true
        return true
    end
    local entry = get_custom_frame_entry(category)
    if not entry then return false end
    entry[key] = enabled == true
    return true
end

function M.get_background_color_sync_enabled(category)
    return get_participation_setting(category, "sync_bar_bg") == true
end

function M.set_background_color_sync_enabled(category, enabled)
    return set_participation_setting(category, "sync_bar_bg", enabled)
end

function M.get_bar_color_sync_enabled(category)
    return get_participation_setting(category, "sync_bar_color") == true
end

function M.set_bar_color_sync_enabled(category, enabled)
    return set_participation_setting(category, "sync_bar_color", enabled)
end

function M.get_text_color_sync_enabled(category)
    return get_participation_setting(category, "sync_text_color") == true
end

function M.set_text_color_sync_enabled(category, enabled)
    return set_participation_setting(category, "sync_text_color", enabled)
end

function M.is_debuff_frame_category(category)
    local frame_def = M.FRAME_DEFS_BY_KEY[category]
    if frame_def then return frame_def.is_debuff == true end
    local entry = get_custom_frame_entry(category)
    return entry ~= nil and entry.aura_base_filter == "HARMFUL"
end

function M.get_color_consumer_group(category)
    return M.is_debuff_frame_category(category)
        and M.COLOR_CONSUMER_GROUPS.debuffs
        or M.COLOR_CONSUMER_GROUPS.buffs
end

function M.register_background_color_targets(category, label, order)
    if not color_sync or not color_sync.register_target then return end
    local row_label = label or category
    color_sync.register_target(M.MODULE_KEY, M.get_background_color_target_key(category, "frame"), {
        label = row_label .. " Frame Background",
        order = order,
        default_enabled = true,
        supports_visibility = true,
        get_global_group = function() return M.get_color_consumer_group(category) end,
    })
    color_sync.register_target(M.MODULE_KEY, M.get_background_color_target_key(category, "bar"), {
        label = row_label .. " Bar Background",
        order = order,
        default_enabled = true,
        supports_visibility = false,
        get_global_group = function() return M.get_color_consumer_group(category) end,
    })
end

function M.unregister_background_color_targets(category)
    if not color_sync or not color_sync.unregister_target then return end
    color_sync.unregister_target(M.MODULE_KEY, M.get_background_color_target_key(category, "frame"))
    color_sync.unregister_target(M.MODULE_KEY, M.get_background_color_target_key(category, "bar"))
end

if color_sync and color_sync.register_consumer then
    color_sync.register_consumer(M.MODULE_KEY, {
        label = "Buffs & Debuffs",
        order = 100,
        global_toggle = true,
        global_order = 200,
        default_global_enabled = true,
        global_groups = {
            { key = M.COLOR_CONSUMER_GROUPS.buffs, label = "Buffs", order = 1, default_enabled = true },
            { key = M.COLOR_CONSUMER_GROUPS.debuffs, label = "Debuffs", order = 2, default_enabled = true },
        },
        supports_ooc_fade = true,
        refresh = function()
            if M.on_shared_color_changed then
                M.on_shared_color_changed()
            end
        end,
    })
    for _, frame_def in ipairs(M.FRAME_DEFS) do
        M.register_background_color_targets(
            frame_def.key,
            frame_def.frame_label or frame_def.label,
            frame_def.tree_order
        )
    end
end

function M.get_frame_def(category)
    return M.FRAME_DEFS_BY_KEY[category]
end

function M.frame_supports_test_aura(category)
    local frame_def = M.FRAME_DEFS_BY_KEY[category]
    return frame_def == nil or frame_def.supports_test_aura ~= false
end

function M.get_preset_keys(category)
    return {
        show_key = "show_" .. category,
        move_key = "move_" .. category,
        timer_key = "timer_" .. category,
        bg_key = "bg_" .. category,
        scale_key = "scale_" .. category,
        spacing_key = "spacing_" .. category,
    }
end

function M.get_frame_def_from_show_key(show_key)
    if type(show_key) ~= "string" then return nil end
    local category = show_key:gsub("^show_", "")
    return M.get_frame_def(category)
end

M.UPDATE_INTERVALS = addon.UPDATE_INTERVALS

M.DEFAULT_FRAME_WIDTH = 200
M.MIN_FRAME_HEIGHT = 44
M.AURA_FRAME_LIMIT = 40
M.ICON_STACK_INSET = { right = 2, bottom = 2 }
M.DEFAULT_SHORT_THRESHOLD = 300
M.DEFAULT_TIMER_NUMBER_FONT_SIZE = 10
M.DEFAULT_OOC_FADE_DELAY = 2
M.DEFAULT_OOC_FADE_LENGTH = 3
M.MOVE_BORDER_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }

M.SETTING_RANGES = {
    aura_visible_icon_tick = { min = 0.10, max = 0.20, step = 0.05 },
    fade_delay = { min = 0, max = 10, step = 0.1 },
    fade_length = { min = 0, max = 10, step = 0.1 },
    frame_position = { min = -1000, max = 1000, step = 1 },
    ooc_alpha = { min = 0, max = 1, step = 0.05 },
    scale = { min = 0.5, max = 2.5, step = 0.01 },
    short_threshold = { min = 10, max = 300, step = 10 },
    spacing = { min = 0, max = 20, step = 0.1 },
    timer_number_font_size = { min = 8, max = 14, step = 0.5 },
    width = { min = 180, max = 800, step = 1 },
}

M.MIN_FRAME_WIDTH = M.SETTING_RANGES.width.min
M.MAX_FRAME_WIDTH = M.SETTING_RANGES.width.max
M.MIN_WOW_COOLDOWN_OOC_ALPHA = M.SETTING_RANGES.ooc_alpha.min
M.MAX_WOW_COOLDOWN_OOC_ALPHA = M.SETTING_RANGES.ooc_alpha.max
M.WOW_COOLDOWN_OOC_ALPHA_STEP = M.SETTING_RANGES.ooc_alpha.step
M.MIN_VISIBLE_ICON_TICK = M.SETTING_RANGES.aura_visible_icon_tick.min
M.MAX_VISIBLE_ICON_TICK = M.SETTING_RANGES.aura_visible_icon_tick.max
M.VISIBLE_ICON_TICK_STEP = M.SETTING_RANGES.aura_visible_icon_tick.step

M.CUSTOM_AURA_BASE_FILTERS = {
    { value = "HELPFUL", text = "HELPFUL" },
    { value = "HARMFUL", text = "HARMFUL" },
}

M.CUSTOM_AURA_MODIFIERS = {
    { value = "NONE", text = "NONE" },
    { value = "IMPORTANT", text = "IMPORTANT" },
    { value = "PLAYER", text = "PLAYER" },
    { value = "RAID", text = "RAID" },
    { value = "RAID_IN_COMBAT", text = "RAID_IN_COMBAT" },
    { value = "INCLUDE_NAME_PLATE_ONLY", text = "INCLUDE_NAME_PLATE_ONLY" },
    { value = "MAW", text = "MAW" },
    { value = "CANCELABLE", text = "CANCELABLE", force_base = "HELPFUL" },
    { value = "NOT_CANCELABLE", text = "NOT_CANCELABLE", force_base = "HELPFUL" },
    { value = "BIG_DEFENSIVE", text = "BIG_DEFENSIVE", force_base = "HELPFUL" },
    { value = "EXTERNAL_DEFENSIVE", text = "EXTERNAL_DEFENSIVE", force_base = "HELPFUL" },
    { value = "CROWD_CONTROL", text = "CROWD_CONTROL", force_base = "HARMFUL" },
    { value = "RAID_PLAYER_DISPELLABLE", text = "RAID_PLAYER_DISPELLABLE", force_base = "HARMFUL" },
}

M.CUSTOM_AURA_MODIFIERS_BY_VALUE = {}
for _, def in ipairs(M.CUSTOM_AURA_MODIFIERS) do
    M.CUSTOM_AURA_MODIFIERS_BY_VALUE[def.value] = def
end

-- Shared default background color and opacity.
M.BAR_BG_ALPHA_DEFAULT = 0.50
M.BAR_BG_GRAY_DEFAULT = 0.50

local function default_bg_color()
    return {
        r = M.BAR_BG_GRAY_DEFAULT,
        g = M.BAR_BG_GRAY_DEFAULT,
        b = M.BAR_BG_GRAY_DEFAULT,
        a = M.BAR_BG_ALPHA_DEFAULT,
    }
end

local function shared_bar_color_default(kind)
    local color = addon.AURA_BAR_COLOR_DEFAULTS[kind]
    return { r = color.r, g = color.g, b = color.b }
end

-- The Data: strictly default values
M.defaults = {
    last_frames_node = "static_long",
    last_tab_index = 1,

    -- Global Toggles
    enable_blizz_buffs = true,
    enable_blizz_debuffs = true,
    snap_to_grid   = true,
    show_grid      = true,
    show_bar_section_outlines = false,
    short_threshold = M.DEFAULT_SHORT_THRESHOLD,
    learned_helpful_durations = {},
    aura_visible_icon_tick = M.UPDATE_INTERVALS.aura_visible_icon_tick,
    timer_number_font = addon.DEFAULT_FONT_KEY,
    timer_number_font_size = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold = false,
    timer_number_font_outline = true,

    -- SHORT
    show_short      = true,
    move_short      = true,
    timer_short     = true,
    timer_swipe_short = true,
    tooltip_short   = true,
    bg_short        = false,
    scale_short     = 1.0,
    spacing_short   = 1.5,
    width_short     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_short  = true,
    color_short     = { r = 0, g = 0.5, b = 1 },
    bar_bg_color_short = default_bg_color(),
    fade_ooc_short = false,
    ooc_alpha_short = addon.DEFAULT_FADE_ALPHA,
    fade_delay_short = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_short = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_short = default_bg_color(),
    sort_short   = "timeleft",
    timer_number_font_short = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_short = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_short = false,
    timer_color_short = { r = 1, g = 1, b = 1 },
    bar_text_color_short = { r = 1, g = 1, b = 1 },

    -- STATIC / LONG BUFFS
    show_static_long       = false,
    move_static_long       = false,
    timer_static_long      = true,
    timer_swipe_static_long = true,
    tooltip_static_long    = true,
    bg_static_long         = false,
    scale_static_long      = 1.0,
    spacing_static_long    = 2.0,
    width_static_long      = M.DEFAULT_FRAME_WIDTH,
    bar_mode_static_long   = false,
    color_static_long      = shared_bar_color_default("buff"),
    bar_bg_color_static_long = default_bg_color(),
    fade_ooc_static_long = false,
    ooc_alpha_static_long = addon.DEFAULT_FADE_ALPHA,
    fade_delay_static_long = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_static_long = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_static_long = default_bg_color(),
    sort_static_long = "timeleft",
    timer_number_font_static_long = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_static_long = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_static_long = false,
    timer_color_static_long = { r = 1, g = 1, b = 1 },
    bar_text_color_static_long = { r = 1, g = 1, b = 1 },

    -- TIMED BUFFS
    show_timed       = false,
    move_timed       = false,
    timer_timed      = true,
    timer_swipe_timed = true,
    tooltip_timed    = true,
    bg_timed         = false,
    scale_timed      = 1.0,
    spacing_timed    = 2.0,
    width_timed      = M.DEFAULT_FRAME_WIDTH,
    bar_mode_timed   = true,
    color_timed      = shared_bar_color_default("buff"),
    bar_bg_color_timed = default_bg_color(),
    fade_ooc_timed = false,
    ooc_alpha_timed = addon.DEFAULT_FADE_ALPHA,
    fade_delay_timed = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_timed = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_timed = default_bg_color(),
    sort_timed = "timeleft",
    timer_number_font_timed = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_timed = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_timed = false,
    timer_color_timed = { r = 1, g = 1, b = 1 },
    bar_text_color_timed = { r = 1, g = 1, b = 1 },

    -- ESSENTIAL
    cooldown_mode_essential = false,
    hide_blizz_cdm_essential = false,
    show_essential      = false,
    move_essential      = false,
    timer_essential     = true,
    timer_swipe_essential = true,
    tooltip_essential   = true,
    bg_essential        = false,
    scale_essential     = 1.0,
    spacing_essential   = 1.5,
    width_essential     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_essential  = false,
    color_essential     = { r = 1, g = 0.45, b = 0.25 },
    bar_bg_color_essential = default_bg_color(),
    fade_ooc_essential = true,
    ooc_alpha_essential = addon.DEFAULT_FADE_ALPHA,
    fade_delay_essential = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_essential = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_essential = default_bg_color(),
    sort_essential = "timeleft",
    timer_number_font_essential = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_essential = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_essential = false,
    timer_color_essential = { r = 1, g = 1, b = 1 },
    test_aura_essential = false,
    bar_text_color_essential = { r = 1, g = 1, b = 1 },

    -- UTILITY
    cooldown_mode_utility = true,
    hide_blizz_cdm_utility = false,
    show_utility      = false,
    move_utility      = false,
    timer_utility     = true,
    timer_swipe_utility = true,
    tooltip_utility   = true,
    bg_utility        = false,
    scale_utility     = 1.0,
    spacing_utility   = 1.5,
    width_utility     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_utility  = false,
    color_utility     = { r = 0.65, g = 0.55, b = 1 },
    bar_bg_color_utility = default_bg_color(),
    fade_ooc_utility = true,
    ooc_alpha_utility = addon.DEFAULT_FADE_ALPHA,
    fade_delay_utility = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_utility = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_utility = default_bg_color(),
    sort_utility = "timeleft",
    timer_number_font_utility = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_utility = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_utility = false,
    timer_color_utility = { r = 1, g = 1, b = 1 },
    test_aura_utility = false,
    bar_text_color_utility = { r = 1, g = 1, b = 1 },

    -- TRACKED BUFFS
    hide_blizz_cdm_tracked_buffs = false,
    show_tracked_buffs      = false,
    move_tracked_buffs      = false,
    timer_tracked_buffs     = true,
    timer_swipe_tracked_buffs = true,
    tooltip_tracked_buffs   = true,
    bg_tracked_buffs        = false,
    scale_tracked_buffs     = 1.0,
    spacing_tracked_buffs   = 1.5,
    width_tracked_buffs     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_tracked_buffs  = false,
    color_tracked_buffs     = { r = 0.2, g = 0.85, b = 0.55 },
    bar_bg_color_tracked_buffs = default_bg_color(),
    fade_ooc_tracked_buffs = true,
    ooc_alpha_tracked_buffs = addon.DEFAULT_FADE_ALPHA,
    fade_delay_tracked_buffs = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_tracked_buffs = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_tracked_buffs = default_bg_color(),
    sort_tracked_buffs = "timeleft",
    timer_number_font_tracked_buffs = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_tracked_buffs = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_tracked_buffs = false,
    timer_color_tracked_buffs = { r = 1, g = 1, b = 1 },
    test_aura_tracked_buffs = false,
    bar_text_color_tracked_buffs = { r = 1, g = 1, b = 1 },

    -- TRACKED BARS
    hide_blizz_cdm_tracked_bars = false,
    show_tracked_bars      = false,
    move_tracked_bars      = false,
    timer_tracked_bars     = true,
    timer_swipe_tracked_bars = true,
    tooltip_tracked_bars   = true,
    bg_tracked_bars        = false,
    scale_tracked_bars     = 1.0,
    spacing_tracked_bars   = 1.5,
    width_tracked_bars     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_tracked_bars  = true,
    color_tracked_bars     = { r = 0.2, g = 0.65, b = 1 },
    bar_bg_color_tracked_bars = default_bg_color(),
    fade_ooc_tracked_bars = true,
    ooc_alpha_tracked_bars = addon.DEFAULT_FADE_ALPHA,
    fade_delay_tracked_bars = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_tracked_bars = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_tracked_bars = default_bg_color(),
    sort_tracked_bars = "timeleft",
    timer_number_font_tracked_bars = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_tracked_bars = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_tracked_bars = false,
    timer_color_tracked_bars = { r = 1, g = 1, b = 1 },
    test_aura_tracked_bars = false,
    bar_text_color_tracked_bars = { r = 1, g = 1, b = 1 },

    -- DEBUFFS
    show_debuff     = true,
    move_debuff     = true,
    timer_debuff    = true,
    timer_swipe_debuff = true,
    tooltip_debuff  = true,
    bg_debuff       = false,
    scale_debuff    = 1.0,
    spacing_debuff  = 1.0,
    width_debuff    = M.DEFAULT_FRAME_WIDTH,
    bar_mode_debuff = true,
    color_debuff    = shared_bar_color_default("debuff"),
    bar_bg_color_debuff = default_bg_color(),
    fade_ooc_debuff = false,
    ooc_alpha_debuff = addon.DEFAULT_FADE_ALPHA,
    fade_delay_debuff = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_debuff = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color_debuff = default_bg_color(),
    sort_debuff  = "timeleft",
    timer_number_font_debuff = addon.DEFAULT_FONT_KEY,
    timer_number_font_size_debuff = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold_debuff = false,
    timer_color_debuff = { r = 1, g = 1, b = 1 },
    bar_text_color_debuff = { r = 1, g = 1, b = 1 },

    -- Custom filtered frames (array of entry tables, see M.CUSTOM_FRAME_TEMPLATE)
    custom_frames = {},

    -- POSITIONS
    -- pos.x = left edge offset from screen center; pos.y = top edge offset from screen center
    positions = {
        debuff = { point = "TOPLEFT", x = 485, y = 246.5 },
        short  = { point = "TOPLEFT", x = 485, y = 128.5 },
        static_long = { point = "TOPLEFT", x = 100, y = 29 },
        timed = { point = "TOPLEFT", x = 100, y = -25 },
        essential = { point = "TOPLEFT", x = -100, y = 25 },
        utility = { point = "TOPLEFT", x = -100, y = -25 },
        tracked_buffs = { point = "TOPLEFT", x = -100, y = -75 },
        tracked_bars = { point = "TOPLEFT", x = -100, y = -125 },
    }
}

M.apply_presentation_growth_defaults(M.defaults, M.FRAME_DEFS)

for _, category in ipairs(M.CATEGORIES) do
    M.defaults["stack_number_font_" .. category] = addon.DEFAULT_FONT_KEY
    M.defaults["stack_number_font_size_" .. category] = M.DEFAULT_TIMER_NUMBER_FONT_SIZE
    M.defaults["stack_number_font_bold_" .. category] = false
    M.defaults["stack_number_font_outline_" .. category] = true
    M.defaults["stack_color_" .. category] = { r = 1, g = 1, b = 1 }
end
for _, category in ipairs(M.TIMER_CATEGORIES) do
    M.defaults["timer_number_font_outline_" .. category] = true
end

M.defaults.shared_frame_background_color = { r = 0, g = 0, b = 0, a = 0.5 }
M.defaults.shared_bar_background_color = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 }
M.defaults.shared_buff_bar_color = {
    r = M.defaults.color_static_long.r,
    g = M.defaults.color_static_long.g,
    b = M.defaults.color_static_long.b,
}
M.defaults.shared_debuff_bar_color = {
    r = M.defaults.color_debuff.r,
    g = M.defaults.color_debuff.g,
    b = M.defaults.color_debuff.b,
}
M.defaults.shared_bar_text_color = { r = 1, g = 1, b = 1 }
M.defaults.shared_timer_text_color = { r = 1, g = 1, b = 1 }
M.SHARED_COLOR_COLUMNS = {
    {
        title = "BG Colors",
        column = 2,
        pickers = {
            {
                label = "Frame BG",
                db_key = "shared_frame_background_color",
                control_key = "background_color_sync_frame_picker",
                has_alpha = true,
            },
            {
                label = "Bar BG",
                db_key = "shared_bar_background_color",
                control_key = "background_color_sync_bar_picker",
                has_alpha = true,
            },
        },
    },
    {
        title = "Bar Colors",
        column = 3,
        pickers = {
            {
                label = "Buff Bar",
                db_key = "shared_buff_bar_color",
                control_key = "background_color_sync_buff_bar_picker",
                has_alpha = true,
            },
            {
                label = "Debuff Bar",
                db_key = "shared_debuff_bar_color",
                control_key = "background_color_sync_debuff_bar_picker",
                has_alpha = true,
            },
        },
    },
    {
        title = "Text Colors",
        column = 4,
        pickers = {
            {
                label = "Bar Text",
                db_key = "shared_bar_text_color",
                control_key = "background_color_sync_bar_text_picker",
                has_alpha = false,
            },
            {
                label = "Timer Text",
                db_key = "shared_timer_text_color",
                control_key = "background_color_sync_timer_text_picker",
                has_alpha = false,
            },
        },
    },
}
M.defaults.shared_background_color_enabled = false
for _, category in ipairs(M.CATEGORIES) do
    M.defaults["sync_bar_bg_" .. category] = true
    M.defaults["sync_bar_color_" .. category] = true
    M.defaults["sync_text_color_" .. category] = true
end

--#endregion FRAME DEFINITIONS AND DEFAULTS ===================================
--#region CUSTOM FRAME TEMPLATE ================================================
-- Default values for a newly created custom filtered frame.
-- Each entry in M.db.custom_frames is a copy of this template with a unique id/name.
M.CUSTOM_FRAME_TEMPLATE = {
    -- Identity (always overwritten on create, never defaulted)
    -- id   = "custom_N"   set by spawn logic
    -- name = "Custom N"   set by spawn logic

    aura_base_filter = "HELPFUL",
    aura_modifier    = "IMPORTANT",

    -- Display
    show     = true,
    move     = true,
    timer    = true,
    timer_swipe = true,
    tooltip  = true,
    bg       = false,
    scale    = 1.0,
    spacing  = 1.5,
    width    = M.DEFAULT_FRAME_WIDTH,
    bar_mode = true,
    color    = { r = 0.8, g = 0.6, b = 1.0 },
    bar_bg_color = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 },
    fade_ooc = false,
    ooc_alpha = addon.DEFAULT_FADE_ALPHA,
    fade_delay = M.DEFAULT_OOC_FADE_DELAY,
    fade_length = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color     = default_bg_color(),
    sync_bar_bg = true,
    sync_bar_color = true,
    sync_text_color = true,
    test_aura    = true,

    -- Timer font (matches TIMER_CATEGORIES convention)
    timer_number_font      = addon.DEFAULT_FONT_KEY,
    timer_number_font_size = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    timer_number_font_bold = false,
    timer_number_font_outline = true,
    timer_color     = { r = 1, g = 1, b = 1 },
    stack_number_font      = addon.DEFAULT_FONT_KEY,
    stack_number_font_size = M.DEFAULT_TIMER_NUMBER_FONT_SIZE,
    stack_number_font_bold = false,
    stack_number_font_outline = true,
    stack_color     = { r = 1, g = 1, b = 1 },
    bar_text_color  = { r = 1, g = 1, b = 1 },

    -- Position
    position = { point = "TOPLEFT", x = 0, y = 50 },
}

M.apply_custom_presentation_growth_defaults(M.CUSTOM_FRAME_TEMPLATE)

-- Max number of custom frames the user can create.
M.MAX_CUSTOM_FRAMES = 4

--#endregion CUSTOM FRAME TEMPLATE =============================================
