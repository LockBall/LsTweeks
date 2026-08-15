-- Aura Frames managed AuraContainer framework tests. Runs under desktop Lua 5.1
-- against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local base_create_frame = CreateFrame
local created_containers = {}

C_XMLUtil = {
    GetTemplateInfo = function(template)
        if template == "CustomAuraContainerTemplate" then return {} end
    end,
}

AnchorUtil = {
    FlowLayoutAxis = { Horizontal = 1, Vertical = 2 },
    FlowDirection = { Right = 2, Down = 3, Up = 4 },
}

CreateFrame = function(kind, name, parent, template)
    local frame = base_create_frame(kind, name, parent, template)
    if kind ~= "AuraContainer" then return frame end

    frame.__groups = {}
    frame.__group_calls = {}

    function frame:SetUnit(unit)
        self.__unit = unit
    end

    function frame:SetEnabled(enabled)
        self.__engine_enabled = enabled == true
    end

    function frame:IsEnabled()
        return self.__engine_enabled == true
    end

    function frame:SetFlowLayoutPadding(left, right, top, bottom)
        self.__flow_padding = { left, right, top, bottom }
    end

    function frame:SetFlowLayoutAxis(axis)
        self.__flow_axis = axis
    end

    function frame:SetFlowLayoutAnchorPoint(point)
        self.__flow_anchor = point
    end

    function frame:SetFlowLayoutGrowthDirection(horizontal, vertical)
        self.__flow_growth = { horizontal, vertical }
    end

    function frame:SetFlowLayoutMaximumLineSize(size)
        self.__flow_line_size = size
    end

    function frame:AddAuraGroup(key, filter_string, options)
        local group = {
            key = key,
            filter_string = filter_string,
            options = options,
            buttons = {},
        }
        self.__groups[key] = group

        for index = 1, options.maxFrameCount do
            local aura_button = base_create_frame("AuraButton", nil, self, "CustomAuraButtonTemplate")
            function aura_button:SetHideTooltipInCombat(enabled)
                self.__hide_tooltip_in_combat = enabled == true
            end
            function aura_button:SetSpellName(region)
                self.__spell_name_region = region
            end
            function aura_button:SetDurationText(region, binding_options)
                self.__duration_text_region = region
                self.__duration_text_options = binding_options
            end
            function aura_button:SetApplicationCount(region, binding_options)
                self.__application_count_region = region
                self.__application_count_options = binding_options
            end
            function aura_button:SetDurationBar(region, binding_options)
                self.__duration_bar_region = region
                self.__duration_bar_options = binding_options
            end
            aura_button.__managed_group_key = key
            options.initializeFrame(aura_button)
            aura_button.__access_constrained = true
            group.buttons[index] = aura_button
        end
    end

    function frame:SetAuraGroupLayout(key, layout)
        self.__groups[key].layout = layout
    end

    function frame:SetAuraGroupFilter(key, value)
        self.__group_calls[#self.__group_calls + 1] = { "filter", key, value }
    end

    function frame:SetAuraGroupCandidateFilters(key, value)
        self.__group_calls[#self.__group_calls + 1] = { "candidate_filters", key, value }
    end

    function frame:SetAuraGroupMaxFrameCount(key, value)
        self.__group_calls[#self.__group_calls + 1] = { "max_frame_count", key, value }
    end

    function frame:SetAuraGroupSortMethod(key, method, direction)
        self.__group_calls[#self.__group_calls + 1] = { "sort", key, method, direction }
    end

    created_containers[#created_containers + 1] = frame
    return frame
end

h.load_addon()

h.test("Debuff preset uses one managed HARMFUL group and no legacy Aura events", function()
    local M = h.addon.aura_frames
    h.boot({
        aura_frames = {
            show_debuff = true,
            move_debuff = false,
            max_icons_debuff = 2,
            width_debuff = 120,
            bar_mode_debuff = true,
            growth_debuff = "UP",
            fade_ooc_debuff = true,
            ooc_alpha_debuff = 0.35,
            fade_delay_debuff = 0,
            fade_length_debuff = 0,
        },
    })

    local frame = M.frames.show_debuff
    local backend = frame._managed_aura_backend

    h.ok(backend, "Debuff frame owns a managed backend")
    h.eq(backend.container.__groups.debuffs.filter_string, "HARMFUL", "Debuff group uses HARMFUL")
    h.eq(backend.container.__groups.debuffs.options.maxFrameCount, 2, "Debuff pool uses saved maximum")
    h.eq(backend.container.__width, 1, "managed container starts at its auto-layout seed width")
    h.eq(backend.container.__height, 1, "managed container starts at its auto-layout seed height")
    h.eq(backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "bar-mode Debuffs lay out vertically")
    h.eq(backend.container.__flow_anchor, "BOTTOMLEFT", "upward Debuff flow starts at the bottom corner")
    h.eq(backend.container.__flow_growth[1], AnchorUtil.FlowDirection.Right,
        "additional Debuff columns grow right")
    h.eq(backend.container.__flow_growth[2], AnchorUtil.FlowDirection.Up,
        "Debuff rows grow up")
    h.eq(backend.container.__flow_line_size, 38, "Debuff flow reserves one vertical line for every row")
    h.eq(backend.container.__groups.debuffs.layout.elementSpacing, 1,
        "Debuff group receives explicit element spacing")
    h.eq(frame.icons, nil, "managed Debuff frame creates no legacy icon pool")
    h.ok(frame:GetScript("OnEvent"), "managed Debuff shell owns its combat-state handler")
    h.eq(frame.__events.UNIT_AURA, nil, "managed Debuff frame does not register UNIT_AURA")
    h.eq(frame.__events.PLAYER_REGEN_DISABLED, true, "managed Debuff shell watches combat entry")
    h.eq(frame.__events.PLAYER_REGEN_ENABLED, true, "managed Debuff shell watches combat exit")

    for _, aura_button in ipairs(backend.container.__groups.debuffs.buttons) do
        h.eq(aura_button.__width, 108, "managed Debuff bar uses the saved inner frame width")
        h.eq(aura_button.__height, 18, "managed Debuff bar uses the legacy row height")
        h.eq(#(aura_button:GetCalls("SetIcon") or {}), 1, "managed Debuff AuraButton binds one native icon")
        h.ok(aura_button.__spell_name_region, "managed Debuff AuraButton binds native spell text")
        h.ok(aura_button.__duration_text_region, "managed Debuff AuraButton binds native duration text")
        h.ok(aura_button.__application_count_region, "managed Debuff AuraButton binds native stack text")
        h.ok(aura_button.__duration_bar_region, "managed Debuff AuraButton binds a native duration bar")
        h.eq(aura_button.__mouse_motion_enabled, true, "managed Debuff AuraButton enables native hover")
        h.eq(aura_button.__hide_tooltip_in_combat, true,
            "managed Debuff AuraButton hides its native tooltip in combat")
    end

    h.ok(frame:IsShown(), "runtime startup shows the enabled managed Debuff shell")
    h.eq(frame.title_bar:IsShown(), false, "move controls follow saved off state")
    h.eq(frame:GetAlpha(), 0.35, "managed Debuff shell applies its saved out-of-combat alpha")
    h.fire_event("PLAYER_REGEN_DISABLED")
    h.eq(frame:GetAlpha(), 1, "combat-entry event makes the managed Debuff shell fully visible")
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.eq(frame:GetAlpha(), 0.35, "combat-exit event restores the managed Debuff shell OOC alpha")
    M.set_managed_aura_runtime_enabled(false)
end)

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
