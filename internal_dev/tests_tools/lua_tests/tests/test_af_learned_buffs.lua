-- Aura Frames OOC learned Static / Long Buff cache tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
h.load_addon()

local M = h.addon.aura_frames

h.test("OOC learner persists readable durations and builds native long/static inclusion", function()
    M.db = {
        short_threshold = 300,
        learned_helpful_durations = {},
    }
    h.stub.in_combat = false
    h.stub.auras.player = {
        buffs = {
            { auraInstanceID = 1, spellId = 1001, duration = 0 },
            { auraInstanceID = 2, spellId = 1002, duration = 600 },
            { auraInstanceID = 3, spellId = 1003, duration = 300 },
            { auraInstanceID = 4, spellId = 1004,
                duration = { __lstweeks_test_secret_value = true } },
            { auraInstanceID = 5, spellId = nil, duration = 900 },
        },
        debuffs = {},
    }

    local changed, learned = M.learn_helpful_aura_durations_ooc()
    h.eq(changed, true, "readable OOC observations change the learned cache")
    h.eq(learned, 3, "learner accepts only readable spell ID and duration pairs")
    h.eq(M.db.learned_helpful_durations[1001], 0, "permanent Aura duration is retained")
    h.eq(M.db.learned_helpful_durations[1002], 600, "long Aura duration is retained")
    h.eq(M.db.learned_helpful_durations[1003], 300, "Short boundary duration is retained")
    h.eq(M.db.learned_helpful_durations[1004], nil, "secret duration is ignored")

    local included = M.build_learned_long_static_spell_ids()
    h.eq(included[1001], true, "learned permanent Aura is included")
    h.eq(included[1002], true, "learned Aura above the Short maximum is included")
    h.eq(included[1003], nil, "learned Aura at the Short maximum is excluded")

    h.stub.auras.player.buffs = {
        { auraInstanceID = 6, spellId = 1002, duration = 120 },
    }
    changed, learned = M.learn_helpful_aura_durations_ooc()
    h.eq(changed, true, "later readable observations update a learned spell")
    h.eq(learned, 1, "updated observation is counted")
    h.eq(M.build_learned_long_static_spell_ids()[1002], nil,
        "latest Short observation removes the spell from learned inclusion")

    h.stub.in_combat = true
    h.stub.auras.player.buffs[1].duration = 900
    changed, learned = M.learn_helpful_aura_durations_ooc()
    h.eq(changed, false, "combat blocks the learner")
    h.eq(learned, 0, "combat learns no Aura fields")
    h.eq(M.db.learned_helpful_durations[1002], 120,
        "combat cannot overwrite the last readable observation")
    h.eq(M.clear_learned_helpful_durations(), false, "combat blocks cache clearing")
    h.eq(M.db.learned_helpful_durations[1002], 120,
        "blocked combat clear preserves learned observations")

    h.stub.in_combat = false
    M.clear_learned_helpful_durations()
    h.eq(next(M.db.learned_helpful_durations), nil, "clear removes learned observations")
    h.stub.auras.player = nil
end)

h.test("Aura Frames reset queues a fresh OOC learned-buff observation", function()
    M.db = {}
    h.addon.apply_defaults(M.defaults, M.db)
    local queued = 0
    local original_queue = M.queue_learned_buff_scan
    M.queue_learned_buff_scan = function()
        queued = queued + 1
    end

    M.on_reset_complete()

    M.queue_learned_buff_scan = original_queue
    h.eq(queued, 1, "reset requests one learner refresh after replacing its cache")
end)

h.run("af_learned_buffs")

--#endregion FILE CONTENTS ===================================================
