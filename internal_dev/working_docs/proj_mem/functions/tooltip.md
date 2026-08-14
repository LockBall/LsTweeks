# Tooltip Function Memory
Durable architecture and safety contracts for the shared tooltip subsystem in `functions/tooltip.lua`.


## Table of Contents
- [Ownership And Public API](#ownership-and-public-api)
- [Renderer Architecture](#renderer-architecture)
- [Secret Data Contract](#secret-data-contract)
- [Incident Evidence](#incident-evidence)
- [Validation](#validation)


## Ownership And Public API
- `functions/tooltip.lua` is the only project-owned tooltip factory and secret-tooltip-data boundary. Route general help, guarded line rendering, and tooltip hiding through it instead of creating module-local tooltip machinery.
- Owned display: `addon.CreateOwnedTooltip()`, `addon.ShowOwnedTooltipLines()`, `addon.ShowOwnedTooltip()`, `addon.AttachTooltip()`, and `addon.HideOwnedTooltip()`.
- Guarded conversion: `addon.CopySafeTooltipDataLines()` converts readable `C_TooltipInfo` data into the owned line schema after validating every container and value.
- Restricted display defaults to guarded copied or addon-authored basic lines on the owned plain frame. `/lst tooltipdebug native-on` enables a reload-scoped experiment using Blizzard's global secure Aura setter; `native-off` restores the default immediately.
- Diagnostics: `/lst tooltipdebug` prints a 64-event safety trace with wall-clock and session-relative time, combat state, coarse instance context, instance/combat transitions, native experiment state, and route attempts/completions. `/lst tooltipdebug mark` adds a boundary without discarding earlier evidence; `clear` remains a non-destructive alias. It stores no zone, Aura ID/name, tooltip text/lines, or raw tooltip data.
- Tests: `test_tooltip.lua` owns factory/data-boundary contracts; module suites own caller order and feature-specific fallback behavior.


## Renderer Architecture
- Addon-authored and copied-safe lines use one plain `Frame` with `TooltipBackdropTemplate`, native tooltip fonts, bounded content sizing, quadrant anchoring, and screen clamping. It deliberately has no `GameTooltip` data or widget machinery.
- Default Aura hover is deterministic: copied-safe cached lines when available, otherwise addon-authored name/duration lines, always on the owned plain frame.
- The native experiment mirrors Blizzard/community usage exactly: set the owner on global `GameTooltip`, call `SetUnitAuraByAuraInstanceID(unit, auraInstanceID)` directly, and let the secure accessor fetch/process/show the data. Do not call `C_TooltipInfo`, create another `GameTooltip`, wrap the setter in `pcall`/`securecallfunction`, inspect rendered lines, or call `Show()`.
- No LsTweeks `GameTooltip` is created for Aura data. Custom full/lightweight templates and direct opaque text forwarding are known-unsafe paths.


## Secret Data Contract
- Only test live Aura display through Blizzard's global secure `SetUnitAuraByAuraInstanceID` accessor with untouched unit/Aura-instance arguments. Never fetch and forward live values through `AddLine`/`AddDoubleLine` or process them on an addon-created `GameTooltip`.
- `CopySafeTooltipDataLines()` validates outer data, `lines`, each line, text, color tables/components, and wrap flags before field-dependent use or caching. Validate every containing table before field, length, or index access; individual spells may remain secret outside combat.
- Never inspect rendered native lines or use `securecallfunction`/`pcall` as a taint workaround. The accessor itself owns secure delegation; extra wrappers depart from the supported path and can hide a partially processed tooltip failure.
- Error suppression is acceptable only when the rendering path remains usable and the failure cannot wedge later tooltips. Hiding reports while tooltip processing remains broken is not recovery.
- Research sources for secret predicates, tooltip processing, templates, and private Aura behavior live in `research_sources.md` `## Blizzard UI Source`.


## Incident Evidence
- 2026-06-28: Area POI `UIWidgetTemplateTextWithStateMixin:Setup()` failed on secret `textHeight` after tooltip contamination.
- 2026-07-01 and 2026-07-03: world quest `EmbeddedItemTooltip_UpdateSize()` failed on secret width; Area POI status-bar partitions failed on secret `barWidth`.
- 2026-07-19: an isolated tooltip plus `securecallfunction` and rendered-line inspection still contaminated later map POI layout.
- 2026-07-20: the then-current shared `GameTooltip` wrapper preceded delayed Area POI failures, but it used a captured method plus `pcall`, manual `Show()`, and incomplete session isolation. Treat it as evidence against that wrapper, not against Blizzard's direct secure accessor.
- 2026-07-21: a dedicated full-template tooltip failed later in `GameTooltip_ClearWidgetSet`; a lightweight unguarded Aura setter then failed immediately when Blizzard indexed a secret line-color table and left `processingInfo` active, disabling later tooltips.
- 2026-08-01: with opaque forwarding disabled, the isolated `LsTweeksNativeTooltip` processed a secret Aura text color table after multiple OOC `native-aura` hovers. Predicate-approved native Aura data is therefore unsafe too.
- 2026-08-10: after days without a visible failure, the isolated data-mixin-free opaque renderer still caused Area POI `InitPartitions()` to receive a secret `barWidth` while tainted by LsTweeks. Direct live-text forwarding is unsafe even without native Aura processing.
- These incidents establish custom tooltip processing as unsafe. Blizzard's direct secure global accessor remains a plausible supported path and must pass a fresh-reload controlled experiment before becoming the default.


## Validation
- Headless contracts must prove: the default route leaves shared `GameTooltip` untouched; the experiment makes exactly one direct secure-setter call with no addon `C_TooltipInfo`, custom `GameTooltip`, or manual `Show()`; secret containers are rejected before inspection on the default route; and copied/basic fallbacks remain usable.
- In-game native experiment: start with a fresh reload, run `/lst tooltipdebug native-on`, exercise addon Aura icons/bars out of combat and in combat including first-seen short-lived effects, then hover world quests, delve entrances, Quick Join, chat links, action bars, and other widget-bearing tooltips. Capture `/lst tooltipdebug` after any incident. Run `native-off` or reload to restore the control route. Headless tests cannot model Blizzard taint propagation.
