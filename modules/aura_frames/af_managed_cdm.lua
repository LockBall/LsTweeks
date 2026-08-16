-- Managed active-Aura transport for Cooldown Manager-backed Aura Frames.
-- Cooldown entries remain addon-rendered from Blizzard viewer state, while
-- AuraContainer groups/slots own all active Aura identity, timing, and display.

local _, addon = ...

local M = addon.aura_frames

local EMPTY_SPELL_IDS = {}
local CDM_FILTER = "HELPFUL"

--#region COOLDOWN MANAGER DATA ===============================================

local function get_cdm_category(category)
    local frame_def = M.get_frame_def and M.get_frame_def(category)
    local enum = Enum and Enum.CooldownViewerCategory
    return frame_def and enum and enum[frame_def.cdm_category_enum]
end

local function get_ordered_cooldown_records(category)
    local category_enum = get_cdm_category(category)
    local cdm_api = C_CooldownViewer
    if category_enum == nil or not (cdm_api
        and cdm_api.GetCooldownViewerCategorySet
        and cdm_api.GetCooldownViewerCooldownInfo) then
        return nil
    end

    local ok, cooldown_ids = pcall(cdm_api.GetCooldownViewerCategorySet, category_enum, false)
    if not (ok and cooldown_ids) then return nil end

    local records = {}
    for order, cooldown_id in ipairs(cooldown_ids) do
        if cooldown_id ~= nil and not issecretvalue(cooldown_id) then
            local info_ok, info = pcall(cdm_api.GetCooldownViewerCooldownInfo, cooldown_id)
            if info_ok and info then
                records[#records + 1] = {
                    cooldown_id = cooldown_id,
                    info = info,
                    order = order,
                }
            end
        end
    end
    return records
end

M.get_ordered_cdm_records = get_ordered_cooldown_records

local function add_spell_id(spell_ids, spell_id)
    if spell_id ~= nil and not issecretvalue(spell_id) then
        spell_ids[spell_id] = true
    end
end

local function build_cooldown_spell_ids(info)
    local spell_ids = {}
    if not info then return spell_ids end
    add_spell_id(spell_ids, info.spellID)
    add_spell_id(spell_ids, info.overrideSpellID)
    add_spell_id(spell_ids, info.previousOverrideSpellID)
    add_spell_id(spell_ids, info.overrideTooltipSpellID)
    add_spell_id(spell_ids, info.linkedSpellID)
    if type(info.linkedSpellIDs) == "table" then
        for _, spell_id in ipairs(info.linkedSpellIDs) do
            add_spell_id(spell_ids, spell_id)
        end
    end
    return spell_ids
end

local function spell_id_maps_equal(a, b)
    for spell_id in pairs(a) do
        if not b[spell_id] then return false end
    end
    for spell_id in pairs(b) do
        if not a[spell_id] then return false end
    end
    return true
end

--#endregion COOLDOWN MANAGER DATA ============================================

--#region MANAGED RECORD CREATION =============================================

local function make_key(category, source, mode, cooldown_id)
    return table.concat({ "cdm", category, source, mode, tostring(cooldown_id) }, ":")
end

local function make_group_layout(backend, bar_mode, order)
    local cfg_db = backend.cfg_db
    local category = backend.category
    local show_timer_text = cfg_db["timer_" .. category] ~= false
    local layout = M.configure_managed_presentation_layout(
        backend.container,
        backend.owner,
        cfg_db,
        category,
        M.AURA_FRAME_LIMIT,
        bar_mode,
        show_timer_text
    )
    local spacing = cfg_db["spacing_" .. category] or 1
    layout.layoutIndex = order
    layout.groupSpacing = spacing
    layout.groupLineSpacing = spacing
    layout.forceNewLine = false
    return layout
end

local function create_record_mode(backend, record, mode)
    local bar_mode = mode == "bar"
    local category = backend.category
    local candidate_filters = { includeSpellIDs = record.spell_ids }
    local initializer = M.create_managed_presentation_initializer(
        backend.cfg_db,
        category,
        bar_mode,
        backend
    )
    local group_key = make_key(category, "group", mode, record.cooldown_id)
    local group, group_error = M.add_managed_aura_group(
        backend,
        group_key,
        CDM_FILTER,
        {
            maxFrameCount = 1,
            candidateFilters = candidate_filters,
            initializeFrame = initializer,
        },
        make_group_layout(backend, bar_mode, record.order)
    )
    if not group then return nil, group_error end

    -- Slot buttons occupy the matching addon cooldown cell and are enabled
    -- only in cooldown mode. Their visibility is driven natively by Blizzard.
    local slot_backend = setmetatable({
        skip_frame_background_rows = true,
        icon_duration_overlay = not bar_mode,
        duration_font = backend.duration_font,
        stack_font = backend.stack_font,
        bar_regions = backend.bar_regions,
        frame_background_rows = backend.frame_background_rows,
    }, { __index = backend })
    local initialize_slot_presentation = M.create_managed_presentation_initializer(
        backend.cfg_db,
        category,
        bar_mode,
        slot_backend
    )
    local slot_initializer = function(aura_button)
        initialize_slot_presentation(aura_button)
        local obj = backend.owner.icons and backend.owner.icons[record.order]
        if not obj then return end
        if bar_mode then
            aura_button:SetAllPoints(obj)
        else
            aura_button:SetPoint("TOP", obj, "TOP")
        end
    end
    local slot_key = make_key(category, "slot", mode, record.cooldown_id)
    local slot, slot_error = M.add_managed_aura_slot(
        backend,
        slot_key,
        CDM_FILTER,
        {
            candidateFilters = candidate_filters,
            initializeFrame = slot_initializer,
        }
    )
    if not slot then return nil, slot_error end

    record.modes[mode] = {
        group_key = group_key,
        slot_key = slot_key,
        slot_button = slot.aura_button,
    }
    return true
end

local function create_managed_record(backend, source_record)
    local cooldown_id = source_record.cooldown_id
    local record = {
        cooldown_id = cooldown_id,
        order = source_record.order,
        spell_ids = build_cooldown_spell_ids(source_record.info),
        modes = {},
    }
    backend.cdm_records[cooldown_id] = record
    local ok, err = create_record_mode(backend, record, "icon")
    if not ok then return nil, err end
    ok, err = create_record_mode(backend, record, "bar")
    if not ok then return nil, err end
    return record
end

--#endregion MANAGED RECORD CREATION ==========================================

--#region PRESENTATION AND LAYOUT =============================================

local function set_record_mode_enabled(backend, record, mode, aura_mode, bar_mode)
    local mode_record = record.modes[mode]
    if not mode_record then return end
    local is_selected_mode = (mode == "bar") == bar_mode
    local group_count = (aura_mode and is_selected_mode) and 1 or 0
    local group_filters = (aura_mode and is_selected_mode)
        and { includeSpellIDs = record.spell_ids }
        or { includeSpellIDs = EMPTY_SPELL_IDS }
    backend.container:SetAuraGroupCandidateFilters(mode_record.group_key, group_filters)
    backend.container:SetAuraGroupMaxFrameCount(mode_record.group_key, group_count)
    local slot_filters = (not aura_mode and is_selected_mode)
        and { includeSpellIDs = record.spell_ids }
        or { includeSpellIDs = EMPTY_SPELL_IDS }
    backend.container:SetAuraSlotCandidateFilters(mode_record.slot_key, slot_filters)
    -- configure_managed_presentation_layout mutates the shared container, not
    -- just this group. Never call it for the inactive mode: the icon pass is
    -- followed by the bar pass, so an inactive Bar layout would silently force
    -- every RIGHT/LEFT CDM icon container back to vertical DOWN growth.
    if is_selected_mode then
        backend.container:SetAuraGroupLayout(
            mode_record.group_key,
            make_group_layout(backend, mode == "bar", record.order)
        )
    end
end

local function apply_backend_mode(backend)
    local category = backend.category
    local aura_mode = backend.cfg_db["cooldown_mode_" .. category] ~= true
    local bar_mode = backend.cfg_db["bar_mode_" .. category] == true
    local signature = table.concat({
        tostring(aura_mode),
        tostring(bar_mode),
        tostring(backend.cfg_db["width_" .. category]),
        tostring(backend.cfg_db["spacing_" .. category]),
        tostring(backend.cfg_db["timer_" .. category]),
        tostring(M.get_mode_growth(backend.cfg_db, category, bar_mode)),
        tostring(backend.data_revision or 0),
    }, ":")
    if backend.mode_signature == signature then return end
    backend.mode_signature = signature
    for _, record in pairs(backend.cdm_records) do
        set_record_mode_enabled(backend, record, "icon", aura_mode, bar_mode)
        set_record_mode_enabled(backend, record, "bar", aura_mode, bar_mode)
    end
end

local function apply_backend_style(backend)
    local cfg_db = backend.cfg_db
    local category = backend.category
    local show_timer_text = cfg_db["timer_" .. category] ~= false
    if backend.duration_font and M.apply_number_font_style then
        M.apply_number_font_style(backend.duration_font, category, cfg_db, show_timer_text and 1 or 0)
    end
    if backend.stack_font and M.apply_stack_font_style then
        M.apply_stack_font_style(backend.stack_font, category, cfg_db)
    end
    local metrics = M.MANAGED_PRESENTATION_METRICS
    local width = math.max(M.MIN_FRAME_WIDTH, cfg_db["width_" .. category] or M.DEFAULT_FRAME_WIDTH)
        - ((metrics and metrics.bar_frame_inset or 6) * 2)
    local bar_color = M.get_managed_presentation_bar_color(cfg_db, category)
    M.for_each_accessible_managed_aura_button(backend, function(aura_button)
        local duration_bar = backend.bar_regions[aura_button]
        if duration_bar then
            M.set_managed_presentation_bar_width(aura_button, width)
            M.set_managed_presentation_bar_color(duration_bar, bar_color)
        end
    end)
end

local function anchor_slot_buttons(frame, backend)
    local displayed = frame._display_count or 0
    for index = 1, displayed do
        local obj = frame.icons[index]
        local record = obj and backend.cdm_records[obj.cdm_cooldown_id]
        if record then
            for mode, mode_record in pairs(record.modes) do
                local aura_button = mode_record.slot_button
                if aura_button and M.is_managed_aura_button_accessible(aura_button) then
                    aura_button:ClearAllPoints()
                    if mode == "bar" then
                        aura_button:SetAllPoints(obj)
                    else
                        aura_button:SetPoint("TOP", obj, "TOP")
                    end
                end
            end
        end
    end
end

function M.refresh_managed_cdm_backend(frame, bar_mode)
    local backend = frame and frame._managed_cdm_backend
    if not backend then return false end
    M.set_managed_aura_backend_enabled(backend, frame:IsShown())
    if InCombatLockdown and InCombatLockdown() then return true end

    local source_records = get_ordered_cooldown_records(backend.category)
    if source_records then
        local seen = {}
        local data_changed = false
        for _, source_record in ipairs(source_records) do
            seen[source_record.cooldown_id] = true
            local record = backend.cdm_records[source_record.cooldown_id]
            if not record then
                record = create_managed_record(backend, source_record)
                data_changed = record ~= nil or data_changed
            end
            if record then
                if record.order ~= source_record.order then
                    data_changed = true
                end
                record.order = source_record.order
                local spell_ids = build_cooldown_spell_ids(source_record.info)
                if not spell_id_maps_equal(record.spell_ids, spell_ids) then
                    record.spell_ids = spell_ids
                    data_changed = true
                end
            end
        end
        for cooldown_id, record in pairs(backend.cdm_records) do
            if not seen[cooldown_id] and next(record.spell_ids) ~= nil then
                record.spell_ids = {}
                data_changed = true
            end
        end
        if data_changed then
            backend.data_revision = (backend.data_revision or 0) + 1
        end
    end
    anchor_slot_buttons(frame, backend)
    apply_backend_mode(backend)
    apply_backend_style(backend)
    return true
end

function M.create_managed_cdm_backend(frame, cfg_db, category)
    if not (frame and cfg_db and category and M.create_managed_aura_backend) then return nil end
    local backend, backend_error = M.create_managed_aura_backend(
        frame,
        "cdm:" .. category,
        "player"
    )
    if not backend then return nil, backend_error end
    backend.category = category
    backend.cfg_db = cfg_db
    backend.skip_frame_background_rows = true
    backend.cdm_records = {}
    backend.bar_regions = {}
    backend.frame_background_rows = {}
    frame._managed_cdm_backend = backend

    local source_records = get_ordered_cooldown_records(category)
    if source_records then
        for _, source_record in ipairs(source_records) do
            local record, record_error = create_managed_record(backend, source_record)
            if not record then
                M.release_managed_aura_backend(backend)
                frame._managed_cdm_backend = nil
                return nil, record_error
            end
        end
    end
    apply_backend_mode(backend)
    return backend
end

--#endregion PRESENTATION AND LAYOUT ==========================================
