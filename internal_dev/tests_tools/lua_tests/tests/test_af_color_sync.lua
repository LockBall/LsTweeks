-- Aura Frames ownership tests for shared background color controls.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon()
h.boot({})

local addon = h.addon
local M = addon.aura_frames
local color_sync = addon.all_the_colors

---@class TestButton : Button
---@field __kind string

---@class TestFontString : FontString

local function find_button(frame, text)
    if frame and frame.__kind == "Button" and frame:GetText() == text then return frame end
    for _, child in ipairs({ frame:GetChildren() }) do
        local match = find_button(child, text)
        if match then return match end
    end
end

local function click_open_dropdown_option(text)
    for _, popup in ipairs({ UIParent:GetChildren() }) do
        if popup:IsShown() then
            for _, row in ipairs({ popup:GetChildren() }) do
                ---@cast row TestButton
                if row.__kind == "Button" then
                    for _, region in ipairs({ row:GetRegions() }) do
                        ---@cast region TestFontString
                        if region:GetText() == text then
                            row:Click()
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

h.test("Shared BG Colors tab owns the Aura frame participation matrix", function()
    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(925, 700)
    M.db.last_frames_node = "static_long"
    M.db.bar_mode_static_long = false
    M.db.growth_icon_static_long = "LEFT"
    M.db.growth_bar_static_long = "UP"
    M.BuildSettings(parent)

    h.ok(M.controls.clear_learned_buffs,
        "Static / Long Buffs exposes the learned-duration cache control")
    h.is_nil(M.controls.test_aura_static_long,
        "managed Static / Long Buffs omits the unsupported Test Aura control")

    h.eq(addon.DEFAULT_FADE_ALPHA, 0.50,
        "one shared Fade Alpha constant owns every module default")
    h.eq(addon.player_frame.FADE_DEFAULTS.fade_alpha, addon.DEFAULT_FADE_ALPHA,
        "Player Frame uses the shared Fade Alpha default")
    h.eq(addon.module_defaults.sv.skyriding_vigor.fade_alpha, addon.DEFAULT_FADE_ALPHA,
        "Skyriding Vigor uses the shared Fade Alpha default")
    h.eq(addon.module_defaults.sv.skyriding_vigor.race_profile.fade_alpha, addon.DEFAULT_FADE_ALPHA,
        "new Skyriding race profiles use the shared Fade Alpha default")
    for _, category in ipairs(M.CATEGORIES) do
        h.eq(M.defaults["ooc_alpha_" .. category], addon.DEFAULT_FADE_ALPHA,
            category .. " reset uses the shared Fade Alpha default")
    end
    local new_custom_entry = M.new_custom_entry("custom_default_alpha", "Default Alpha")
    h.eq(new_custom_entry.ooc_alpha, addon.DEFAULT_FADE_ALPHA,
        "new custom frames use the shared Fade Alpha default")

    local move_control = M.controls.move_static_long
    h.ok(move_control.checkbox:GetScript("OnEnter"),
        "Move Mode checkbox exposes its OOC fade behavior")
    move_control.checkbox:GetScript("OnEnter")(move_control.checkbox)
    h.eq(addon.GetOwnedTooltip().lines[1]:GetText(), "Disables OOC Fade",
        "Move Mode tooltip explains that it disables OOC Fade")
    move_control.checkbox:GetScript("OnLeave")(move_control.checkbox)

    local frame_bg_control = M.controls.bg_static_long
    M.db.move_static_long = false
    M.db.bg_static_long = false
    M.db.move_bg_opt_out_static_long = false
    move_control:SetCheckedSilently(false)
    frame_bg_control:SetCheckedSilently(false)

    move_control.checkbox:SetChecked(true)
    move_control.checkbox:Click()
    h.eq(M.db.bg_static_long, true, "entering Move Mode enables Frame BG")
    h.eq(frame_bg_control:GetChecked(), true, "Move Mode syncs the Frame BG checkbox")

    frame_bg_control.checkbox:SetChecked(false)
    frame_bg_control.checkbox:Click()
    h.eq(M.db.move_bg_opt_out_static_long, true, "manually disabling Frame BG records the opt-out")

    move_control.checkbox:SetChecked(false)
    move_control.checkbox:Click()
    move_control.checkbox:SetChecked(true)
    move_control.checkbox:Click()
    h.eq(M.db.bg_static_long, false, "Move Mode respects the saved Frame BG opt-out")

    frame_bg_control.checkbox:SetChecked(true)
    frame_bg_control.checkbox:Click()
    h.eq(M.db.move_bg_opt_out_static_long, false, "manually enabling Frame BG clears the opt-out")

    M.db.move_static_long = false
    M.db.bg_static_long = false
    M.db.move_bg_opt_out_static_long = false
    move_control:SetCheckedSilently(false)
    frame_bg_control:SetCheckedSilently(false)

    local bar_mode = M.controls.bar_mode_static_long
    local growth = M.controls.growth_dropdown_static_long
    local _, growth_anchor = growth:GetPoint(1)
    h.eq(growth_anchor, M.controls.tooltip_static_long,
        "Growth Direction is grouped in the first control column")
    h.eq(growth:GetValue(), "LEFT", "Static / Long Buffs opens with its saved Icon Mode growth")
    bar_mode.checkbox:SetChecked(true)
    bar_mode.checkbox:Click()
    h.eq(growth:GetValue(), "UP", "Bar Mode restores its independent growth")
    h.eq(M.db.growth_icon_static_long, "LEFT", "Bar Mode does not overwrite Icon Mode growth")
    bar_mode.checkbox:SetChecked(false)
    bar_mode.checkbox:Click()
    h.eq(growth:GetValue(), "LEFT", "Icon Mode restores its prior growth after toggling")

    local timer_font = M.controls.timer_number_font_dropdown_static_long
    local timer_bold = M.controls.timer_number_font_bold_static_long
    h.eq(timer_font:GetValue(), M.DEFAULT_AURA_FONT_KEY,
        "Aura timer fonts default to Game Default")
    h.ok(not timer_bold.checkbox:IsEnabled(),
        "Game Default initially disables its unavailable Bold option")
    timer_font.button:Click()
    h.ok(click_open_dropdown_option("Game Default"), "Game Default timer font option is selectable")
    h.eq(timer_font.button:GetFontString():GetFontObject(), GameFontNormalSmall,
        "Game Default timer selector previews Blizzard GameFontNormalSmall")
    h.ok(not timer_bold.checkbox:IsEnabled(), "Game Default greys and disables the unavailable Bold option")
    timer_font.button:Click()
    h.ok(click_open_dropdown_option("Source Code Pro"), "Source Code Pro timer font option is selectable")
    h.ok(timer_bold.checkbox:IsEnabled(), "selecting a font with a bold face re-enables Bold")

    local stack_font = M.controls.stack_number_font_dropdown_static_long
    stack_font.button:Click()
    h.ok(click_open_dropdown_option("Game Default"), "Game Default stack font option is selectable")
    h.eq(stack_font.button:GetFontString():GetFontObject(), NumberFontNormal,
        "Game Default stack selector previews Blizzard NumberFontNormal")

    h.ok(M.controls.background_color_sync_frame_picker, "frame background picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_bar_picker, "bar background picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_buff_bar_picker, "Buff bar picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_debuff_bar_picker, "Debuff bar picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_bar_text_picker, "Bar Text picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_timer_text_picker, "Timer Text picker is on Shared BG Colors")
    h.ok(M.controls.background_color_sync_enabled, "shared color section exposes its enable checkbox")
    h.ok(M.controls.background_color_sync_disable_ooc_fade, "shared tab exposes the linked global fade policy")
    h.ok(M.controls.background_color_sync_test_auras, "shared tab exposes global test Auras")
    h.ok(M.controls.background_color_sync_test_auras_play_pause, "shared tab exposes global test Aura playback")
    h.eq(M.db.shared_background_color_enabled, false, "shared color defaults disabled")
    h.ok(M.shared_background_color_group, "tab exposes shared color controls")
    h.ok(M.background_color_matrix_group, "tab exposes the participation matrix")
    h.eq(M.shared_background_color_group:GetWidth(), 700, "shared color section fits all four columns")
    h.eq(
        M.background_color_matrix_group:GetParent(),
        M.shared_background_color_group,
        "participation matrix shares the color section"
    )

    local background_control = M.controls["background_color_sync:bg:static_long"]
    local bar_color_control = M.controls["bar_color_sync:static_long"]
    local text_color_control = M.controls["text_color_sync:static_long"]
    h.ok(background_control, "selected Aura frame exposes one BG Colors participation control")
    h.ok(bar_color_control, "selected Aura frame exposes bar color participation")
    h.ok(text_color_control, "selected Aura frame exposes text color participation")
    h.ok(not background_control.checkbox:IsEnabled(), "disabled shared color makes participation inactive")
    h.ok(not bar_color_control.checkbox:IsEnabled(), "disabled shared color makes bar color participation inactive")
    h.ok(not text_color_control.checkbox:IsEnabled(), "disabled shared color makes text participation inactive")

    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    h.eq(M.db.sync_bar_bg_static_long, true, "BG Colors starts selected in Aura DB")
    h.eq(M.db.sync_bar_color_static_long, true, "bar color starts selected in Aura DB")
    h.eq(M.db.sync_text_color_static_long, true, "text colors start selected in Aura DB")
    h.eq(M.defaults.shared_buff_bar_color.r, M.defaults.color_static_long.r,
        "shared Buff bar uses the Buff bar default")
    h.eq(M.defaults.shared_debuff_bar_color.r, M.defaults.color_debuff.r,
        "shared Debuff bar uses the Debuff bar default")
    h.eq(M.defaults.shared_bar_background_color.r, 0.5, "shared Bar BG defaults to #808080")
    h.eq(M.defaults.shared_bar_background_color.a, 0.5, "shared Bar BG defaults to 50% alpha")

    local refresh_calls = 0
    local original_refresh = M.on_shared_color_changed
    M.on_shared_color_changed = function()
        refresh_calls = refresh_calls + 1
    end
    M.db.shared_bar_background_color = { r = 1, g = 1, b = 1, a = 1 }
    local bar_bg_reset = find_button(M.controls.background_color_sync_bar_picker, "Reset")
    h.ok(bar_bg_reset, "Bar BG picker exposes its reset button")
    bar_bg_reset:Click()
    h.eq(refresh_calls, 1, "Bar BG picker directly refreshes Aura Frames")
    h.eq(M.db.shared_bar_background_color.r, M.defaults.shared_bar_background_color.r,
        "Bar BG picker writes the Aura-owned color")
    M.on_shared_color_changed = original_refresh

    color_sync.set_disable_ooc_fade(false)
    M.sync_background_color_controls()
    local fade_control = M.controls.background_color_sync_disable_ooc_fade
    h.eq(fade_control:GetChecked(), false, "linked fade control reads Background Colors state")
    fade_control:SetChecked(true)
    fade_control.checkbox:Click()
    h.eq(color_sync.get_disable_ooc_fade(), true, "linked fade control writes Background Colors state")

    local colors_parent = CreateFrame("Frame", nil, UIParent)
    colors_parent:SetSize(925, 700)
    color_sync.BuildSettings(colors_parent)
    color_sync.sync_controls()
    local global_fade_control = color_sync.controls.global_disable_ooc_fade
    h.eq(global_fade_control:GetChecked(), true, "All the Colors reflects the shared disabled-fade policy")

    local static_long_fade_control = M.controls.fade_ooc_static_long
    static_long_fade_control:SetChecked(true)
    static_long_fade_control.checkbox:Click()
    h.eq(M.db.fade_ooc_static_long, true, "Static / Long Buffs stores its local Fade OOC selection")
    h.eq(color_sync.get_disable_ooc_fade(), false,
        "enabling a local Fade OOC clears the global disable policy")
    h.eq(fade_control:GetChecked(), false,
        "enabling a local Fade OOC unchecks the linked Aura Frames control")
    h.eq(global_fade_control:GetChecked(), false,
        "enabling a local Fade OOC unchecks the All the Colors control")

    M.controls.background_color_sync_enabled:SetChecked(true)
    M.controls.background_color_sync_enabled.checkbox:Click()
    h.ok(background_control.checkbox:IsEnabled(), "enabling shared color activates participation")
    h.ok(bar_color_control.checkbox:IsEnabled(), "enabling shared color activates bar color participation")
    h.ok(text_color_control.checkbox:IsEnabled(), "enabling shared color activates text participation")

    background_control:SetChecked(false)
    background_control.checkbox:Click()
    bar_color_control:SetChecked(false)
    bar_color_control.checkbox:Click()
    text_color_control:SetChecked(false)
    text_color_control.checkbox:Click()
    h.eq(M.db.sync_bar_bg_static_long, false, "BG Colors control updates Aura-owned participation")
    h.eq(M.db.sync_bar_color_static_long, false, "bar color control updates Aura-owned participation")
    h.eq(M.db.sync_text_color_static_long, false, "text color control updates Aura-owned participation")

    consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    color_sync.get_db().global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.debuffs, true)
    M.sync_background_color_controls()
    h.ok(
        not M.controls.background_color_sync_enabled.checkbox:IsEnabled(),
        "global color disables Aura-specific shared controls"
    )
    h.ok(fade_control.checkbox:IsEnabled(), "global color does not disable its linked global fade control")
    color_sync.get_db().global_enabled = false
    color_sync.set_disable_ooc_fade(false)
    M.sync_background_color_controls()
end)

h.test("shared color matrix tracks custom frame lifecycle", function()
    local entry = M.spawn_custom_frame()
    h.ok(entry and entry.id, "custom frame created")
    h.ok(M.controls["background_color_sync:bg:" .. entry.id], "custom backgrounds join the matrix")
    h.ok(M.controls["bar_color_sync:" .. entry.id], "custom bar color joins the matrix")
    h.ok(M.controls["text_color_sync:" .. entry.id], "custom text colors join the matrix")

    M.destroy_custom_frame(entry.id)
    h.is_nil(M.controls["background_color_sync:bg:" .. entry.id], "deleted custom backgrounds leave the matrix")
    h.is_nil(M.controls["bar_color_sync:" .. entry.id], "deleted custom bar color leaves the matrix")
    h.is_nil(M.controls["text_color_sync:" .. entry.id], "deleted custom text colors leave the matrix")
end)

h.test("Aura Frames resolves shared color before the global override", function()
    local db = color_sync.get_db()
    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    local local_color = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    M.db.shared_frame_background_color = { r = 0.5, g = 0.6, b = 0.7, a = 0.8 }
    M.db.shared_bar_background_color = { r = 0.8, g = 0.7, b = 0.6, a = 0.5 }
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_bg_static_long = true
    db.global_enabled = false

    local resolved, source = M.resolve_background_color("static_long", "frame", local_color)
    h.eq(resolved, M.db.shared_frame_background_color, "selected target uses Aura-owned shared frame color")
    h.eq(source, "local", "Background Colors reports no global override")

    M.db.sync_bar_bg_static_long = false
    resolved = M.resolve_background_color("static_long", "bar", local_color)
    h.eq(resolved, local_color, "deselected BG Colors keeps the local bar background")
    resolved = M.resolve_background_color("static_long", "frame", local_color)
    h.eq(resolved, local_color, "deselected BG Colors keeps the local frame background")
    M.db.sync_bar_bg_static_long = true
    resolved = M.resolve_background_color("static_long", "bar", local_color)
    h.eq(resolved, M.db.shared_bar_background_color, "selected bar target uses its independent shared color")

    h.eq(
        M.resolve_background_visibility("static_long", "frame", false),
        true,
        "selected shared frame background becomes visible even when its local background is off"
    )

    db.global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    resolved, source = M.resolve_background_color("static_long", "frame", local_color)
    h.eq(resolved, db.global_color, "global color overrides selected Aura target")
    h.eq(source, "global", "global source reported")
    resolved = M.resolve_background_color("static_long", "bar", local_color)
    h.eq(resolved, db.aura_bar_bg_color, "Bar BG override stays independent from Frame BG")

    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, false)
    resolved = M.resolve_background_color("static_long", "frame", local_color)
    h.eq(resolved, M.db.shared_frame_background_color, "unchecked module falls back to Aura shared frame color")
end)

h.test("Bar BG picker color reaches rendered Aura bars", function()
    local frame = M.frames.show_essential
    local params = frame and frame.update_params
    h.ok(params, "Essential Aura frame is available")

    color_sync.get_db().global_enabled = false
    M.db.show_essential = true
    M.db.test_aura_essential = true
    M.db.bar_mode_essential = true
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_bg_essential = true
    M.db.shared_bar_background_color = { r = 0.17, g = 0.31, b = 0.73, a = 0.62 }
    M.invalidate_aura_scan_caches()
    M.invalidate_frame_runtime_config(frame)
    M.update_auras(
        frame,
        params.show_key,
        params.move_key,
        params.timer_key,
        params.bg_key,
        params.scale_key,
        params.spacing_key,
        params.aura_filter
    )

    local calls = frame.icons[1].bar_bg:GetCalls("SetColorTexture") or {}
    local applied = calls[#calls]
    h.ok(applied, "rendered bar background receives a color")
    h.eq(applied[1], 0.17, "rendered bar background receives shared red")
    h.eq(applied[2], 0.31, "rendered bar background receives shared green")
    h.eq(applied[3], 0.73, "rendered bar background receives shared blue")
    h.eq(applied[4], 0.62, "rendered bar background receives shared alpha")
end)

h.test("Aura Frames resolves shared Buff and Debuff bar colors before the global override", function()
    local db = color_sync.get_db()
    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    local local_color = { r = 0.1, g = 0.2, b = 0.3 }
    M.db.shared_buff_bar_color = { r = 0.2, g = 0.4, b = 0.6 }
    M.db.shared_debuff_bar_color = { r = 0.8, g = 0.2, b = 0.1 }
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_color_static_long = true
    M.db.sync_bar_color_debuff = true
    db.global_enabled = false

    h.eq(M.resolve_bar_color("static_long", local_color), M.db.shared_buff_bar_color,
        "Buff category uses the shared Buff bar color")
    h.eq(M.resolve_bar_color("debuff", local_color), M.db.shared_debuff_bar_color,
        "Debuff category uses the shared Debuff bar color")

    M.db.sync_bar_color_static_long = false
    h.eq(M.resolve_bar_color("static_long", local_color), local_color,
        "deselected bar color target keeps its local color")

    local custom = M.spawn_custom_frame()
    custom.aura_base_filter = "HARMFUL"
    custom.sync_bar_color = true
    h.eq(M.resolve_bar_color(custom.id, local_color), M.db.shared_debuff_bar_color,
        "harmful custom frame uses the shared Debuff bar color")
    M.destroy_custom_frame(custom.id)

    M.db.sync_bar_color_static_long = true
    db.global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, false)
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.debuffs, true)
    db.aura_debuff_bar_color = { r = 0.9, g = 0.8, b = 0.7 }
    h.eq(M.resolve_bar_color("static_long", local_color), M.db.shared_buff_bar_color,
        "disabled Buff participation keeps the Aura-owned Buff bar color")
    h.eq(M.resolve_bar_color("debuff", local_color), db.aura_debuff_bar_color,
        "global color overrides the Aura-owned Debuff bar color")
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.debuffs, false)
    h.eq(M.resolve_bar_color("static_long", local_color), db.aura_buff_bar_color,
        "Buff participation can be enabled independently")
    h.eq(M.resolve_bar_color("debuff", local_color), M.db.shared_debuff_bar_color,
        "disabled Debuff participation keeps the Aura-owned Debuff bar color")
    db.global_enabled = false
end)

h.test("Aura Frames resolves shared Bar and Timer text colors before the global override", function()
    local db = color_sync.get_db()
    local consumer_db = color_sync.ensure_consumer_db(M.MODULE_KEY)
    local local_color = { r = 0.1, g = 0.2, b = 0.3 }
    M.db.shared_bar_text_color = { r = 0.2, g = 0.4, b = 0.6 }
    M.db.shared_timer_text_color = { r = 0.8, g = 0.7, b = 0.3 }
    M.db.shared_background_color_enabled = true
    M.db.sync_text_color_short = true
    db.global_enabled = false

    h.eq(M.resolve_text_color("short", "bar", local_color), M.db.shared_bar_text_color,
        "Bar Text uses the shared Aura color")
    h.eq(M.resolve_text_color("short", "timer", local_color), M.db.shared_timer_text_color,
        "Timer Text uses the shared Aura color")

    M.db.sync_text_color_short = false
    h.eq(M.resolve_text_color("short", "bar", local_color), local_color,
        "deselected text target keeps its local color")

    db.global_enabled = true
    color_sync.set_global_participation_enabled(
        M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs, true)
    h.eq(M.resolve_text_color("short", "timer", local_color), db.aura_timer_text_color,
        "global Timer Text overrides the Aura-owned shared color")
    db.global_enabled = false
end)

h.test("Aura profiles own shared color and target selections", function()
    M.db.shared_frame_background_color = { r = 0.2, g = 0.3, b = 0.4, a = 0.5 }
    M.db.shared_bar_background_color = { r = 0.6, g = 0.7, b = 0.8, a = 0.9 }
    M.db.shared_buff_bar_color = { r = 0.3, g = 0.4, b = 0.5 }
    M.db.shared_debuff_bar_color = { r = 0.7, g = 0.2, b = 0.1 }
    M.db.shared_bar_text_color = { r = 0.1, g = 0.3, b = 0.5 }
    M.db.shared_timer_text_color = { r = 0.9, g = 0.7, b = 0.5 }
    M.db.shared_background_color_enabled = false
    M.db.sync_bar_bg_static_long = true
    M.db.sync_bar_color_static_long = false
    M.db.sync_text_color_static_long = false
    M.db.move_bg_opt_out_static_long = true
    local saved = M.export_aura_frame_profile_data()

    M.db.shared_frame_background_color.r = 0.9
    M.db.shared_bar_background_color.r = 0.1
    M.db.shared_buff_bar_color.r = 0.9
    M.db.shared_debuff_bar_color.r = 0.9
    M.db.shared_bar_text_color.r = 0.9
    M.db.shared_timer_text_color.r = 0.1
    M.db.shared_background_color_enabled = true
    M.db.sync_bar_bg_static_long = false
    M.db.sync_bar_color_static_long = true
    M.db.sync_text_color_static_long = true
    M.db.move_bg_opt_out_static_long = false
    local ok = M.apply_aura_frame_profile_data(saved)

    h.ok(ok, "Aura profile applies")
    h.eq(M.db.shared_frame_background_color.r, 0.2, "Aura profile restores shared frame color")
    h.eq(M.db.shared_bar_background_color.r, 0.6, "Aura profile restores shared bar color")
    h.eq(M.db.shared_buff_bar_color.r, 0.3, "Aura profile restores shared Buff bar color")
    h.eq(M.db.shared_debuff_bar_color.r, 0.7, "Aura profile restores shared Debuff bar color")
    h.eq(M.db.shared_bar_text_color.r, 0.1, "Aura profile restores shared Bar Text color")
    h.eq(M.db.shared_timer_text_color.r, 0.9, "Aura profile restores shared Timer Text color")
    h.eq(M.db.shared_background_color_enabled, false, "Aura profile restores shared enablement")
    h.eq(M.db.sync_bar_bg_static_long, true, "Aura profile restores BG Colors selection")
    h.eq(M.db.sync_bar_color_static_long, false, "Aura profile restores bar color selection")
    h.eq(M.db.sync_text_color_static_long, false, "Aura profile restores text color selection")
    h.eq(M.db.move_bg_opt_out_static_long, true, "Aura profile restores the Move Mode Frame BG opt-out")
end)

h.test("Icon Mode growth falls back Right when no prior icon direction is saved", function()
    local saved_growth = M.db.growth_icon_short
    M.db.growth_icon_short = nil

    h.eq(M.get_mode_growth(M.db, "short", false), "RIGHT",
        "deselecting Bar Mode without a saved Icon Mode direction falls back Right")

    M.db.growth_icon_short = saved_growth
end)

h.run("af_color_sync")

--#endregion FILE CONTENTS ===================================================
