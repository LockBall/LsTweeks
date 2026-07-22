# Tooltip Taint Fix Review (2026-07-21, commit b4b0f9d)

**Resolution (2026-07-21):** Both investigations are complete. Blizzard's
generated API docs expose `C_Secrets.ShouldSpellAuraBeSecret`, so the native
Aura spell fallback now requires that predicate to return explicit `false`
before calling `SetSpellByID`; secret or indeterminate spells continue to the
live opaque Aura renderer. Unauthenticated repository-wide path discovery is
available through GitHub's recursive tree API, and that workflow plus the
relevant generated API and tooltip-runtime sources are recorded in
`research_sources.md`. Regression tests cover the spell gate and preservation
of the live opaque title/description.

**Update:** this review was first written relying mainly on the project's own
tests and module-memory docs, which were added/updated in the same commit
being reviewed — that's circular evidence, since both could just encode
whatever mistake was made. Re-verified below against Blizzard's actual
FrameXML source (`Gethe/wow-ui-source`, the mirror this project's
`research_sources.md` already points at) and the raw stack trace in
`new_issue_condensed.md`, not the project's paraphrase of it.

## What broke
Full stack trace (`new_issue_condensed.md`), not just the top line:
```
[SharedTooltipTemplates.lua]:167: in function 'GameTooltip_AddColoredLine'
[TooltipDataHandler.lua]:348: in function 'AddLineDataText'
[TooltipDataHandler.lua]:329: in function 'ProcessLineData'
[TooltipDataHandler.lua]:315: in function 'ProcessLines'
[C]: in function 'securecallfunction'
...
[LsTweeks/functions/tooltip.lua]:282
[LsTweeks/modules/aura_frames/af_main.lua]:518
```
Locals confirm the tooltip at fault is `LsTweeksNativeTooltip`, and
`color=<secret table>`.

Confirmed independently against Blizzard's live source (not this project's
docs):
- `GameTooltip_AddColoredLine(tooltip, text, color, wrap, leftOffset)` calls
  `color:GetRGB()` with **no nil/secret check whatsoever**.
- `TooltipDataHandler.lua`'s `AddLineDataText` does
  `local leftColor = lineData.leftColor or NORMAL_FONT_COLOR` and passes that
  straight into `GameTooltip_AddColoredLine` — i.e. Blizzard's own tooltip
  data pipeline forwards a restricted aura's real `leftColor`/`rightColor`
  table unmodified.

So this crash happens **inside Blizzard's own code**, triggered purely by
calling the native `SetUnitAuraByAuraInstanceID` setter (via
`GameTooltipDataMixin`'s `ProcessLines`) on a secret aura. LsTweeks has no
opportunity to intercept or sanitize `color` partway through — by the time
`GameTooltip_AddColoredLine` runs, control is inside Blizzard's call stack.
The only fix that actually prevents this is **never calling that native
setter on a secret aura in the first place.**

## What changed (commit b4b0f9d)
`functions/tooltip.lua`:
- Native tooltip (`GetNativeTooltip`) rebuilt on `SharedTooltipArtTemplate` +
  `GameTooltipDataMixin` instead of full `GameTooltipTemplate`, keeping native
  `SetUnitAuraByAuraInstanceID`/`SetSpellByID` rendering but dropping the
  widget-container/`GameTooltip_OnHide` cleanup path implicated in the earlier
  `GameTooltip_ClearWidgetSet()` failures.
- New `ShowOpaqueAuraTooltip` / `get_opaque_aura_tooltip`: a second, data-mixin-free
  `SharedTooltipArtTemplate` tooltip for secret Aura instances. Live
  `leftText`/`rightText` strings are forwarded to `AddLine`/`AddDoubleLine`
  as-is (never read/concatenated by addon Lua), while color is only ever
  taken from a previously-cached *known-safe* palette (`get_known_opaque_color`),
  never from the live secret line's own `leftColor`/`rightColor` table. This
  is the direct fix for the `SharedTooltipTemplates.lua:167` crash.
- `ShowNativeAuraTooltip` now gates on `C_Secrets.ShouldUnitAuraInstanceBeSecret`
  returning explicit `false` before calling the true native setter; anything
  secret or indeterminate falls through to the opaque renderer instead.
- `HideNativeTooltip` extracted to `hide_tooltip_for_owner`, applied to both
  the native and opaque tooltips so leaving an Aura icon only hides the
  tooltip it actually owns.

`modules/aura_frames/af_main.lua`:
- Tooltip cache lookup/store split into identity-based helpers
  (`*_for_identity(aura_instance_id, spell_id)`) so both the per-icon prewarm
  and a new whole-scan prewarm can share the same cache without needing a
  live icon object.
- `show_aura_icon_tooltip` priority order: native (non-secret) →
  opaque-with-known-cached-colors → native spell-by-ID → opaque-plain →
  addon-owned cached/basic fallback. This matches the priority documented in
  `aura_frames.md` `## Aura Tooltips`.
- New `prewarm_scanned_aura_tooltip_cache`, called from `af_scan.lua`'s
  `unified_scan`, prewarms tooltip data for every entry in the full scanned
  Aura map (not just visible icons), capped at 2 failed attempts per key via
  `tooltip_scan_cache_attempts`, cleared on successful cache or on
  `clear_aura_tooltip_instance_cache`.

## Verification performed
- Read the full diff (`git show b4b0f9d`) against `functions/tooltip.lua`,
  `af_main.lua`, `af_scan.lua`.
- Cross-checked behavior against `aura_frames.md` `## Aura Tooltips` (updated
  in the same commit) — renderer order, secret-gate requirement, cache-key
  rules, and retry caps all match what the code does.
- Ran the headless suites:
  - `tooltip` suite: 9/9 pass, including new tests for the secret-gate check,
    the opaque renderer never reading forbidden fields (via a metatable that
    errors if touched), and the native tooltip's template/hide-script identity.
  - `af_ranges` suite: 32/32 pass, including new tests for scanned-map
    prewarm, capped-miss retries, and native/opaque tooltip delegate use in
    and out of combat.
- No other suites touch tooltip code; this is within the impact-selected
  validation policy.

## Assessment (revised after independent source check)
The actual fix for the reported crash is narrower than first described: the
new `C_Secrets.ShouldUnitAuraInstanceBeSecret` gate in `ShowNativeAuraTooltip`
(`functions/tooltip.lua:321-336`), which refuses the native
`SetUnitAuraByAuraInstanceID` path unless the check explicitly returns
`false`. That's what stops Blizzard's own `GameTooltip_AddColoredLine` from
ever running against a secret aura's color table — confirmed against
Blizzard's live FrameXML source, independent of this project's tests/docs.

The new `ShowOpaqueAuraTooltip` renderer is good defense-in-depth and correct
on its own terms (it never touches Blizzard's colored-line pipeline, uses the
addon's own `tooltip:AddLine`/`AddDoubleLine`, and only substitutes color from
a previously-cached known-safe palette) — but it is not itself what fixes the
reported `SharedTooltipTemplates.lua:167` crash, since that crash originates
one layer up, inside the native setter call, before the opaque renderer would
ever be reached. My first pass over-attributed the fix to the opaque
renderer because I leaned on the commit's own docs/tests instead of tracing
the actual Blizzard call chain.

Test coverage (`test_tooltip.lua`: "secret Aura data never enters the native
tooltip processor") does directly exercise the real fix (the secret gate),
so the regression guard is sound even though my original causal narrative
was off.

### Process note
When validating a taint/crash fix, trace the actual Blizzard call chain from
the raw stack trace first rather than trusting the fixing commit's own test
additions or module-memory updates, since those are written by the same
change under review and can encode the same mistaken assumption.
