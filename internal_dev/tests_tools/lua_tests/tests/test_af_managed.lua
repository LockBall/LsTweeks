-- Aura Frames managed AuraContainer foundation and lifecycle tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

local base_create_frame = fixture.base_create_frame
local created_containers = fixture.created_containers

h.test("managed Aura framework creates and initializes protected groups", function()
    local M = h.addon.aura_frames
    local owner = base_create_frame("Frame", nil, UIParent)
    local initialized = 0
    local candidate_filters = { isFromPlayerOrPlayerPet = true }
    local layout = { elementSpacing = 3, maxColumns = 4 }

    local backend, err = M.create_managed_aura_backend(owner, "test_debuff", "player")

    h.is_nil(err, "managed backend created without an error")
    h.ok(backend, "managed backend returned")
    local group_record, group_err = M.add_managed_aura_group(backend, "debuffs", "HARMFUL", {
        maxFrameCount = 3,
        candidateFilters = candidate_filters,
        sortMethod = 10,
        sortDirection = 20,
        initializeFrame = function(aura_button)
            h.eq(aura_button.__access_constrained, nil, "AuraButton initialized before access constraints")
            aura_button:SetSize(32, 32)
            initialized = initialized + 1
        end,
    }, layout)

    h.is_nil(group_err, "managed group created without an error")
    h.ok(group_record, "managed group returned")
    h.eq(backend.container.__unit, "player", "managed container owns the requested unit")
    h.eq(backend.container.__parent, owner, "managed container is parented to addon shell")
    h.eq(backend.container.__engine_enabled, false, "managed engine stays disabled before runtime starts")
    h.eq(initialized, 3, "all managed buttons initialized at group creation")

    local group = backend.container.__groups.debuffs
    h.eq(group.filter_string, "HARMFUL", "filter string forwarded")
    h.eq(group.options.maxFrameCount, 3, "frame pool size forwarded")
    h.eq(group.options.candidateFilters, candidate_filters, "candidate filters forwarded")
    h.eq(group.options.sortMethod, 10, "sort method forwarded")
    h.eq(group.options.sortDirection, 20, "sort direction forwarded")
    h.eq(group.layout, layout, "managed layout applied after group creation")
    h.eq(backend.container:GetScript("OnEvent"), nil, "container owns no addon event handler")
    h.eq(backend.container:GetScript("OnSizeChanged"), nil, "container owns no addon layout handler")
end)

h.test("managed backend lifecycle preserves feature and runtime gates", function()
    local M = h.addon.aura_frames
    local backend = M.get_managed_aura_backend("test_debuff")
    h.ok(backend, "created backend remains registered")
    h.eq(backend.container:IsShown(), false, "backend stays hidden before runtime starts")

    M.set_managed_aura_runtime_enabled(true)
    h.ok(backend.container:IsShown(), "runtime start shows enabled backend")
    h.eq(backend.container.__engine_enabled, true, "runtime start enables AuraContainer processing")

    M.set_managed_aura_backend_enabled(backend, false)
    h.eq(backend.container:IsShown(), false, "feature disable hides container")
    h.eq(backend.container.__engine_enabled, false, "feature disable stops AuraContainer processing")

    M.set_managed_aura_runtime_enabled(false)
    M.set_managed_aura_backend_enabled(backend, true)
    h.eq(backend.container:IsShown(), false, "feature enable cannot bypass stopped runtime")
    h.eq(backend.container.__engine_enabled, false, "feature enable cannot start a stopped runtime")

    M.set_managed_aura_runtime_enabled(true)
    h.eq(backend.container:IsShown(), true, "runtime restart restores enabled backend")
    h.eq(backend.container.__engine_enabled, true, "runtime restart restores AuraContainer processing")

    M.release_managed_aura_backend(backend)
    h.eq(backend.container:IsShown(), false, "released backend remains hidden")
    h.eq(backend.container.__engine_enabled, false, "released backend processing remains stopped")
    h.eq(M.get_managed_aura_backend("test_debuff"), nil, "released backend leaves registry")
end)

h.test("managed Aura slots initialize one stable native indicator", function()
    local M = h.addon.aura_frames
    local owner = CreateFrame("Frame", nil, UIParent)
    local backend = M.create_managed_aura_backend(owner, "test_slot", "player")
    local initialized
    local slot, err = M.add_managed_aura_slot(backend, "spell:1001", "HELPFUL", {
        candidateFilters = { includeSpellIDs = { [1001] = true } },
        initializeFrame = function(aura_button)
            initialized = aura_button
        end,
    })

    h.is_nil(err, "managed slot created without an error")
    h.ok(slot and slot.aura_button, "managed slot returns its stable AuraButton")
    h.eq(slot.aura_button, initialized, "slot initialization receives the returned AuraButton")
    h.eq(backend.aura_buttons[initialized], "spell:1001", "slot button joins accessibility tracking")
    h.eq(backend.container.__slots["spell:1001"].filter_string, "HELPFUL",
        "managed slot preserves its native Aura filter")
end)

h.test("CDM managed backend uses groups for Aura mode and slots for cooldown overlays", function()
    local M = h.addon.aura_frames
    Enum.CooldownViewerCategory = {
        Essential = 0,
        Utility = 1,
        TrackedBuff = 2,
        TrackedBar = 3,
    }
    C_CooldownViewer = {
        GetCooldownViewerCategorySet = function(category)
            h.eq(category, 0, "Essential frame requests the matching public CDM category")
            return { 71 }
        end,
        GetCooldownViewerCooldownInfo = function(cooldown_id)
            h.eq(cooldown_id, 71, "CDM backend resolves static info for its cooldown ID")
            return { spellID = 7001, linkedSpellIDs = { 7002 } }
        end,
    }
    local owner = CreateFrame("Frame", nil, UIParent)
    owner.category = "essential"
    owner.icons = {}
    local cfg_db = {
        cooldown_mode_essential = true,
        bar_mode_essential = false,
        timer_essential = true,
        width_essential = 140,
        spacing_essential = 2,
        growth_icon_essential = "RIGHT",
        growth_bar_essential = "DOWN",
        color_essential = { r = 1, g = 1, b = 1, a = 1 },
        bar_bg_color_essential = { r = 0, g = 0, b = 0, a = 1 },
        bar_text_color_essential = { r = 1, g = 1, b = 1, a = 1 },
    }

    local backend, err = M.create_managed_cdm_backend(owner, cfg_db, "essential")
    h.is_nil(err, "CDM managed backend created without an error")
    h.ok(backend and backend.cdm_records[71], "CDM backend owns one record per cooldown ID")
    local record = backend.cdm_records[71]
    h.eq(record.spell_ids[7001], true, "CDM Aura filter includes the base spell")
    h.eq(record.spell_ids[7002], true, "CDM Aura filter includes linked Aura spells")
    h.eq(backend.container.__groups[record.modes.icon.group_key].active_max_frame_count, 0,
        "cooldown mode disables compact Aura groups")
    h.eq(backend.container.__slots[record.modes.icon.slot_key].options.candidateFilters.includeSpellIDs[7001], true,
        "cooldown mode enables the selected native Aura slot overlay")
    h.eq(record.modes.icon.slot_button.__height, 32,
        "cooldown icon slot keeps native duration text inside the fixed icon cell")
    h.eq(backend.container.__groups[record.modes.icon.group_key].layout.elementWidth, 32,
        "CDM icon groups expose their width so separate tracked groups share a horizontal line")
    h.eq(next(backend.container.__slots[record.modes.bar.slot_key].options.candidateFilters.includeSpellIDs), nil,
        "cooldown mode disables the inactive presentation slot")

    cfg_db.cooldown_mode_essential = false
    M.refresh_managed_cdm_backend(owner, false)
    h.eq(backend.container.__groups[record.modes.icon.group_key].active_max_frame_count, 1,
        "Aura mode enables the compact native group")
    h.eq(next(backend.container.__slots[record.modes.icon.slot_key].options.candidateFilters.includeSpellIDs), nil,
        "Aura mode disables fixed cooldown overlay slots")
    M.release_managed_aura_backend(backend)
    C_CooldownViewer = nil
end)

h.test("managed accessibility helper skips constrained AuraButtons", function()
    local M = h.addon.aura_frames
    local owner = base_create_frame("Frame", nil, UIParent)
    local backend = M.create_managed_aura_backend(owner, "test_access", "player")
    M.add_managed_aura_group(backend, "auras", "HELPFUL", {
        maxFrameCount = 2,
    })

    local buttons = backend.container.__groups.auras.buttons
    buttons[1].CanBeAccessedInContext = function() return true end
    buttons[2].CanBeAccessedInContext = function() return false end
    buttons[1].IsShown = function() error("AuraButton visibility is secret") end
    buttons[2].IsShown = function() error("AuraButton visibility is secret") end
    local visited = {}
    local all_accessible = M.for_each_accessible_managed_aura_button(backend, function(aura_button, group_key)
        visited[aura_button] = group_key
    end)

    h.eq(all_accessible, false, "helper reports a constrained button")
    h.eq(visited[buttons[1]], "auras", "accessible button visited")
    h.eq(visited[buttons[2]], nil, "constrained button skipped")

    local status = table.concat(M.get_managed_aura_status_fields(), ",")
    h.ok(status:find("managed=test_access", 1, true), "status identifies the managed backend")
    h.ok(status:find(":buttons=2:accessible=1", 1, true),
        "status distinguishes created and accessible AuraButtons")
    h.eq(status:find(":active=", 1, true), nil,
        "status never derives active state from secret AuraButton visibility")
end)

h.test("module lifecycle gates every registered managed backend", function()
    local M = h.addon.aura_frames
    local backend = M.get_managed_aura_backend("test_access")

    h.boot({})
    h.ok(backend.container:IsShown(), "enabled module keeps managed backend visible")

    h.addon.set_module_enabled("aura_frames", false)
    h.eq(backend.container:IsShown(), false, "module disable hides managed backend")

    h.addon.set_module_enabled("aura_frames", true)
    h.ok(backend.container:IsShown(), "module re-enable restores managed backend")
end)

h.test("unavailable managed API fails without creating a container", function()
    local M = h.addon.aura_frames
    local owner = base_create_frame("Frame", nil, UIParent)
    local old_get_template_info = C_XMLUtil.GetTemplateInfo
    rawset(C_XMLUtil, "GetTemplateInfo", function() return nil end)
    local before_count = #created_containers

    local backend, err = M.create_managed_aura_backend(owner, "unsupported", "player")

    rawset(C_XMLUtil, "GetTemplateInfo", old_get_template_info)
    h.eq(backend, nil, "unsupported client creates no backend")
    h.ok(type(err) == "string", "unsupported client returns an explanation")
    h.eq(#created_containers, before_count, "unsupported client creates no AuraContainer")
end)


h.run("af_managed")

--#endregion FILE CONTENTS ===================================================
