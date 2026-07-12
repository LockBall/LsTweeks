# Aura Frames Review
Active findings for `modules/aura_frames/`. Verified against the current code after the addon-wide review; remove this file when every remaining item is resolved, rejected, or deferred elsewhere.

## Table of Contents
- [Priority Queue](#priority-queue)
- [Deferred Work](#deferred-work)
- [Confirmed Deliberate](#confirmed-deliberate)

## Priority Queue
- [x] 1. Tooltip lifecycle and cache bounds (`af_main.lua`)
  - [x] a. Clear destroyed custom-frame display and tooltip-retry state.
  - [x] b. Bound the runtime tooltip line cache by clearing `aura:<id>` entries on `PLAYER_ENTERING_WORLD` while retaining reusable `spell:<id>` entries.
  - [x] c. Avoid tooltip-key table allocation in prewarm with bounded key returns.

- [x] 2. Defensive frame and scan behavior
  - [x] a. Preserve explicit false per-frame runtime settings with explicit nil fallback selection.
  - [x] b. Skip malformed helpful and debuff records while continuing later scan entries.
  - [x] c. Preserve explicit false profile settings through the cross-module profile-import fix.

- [x] 3. Scan-path cleanup and targeted optimization (`af_scan.lua`)
  - [x] a. Rebuild Aura order keys only when readable identity changes or secret data requires the conservative path.
  - [x] b. Name the exact-GCD filter and document its intentional distinction from grey-state detection.
  - [x] c. Remove unused `floor` and `format` cached globals.
  - [x] d. Reuse `cache_timing()` child state for the queued category.

- [x] 4. Render and ticker pooling cleanup
  - [x] a. Skip teardown only for fully-cleared hidden pooled icons.
  - [x] b. Centralize the bar min/max cache helper on the Aura module table.

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
