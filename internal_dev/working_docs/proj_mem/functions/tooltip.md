# Tooltip Function Memory
Durable architecture and safety contracts for the shared tooltip subsystem in `functions/tooltip.lua`.


## Table of Contents
- [Ownership And Public API](#ownership-and-public-api)
- [Renderer Architecture](#renderer-architecture)
- [Secret Data Contract](#secret-data-contract)
- [Incident Evidence](#incident-evidence)
- [Validation](#validation)


## Ownership And Public API
- `functions/tooltip.lua` is the only project-owned tooltip factory and secret-tooltip-data boundary. Route general help, guarded line rendering, native Aura/spell rendering, and tooltip hiding through it instead of creating module-local tooltip machinery.
- Owned display: `addon.CreateOwnedTooltip()`, `addon.ShowOwnedTooltipLines()`, `addon.ShowOwnedTooltip()`, `addon.AttachTooltip()`, and `addon.HideOwnedTooltip()`.
- Guarded conversion: `addon.CopySafeTooltipDataLines()` converts readable `C_TooltipInfo` data into the owned line schema after validating every container and value.
- Restricted display: `addon.ShowNativeAuraTooltip()`, `addon.ShowNativeSpellTooltip()`, `addon.ShowOpaqueAuraTooltip()`, and `addon.HideNativeTooltip()`.
- Tests: `test_tooltip.lua` owns factory/data-boundary contracts; module suites own caller order and feature-specific fallback behavior.


## Renderer Architecture
- Addon-authored and copied-safe lines use one plain `Frame` with `TooltipBackdropTemplate`, native tooltip fonts, bounded content sizing, quadrant anchoring, and screen clamping. It deliberately has no `GameTooltip` data or widget machinery.
- Explicitly non-secret Aura/spell data may use one lightweight LsTweeks `GameTooltip`: `SharedTooltipArtTemplate` plus `GameTooltipDataMixin`, `GameTooltip_OnLoad`, `GameTooltip_OnShow`, and `SharedTooltip_OnHide`. It must not inherit full `GameTooltipTemplate` or use `GameTooltip_OnHide`.
- Secret or indeterminate Aura instances use a separate data-mixin-free `SharedTooltipArtTemplate`. Live `C_TooltipInfo` left/right text passes directly into `AddLine`/`AddDoubleLine`; only previously copied safe colors may be reapplied by line position, otherwise neutral colors are used.
- Native and opaque tooltip owners are tracked independently. A leave event hides only the tooltip still owned by that frame, and selecting one renderer hides the other plus the owned fallback.


## Secret Data Contract
- Only call `SetUnitAuraByAuraInstanceID` when `C_Secrets.ShouldUnitAuraInstanceBeSecret(unit, auraInstanceID)` succeeds and returns explicit `false`.
- Only call the Aura spell fallback `SetSpellByID` when `C_Secrets.ShouldSpellAuraBeSecret(spellID)` succeeds and returns explicit `false`. A readable spell ID does not itself prove its Aura tooltip data is safe.
- `CopySafeTooltipDataLines()` validates outer data, `lines`, each line, text, color tables/components, and wrap flags before field-dependent use or caching. Validate every containing table before field, length, or index access; individual spells may remain secret outside combat.
- Opaque rendering may type-check and forward live text values supported by Blizzard tooltip controls, but must not compare, concatenate, measure, cache, recolor from live data, or inspect secret formatting fields.
- Never put restricted Aura data on Blizzard's shared global `GameTooltip`, inherit full `GameTooltipTemplate` for it, inspect rendered native lines, or use `securecallfunction` as a taint workaround. `pcall` contains synchronous setter/line failures but does not make secret data safe.
- Error suppression is acceptable only when the rendering path remains usable and the failure cannot wedge later tooltips. Hiding reports while tooltip processing remains broken is not recovery.
- Research sources for secret predicates, tooltip processing, templates, and private Aura behavior live in `research_sources.md` `## Blizzard UI Source`.


## Incident Evidence
- 2026-06-28: Area POI `UIWidgetTemplateTextWithStateMixin:Setup()` failed on secret `textHeight` after tooltip contamination.
- 2026-07-01 and 2026-07-03: world quest `EmbeddedItemTooltip_UpdateSize()` failed on secret width; Area POI status-bar partitions failed on secret `barWidth`.
- 2026-07-19: an isolated tooltip plus `securecallfunction` and rendered-line inspection still contaminated later map POI layout.
- 2026-07-20: direct delegation through shared `GameTooltip` caused delayed Area POI `LayoutFrame.lua` secret comparison failures.
- 2026-07-21: a dedicated full-template tooltip failed later in `GameTooltip_ClearWidgetSet`; a lightweight unguarded Aura setter then failed immediately when Blizzard indexed a secret line-color table and left `processingInfo` active, disabling later tooltips.
- These incidents establish three independent requirements: global isolation, no full widget template/cleanup path, and secret predicates before native data processing.


## Validation
- Headless contracts must prove: shared `GameTooltip` remains untouched; the native delegate cannot enter `GameTooltip_OnHide`; secret Aura instances and Aura spells never reach native processors; non-secret data retains exact native rendering; secret containers are rejected before inspection; opaque live title/description text survives without formatting reads; and stale leave events do not hide a replacement owner.
- In-game validation after a fresh reload remains mandatory because headless tests cannot model Blizzard taint propagation. Exercise addon Aura icons/bars out of combat and in combat, including short-lived buffs/debuffs, then hover world quests, delve entrances, Quick Join, chat links, action bars, and other widget-bearing tooltips. Later tooltips must remain functional and free of LsTweeks-attributed secret-value errors.
