# Aura Cancel Notes

Date: 2026-05-26
Scope decision: out-of-combat only, real cancelable player buffs only, selectable modifier key (CTRL/ALT/SHIFT), no in-combat support.


## Short Answer
Yes. The WoW API supports modifier-based click behavior and aura cancellation, but secure/protected rules apply. Your chosen scope (no combat support) is the practical low-risk path.


## Authoritative Sources

1. Warcraft Wiki: SecureActionButtonTemplate

- https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate

- Documents modified attributes such as `shift-type2`, `ctrl-type1`, `alt-type1`.

- Documents `cancelaura` as a secure action type.

- Notes `InsecureActionButtonTemplate` can perform protected actions only while not in combat lockdown.

- Caveat: the wiki action table still describes the `spell` path in older `CancelUnitBuff(unit, spell, rank)` terms. Current FrameXML uses `CancelSpellByName(spell)` for the `spell` attribute and `CancelUnitBuff("player", index, filter)` for the `index` attribute.

2. Warcraft Wiki: API_CancelUnitBuff

- https://warcraft.wiki.gg/wiki/API_CancelUnitBuff

- Marks the API as restricted and `#nocombat`.

- Documents that buff cancellation is protected in combat.

- Documents the current API signature as index-based: `CancelUnitBuff(unit, buffIndex [, filter])`.

- Notes the patch 8.0.1 removal of name/rank cancellation from `CancelUnitBuff`; use `CancelSpellByName` or `/cancelaura` for name-based cancellation.

3. Blizzard FrameXML source (Gethe mirror): SecureTemplates.lua

- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua

- Contains `SECURE_ACTIONS.cancelaura` implementation.

- Contains modifier prefix logic in `SecureButton_GetModifierPrefix` (`shift-`, `ctrl-`, `alt-`).

- Contains modified attribute resolution via `SecureButton_GetModifiedAttribute`.

- Current `SECURE_ACTIONS.cancelaura` behavior:

  - `spell` attribute: `CancelSpellByName(spell)`.

  - weapon enchant `target-slot`: `CancelItemTempEnchantment(...)`.

  - `index` attribute or button ID: `CancelUnitBuff("player", index, filter)`.

4. Blizzard restricted aura template (Gethe mirror): SecureGroupHeaders.xml

- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml

- Shows `SecureAuraButtonTemplate` inheriting `SecureActionButtonTemplate` with right-click cancel aura behavior (`type2 = cancelaura`).

- Registers the template for `RightButtonDown`.

5. Warcraft Wiki: C_UnitAuras.GetBuffDataByIndex

- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetBuffDataByIndex

- Documents the `CANCELABLE` aura filter: buffs that can be cancelled with `/cancelaura` or `CancelUnitBuff()`.


## What This Means For LsTweeks

Current addon aura icons are plain frames with tooltip hover scripts, not secure aura buttons.

Relevant local files:
- modules/aura_frames/af_main.lua

- modules/aura_frames/af_core.lua

Implication:
- API capability exists.

- Implementation must respect protected action rules.

- Since combat support is intentionally excluded, complexity is reduced.

- For the chosen out-of-combat scope, a plain frame `OnMouseUp`/`OnClick` path that calls `CancelUnitBuff("player", index, filter)` is simpler than converting the icon pool to secure aura buttons. If using secure buttons later, set attributes only out of combat and account for index/filter updates every render.

- `obj.aura_index` currently stores `auraInstanceID`, not the positional buff index expected by `CancelUnitBuff`. Do not pass `obj.aura_index` directly to `CancelUnitBuff`.


## Agreed Boundaries

Included:
- Out-of-combat only interaction.

- Preset long and static buff frames.

- Custom AuraFilter frames when the clicked icon resolves to a real, currently cancelable player buff.

- Selectable modifier key (CTRL, ALT, SHIFT).

Excluded:
- Any in-combat cancel behavior.

- Debuff canceling.

- Preset short buff canceling, unless explicitly changed later.

- CDM/cooldown-viewer entries unless they are backed by a real player buff `auraInstanceID` and pass the current cancelable scan.

- Keyboard-only global binding flow.


## Recommended Safe Behavior

1. Add a configurable modifier option with values: OFF, CTRL, ALT, SHIFT.

2. Trigger cancel attempt only when all checks pass, in cheap-to-expensive order:

- Feature is enabled.

- Player is out of combat.

- Active modifier matches selected setting.

- Clicked icon has a real `auraInstanceID`.

- Clicked icon is not known test data, a spell cooldown entry, or another non-aura entry.

- Frame/source policy allows the click: preset long/static, or custom frame with real aura identity.

- Cheap stored metadata does not disqualify the aura, if available.

- Fresh scan confirms the current aura is removable/cancelable.

3. Keep hover tooltip and move/resize behavior unchanged.

4. Ignore unsupported states silently (combat, non-cancelable aura, wrong category, wrong modifier).

5. Treat the final `HELPFUL|CANCELABLE` scan as authoritative. Earlier checks are only fast rejection gates.

Modifier meaning:
- OFF: feature disabled.

- CTRL: require `IsControlKeyDown()`.

- ALT: require `IsAltKeyDown()`.

- SHIFT: require `IsShiftKeyDown()`.


## Suggested Out-of-Combat Implementation Shape

1. On render, continue storing `auraInstanceID` as the stable display identity.

2. On click, return immediately if the cancel modifier setting is OFF.

3. Return immediately if `InCombatLockdown()` is true.

4. Return if the selected modifier is not currently held.

5. Return if `obj.aura_index` is not a number, because this addon currently stores `auraInstanceID` there.

6. Return if `obj.is_test_preview` or `obj.is_spell_cooldown` is true.

7. Return if the frame policy fails:

- Preset frames: allow only `static` and `long`.

- Custom frames: allow only if the clicked icon has a real aura identity; do not require the custom frame's derived timer category to be static/long.

8. Resolve the current positional buff index by scanning `C_UnitAuras.GetBuffDataByIndex("player", i, "HELPFUL|CANCELABLE")` until `aura.auraInstanceID == obj.aura_index`.

9. If found, call `CancelUnitBuff("player", index, "HELPFUL|CANCELABLE")`.

10. Queue a normal aura refresh after the attempt.

Important custom-frame note:
- Custom frames are AuraFilter-driven and may display helpful buffs from many filters (`HELPFUL|IMPORTANT`, `HELPFUL|PLAYER`, `HELPFUL|CANCELABLE`, etc.).

- Do not decide custom-frame eligibility from the custom frame's timer category alone. The clicked aura is eligible only if the fresh `HELPFUL|CANCELABLE` scan finds the same `auraInstanceID`.


## Risk Notes

- Even out-of-combat, protected action setup can taint if wired incorrectly.

- Frequent aura remapping means icon metadata and click target identity must stay synchronized.

- Modifier changes during gameplay should avoid introducing combat-time attribute mutation.

- Some buffs/forms are intentionally not cancellable through `CancelUnitBuff`; the cancelable filter should be treated as authoritative.


## Practical Conclusion

The idea is API-valid and implementable with your selected restrictions. The out-of-combat only scope is a sensible approach to avoid secure combat complexity while still providing useful functionality.
