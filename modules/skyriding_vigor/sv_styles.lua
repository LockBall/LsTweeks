-- Skyriding Vigor style catalogs, style DB helpers, and style-facing settings APIs.
-- Visual frame construction and runtime layout live in sv_bar.lua.
local _, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_Texture_GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
local abs = math.abs
local clamp_number = addon.clamp_number
local tonumber = tonumber

local COLOR_EPSILON = 0.001

--#region FLIGHT LOCK HELPERS ==================================================
local function settings_locked_by_flight()
    return M.is_settings_locked_by_flight and M.is_settings_locked_by_flight()
end

local function reject_settings_change_during_flight()
    if not settings_locked_by_flight() then return false end
    if M.sync_settings_controls then
        M.sync_settings_controls(M.get_db and M.get_db())
    end
    return true
end

--#endregion FLIGHT LOCK HELPERS ===============================================
--#region STYLE DEFINITIONS ====================================================

local MAX_SLOTS = 6
local DEFAULT_STYLE_KEY = "default"
local DEFAULT_NODE_COLOR_KEY = "default"
local DEFAULT_VIGOR_FILL_COLOR = { r = 0.00, g = 0.80, b = 1.00, a = 1 }
local NODE_COLORS = {
    default = {
        label = "Default",
    },
    bronze = {
        label = "Bronze (Default)",
    },
    dark = {
        label = "Dark",
    },
    gold = {
        label = "Gold",
    },
    silver = {
        label = "Silver",
    },
}
local NODE_COLOR_ORDER = { "bronze", "dark", "gold", "silver" }
local DEFAULT_DECOR_COLOR_KEY = "default"
local DECOR_COLORS = NODE_COLORS
local DECOR_COLOR_ORDER = NODE_COLOR_ORDER

-- Default vigor art ----------------------------------------------------------

local DEFAULT_BAR_STYLE = {
    label = "Default",
    frame = "dragonriding_vigor_frame",
    frame_colors = {
        default = "dragonriding_vigor_frame",
    },
    background = "dragonriding_vigor_background",
    fill = "dragonriding_vigor_fillfull",
    fill_full = "dragonriding_vigor_fillfull",
    spark = "dragonriding_vigor_spark",
    visible_edge_inset_x = 11.00,
    spark_clip_inset_x = 1.50,
    spark_clip_inset_y = 1.50,
    spacing_offset = 0.00,
    background_scale_x = 0.50,
    background_scale_y = 0.50,
    background_offset_x = 0.00,
    background_offset_y = 0.00,
    background_above_frame = false,
    fill_color = DEFAULT_VIGOR_FILL_COLOR,
    fill_add_alpha = 0.5,
}

local DEFAULT_DECOR_STYLE = {
    label = "Default",
    atlas = "dragonriding_vigor_decor",
    atlas_colors = {
        default = "dragonriding_vigor_decor",
    },
    scale = 1,
    scale_x = 1,
    scale_y = 1,
    decor_node_gap_x = -18.0,
    offset_y = -15.0,
}

local DISABLED_DECOR_STYLE = {
    label = "Disabled",
    disabled = true,
    atlas = DEFAULT_DECOR_STYLE.atlas,
    scale = DEFAULT_DECOR_STYLE.scale,
    scale_x = DEFAULT_DECOR_STYLE.scale_x,
    scale_y = DEFAULT_DECOR_STYLE.scale_y,
    decor_node_gap_x = DEFAULT_DECOR_STYLE.decor_node_gap_x,
    offset_y = DEFAULT_DECOR_STYLE.offset_y,
}

-- Storm Race vigor art -------------------------------------------------------

local STORM_RACE_BAR_STYLE = {
    label = "Storm Race",
    frame = "dragonriding_sgvigor_frame_bronze",
    default_node_color = "bronze",
    frame_colors = {
        bronze = "dragonriding_sgvigor_frame_bronze",
        dark = "dragonriding_sgvigor_frame_dark",
        gold = "dragonriding_sgvigor_frame_gold",
        silver = "dragonriding_sgvigor_frame_silver",
    },
    background = "dragonriding_sgvigor_background",
    fill = "dragonriding_sgvigor_fillfull",
    fill_full = "dragonriding_sgvigor_fillfull",
    spark = "dragonriding_sgvigor_spark",
    visible_edge_inset_x = 0.00,
    spark_clip_inset_x = 0.00,
    spark_clip_inset_y = 0.00,
    spacing_offset = 0.00,
    background_scale_x = 0.75,
    background_scale_y = 0.75,
    background_offset_x = 0.00,
    background_offset_y = 0.00,
    background_above_frame = false,
    fill_color = { r = 1, g = 1, b = 1, a = 1 },
    fill_add_alpha = 0.5,
}

local STORM_RACE_DECOR_STYLE = {
    label = "Storm Race",
    atlas = "dragonriding_sgvigor_decor_bronze",
    default_decor_color = "bronze",
    atlas_colors = {
        bronze = "dragonriding_sgvigor_decor_bronze",
        dark = "dragonriding_sgvigor_decor_dark",
        gold = "dragonriding_sgvigor_decor_gold",
        silver = "dragonriding_sgvigor_decor_silver",
    },
    scale = 1,
    scale_x = 1,
    scale_y = 1,
    decor_node_gap_x = -15.0,
    offset_y = 5.5,
}

local BAR_STYLES = {
    default = DEFAULT_BAR_STYLE,
    storm_race = STORM_RACE_BAR_STYLE,
}
local BAR_STYLE_ORDER = { "default", "storm_race" }
local DEFAULT_DECOR_STYLE_KEY = "default"
local DECOR_STYLES = {
    default = DEFAULT_DECOR_STYLE,
    disabled = DISABLED_DECOR_STYLE,
    storm_race = STORM_RACE_DECOR_STYLE,
}
local DECOR_STYLE_ORDER = { "default", "storm_race", "disabled" }

local SCALE_RANGE = { min = 0.40, max = 2, step = 0.05 }
local FILL_ADD_ALPHA_RANGE = { min = 0, max = 1, step = 0.01 }
local SPARK_SIZE_RANGE = { min = 0.50, max = 15.00, step = 0.5 }
local PROGRESS_UPDATE_HZ_RANGE = { min = 5, max = 60, step = 1 }
local SPACING_RANGE = { min = 0, max = 25, step = 0.5 }
local FADE_ALPHA_RANGE = { min = 0.05, max = 1, step = 0.05 }
local FADE_LENGTH_RANGE = { min = 0, max = 10, step = 0.5 }
local POSITION_RANGE = { min = -1000, max = 1000, step = 1 }
local FILL_ADD_ALPHA = 0.5

M.MAX_SLOTS = MAX_SLOTS
M.BAR_STYLE_DEFAULT = DEFAULT_STYLE_KEY
M.BAR_STYLE_OPTIONS = {}
for _, key in ipairs(BAR_STYLE_ORDER) do
    M.BAR_STYLE_OPTIONS[#M.BAR_STYLE_OPTIONS + 1] = {
        value = key,
        text = BAR_STYLES[key].label,
    }
end
M.NODE_COLOR_DEFAULT = DEFAULT_NODE_COLOR_KEY
M.NODE_COLOR_OPTIONS = {}
for _, key in ipairs(NODE_COLOR_ORDER) do
    M.NODE_COLOR_OPTIONS[#M.NODE_COLOR_OPTIONS + 1] = {
        value = key,
        text = NODE_COLORS[key].label,
    }
end
M.DECOR_COLOR_DEFAULT = DEFAULT_DECOR_COLOR_KEY
M.DECOR_COLOR_OPTIONS = {}
for _, key in ipairs(DECOR_COLOR_ORDER) do
    M.DECOR_COLOR_OPTIONS[#M.DECOR_COLOR_OPTIONS + 1] = {
        value = key,
        text = DECOR_COLORS[key].label,
    }
end
M.DECOR_STYLE_DEFAULT = DEFAULT_DECOR_STYLE_KEY
M.DECOR_STYLE_OPTIONS = {}
for _, key in ipairs(DECOR_STYLE_ORDER) do
    M.DECOR_STYLE_OPTIONS[#M.DECOR_STYLE_OPTIONS + 1] = {
        value = key,
        text = DECOR_STYLES[key].label,
    }
end
M.SETTING_RANGES = {
    fade_alpha = FADE_ALPHA_RANGE,
    fade_length = FADE_LENGTH_RANGE,
    fill_add_alpha = FILL_ADD_ALPHA_RANGE,
    progress_update_hz = PROGRESS_UPDATE_HZ_RANGE,
    spark_size = SPARK_SIZE_RANGE,
    scale = SCALE_RANGE,
    spacing = SPACING_RANGE,
    decor_scale = SCALE_RANGE,
    decor_x_position = { min = -30, max = 10, step = 0.5 },
    decor_y_position = { min = -30, max = 10, step = 0.5 },
    x_position = POSITION_RANGE,
    y_position = POSITION_RANGE,
}
M.SLIDER_KEYS = { "fade_alpha", "fade_length", "spacing", "scale", "fill_add_alpha", "spark_size", "progress_update_hz" }
M.LAYOUT_SETTING_KEYS = {
    scale = true,
    spacing = true,
    style = true,
    node_color = true,
    decor_style = true,
}

--#endregion STYLE DEFINITIONS =================================================

--#region SHARED ACCESSORS =====================================================

local function get_db()
    return M.get_db and M.get_db()
end

local function get_defaults()
    return M.DEFAULTS or {}
end

local function atlas_exists(atlas)
    if not atlas then return true end
    if not C_Texture_GetAtlasInfo then return false end
    local info = C_Texture_GetAtlasInfo(atlas)
    return info and info.width and info.height and info.width > 0 and info.height > 0
end

--#endregion SHARED ACCESSORS ==================================================

--#region STYLE DB HELPERS =====================================================

local function is_valid_style(style)
    return style and atlas_exists(style.frame) and atlas_exists(style.background)
        and atlas_exists(style.fill) and atlas_exists(style.fill_full)
end

local function get_valid_node_color_key(style, key)
    local atlas = style and style.frame_colors and style.frame_colors[key]
    if key and atlas and atlas_exists(atlas) then
        return key
    end
    atlas = style and style.default_node_color and style.frame_colors and style.frame_colors[style.default_node_color]
    if atlas and atlas_exists(atlas) then
        return style.default_node_color
    end
    atlas = style and style.frame_colors and style.frame_colors[DEFAULT_NODE_COLOR_KEY]
    if atlas and atlas_exists(atlas) then
        return DEFAULT_NODE_COLOR_KEY
    end
    return DEFAULT_NODE_COLOR_KEY
end

local function get_valid_decor_color_key(style, key)
    local atlas = style and style.atlas_colors and style.atlas_colors[key]
    if key and atlas and atlas_exists(atlas) then
        return key
    end
    atlas = style and style.default_decor_color and style.atlas_colors and style.atlas_colors[style.default_decor_color]
    if atlas and atlas_exists(atlas) then
        return style.default_decor_color
    end
    atlas = style and style.atlas_colors and style.atlas_colors[DEFAULT_DECOR_COLOR_KEY]
    if atlas and atlas_exists(atlas) then
        return DEFAULT_DECOR_COLOR_KEY
    end
    return DEFAULT_DECOR_COLOR_KEY
end

local function is_valid_decor_style(style)
    return style and (style.disabled or atlas_exists(style.atlas))
end

local function get_bar_style(db)
    local defaults = get_defaults()
    local key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[key]
    if is_valid_style(style) then
        return key, style
    end
    return DEFAULT_STYLE_KEY, BAR_STYLES[DEFAULT_STYLE_KEY]
end

M.get_bar_style = get_bar_style

function M.get_valid_bar_style_key(key)
    if is_valid_style(BAR_STYLES[key]) then
        return key
    end
    return DEFAULT_STYLE_KEY
end

function M.bar_style_supports_node_color(style_key)
    local db = get_db()
    local defaults = get_defaults()
    style_key = M.get_valid_bar_style_key(style_key or (db and db.style) or defaults.style or DEFAULT_STYLE_KEY)
    local style = BAR_STYLES[style_key]
    if not style or not style.frame_colors then return false end

    for key, atlas in pairs(style.frame_colors) do
        if key ~= DEFAULT_NODE_COLOR_KEY and atlas_exists(atlas) then
            return true
        end
    end
    return false
end

function M.get_style_layout_default(style_key, field)
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    if field == "scale" then
        return (get_defaults().scale or 1)
    elseif field == "node_color" then
        return get_valid_node_color_key(style, style and style.default_node_color or DEFAULT_NODE_COLOR_KEY)
    elseif field == "fill_color" then
        local color = style and style.fill_color or { r = 1, g = 1, b = 1, a = 1 }
        return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1 }
    elseif field == "fill_add_alpha" then
        return style and style.fill_add_alpha or FILL_ADD_ALPHA
    end
    return nil
end

function M.get_style_layout_table(db, style_key, create, initial_scale)
    if not db then return nil end
    style_key = M.get_valid_bar_style_key(style_key or db.style or DEFAULT_STYLE_KEY)
    if create then
        db.style_layouts = db.style_layouts or {}
        db.style_layouts[style_key] = db.style_layouts[style_key] or {}
        local layout = db.style_layouts[style_key]
        if layout.scale == nil then
            layout.scale = initial_scale or M.get_style_layout_default(style_key, "scale")
        end
        if layout.fill_color == nil then
            layout.fill_color = M.get_style_layout_default(style_key, "fill_color")
        end
        if layout.fill_add_alpha == nil then
            layout.fill_add_alpha = M.get_style_layout_default(style_key, "fill_add_alpha")
        end
        layout.node_color = get_valid_node_color_key(BAR_STYLES[style_key], layout.node_color or M.get_style_layout_default(style_key, "node_color"))
        return layout
    end
    return db.style_layouts and db.style_layouts[style_key] or nil
end

local function get_style_layout_number(db, style_key, field)
    local layout = M.get_style_layout_table(db, style_key, false)
    local value = layout and tonumber(layout[field])
    if value == nil then
        value = M.get_style_layout_default(style_key, field)
    end
    return value
end

M.get_style_layout_number = get_style_layout_number

function M.get_style_fill_color_value(db, style_key)
    db = db or get_db()
    style_key = M.get_valid_bar_style_key(style_key or (db and db.style) or DEFAULT_STYLE_KEY)
    local layout = M.get_style_layout_table(db, style_key, true)
    local color = layout and layout.fill_color
    if not color then
        color = M.get_style_layout_default(style_key, "fill_color")
    end
    return color
end

local function fill_color_is_custom(color)
    if not color then return false end
    return abs((color.r or 1) - 1) > COLOR_EPSILON
        or abs((color.g or 1) - 1) > COLOR_EPSILON
        or abs((color.b or 1) - 1) > COLOR_EPSILON
end

M.fill_color_is_custom = fill_color_is_custom

function M.apply_fill_texture_color(texture, color)
    if not texture then return end
    color = color or { r = 1, g = 1, b = 1, a = 1 }
    texture:SetDesaturated(fill_color_is_custom(color))
    texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

function M.apply_fill_boost_texture_color(texture, color)
    if not texture then return end
    color = color or { r = 1, g = 1, b = 1, a = 1 }
    local add_alpha = M.get_style_fill_add_alpha and M.get_style_fill_add_alpha() or FILL_ADD_ALPHA
    texture:SetDesaturated(true)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, (color.a or 1) * add_alpha)
end

function M.get_node_color()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    local layout = M.get_style_layout_table(db, style_key, true)
    return get_valid_node_color_key(style, layout and layout.node_color or M.get_style_layout_default(style_key, "node_color"))
end

function M.set_node_color(value)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.node_color = get_valid_node_color_key(style, value)
    if M.sync_node_color_controls then
        M.sync_node_color_controls()
    end
    M.refresh_layout()
end

local function get_frame_atlas(db, style_key, style)
    local layout = M.get_style_layout_table(db, style_key, true)
    local color_key = get_valid_node_color_key(style, layout and layout.node_color or nil)
    return style.frame_colors and style.frame_colors[color_key] or style.frame
end

M.get_frame_atlas = get_frame_atlas

function M.get_spark_atlas(_db, _style_key, style)
    local atlas = style and style.spark
    if atlas and atlas_exists(atlas) then
        return atlas
    end
    return nil
end

function M.get_spark_color(db)
    db = db or get_db()
    local defaults = get_defaults()
    return db and db.spark_color or defaults.spark_color or { r = 1, g = 1, b = 1, a = 1 }
end

function M.get_spark_size(db)
    db = db or get_db()
    local defaults = get_defaults()
    local fallback = defaults.spark_size or 1
    return clamp_number(db and db.spark_size, fallback, M.SETTING_RANGES and M.SETTING_RANGES.spark_size)
end

function M.get_style_scale()
    local db = get_db()
    local defaults = get_defaults()
    if not db then return defaults.scale or 1 end
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    local value = layout and layout.scale
    if value == nil then
        value = M.get_style_layout_default(style_key, "scale")
    end
    return value or defaults.scale or 1
end

function M.set_style_scale(value)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local fallback = db.scale or defaults.scale or 1
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.scale = clamp_number(value, fallback, M.SETTING_RANGES and M.SETTING_RANGES.scale)
    db.scale = layout.scale
    M.refresh_layout()
end

function M.get_style_fill_color()
    local db = get_db()
    if not db then return { r = 1, g = 1, b = 1, a = 1 } end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_fill_color_value(db, style_key) or { r = 1, g = 1, b = 1, a = 1 }
end

function M.get_style_fill_color_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_layout_default(style_key, "fill_color") or { r = 1, g = 1, b = 1, a = 1 }
end

function M.set_style_fill_color(color)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db or type(color) ~= "table" then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.fill_color = {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = color.a or 1,
    }
    if M.apply_fill_color then
        M.apply_fill_color()
    elseif M.refresh then
        M.refresh()
    end
end

function M.get_style_fill_add_alpha()
    local db = get_db()
    if not db then return FILL_ADD_ALPHA end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    local value = layout and layout.fill_add_alpha
    if value == nil then
        value = M.get_style_layout_default(style_key, "fill_add_alpha")
    end
    return clamp_number(value, FILL_ADD_ALPHA, M.SETTING_RANGES and M.SETTING_RANGES.fill_add_alpha)
end

function M.get_style_fill_add_alpha_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_layout_default(style_key, "fill_add_alpha") or FILL_ADD_ALPHA
end

function M.set_style_fill_add_alpha(value)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.fill_add_alpha = clamp_number(value, M.get_style_fill_add_alpha_default(), M.SETTING_RANGES and M.SETTING_RANGES.fill_add_alpha)
    if M.apply_fill_color then
        M.apply_fill_color()
    elseif M.refresh then
        M.refresh()
    end
end

local function get_decor_style(db)
    local defaults = get_defaults()
    local key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[key]
    if is_valid_decor_style(style) then
        return key, style
    end
    return DEFAULT_DECOR_STYLE_KEY, DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
end

M.get_decor_style = get_decor_style

function M.get_valid_decor_style_key(key)
    if is_valid_decor_style(DECOR_STYLES[key]) then
        return key
    end
    return DEFAULT_DECOR_STYLE_KEY
end

function M.decor_style_supports_color(style_key)
    local db = get_db()
    local defaults = get_defaults()
    style_key = M.get_valid_decor_style_key(style_key or (db and db.decor_style) or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY)
    local style = DECOR_STYLES[style_key]
    if not style or style.disabled or not style.atlas_colors then return false end

    for key, atlas in pairs(style.atlas_colors) do
        if key ~= DEFAULT_DECOR_COLOR_KEY and atlas_exists(atlas) then
            return true
        end
    end
    return false
end

function M.get_decor_layout_default(style_key, field)
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    if field == "decor_node_gap_x" then
        return style and style.decor_node_gap_x or 0
    elseif field == "offset_y" then
        return style and style.offset_y or 0
    elseif field == "scale" then
        return style and (style.scale or style.scale_x) or 1
    elseif field == "decor_color" then
        if style and style.disabled then
            return DEFAULT_DECOR_COLOR_KEY
        end
        return get_valid_decor_color_key(style, style and style.default_decor_color or DEFAULT_DECOR_COLOR_KEY)
    end
    return nil
end

function M.get_decor_layout_table(db, style_key, create)
    if not db then return nil end
    style_key = M.get_valid_decor_style_key(style_key or db.decor_style or DEFAULT_DECOR_STYLE_KEY)
    if create then
        db.decor_layouts = db.decor_layouts or {}
        db.decor_layouts[style_key] = db.decor_layouts[style_key] or {}
        local layout = db.decor_layouts[style_key]
        if layout.decor_node_gap_x == nil then
            layout.decor_node_gap_x = M.get_decor_layout_default(style_key, "decor_node_gap_x")
        end
        if layout.offset_y == nil then
            layout.offset_y = M.get_decor_layout_default(style_key, "offset_y")
        end
        if layout.scale == nil then
            layout.scale = M.get_decor_layout_default(style_key, "scale")
        end
        if DECOR_STYLES[style_key] and DECOR_STYLES[style_key].disabled then
            layout.decor_color = DEFAULT_DECOR_COLOR_KEY
        else
            layout.decor_color = get_valid_decor_color_key(DECOR_STYLES[style_key], layout.decor_color or M.get_decor_layout_default(style_key, "decor_color"))
        end
        return layout
    end
    return db.decor_layouts and db.decor_layouts[style_key] or nil
end

local function get_decor_layout_number(db, style_key, field)
    local layout = M.get_decor_layout_table(db, style_key, false)
    local value = layout and tonumber(layout[field])
    if value == nil then
        value = M.get_decor_layout_default(style_key, field)
    end
    return value
end

M.get_decor_layout_number = get_decor_layout_number

local function get_decor_position_field(axis)
    if axis == "x" then
        return "decor_node_gap_x", "decor_x_position"
    elseif axis == "y" then
        return "offset_y", "decor_y_position"
    end
    return nil
end

function M.get_decor_position_axis(axis)
    local field = get_decor_position_field(axis)
    if not field then return 0 end
    local db = get_db()
    if not db then return 0 end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local layout = M.get_decor_layout_table(db, style_key, true)
    local value = layout and layout[field]
    if value == nil then
        value = M.get_decor_layout_default(style_key, field)
    end
    return value or 0
end

function M.get_decor_position_default(axis)
    local field = get_decor_position_field(axis)
    if not field then return 0 end
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    return M.get_decor_layout_default(style_key, field) or 0
end

function M.set_decor_position_axis(axis, value)
    if reject_settings_change_during_flight() then return end

    local field, range_key = get_decor_position_field(axis)
    if not field then return end
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local fallback = M.get_decor_layout_default(style_key, field) or 0
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    layout[field] = clamp_number(value, fallback, M.SETTING_RANGES and M.SETTING_RANGES[range_key])
    M.refresh_layout()
end

function M.get_decor_scale()
    local db = get_db()
    if not db then return 1 end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local layout = M.get_decor_layout_table(db, style_key, true)
    local value = layout and layout.scale
    if value == nil then
        value = M.get_decor_layout_default(style_key, "scale")
    end
    return value or 1
end

function M.get_decor_scale_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    return M.get_decor_layout_default(style_key, "scale") or 1
end

function M.set_decor_scale(value)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local fallback = M.get_decor_layout_default(style_key, "scale") or 1
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    layout.scale = clamp_number(value, fallback, M.SETTING_RANGES and M.SETTING_RANGES.decor_scale)
    M.refresh_layout()
end

function M.get_decor_color()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    if style and style.disabled then return DEFAULT_DECOR_COLOR_KEY end
    local layout = M.get_decor_layout_table(db, style_key, true)
    return get_valid_decor_color_key(style, layout and layout.decor_color or M.get_decor_layout_default(style_key, "decor_color"))
end

function M.set_decor_color(value)
    if reject_settings_change_during_flight() then return end

    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    if style and style.disabled then
        layout.decor_color = DEFAULT_DECOR_COLOR_KEY
        if M.sync_decor_color_controls then
            M.sync_decor_color_controls()
        end
        return
    end

    layout.decor_color = get_valid_decor_color_key(style, value)
    if M.sync_decor_color_controls then
        M.sync_decor_color_controls()
    end
    M.refresh_layout()
end

local function get_decor_atlas(db, style_key, style)
    local layout = M.get_decor_layout_table(db, style_key, true)
    local color_key = get_valid_decor_color_key(style, layout and layout.decor_color or nil)
    return style.atlas_colors and style.atlas_colors[color_key] or style.atlas
end

M.get_decor_atlas = get_decor_atlas

--#endregion STYLE DB HELPERS ==================================================
