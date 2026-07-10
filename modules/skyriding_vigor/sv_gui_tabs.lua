-- Skyriding Vigor settings tabs.
local _, addon = ...
local M = addon.skyriding_vigor
--#region TABS =================================================================
function M.BuildSettings(parent)
    local db, tabs, panels = M.get_root_db(), {}, {}
    local defs = {
        { label = "General", build = function(panel)
            local reset = addon.CreateModuleReset(panel, M.get_root_db(), M.DEFAULTS, {
                preserve_label = "Keep Profiles",
                preserve_default = true,
                preserve_keys = { "profiles", "last_profile_name" },
                before_reset = function()
                    return not (M.is_settings_locked_by_flight and M.is_settings_locked_by_flight())
                end,
                after_reset = M.on_reset_complete,
            })
            reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
        end },
        { label = "Vigor Bar", build = M.BuildVigorTab },
        { label = "Profiles", build = function(panel) M.refresh_profiles_tab = addon.BuildProfilesTab(panel, M.profile_manager, { label = "Skyriding Vigor" }) end },
    }
    local selected = math.max(1, math.min(#defs, tonumber(db.last_tab_index) or 1))
    local function select_tab(index) selected = index; db.last_tab_index = index for i, panel in ipairs(panels) do panel:SetShown(i == index); if i == index then PanelTemplates_SelectTab(tabs[i]) else PanelTemplates_DeselectTab(tabs[i]) end end end
    for i, def in ipairs(defs) do local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate"); tab:SetID(i); tab:SetText(def.label); tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i - 1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and 20 or 5, -12); PanelTemplates_TabResize(tab, 0); tabs[i] = tab; local panel = CreateFrame("Frame", nil, parent); panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -48); panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0); panels[i] = panel; def.build(panel); tab:SetScript("OnClick", function(self) select_tab(self:GetID()) end) end
    PanelTemplates_SetNumTabs(parent, #defs); select_tab(selected); PanelTemplates_UpdateTabs(parent)
end
--#endregion TABS ==============================================================
