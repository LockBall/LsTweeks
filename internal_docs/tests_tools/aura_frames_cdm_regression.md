# Aura Frames CDM Regression Test

Manual in-game test for WoW Cooldown Manager backed Aura Frames.

## Purpose

Verify CDM-backed frames display active aura duration first, then cooldown, and that
Blizzard reused CDM child frames do not carry stale cached spell name/icon identity.

Regression fixed:
- Utility CDM frame could display cooldown immediately instead of active aura duration.
- Root cause was stale addon-owned cached spell name/icon state for reused Blizzard
  CooldownViewer child frames after `cooldownID` or spell ID changed.

## Setup

1. Reload UI after code changes.
2. Enable the addon CDM frame being tested.
3. Use WoW's Cooldown Manager UI to move the same tracked spell between CDM groups.
4. Keep the addon CDM frame in cooldown mode.

## Core Matrix

For each spell and CDM group:

1. Put the spell in the CDM group.
2. Enter combat.
3. Cast the spell.
4. Confirm the addon frame shows active aura duration first.
5. Let the active aura expire.
6. Confirm the addon frame then shows the cooldown without waiting for combat exit.

Test spells:
- Blessing of Freedom
- Divine Protection

Test groups:
- Essential
- Utility
- Tracked Buffs, if applicable for the spell
- Tracked Bars, if applicable for the spell

## Prior Regression Case

1. Put Divine Protection in Utility.
2. Cast Divine Protection out of combat.
3. Enter combat while the active aura is still running.
4. Let the active aura expire in combat.
5. Confirm cooldown appears immediately after active aura expires.

## First In-Combat Cast Case

1. Reload UI or start from a fresh session.
2. Put Divine Protection in Utility.
3. Enter combat before casting.
4. Cast Divine Protection.
5. Confirm the first cast shows active aura duration before cooldown.
6. Repeat once more in the same session and confirm behavior stays consistent.

Reload/wait variant:
1. Reload UI.
2. Wait out of combat long enough for CDM viewer state to settle.
3. Enter combat and cast Divine Protection from Utility.
4. Confirm Utility still shows active aura duration before cooldown, matching Essential.

## Pass Criteria

Pass:
- Active aura duration appears before cooldown for each spell/group pairing.
- The same spell behaves consistently when moved between Essential and Utility.
- No frame shows a stale spell name/icon after moving spells between CDM groups.

Fail:
- Active aura duration is skipped and cooldown appears immediately.
- Cooldown appears only after leaving combat.
- A frame shows a stale spell name/icon after a spell is moved between CDM groups.
