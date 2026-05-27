# Aura Cancel Interaction Notes

Date: 2026-05-26
Scope decision: out-of-combat only, long/static buff categories only, selectable modifier key (CTRL/ALT/SHIFT), no in-combat support.

## Short Answer
Yes. The WoW API supports modifier-based click behavior and aura cancellation, but secure/protected rules apply. Your chosen scope (no combat support) is the practical low-risk path.

## Authoritative Sources

1. Warcraft Wiki: SecureActionButtonTemplate
- https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate
- Documents modified attributes such as `shift-type2`, `ctrl-type1`, `alt-type1`.
- Documents `cancelaura` as a secure action type.
- Notes `InsecureActionButtonTemplate` can perform protected actions only while not in combat lockdown.

2. Warcraft Wiki: API_CancelUnitBuff
- https://warcraft.wiki.gg/wiki/API_CancelUnitBuff
- Marks the API as restricted and `#nocombat`.
- Documents that buff cancellation is protected in combat.

3. Blizzard FrameXML source (Gethe mirror): SecureTemplates.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua
- Contains `SECURE_ACTIONS.cancelaura` implementation.
- Contains modifier prefix logic in `SecureButton_GetModifierPrefix` (`shift-`, `ctrl-`, `alt-`).
- Contains modified attribute resolution via `SecureButton_GetModifiedAttribute`.

4. Blizzard restricted aura template (Gethe mirror): SecureGroupHeaders.xml
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml
- Shows `SecureAuraButtonTemplate` inheriting `SecureActionButtonTemplate` with right-click cancel aura behavior (`type2 = cancelaura`).

## What This Means For LsTweeks

Current addon aura icons are plain frames with tooltip hover scripts, not secure aura buttons.

Relevant local files:
- modules/aura_frames/af_main.lua
- modules/aura_frames/af_core.lua

Implication:
- API capability exists.
- Implementation must respect protected action rules.
- Since combat support is intentionally excluded, complexity is reduced.

## Agreed Boundaries

Included:
- Out-of-combat only interaction.
- Only long and static buff categories.
- Selectable modifier key (CTRL, ALT, SHIFT).

Excluded:
- Any in-combat cancel behavior.
- Debuff/short/CDM/custom category canceling.
- Keyboard-only global binding flow.

## Recommended Safe Behavior

1. Add a configurable modifier option with values: OFF, CTRL, ALT, SHIFT.
2. Trigger cancel attempt only when all checks pass:
- Player is out of combat.
- Frame category is long or static.
- Aura is removable/cancelable.
- Active modifier matches selected setting.
3. Keep hover tooltip and move/resize behavior unchanged.
4. Ignore unsupported states silently (combat, non-cancelable aura, wrong category, wrong modifier).

## Risk Notes

- Even out-of-combat, protected action setup can taint if wired incorrectly.
- Frequent aura remapping means icon metadata and click target identity must stay synchronized.
- Modifier changes during gameplay should avoid introducing combat-time attribute mutation.

## Practical Conclusion

The idea is API-valid and implementable with your selected restrictions. The out-of-combat only scope is a sensible approach to avoid secure combat complexity while still providing useful functionality.
