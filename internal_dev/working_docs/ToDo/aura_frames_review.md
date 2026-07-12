# Aura Frames Review
Active findings for `modules/aura_frames/`. Verified against the current code after the addon-wide review; remove this file when every remaining item is resolved, rejected, or deferred elsewhere.

## Table of Contents
- [Priority Queue](#priority-queue)
- [Deferred Work](#deferred-work)
- [Confirmed Deliberate](#confirmed-deliberate)

## Priority Queue
- [ ] 1. Tooltip lifecycle and cache bounds (`af_main.lua`)
  - [ ] a. Clear destroyed custom-frame display and tooltip-retry state — `destroy_custom_frame()` leaves `_display_count` and `_tooltip_cache_retry_pending`, allowing a scheduled retry to inspect stale icon data while the module remains enabled. Clear the display count, retry count, and pending flag during destruction.
  - [ ] b. Bound the runtime tooltip line cache — `_tooltip_data_lines_cache` stores one entry per aura instance ID for the session. Clear only `aura:<id>` entries on `PLAYER_ENTERING_WORLD`, retain reusable `spell:<id>` entries, and add regression coverage for eviction.
  - [ ] c. Avoid tooltip-key table allocation in prewarm — `get_aura_tooltip_cache_keys()` allocates a table and strings per displayed icon. Return bounded values or use safe reusable scratch state without weakening numeric-only key rules.

- [ ] 2. Defensive frame and scan behavior
  - [ ] a. Preserve explicit false per-frame settings (`af_logic_main.lua`) — bar mode and background enable use `x ~= nil and x or y`, so category-specific `false` can fall through to a future flat fallback. Use explicit nil selection.
  - [ ] b. Skip malformed aura records (`af_scan.lua`) — helpful and debuff loops stop at a missing `auraInstanceID`. The index already advances, so skip the record and continue scanning later entries.

- [ ] 3. Scan-path cleanup and targeted optimization (`af_scan.lua`)
  - [ ] a. Avoid rebuilding unchanged aura order keys — retain the existing key unless readable spell ID, name, or icon changes; preserve secret-value behavior.
  - [ ] b. Name the exact-GCD filter — `SetCooldown` ignores durations at or below `1.5`, while grey-state detection uses `GCD_GREY_THRESHOLD = 2.0`. Name the exact-GCD threshold and document the intentional distinction.
  - [ ] c. Remove unused `floor` and `format` cached globals.
  - [ ] d. Reuse `cache_timing()` child state — pass `state.category` to `queue_cooldown_viewer_refresh()` instead of fetching the state again.

- [ ] 4. Render and ticker pooling cleanup
  - [ ] a. Skip already-cleared pooled icons (`af_render.lua`) — bypass teardown only for objects already hidden and fully cleared; previously displayed cooldown, grey, count, and tooltip state must still clear.
  - [ ] b. Centralize the bar min/max cache helper — `af_render.lua` and `af_logic_ticker.lua` duplicate `set_bar_minmax_if_changed()` and its `_lstweeks_min_value/_lstweeks_max_value` contract. Move it to the Aura module table.

- [ ] 5. Layout ownership refactor (`af_logic_main.lua`, `af_icon_layout.lua`)
  - [ ] Derive frame height from layout-owned values instead of duplicated icon/bar padding literals. Require focused growth-anchor regression coverage because height, combat guards, and user positioning interact.

## Deferred Work
- [ ] CDM viewer-child scratch ownership — `_scratch_viewer_children` is safe while every caller consumes it synchronously. Revisit only with CDM work; per-call tables trade a small allocation cost for a looser ownership contract.
- [ ] Helpful scan-depth reduction — enabled CDM frames can increase helpful scan depth even though they render viewer children. Do not change without the Divine Protection CDM transition regression and in-game validation.
- [ ] Central `UNIT_AURA` dispatcher — enabled frames currently merge the same payload and queue separate buckets. Profile first; the established per-frame model is intentionally conservative around taint and frame ownership.

## Confirmed Deliberate
- Custom static entries now clear timer text during render, so the former pooled permanent-aura timer finding is resolved.
- Helpful and debuff expiration handling intentionally differs: debuffs always belong to the debuff path, while helpful expiration determines a category.
- Fixed login-size icon pools, display-signature skips, the `0.20s` event bucket, visible-icon tick range, Blizzard frame suppression, CDM alpha hiding, tooltip security flow, and OOC fade/hover behavior remain documented design decisions.
