-- Shared managed AuraContainer test fixture for isolated suite processes.
---@diagnostic disable: undefined-global

local h = require("harness")

--#region MANAGED AURA TEST FIXTURE ===========================================

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

AuraContainerSortMethod = { ExpirationOnly = 5 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }

CreateFrame = function(kind, name, parent, template)
    local frame = base_create_frame(kind, name, parent, template)
    if kind ~= "AuraContainer" then return frame end

    frame.__groups = {}
    frame.__slots = {}
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
            function aura_button:SetCancelAuraButtons(buttons)
                self.__cancel_aura_buttons = buttons
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

    function frame:AddAuraSlot(key, filter_string, options)
        local aura_button = base_create_frame("AuraButton", nil, self, "CustomAuraButtonTemplate")
        function aura_button:SetHideTooltipInCombat(enabled)
            self.__hide_tooltip_in_combat = enabled == true
        end
        function aura_button:SetCancelAuraButtons(buttons)
            self.__cancel_aura_buttons = buttons
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
        local slot = {
            key = key,
            filter_string = filter_string,
            options = options,
            button = aura_button,
        }
        self.__slots[key] = slot
        options.initializeFrame(aura_button)
        aura_button.__access_constrained = true
        return aura_button
    end

    function frame:SetAuraGroupLayout(key, layout)
        self.__groups[key].layout = layout
    end

    function frame:SetAuraGroupFilter(key, value)
        self.__group_calls[#self.__group_calls + 1] = { "filter", key, value }
    end

    function frame:SetAuraGroupCandidateFilters(key, value)
        self.__groups[key].options.candidateFilters = value
        self.__group_calls[#self.__group_calls + 1] = { "candidate_filters", key, value }
    end

    function frame:SetAuraGroupMaxFrameCount(key, value)
        self.__groups[key].active_max_frame_count = value
        self.__group_calls[#self.__group_calls + 1] = { "max_frame_count", key, value }
    end

    function frame:SetAuraGroupSortMethod(key, method, direction)
        self.__group_calls[#self.__group_calls + 1] = { "sort", key, method, direction }
    end


    function frame:SetAuraSlotCandidateFilters(key, value)
        self.__slots[key].options.candidateFilters = value
    end

    created_containers[#created_containers + 1] = frame
    return frame
end

h.load_addon()
local function boot_managed_presets()
    local M = h.addon.aura_frames
    h.boot({
        aura_frames = {
            short_threshold = 300,
            learned_helpful_durations = {
                [9001] = 0,
                [9002] = 600,
                [9003] = 120,
            },
            show_short = true,
            move_short = false,
            width_short = 145,
            bar_mode_short = true,
            growth_icon_short = "DOWN",
            growth_bar_short = "DOWN",
            show_debuff = true,
            move_debuff = false,
            width_debuff = 120,
            bar_mode_debuff = true,
            growth_icon_debuff = "UP",
            growth_bar_debuff = "UP",
            fade_ooc_debuff = true,
            ooc_alpha_debuff = 0.35,
            fade_delay_debuff = 0,
            fade_length_debuff = 0,
            bg_debuff = true,
            bg_color_debuff = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 },
            show_static_long = true,
            move_static_long = false,
            width_static_long = 140,
            bar_mode_static_long = true,
            growth_icon_static_long = "DOWN",
            growth_bar_static_long = "DOWN",
            fade_ooc_static_long = true,
            ooc_alpha_static_long = 0.25,
            fade_delay_static_long = 0,
            fade_length_static_long = 0,
            bg_static_long = true,
            bg_color_static_long = { r = 0.4, g = 0.3, b = 0.2, a = 0.1 },
            show_timed = true,
            move_timed = false,
            width_timed = 150,
            bar_mode_timed = true,
            growth_icon_timed = "DOWN",
            growth_bar_timed = "DOWN",
        },
    })
    return M
end

return {
    h = h,
    base_create_frame = base_create_frame,
    created_containers = created_containers,
    boot_managed_presets = boot_managed_presets,
}

--#endregion MANAGED AURA TEST FIXTURE ========================================
