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
    FlowDirection = { Left = 1, Right = 2, Down = 3, Up = 4 },
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
        self.__groups[key].active_max_frame_count = value
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
            show_long = false,
            show_combined = true,
            move_combined = false,
            max_icons_combined = 3,
            width_combined = 140,
            bar_mode_combined = true,
            growth_combined = "DOWN",
        },
    })

    local frame = M.frames.show_debuff
    local backend = frame._managed_aura_backend

    h.ok(backend, "Debuff frame owns a managed backend")
    h.eq(backend.container.__groups["debuffs:bar"].filter_string, "HARMFUL", "Debuff groups use HARMFUL")
    h.eq(backend.container.__groups["debuffs:bar"].options.maxFrameCount, 2, "Debuff bar pool uses saved maximum")
    h.eq(backend.container.__groups["debuffs:icon"].options.maxFrameCount, 2, "Debuff icon pool uses saved maximum")
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
    h.eq(backend.container.__groups["debuffs:bar"].layout.elementSpacing, 1,
        "Debuff bar group receives explicit element spacing")
    h.eq(frame.icons, nil, "managed Debuff frame creates no legacy icon pool")
    h.ok(frame:GetScript("OnEvent"), "managed Debuff shell owns its combat-state handler")
    h.eq(frame.__events.UNIT_AURA, nil, "managed Debuff frame does not register UNIT_AURA")
    h.eq(frame.__events.PLAYER_REGEN_DISABLED, true, "managed Debuff shell watches combat entry")
    h.eq(frame.__events.PLAYER_REGEN_ENABLED, true, "managed Debuff shell watches combat exit")

    for _, aura_button in ipairs(backend.container.__groups["debuffs:bar"].buttons) do
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
    h.eq(frame.move_handle:IsShown(), false, "move controls follow saved off state")
    M.db.move_debuff = true
    M.update_managed_preset_frame(frame, "show_debuff", "move_debuff")
    h.eq(frame.move_handle:IsShown(), true, "managed Move Mode shows its mover border")
    h.eq(backend.container.__flow_padding[3], 0,
        "managed Move Mode does not alter native AuraContainer layout")
    h.eq(frame.move_handle:GetParent(), frame,
        "addon mover remains parented to its safe shell, never the managed AuraContainer")
    local _, resize_relative_to = frame.resizer:GetPoint(1)
    h.eq(resize_relative_to, frame, "managed resize grip overlays the shell border corner")
    M.db.move_debuff = false
    M.update_managed_preset_frame(frame, "show_debuff", "move_debuff")
    h.eq(frame:GetAlpha(), 0.35, "managed Debuff shell applies its saved out-of-combat alpha")
    h.fire_event("PLAYER_REGEN_DISABLED")
    h.eq(frame:GetAlpha(), 1, "combat-entry event makes the managed Debuff shell fully visible")
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.eq(frame:GetAlpha(), 0.35, "combat-exit event restores the managed Debuff shell OOC alpha")

    local long_frame = M.frames.show_long
    h.eq(long_frame._managed_aura_backend, nil, "Long remains separate from the combined managed capability")
    h.ok(long_frame.icons, "Long retains its existing frame implementation")
    h.eq(long_frame.__events.UNIT_AURA, true, "Long retains its existing event route while disabled")

    local buffs_frame = M.frames.show_combined
    local buffs_backend = buffs_frame._managed_aura_backend
    h.ok(buffs_backend, "combined Buffs frame owns a managed backend")
    h.eq(buffs_backend.container.__groups["buffs:bar"].filter_string, "HELPFUL",
        "combined Buff groups request every helpful Aura")
    h.eq(buffs_backend.container.__groups["buffs:bar"].options.maxFrameCount, 3,
        "combined Buff bar pool uses its own saved maximum")
    h.eq(buffs_backend.container.__groups["buffs:icon"].options.maxFrameCount, 3,
        "combined Buff icon pool uses its own saved maximum")
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "bar-mode combined Buffs use vertical flow")
    h.eq(buffs_frame.icons, nil, "combined Buffs frame creates no legacy icon pool")
    h.eq(buffs_frame.__events.UNIT_AURA, nil, "combined Buffs frame does not register UNIT_AURA")
    h.ok(buffs_frame:IsShown(), "runtime startup shows enabled combined Buffs")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:bar"].buttons) do
        h.eq(aura_button.__width, 128, "combined Buff bars use the saved inner frame width")
        h.eq(aura_button.__height, 18, "combined Buff bars use the shared native row height")
        h.eq(#(aura_button:GetCalls("SetIcon") or {}), 1,
            "combined Buffs AuraButtons bind their native icon")
        h.ok(aura_button.__spell_name_region, "combined Buff bars bind native spell text")
        h.ok(aura_button.__duration_text_region, "combined Buff bars bind native duration text")
        h.ok(aura_button.__application_count_region, "combined Buff bars bind native stack text")
        h.ok(aura_button.__duration_bar_region, "combined Buff bars bind a native duration bar")
        h.eq(aura_button.__hide_tooltip_in_combat, true,
            "combined Buffs AuraButtons use the combat-safe native tooltip policy")
    end
    h.eq(buffs_backend.presentation_mode, "bar", "saved Bar Mode activates the combined Buff bar group")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, 3,
        "combined Buff bar group is active")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, 0,
        "combined Buff icon group is parked")

    M.db.bar_mode_combined = false
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    h.eq(buffs_backend.presentation_mode, "icon", "OOC Bar Mode change activates icon presentation")
    h.eq(buffs_backend.container.__groups["buffs:bar"].active_max_frame_count, 0,
        "combined Buff bar group is parked after switching")
    h.eq(buffs_backend.container.__groups["buffs:icon"].active_max_frame_count, 3,
        "combined Buff icon group activates after switching")
    h.ok(buffs_backend.duration_font,
        "combined Buff managed presentations share an addon-owned duration font")
    for _, aura_button in ipairs(buffs_backend.container.__groups["buffs:icon"].buttons) do
        h.eq(aura_button.__height, 46,
            "combined Buff icon cells reserve a row below the icon for duration text")
        h.ok(aura_button.__duration_text_region,
            "combined Buff icons bind native duration text")
        h.eq(aura_button.__duration_text_region.__points[1][1], "TOP",
            "combined Buff icon duration text anchors below the icon")
        h.eq(aura_button.__duration_text_region:GetFontObject(), buffs_backend.duration_font,
            "combined Buff icon duration text uses the managed duration font")
        h.ok(aura_button.__application_count_region,
            "combined Buff icons bind native stack text")
        h.eq(aura_button.__application_count_region.__points[1][1], "BOTTOMRIGHT",
            "combined Buff icon stack text remains anchored to the icon")
    end
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "combined Buff layout retains the saved DOWN growth after switching to icons")
    h.eq(M.get_managed_aura_backend("preset:combined"), buffs_backend,
        "Bar Mode switching reuses the original managed backend")

    M.db.timer_combined = false
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    h.eq(buffs_backend.container.__groups["buffs:icon"].layout.elementHeight, 32,
        "disabling managed icon timer text removes its layout row")
    h.eq(buffs_backend.duration_font:GetLastCall("SetTextColor")[4], 0,
        "disabling managed timer text hides the shared duration font")

    M.db.timer_combined = true
    M.db.timer_number_font_size_combined = 14
    M.db.timer_number_font_bold_combined = true
    M.db.timer_color_combined = { r = 0.2, g = 0.3, b = 0.4 }
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    local font_call = buffs_backend.duration_font:GetLastCall("SetFont")
    local color_call = buffs_backend.duration_font:GetLastCall("SetTextColor")
    h.eq(font_call[1], M.NUMBER_FONT_BOLD_PATHS[M.DEFAULT_TIMER_NUMBER_FONT_KEY],
        "managed timer font applies the saved bold face")
    h.eq(font_call[2], 14, "managed timer font applies the saved size")
    h.eq(color_call[1], 0.2, "managed timer font applies the saved red component")
    h.eq(color_call[2], 0.3, "managed timer font applies the saved green component")
    h.eq(color_call[3], 0.4, "managed timer font applies the saved blue component")
    h.eq(color_call[4], 1, "enabling managed timer text restores its opacity")

    local growth_cases = {
        RIGHT = { AnchorUtil.FlowLayoutAxis.Horizontal, "TOPLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down },
        LEFT = { AnchorUtil.FlowLayoutAxis.Horizontal, "TOPRIGHT", AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down },
        DOWN = { AnchorUtil.FlowLayoutAxis.Vertical, "TOPLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down },
        UP = { AnchorUtil.FlowLayoutAxis.Vertical, "BOTTOMLEFT", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up },
    }
    for growth, expected in pairs(growth_cases) do
        M.db.growth_combined = growth
        M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
            "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
        h.eq(buffs_backend.container.__flow_axis, expected[1], growth .. " uses its canonical flow axis")
        h.eq(buffs_backend.container.__flow_anchor, expected[2], growth .. " uses its canonical anchor")
        h.eq(buffs_backend.container.__flow_growth[1], expected[3], growth .. " uses its horizontal direction")
        h.eq(buffs_backend.container.__flow_growth[2], expected[4], growth .. " uses its vertical direction")
    end

    M.db.bar_mode_combined = true
    M.db.growth_combined = "LEFT"
    M.update_auras(buffs_frame, "show_combined", "move_combined", "timer_combined",
        "bg_combined", "scale_combined", "spacing_combined", "HELPFUL")
    h.eq(buffs_backend.presentation_mode, "bar", "combined Buffs return to bar presentation")
    h.eq(buffs_backend.container.__flow_axis, AnchorUtil.FlowLayoutAxis.Vertical,
        "horizontal saved growth normalizes to vertical flow in Bar Mode")
    h.eq(buffs_backend.container.__flow_anchor, "TOPLEFT",
        "horizontal saved growth falls back to the DOWN bar anchor")
    h.eq(buffs_backend.container.__flow_growth[2], AnchorUtil.FlowDirection.Down,
        "horizontal saved growth falls back to DOWN bar growth")
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
