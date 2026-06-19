# WoW API Update Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

Source checked:
1. Gethe/wow-ui-source tags: https://github.com/Gethe/wow-ui-source/tags

2. Compared 12.0.5 to 12.0.7: https://github.com/Gethe/wow-ui-source/compare/12.0.5...12.0.7

## Notes

1. Priority: High | Impact: High | Change Risk: High - No evidence from the diff says we should broadly re-work the whole addon immediately. The safer next step is targeted audit/testing around APIs this addon already touches.

2. Priority: High | Impact: High | Change Risk: Medium - Skyriding Vigor should be reviewed around `UnitPower` and `UnitPowerMax`. The 12.0.5 -> 12.0.7 API docs include `ShouldUnitPowerBeSecret`, `ShouldUnitPowerMaxBeSecret`, and secret annotations for restricted unit power reads. `sv_state.lua` already has some `issecretvalue` handling, but verify both current and max vigor paths, especially when using `Enum.PowerType.AlternateMount` or the Alternate fallback.

3. Priority: High | Impact: High | Change Risk: High - The diff adds/expands `C_CooldownViewer` and Blizzard_CooldownViewer files. This is more relevant to cooldown/display modules than Skyriding Vigor. If LsTweeks currently hooks or reads Blizzard cooldown viewer frames directly, consider a later pass to see whether the public `C_CooldownViewer` API can replace any frame-level assumptions.

4. Priority: High | Impact: High | Change Risk: Medium - The diff contains broader restricted/secret-value documentation changes and notes around protected UI operations. Audit code that opens Blizzard UI panels, especially the Skyriding Talents button path, and guard or disable it in combat if testing shows blocked/protected behavior.

5. Priority: Medium | Impact: High | Change Risk: Medium - Aura APIs used elsewhere in the addon, including `C_UnitAuras.GetUnitAuraInstanceIDs`, `GetAuraDataByAuraInstanceID`, `GetAuraDataByIndex`, `GetAuraDuration`, `DoesAuraHaveExpirationTime`, and `GetAuraApplicationDisplayCount`, still appear in the API docs. No immediate aura rewrite is indicated from this source alone, but refresh local annotations and run diagnostics after the WoW API update.

6. Priority: Medium | Impact: Medium | Change Risk: Low - `C_PlayerInfo.GetGlidingInfo`, `Enum.PowerType.AlternateMount`, `C_Spell.GetSpellCharges`, `C_Spell.GetSpellCooldown`, and `C_Spell.GetSpellCooldownDuration` remain present in the compared source. This supports the current Skyriding Vigor approach, pending in-game validation.

7. Priority: Medium | Impact: Medium | Change Risk: Low - `C_Texture.GetAtlasInfo` remains present, so the atlas validation work for vigor textures and spark atlases does not need an immediate API rewrite. Still test selected atlas names in-game because art kit names can fail silently when assumptions are wrong.

8. Priority: Low | Impact: Low | Change Risk: Low - The mirror shows 12.0.5 as build 67602 and 12.0.7 as the latest tag available during this review. This is not Blizzard's official documentation, but it is a direct public mirror of Blizzard UI source/API docs and is useful for identifying addon-facing changes.

## Recommended Follow-Up

1. Priority: High | Impact: High | Change Risk: Low - Run LuaLS/Ketho diagnostics against updated API annotations.

2. Priority: High | Impact: High | Change Risk: Low - In-game smoke test Skyriding Vigor for normal flight, recharge, max vigor, and no-vigor states after the 12.0.7 client update.

3. Priority: High | Impact: Medium | Change Risk: Low - Test the Skyriding Talents button both out of combat and in combat.

4. Priority: High | Impact: High | Change Risk: High - Add a focused review of cooldown viewer integration if this addon is touching Blizzard cooldown viewer frames.
