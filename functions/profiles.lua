-- Shared versioned profile storage and settings-tab UI.
-- Modules own profile contents and runtime application through factory callbacks.

local _, addon = ...

--#region PROFILE MANAGER ======================================================

local function deep_copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deep_copy(child)
    end
    return copy
end

local function trim_name(name)
    return (name or ""):match("^%s*(.-)%s*$")
end

function addon.CreateProfileManager(opts)
    opts = opts or {}
    local manager = {
        label = opts.label or "Module",
        schema_version = opts.schema_version or 1,
        get_db = opts.get_db,
        export_data = opts.export_data,
        apply_data = opts.apply_data,
        profiles_key = opts.profiles_key or "profiles",
        selected_name_key = opts.selected_name_key or "last_profile_name",
    }

    function manager:get_profiles()
        local db = self.get_db and self.get_db()
        if not db then return {} end
        db[self.profiles_key] = db[self.profiles_key] or {}
        return db[self.profiles_key]
    end

    function manager:find(name)
        name = trim_name(name)
        if name == "" then return nil, nil end
        for index, profile in ipairs(self:get_profiles()) do
            if profile.name == name then return profile, index end
        end
        return nil, nil
    end

    function manager:get_selected_name()
        local db = self.get_db and self.get_db()
        return db and db[self.selected_name_key] or nil
    end

    function manager:set_selected_name(name)
        local db = self.get_db and self.get_db()
        if db then db[self.selected_name_key] = name end
    end

    function manager:save(name, overwrite)
        name = trim_name(name)
        if name == "" then return false, "Enter a profile name." end
        if type(self.export_data) ~= "function" then return false, "Profile export is unavailable." end
        local existing, index = self:find(name)
        if existing and not overwrite then return false, "Profile already exists. Use Overwrite." end
        local profile = {
            name = name,
            version = self.schema_version,
            saved_at = date and date("%Y-%m-%d %H:%M") or nil,
            data = deep_copy(self.export_data()),
        }
        local profiles = self:get_profiles()
        if index then profiles[index] = profile else profiles[#profiles + 1] = profile end
        self:set_selected_name(name)
        return true, "Saved profile: " .. name
    end

    function manager:delete(name)
        local _, index = self:find(name)
        if not index then return false, "Profile not found." end
        local profiles = self:get_profiles()
        table.remove(profiles, index)
        if self:get_selected_name() == name then
            self:set_selected_name(profiles[1] and profiles[1].name or nil)
        end
        return true, "Deleted profile: " .. name
    end

    function manager:rename(old_name, new_name)
        local profile = self:find(old_name)
        if not profile then return false, "Profile not found." end
        new_name = trim_name(new_name)
        if new_name == "" then return false, "Enter a new profile name." end
        if new_name == profile.name then return true, "Profile name unchanged." end
        if self:find(new_name) then return false, "A profile with that name already exists." end
        profile.name = new_name
        if self:get_selected_name() == old_name then self:set_selected_name(new_name) end
        return true, "Renamed profile: " .. new_name
    end

    function manager:load(name)
        local profile = self:find(name)
        if not profile then return false, "Profile not found." end
        if InCombatLockdown and InCombatLockdown() then
            return false, "Cannot load a " .. self.label:lower() .. " profile in combat."
        end
        if type(self.apply_data) ~= "function" then return false, "Profile load is unavailable." end
        local ok, message = self.apply_data(deep_copy(profile.data), tonumber(profile.version) or 0)
        if ok then
            self:set_selected_name(profile.name)
            return true, message or ("Loaded profile: " .. profile.name)
        end
        return false, message or "Profile could not be loaded."
    end

    return manager
end

--#endregion PROFILE MANAGER ===================================================

--#region PROFILES TAB =========================================================

function addon.BuildProfilesTab(parent, manager, opts)
    opts = opts or {}
    local selected_name = manager:get_selected_name()
    local rows = {}
    local label = opts.label or manager.label

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -12)
    title:SetText(label .. " Profiles")
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    note:SetWidth(600)
    note:SetJustifyH("LEFT")
    note:SetText(opts.note or ("Profiles save this " .. label .. " setup for use on another character."))
    local name_label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name_label:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -28)
    name_label:SetText("Profile Name")
    local name_box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    name_box:SetSize(220, 22)
    name_box:SetPoint("TOPLEFT", name_label, "BOTTOMLEFT", 0, -4)
    name_box:SetAutoFocus(false)
    name_box:SetMaxLetters(32)
    name_box:SetText(selected_name or "")
    local status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", name_box, "BOTTOMLEFT", 0, -12)
    status:SetWidth(450)
    status:SetJustifyH("LEFT")
    local list_title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    list_title:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, -70)
    list_title:SetText("Saved Profiles")
    local list_box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list_box:SetPoint("TOPLEFT", list_title, "BOTTOMLEFT", 0, -8)
    list_box:SetSize(260, 260)
    addon.ApplyControlPanelBackdrop(list_box)
    local list_area = CreateFrame("Frame", nil, list_box)
    list_area:SetPoint("TOPLEFT", list_box, "TOPLEFT", 8, -8)
    list_area:SetPoint("BOTTOMRIGHT", list_box, "BOTTOMRIGHT", -8, 8)
    local function set_status(ok, message)
        status:SetText(message or "")
        status:SetTextColor(ok and 0.2 or 1, ok and 1 or 0.25, ok and 0.2 or 0.25)
    end
    local function get_name()
        return trim_name(name_box:GetText())
    end
    local function select_profile(name)
        selected_name = name
        name_box:SetText(name or "")
        manager:set_selected_name(name)
        for _, row in ipairs(rows) do
            if row._profile_name then
                local selected = row._profile_name == selected_name
                row.bg:SetShown(selected)
                row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
            end
        end
    end
    local function rebuild_list()
        for _, row in ipairs(rows) do row:Hide() end
        rows = {}
        local profiles = manager:get_profiles()
        for index, profile in ipairs(profiles) do
            local row = CreateFrame("Button", nil, list_area)
            row:SetSize(238, 20)
            row:SetPoint("TOPLEFT", list_area, "TOPLEFT", 0, -((index - 1) * 22))
            row._profile_name = profile.name
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
            row.bg:Hide()
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.text:SetText(profile.name or ("Profile " .. index))
            row:SetScript("OnClick", function() select_profile(profile.name); set_status(true, "Selected profile: " .. profile.name) end)
            rows[#rows + 1] = row
        end
        select_profile(selected_name)
    end
    local function button(text, anchor, on_click)
        local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        control:SetSize(100, 22)
        control:SetText(text)
        addon.ApplyStandardButtonStyle(control)
        control:SetPoint(unpack(anchor))
        control:SetScript("OnClick", on_click)
        return control
    end
    local function confirm(dialog_key, text, accept_text, on_accept)
        StaticPopupDialogs[dialog_key] = {
            text = text,
            button1 = accept_text,
            button2 = "Cancel",
            OnAccept = on_accept,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show(dialog_key)
    end
    local save = button("Save New", { "TOPLEFT", status, "BOTTOMLEFT", 0, -18 }, function()
        local ok, message = manager:save(get_name(), false)
        if ok then select_profile(get_name()); rebuild_list() end
        set_status(ok, message)
    end)
    button("Overwrite", { "LEFT", save, "RIGHT", 8, 0 }, function()
        local name = get_name()
        if name == "" then set_status(false, "Enter a profile name to overwrite."); return end
        confirm("LSTWEEKS_OVERWRITE_PROFILE", 'Overwrite ' .. label:lower() .. ' profile "' .. name .. '"?', "Overwrite", function()
            local ok, message = manager:save(name, true)
            if ok then select_profile(name); rebuild_list() end
            set_status(ok, message)
        end)
    end)
    local load = button("Load", { "TOPLEFT", save, "BOTTOMLEFT", 0, -8 }, function()
        local name = get_name() ~= "" and get_name() or selected_name
        local ok, message = manager:load(name)
        selected_name = manager:get_selected_name()
        name_box:SetText(selected_name or "")
        rebuild_list()
        set_status(ok, message)
    end)
    button("Rename", { "LEFT", load, "RIGHT", 8, 0 }, function()
        local ok, message = manager:rename(selected_name, get_name())
        if ok then selected_name = manager:get_selected_name(); rebuild_list() end
        set_status(ok, message)
    end)
    button("Delete", { "TOPLEFT", load, "BOTTOMLEFT", 0, -8 }, function()
        local name = get_name() ~= "" and get_name() or selected_name
        if not name or name == "" then set_status(false, "Select a profile to delete."); return end
        confirm("LSTWEEKS_DELETE_PROFILE", 'Delete ' .. label:lower() .. ' profile "' .. name .. '"?', "Delete", function()
            local ok, message = manager:delete(name)
            if ok then selected_name = manager:get_selected_name(); name_box:SetText(selected_name or ""); rebuild_list() end
            set_status(ok, message)
        end)
    end)
    rebuild_list()
    return function()
        selected_name = manager:get_selected_name()
        name_box:SetText(selected_name or "")
        rebuild_list()
    end
end

--#endregion PROFILES TAB ======================================================
