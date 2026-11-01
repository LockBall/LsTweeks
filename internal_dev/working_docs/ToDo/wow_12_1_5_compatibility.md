# Retail 12.1.5 Compatibility Review
Active client acceptance review originally prepared for LsTweeks 00.23.01. No runtime changes were required by that source comparison; the TOC adds interface 120105 while retaining earlier declarations. The current candidate is 00.24.00, adding ChatCopySghetti with separate acceptance in `new_chat_copy.md`; the source-review evidence below retains its original scope.


## Table of Contents
- [1. Evidence And Scope](#1-evidence-and-scope)
- [2. Source Findings](#2-source-findings)
- [3. Automated Validation](#3-automated-validation)
- [4. Pending In-Game Acceptance](#4-pending-in-game-acceptance)


## 1. Evidence And Scope
- **a** Review date: 2026-10-30. Live reference: 12.1.5.70575, interface 120105, Blizzard source `15881d522c44cd106d3d8660106ec9f9d2f44167`; compared with the prior managed snapshot `8ea15b61` (12.1.0.69587).
- **b** Annotation inputs: Ketho generator `d0b5b51fac4c52c493371b9b18e66ce604ea4326`, BlizzardInterfaceResources `f3b334b33bd19fa6a0250f7922ecfa83db7fe356`, FrameXML annotations `945f348caaeb4218b5824c4e24815c933f8ffd33`.
- **c** Scope: managed presets and CDM groups/slots, custom Aura rendering, shared tooltips, Player Frame, Objectives, Skyriding Vigor, Audio Volumes, and addon metadata. Source compatibility is observed; runtime compatibility remains unverified until section 4 passes.
- **d** Installed retail Wow.exe file/product version is also 12.1.5.70575, matching the reference. The live client interface should still be confirmed in game.


## 2. Source Findings
- **a** AuraContainer: existing group/slot construction, candidate filters, max-frame-count switching, and layout APIs remain present. New group/slot enable APIs are optional; retaining the existing path avoids introducing an untested lifecycle change. Blizzard changed internal assignment refresh and clears native cooldowns on assignment changes; managed duration bindings remain Blizzard-owned.
- **b** AuraButton: deprecated AuraBorder/AuraSymbol aliases were removed, and display-element removal now accepts objects instead of indices. LsTweeks uses neither changed interface. New caster-name and animation bindings are outside current feature scope. No addon visibility handlers or secret Aura inspection were added.
- **c** Cooldown Viewer: category/provider access used by the addon remains available. Linked-spell event handling, equipped-item cooldown interpretation, and pandemic alerts changed inside Blizzard code; LsTweeks does not replace those methods or implement those alert calculations. Its existing public-metadata/native-Aura split remains applicable.
- **d** Cooldown setters and Clear are newly marked protected in generated API declarations; time types now use Seconds/Milliseconds. Existing addon-rendered cooldown cells and Blizzard-owned managed duration bindings require combat acceptance. This declaration change alone does not establish that an addon-owned cell is blocked, and is not grounds for suppressing errors or replacing native bindings.
- **e** Player Frame: PvP badge logic moved into UnitFrameUtil; the addon does not hook that code. Its HitIndicator path and UnitHealthPercent/curve health gate remain available. Objectives changes affect Scenario stage sound/header presentation and AutoQuest popup layout; the addon does not call those changed methods. Preserve the existing visibility-only auto-collapse boundary and its known expanded-height limitation.
- **f** Vigor charge/glide APIs, quest/content tracking count APIs, sound/CVar APIs, and tooltip APIs used here have no signature removal in the compared declarations. BuffFrame adds a consolidated-tooltip anchor override; addon suppression still operates on the parent frames. Removed PlayVocalErrorSoundID, C_TableUtil.FindIndexedMismatch, and changed table.count returns are unused by project runtime code.


## 3. Automated Validation
- **a** All 27 headless Lua suites passed against the existing runtime code. These model addon contracts, not Blizzard taint or actual rendering.
- **b** Full LuaLS check against refreshed annotations passed with no diagnostics.
- **c** Fast non-test validation passed: region markers, memory section sizes, internal ownership contracts, whitespace, and line endings. No Lua files changed. Release package `dist/LsTweeks-00.23.01.zip` rebuilt with the public changelog and verified successfully (149 entries); no publishing was performed.


## 4. Pending In-Game Acceptance
- [ ] **a** Fresh reload with script errors enabled. Confirm the installed client interface with `/dump (select(4, GetBuildInfo()))`, current candidate addon version 00.24.00, and `/lst status`. Report a differing client build before claiming acceptance.
- [ ] **b** Preset Auras: Short, Static / Long, Timed, and Debuffs in Icon/Bar modes; apply, refresh, expire, and cancel supported buffs; exercise combat entry/exit, OOC fade, native hover, growth, mode switches OOC, and frame/module disable plus reload. Confirm no duplicate modes, stale swipes, invisible hitboxes, or blocked actions.
- [ ] **c** CDM: Essential, Utility, Tracked Buffs, and Tracked Bars in Aura/Cooldown and Icon/Bar modes. Exercise active-Aura-to-cooldown handoff, cooldown start/finish in combat, charge changes, settings reorder/category moves, and specialization changes OOC. Confirm order, overlay placement, timer cleanup, and no errors.
- [ ] **d** Player Frame: portrait combat text suppression, low-health visibility, OOC delay/fade, combat re-entry during fade, and module disable/restore.
- [ ] **e** Objectives: auto-collapse/manual expand, section counts, background/position, combat-deferred settings, and scenario/world-event updates. Exercise tracker expand/collapse and subsequent objective progress; confirm no delayed Scenario secret-value errors. Existing visibility-only layout gaps are a known limitation, not a new acceptance criterion.
- [ ] **f** Vigor: mounted flight, charge spend/recharge, full-charge fade, landing, ridealong, and race state. Audio: replacement previews, Original restoration, enabled situations, and module disable restoration.
- [ ] **g** After normal combat/gameplay, check world-map POIs, world quests, and other widget-bearing tooltips for delayed contamination. Keep the default tooltip route; the separate native tooltip experiment is not needed for this compatibility update.
- **h** After acceptance, consolidate durable findings into owning memory and retire this active review. Archive any new error export through the repository error-batch workflow.
