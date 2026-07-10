-- Objectives settings tab host.
local _, addon = ...
addon.objectives = addon.objectives or {}
local M = addon.objectives

--#region SETTINGS CONSTRUCTION ================================================

function M.BuildSettings(parent)
    local db, tabs, panels = M.get_db(), {}, {}
    local definitions = {
        { label = "General", builder = M.BuildGeneralTab },
        { label = "Tracker", builder = function(panel)
            M.BuildPositionSettings(panel)
            M.BuildBackgroundSettings(panel)
            M.BuildAutoCollapseSettings(panel)
            M.BuildSectionCountSettings(panel)
        end },
        { label = "Profiles", builder = M.BuildProfilesTab },
    }
    local selected_index = math.max(1, math.min(#definitions, tonumber(db.last_tab_index) or 1))
    local function select_tab(index)
        selected_index = definitions[index] and index or 1
        db.last_tab_index = selected_index
        for i, panel in ipairs(panels) do
            panel:SetShown(i == selected_index)
            if i == selected_index then PanelTemplates_SelectTab(tabs[i]) else PanelTemplates_DeselectTab(tabs[i]) end
        end
    end
    for i, definition in ipairs(definitions) do
        local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(definition.label)
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i - 1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and 20 or 5, -12)
        PanelTemplates_TabResize(tab, 0)
        tabs[i] = tab
        local panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -48)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        panels[i] = panel
        definition.builder(panel)
        tab:SetScript("OnClick", function(self) select_tab(self:GetID()) end)
    end
    PanelTemplates_SetNumTabs(parent, #definitions)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

--#endregion SETTINGS CONSTRUCTION =============================================
