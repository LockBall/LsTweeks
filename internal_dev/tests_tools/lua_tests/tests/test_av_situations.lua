-- Behavioral tests for Audio Volumes temporary situations: combat volumes and fishing focus
-- must cache the normal CVar profile, apply the override, and restore exactly on exit.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.load_addon("modules/audio_volumes")
h.boot({})

local AV = h.addon.audio_volumes
local FISHING_SPELL_ID = 131476

-- The "normal" player sound profile the situations must restore to.
local NORMAL_CVARS = {
    Sound_MasterVolume = "1",
    Sound_MusicVolume = "0.4",
    Sound_SFXVolume = "0.6",
    Sound_AmbienceVolume = "0.6",
    Sound_DialogVolume = "0.8",
}

local function reset_sound_state()
    stub.in_combat = false
    AV._fishing_focus_active = false
    AV._combat_volumes_active = false
    AV._manual_situation_active_key = nil
    AV._temporary_sound_profile_cached = nil
    stub.cvars = {}
    for cvar, value in pairs(NORMAL_CVARS) do
        stub.cvars[cvar] = value
    end
end

local function assert_normal_profile(label)
    for cvar, value in pairs(NORMAL_CVARS) do
        h.eq(stub.cvars[cvar], value, label .. ": " .. cvar)
    end
end

local function av_db()
    Ls_Tweeks_DB.audio_volumes = Ls_Tweeks_DB.audio_volumes or {}
    return Ls_Tweeks_DB.audio_volumes
end

h.test("combat volumes apply on entering combat and restore exactly on leaving", function()
    reset_sound_state()
    local combat_db = AV.get_combat_volumes_db()
    combat_db.enabled = true
    combat_db.master = 20
    combat_db.music = 0
    AV.sync_combat_volumes_events()

    h.enter_combat()
    h.eq(stub.cvars.Sound_MasterVolume, "0.2", "master lowered in combat")
    h.eq(stub.cvars.Sound_MusicVolume, "0", "music muted in combat")

    h.leave_combat()
    assert_normal_profile("restored after combat")
end)

h.test("combat volumes disabled: regen events change nothing", function()
    reset_sound_state()
    AV.get_combat_volumes_db().enabled = false
    AV.sync_combat_volumes_events()

    h.enter_combat()
    assert_normal_profile("no override while disabled")
    h.leave_combat()
    assert_normal_profile("still normal after combat")
end)

h.test("fishing focus applies on channel start and restores on channel stop", function()
    reset_sound_state()
    local focus_db = AV.get_fishing_focus_db()
    focus_db.enabled = true
    focus_db.master = 50
    focus_db.sfx = 100
    av_db().fishing_focus.enabled = true
    AV.sync_fishing_focus_events()

    h.fire_event("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-guid", FISHING_SPELL_ID)
    h.eq(stub.cvars.Sound_MasterVolume, "0.5", "master at fishing level")
    h.eq(stub.cvars.Sound_SFXVolume, "1", "sfx boosted for bobber sound")

    h.fire_event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-guid", FISHING_SPELL_ID)
    assert_normal_profile("restored after fishing channel")
end)

h.test("non-fishing channel spells are ignored", function()
    reset_sound_state()
    av_db().fishing_focus.enabled = true
    AV.sync_fishing_focus_events()

    h.fire_event("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-guid", 12345)
    assert_normal_profile("unrelated channel spell does not trigger focus")
end)

h.test("Specifics controls write the reset target table", function()
    reset_sound_state()
    local parent = CreateFrame("Frame", nil, UIParent)
    local target_key = "ready_check"
    AV.BuildSoundTargetSliderPanel(parent, target_key, AV.SOUND_TARGETS[target_key])
    local stale_target = AV.get_target_db(target_key)

    table.wipe(av_db())
    h.addon.deep_copy_into(AV.defaults.audio_volumes, av_db())
    AV.on_reset_complete()
    local fresh_target = AV.get_target_db(target_key)
    h.ok(fresh_target ~= stale_target, "reset replaces target table")

    local preset = AV.controls[target_key .. "_preset"]
    preset.Slider:SetValue(5)
    preset:TriggerCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, 5)

    h.eq(fresh_target.preset, "15", "slider updates reset target table")
    h.eq(stale_target.preset, "10", "slider leaves stale target table untouched")
end)

h.test("Situations controls rebuild against reset profile tables", function()
    reset_sound_state()
    local custom_key = AV.create_custom_situation()
    av_db().last_tab_index = 3
    av_db().last_situation_key = custom_key
    local parent = CreateFrame("Frame", nil, UIParent)
    AV.BuildSettings(parent)
    local stale_fishing = AV.get_fishing_focus_db()
    h.ok(AV.controls["situation_" .. custom_key .. "_master"], "custom situation control exists before reset")

    table.wipe(av_db())
    h.addon.deep_copy_into(AV.defaults.audio_volumes, av_db())
    AV.on_reset_complete()
    local fresh_fishing = AV.get_fishing_focus_db()
    h.ok(fresh_fishing ~= stale_fishing, "reset replaces fishing profile table")
    h.is_nil(AV.controls["situation_" .. custom_key .. "_master"], "deleted custom control is removed with rebuilt tab")

    local fishing_slider = AV.controls.fishing_focus_master.slider
    fishing_slider:SetValue(45)
    fishing_slider:GetScript("OnValueChanged")(fishing_slider, 45)
    h.eq(fresh_fishing.master, 45, "slider updates reset fishing profile table")
    h.ok(stale_fishing.master ~= 45, "slider leaves stale fishing profile table untouched")
end)

h.test("Original toggle previews only when Play on Adjust is enabled", function()
    reset_sound_state()
    local parent = CreateFrame("Frame", nil, UIParent)
    local target_key = "ready_check"
    local target_db = AV.get_target_db(target_key)
    target_db.play_on_adjust = false
    target_db.use_original = false
    AV.BuildSoundTargetSliderPanel(parent, target_key, AV.SOUND_TARGETS[target_key])

    local previews = 0
    local original_play_replacement = AV.play_replacement
    AV.play_replacement = function()
        previews = previews + 1
    end

    local original_control = AV.controls[target_key .. "_use_original"]
    original_control.checkbox:SetChecked(true)
    original_control.checkbox:Click()
    h.eq(previews, 0, "Original toggle is silent when Play on Adjust is disabled")

    target_db.play_on_adjust = true
    original_control.checkbox:SetChecked(false)
    original_control.checkbox:Click()
    h.eq(previews, 1, "Original toggle previews when Play on Adjust is enabled")
    AV.play_replacement = original_play_replacement
end)

h.test("Audio Volumes profiles restore copied sound and situation settings", function()
    reset_sound_state()
    local db = av_db()
    db.profiles = {}
    local target = AV.get_target_db("ready_check")
    target.preset = "5"
    local fishing = AV.get_fishing_focus_db()
    fishing.enabled = true
    fishing.master = 35
    local custom_key = AV.create_custom_situation()
    AV.get_situation_profile_db(custom_key).music = 15

    local ok = AV.save_audio_volumes_profile("Regression", false)
    h.ok(ok, "profile saves")
    target.preset = "15"
    fishing.master = 80
    AV.get_situation_profile_db(custom_key).music = 90

    ok = AV.load_audio_volumes_profile("Regression")
    h.ok(ok, "profile loads")
    h.eq(AV.get_target_db("ready_check").preset, "5", "target preset restored")
    h.eq(AV.get_fishing_focus_db().master, 35, "fishing profile restored")
    h.eq(AV.get_situation_profile_db(custom_key).music, 15, "custom Quick Pick restored")
    h.eq(AV.get_audio_volumes_profiles()[1].version, 1, "profile records schema version")
end)

h.test("combat volumes win over fishing focus and restore cleanly through both exits", function()
    reset_sound_state()
    local focus_db = AV.get_fishing_focus_db()
    focus_db.enabled = true
    focus_db.master = 50
    av_db().fishing_focus.enabled = true
    local combat_db = AV.get_combat_volumes_db()
    combat_db.enabled = true
    combat_db.master = 20
    AV.sync_fishing_focus_events()
    AV.sync_combat_volumes_events()

    h.fire_event("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-guid", FISHING_SPELL_ID)
    h.eq(stub.cvars.Sound_MasterVolume, "0.5", "fishing profile active")

    h.enter_combat()
    h.eq(stub.cvars.Sound_MasterVolume, "0.2", "combat profile overrides fishing")

    h.leave_combat()
    h.fire_event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-guid", FISHING_SPELL_ID)
    assert_normal_profile("normal profile after both situations end")
end)

h.test("cached normal profile survives a setting resync mid-situation", function()
    reset_sound_state()
    local combat_db = AV.get_combat_volumes_db()
    combat_db.enabled = true
    combat_db.master = 20
    AV.sync_combat_volumes_events()

    h.enter_combat()
    combat_db.master = 40
    AV.resync_combat_volumes()
    h.eq(stub.cvars.Sound_MasterVolume, "0.4", "resync applies new combat level")

    h.leave_combat()
    assert_normal_profile("restore still uses original pre-combat profile")
end)

h.test("module disable mid-combat restores the normal profile", function()
    reset_sound_state()
    local combat_db = AV.get_combat_volumes_db()
    combat_db.enabled = true
    combat_db.master = 20
    AV.sync_combat_volumes_events()

    h.enter_combat()
    h.eq(stub.cvars.Sound_MasterVolume, "0.2", "combat profile active")

    h.addon.set_module_enabled("audio_volumes", false)
    AV.sync_combat_volumes_events()
    assert_normal_profile("disable restores normal profile immediately")

    h.addon.set_module_enabled("audio_volumes", true)
end)

h.run("av_situations")

--#endregion FILE CONTENTS ===================================================
