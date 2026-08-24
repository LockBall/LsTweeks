-- Aura Frames frame-background owner: shared-color policy, addon-shell rendering,
-- combat-safe variants, and managed AuraContainer background geometry.

local _, addon = ...

local M = addon.aura_frames
local math_max = math.max
local math_min = math.min
local InCombatLockdown = InCombatLockdown
local NO_INSETS = { left = 0, right = 0, top = 0, bottom = 0 }

--#region BACKGROUND POLICY ===================================================

function M.resolve_background_color(category, target_type, local_color)
    local resolved = local_color
    local shared_color = target_type == "bar"
        and M.db and M.db.shared_bar_background_color
        or M.db and M.db.shared_frame_background_color
    if M.db
        and M.db.shared_background_color_enabled == true
        and M.get_background_color_sync_enabled(category, target_type)
        and shared_color
    then
        resolved = shared_color
    end

    local color_sync = addon.all_the_colors
    local consumer_group = M.get_color_consumer_group(category)
    if target_type == "bar" and color_sync and color_sync.resolve_module_color then
        return color_sync.resolve_module_color(M.MODULE_KEY, "aura_bar_bg_color", resolved, consumer_group)
    end
    if color_sync and color_sync.resolve_color then
        return color_sync.resolve_color(
            M.MODULE_KEY,
            M.get_background_color_target_key(category, target_type),
            resolved
        )
    end
    return resolved
end

function M.resolve_background_visibility(category, target_type, local_enabled)
    local resolved = local_enabled == true
    if target_type == "frame"
        and M.db
        and M.db.shared_background_color_enabled == true
        and M.get_background_color_sync_enabled(category, target_type)
    then
        resolved = true
    end

    local color_sync = addon.all_the_colors
    if color_sync and color_sync.resolve_visibility then
        return color_sync.resolve_visibility(
            M.MODULE_KEY,
            M.get_background_color_target_key(category, target_type),
            resolved
        )
    end
    return resolved
end

function M.resolve_frame_background(cfg_db, category)
    local enabled = M.get_setting(cfg_db, category, "bg", false) == true
    local color = M.get_setting(cfg_db, category, "bg_color", { r = 0, g = 0, b = 0, a = 0.5 })
    return M.resolve_background_visibility(category, "frame", enabled),
        M.resolve_background_color(category, "frame", color)
end

--#endregion BACKGROUND POLICY ================================================


--#region ADDON-RENDERED BACKGROUNDS =========================================

function M.setup_combat_background_variants(frame)
    if not frame or InCombatLockdown() then return end

    local layout = frame._layout_cache
    local max_count = frame.icons and #frame.icons or 0
    if not layout then return end

    local variants = frame._combat_background_variants or {}
    frame._combat_background_variants = variants
    frame._combat_background_variant_count = max_count

    local growth_layout = layout.growth_layout or addon.GetGrowthDirection(layout.growth)
    local anchor = growth_layout.anchor
    for count = 0, max_count do
        local variant = variants[count + 1]
        if not variant then
            variant = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
            variants[count + 1] = variant
        end
        variant:ClearAllPoints()
        variant:SetPoint(anchor, frame, anchor, 0, 0)
        variant:SetSize(
            layout.frame_width,
            M.get_aura_frame_height(
                layout,
                count,
                layout.bar_mode,
                layout.spacing,
                layout.layout_show_timer_text
            )
        )
        variant:Hide()
    end

    for index = max_count + 2, #variants do
        variants[index]:Hide()
    end
    frame._combat_background_index = nil
end

function M.update_combat_background(frame, display_count, enabled, color, in_combat, is_moving)
    if not frame then return false end
    local variants = frame._combat_background_variants

    if not in_combat and variants and color then
        local r, g, b, a = color.r, color.g, color.b, color.a or 1
        if frame._combat_background_r ~= r
            or frame._combat_background_g ~= g
            or frame._combat_background_b ~= b
            or frame._combat_background_a ~= a
        then
            frame._combat_background_r = r
            frame._combat_background_g = g
            frame._combat_background_b = b
            frame._combat_background_a = a
            for index = 1, (frame._combat_background_variant_count or 0) + 1 do
                variants[index]:SetColorTexture(r, g, b, a)
            end
        end
    end

    local wanted_index
    if in_combat and enabled and color and not is_moving and variants then
        local max_count = frame._combat_background_variant_count or 0
        wanted_index = math_min(max_count, math_max(0, tonumber(display_count) or 0)) + 1
    end

    local current_index = frame._combat_background_index
    if current_index == wanted_index then return wanted_index ~= nil end
    if current_index and variants and variants[current_index] then
        variants[current_index]:Hide()
    end
    frame._combat_background_index = wanted_index
    if wanted_index and variants[wanted_index] then
        variants[wanted_index]:Show()
        return true
    end
    return false
end

local function set_backdrop_state(frame, bg_r, bg_g, bg_b, bg_a, br_r, br_g, br_b, br_a)
    if frame._lstweeks_bg_r == bg_r
        and frame._lstweeks_bg_g == bg_g
        and frame._lstweeks_bg_b == bg_b
        and frame._lstweeks_bg_a == bg_a
        and frame._lstweeks_br_r == br_r
        and frame._lstweeks_br_g == br_g
        and frame._lstweeks_br_b == br_b
        and frame._lstweeks_br_a == br_a
    then
        return
    end

    frame._lstweeks_bg_r = bg_r
    frame._lstweeks_bg_g = bg_g
    frame._lstweeks_bg_b = bg_b
    frame._lstweeks_bg_a = bg_a
    frame._lstweeks_br_r = br_r
    frame._lstweeks_br_g = br_g
    frame._lstweeks_br_b = br_b
    frame._lstweeks_br_a = br_a
    frame:SetBackdropColor(bg_r, bg_g, bg_b, bg_a)
    frame:SetBackdropBorderColor(br_r, br_g, br_b, br_a)
end

function M.apply_addon_frame_background(frame, options)
    if not frame then return end
    options = options or {}
    local enabled = options.enabled == true and options.suppressed ~= true
    local color = options.color
    local is_moving = options.is_moving == true
    local combat_background_active = M.update_combat_background(
        frame,
        options.display_count,
        enabled,
        color,
        options.in_combat == true,
        is_moving
    )

    local bg_r, bg_g, bg_b, bg_a = 0, 0, 0, 0
    local br_r, br_g, br_b, br_a = 0, 0, 0, 0
    if options.suppressed ~= true then
        if is_moving then
            if enabled and color then
                bg_r, bg_g, bg_b, bg_a = color.r, color.g, color.b, color.a or 1
            else
                bg_r, bg_g, bg_b, bg_a = 0, 0, 0, 0.8
            end
            br_r, br_g, br_b, br_a = 1, 1, 1, 1
        elseif enabled and color then
            bg_r, bg_g, bg_b, bg_a = color.r, color.g, color.b, color.a or 1
        end
    end
    if combat_background_active then
        bg_a = 0
        br_a = 0
    end
    set_backdrop_state(frame, bg_r, bg_g, bg_b, bg_a, br_r, br_g, br_b, br_a)
end

--#endregion ADDON-RENDERED BACKGROUNDS ======================================


--#region MANAGED BACKGROUNDS =================================================

function M.initialize_managed_test_preview_background(frame)
    if not frame then return false end
    frame._managed_test_preview_background_anchor = frame._managed_test_preview_background_anchor
        or CreateFrame("Frame", nil, frame)
    frame._managed_test_preview_background = frame._managed_test_preview_background
        or addon.CreateBackgroundRegion(frame, {
            anchor_to = frame._managed_test_preview_background_anchor,
        })
    return frame._managed_test_preview_background ~= nil
end

function M.apply_managed_test_preview_background(frame, cfg_db, category)
    local background = frame and frame._managed_test_preview_background
    if not background then return false end
    local enabled, color = M.resolve_frame_background(cfg_db, category)
    background:Apply(enabled, color, NO_INSETS)
    return true
end

function M.hide_managed_test_preview_background(frame)
    local background = frame and frame._managed_test_preview_background
    if background then background:SetShown(false) end
end

function M.initialize_managed_frame_background(backend, owner)
    if not (backend and owner and backend.container) then return false end
    backend.frame_background_rows = backend.frame_background_rows or {}
    backend.frame_background_anchor = backend.frame_background_anchor or CreateFrame("Frame", nil, owner)
    backend.frame_background_layer = backend.frame_background_layer
        or CreateFrame("Frame", nil, backend.container, "DisableUntrustedLayoutScriptsTemplate")
    backend.frame_background_layer:SetAllPoints(backend.container)
    backend.frame_background = backend.frame_background
        or addon.CreateBackgroundRegion(backend.frame_background_layer, {
            anchor_to = backend.frame_background_anchor,
        })
    -- Blizzard resets an empty AuraContainer to 1x1 after every native layout.
    -- Keep one shell-anchored base cell, then partition two extensions around
    -- it. All three textures live in one container-owned layer: that avoids
    -- mixed-hierarchy alpha on the first cell without making a safe owner-level
    -- region depend on forbidden AuraContainer layout.
    backend.icon_frame_background = backend.icon_frame_background
        or addon.CreateBackgroundRegion(backend.frame_background_layer)
    backend.icon_frame_background_cross = backend.icon_frame_background_cross
        or addon.CreateBackgroundRegion(backend.frame_background_layer)
    return backend.frame_background ~= nil
        and backend.icon_frame_background ~= nil
        and backend.icon_frame_background_cross ~= nil
end

function M.register_managed_frame_background_row(backend, aura_button, mode, index)
    if not (backend and aura_button) or mode ~= "bar" or backend.skip_frame_background_rows then return end
    backend.frame_background_rows[aura_button] = {
        aura_button = aura_button,
        background = addon.CreateBackgroundRegion(aura_button),
        index = tonumber(index) or 1,
    }
end

local function configure_managed_frame_background(
    backend,
    bar_mode,
    width,
    spacing,
    show_timer_text,
    growth_layout
)
    local metrics = M.MANAGED_PRESENTATION_METRICS
    local icon_size = metrics.icon_size
    local icon_cell_height = metrics.icon_cell_height
    local bar_row_height = metrics.bar_row_height
    local bar_inset = metrics.bar_frame_inset
    local cell_height = show_timer_text and icon_cell_height or icon_size
    local signature = table.concat({ bar_mode and "bar" or "icon", width, spacing, cell_height,
        growth_layout.value }, ":")
    if backend.frame_background_signature == signature then return end
    backend.frame_background_signature = signature

    local background_width = bar_mode and width or icon_size
    local minimum_height = bar_mode and (bar_row_height + (bar_inset * 2)) or cell_height
    local anchor = backend.frame_background_anchor
    anchor:ClearAllPoints()
    anchor:SetPoint(growth_layout.anchor, backend.owner, growth_layout.anchor)
    anchor:SetSize(background_width, minimum_height)

    local container = backend.container
    local primary = backend.icon_frame_background.texture
    local cross = backend.icon_frame_background_cross.texture
    primary:ClearAllPoints()
    cross:ClearAllPoints()
    backend.icon_frame_background_uses_cross = not growth_layout.vertical
    if growth_layout.value == "LEFT" then
        primary:SetPoint("TOPRIGHT", anchor, "TOPLEFT")
        primary:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT")
        cross:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")
        cross:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", -icon_size, 0)
    elseif growth_layout.value == "UP" then
        primary:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT")
        primary:SetPoint("TOPRIGHT", container, "TOPRIGHT")
    elseif growth_layout.vertical then
        primary:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
        primary:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
    else
        primary:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
        primary:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
        cross:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
        cross:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT", icon_size, 0)
    end

    local grows_up = growth_layout.vertical_direction == "UP"
    for _, record in pairs(backend.frame_background_rows) do
        local texture = record.background.texture
        record.extends_background = bar_mode and record.index > 1
        texture:ClearAllPoints()
        if record.extends_background then
            texture:SetSize(width, bar_row_height + spacing)
            if grows_up then
                texture:SetPoint(
                    "BOTTOMLEFT",
                    record.aura_button,
                    "BOTTOMLEFT",
                    -bar_inset,
                    bar_inset - spacing
                )
            else
                texture:SetPoint(
                    "TOPLEFT",
                    record.aura_button,
                    "TOPLEFT",
                    -bar_inset,
                    spacing - bar_inset
                )
            end
        end
    end
end

function M.apply_managed_frame_background(
    backend,
    cfg_db,
    bar_mode,
    width,
    spacing,
    show_timer_text,
    growth_layout
)
    local background = backend and backend.frame_background
    local icon_background = backend and backend.icon_frame_background
    local icon_background_cross = backend and backend.icon_frame_background_cross
    if not (background and icon_background and icon_background_cross) then return false end
    configure_managed_frame_background(
        backend,
        bar_mode,
        width,
        spacing,
        show_timer_text,
        growth_layout
    )
    local enabled, color = M.resolve_frame_background(cfg_db, backend.category)
    background:Apply(enabled, color, NO_INSETS)
    icon_background:SetColor(color)
    icon_background:SetShown(enabled and not bar_mode)
    icon_background_cross:SetColor(color)
    icon_background_cross:SetShown(
        enabled and not bar_mode and backend.icon_frame_background_uses_cross
    )
    for _, record in pairs(backend.frame_background_rows) do
        record.background:SetColor(color)
        record.background:SetShown(enabled and bar_mode and record.extends_background)
    end
    return true
end

function M.hide_managed_frame_background(backend)
    if not backend then return end
    if backend.frame_background then backend.frame_background:SetShown(false) end
    if backend.icon_frame_background then backend.icon_frame_background:SetShown(false) end
    if backend.icon_frame_background_cross then backend.icon_frame_background_cross:SetShown(false) end
    for _, record in pairs(backend.frame_background_rows or {}) do
        record.background:SetShown(false)
    end
end

--#endregion MANAGED BACKGROUNDS ==============================================
