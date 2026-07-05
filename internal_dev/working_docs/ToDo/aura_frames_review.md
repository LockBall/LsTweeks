# Aura Frames Review Findings 2026-07-04
Unprompted-mistake and optimization review of `modules/aura_frames/`. Full reads: `af_scan.lua`, `af_render.lua`, `af_logic_main.lua`, `af_logic_ticker.lua`, `af_logic_native_visibility.lua`, `af_functions.lua`, `af_main.lua`, `af_icon_layout.lua`, `af_profiles.lua`, `af_test_aura.lua`, `af_screen_grid.lua`. Partial: `af_gui_frame_builders.lua` (frame panel section). Not reviewed: `af_gui.lua`, `af_gui_tree.lua`, `af_debug_outlines.lua`, rest of `af_gui_frame_builders.lua`. Items are ranked within each section; strike or annotate items as they are resolved or rejected.


## Table of Contents
- [Current Review State](#current-review-state)

- [Recommended Work Order](#recommended-work-order)

- [Potential Bugs To Verify](#potential-bugs-to-verify)

- [Latent Traps](#latent-traps)

- [Optimization Candidates](#optimization-candidates)

- [Minor Cleanups](#minor-cleanups)

- [Reviewed And Confirmed Deliberate](#reviewed-and-confirmed-deliberate)


## Current Review State
- 2026-07-04 skeptical pass: no item has been rejected yet. The first implementation batch should be narrow behavior fixes, then low-risk defensive cleanup. Potential Bug 2 is a valid long-session risk but needs a deliberately bounded cache policy before implementation.

- Defer Optimization Candidates 3 and 4 unless Aura Frames profiling reopens or an in-game behavior bug gives a narrower target. Both overlap module-memory warnings about CDM regression risk and central dispatcher/profile gating.

- Minor Cleanups are valid, but should be batched only after behavior fixes unless the touched code already makes them cheap.


## Recommended Work Order
1. Potential Bug 1: stale timer text on pooled icon reuse.
   - Reasoning: Most concrete user-visible bug, clearly reachable in custom HELPFUL frames, and the fix should be local to timer/bar clearing in `af_render.lua`.

2. Potential Bug 4: destroyed custom frame cleanup.
   - Reasoning: Also narrow and low-risk. It prevents queued tooltip prewarm retries from reading stale destroyed-frame state, and should only require clearing runtime fields during `destroy_custom_frame()`.

3. Latent Trap 1: explicit nil fallback for false values.
   - Reasoning: Simple defensive cleanup that preserves current behavior while preventing future flat fallback keys from overriding intentional per-frame `false` settings.

4. Potential Bug 3: align `DoesAuraHaveExpirationTime` handling.
   - Reasoning: Valid inconsistency, but secret-value behavior is subtle. Do it after the narrower fixes so it gets focused review in `af_scan.lua`.

5. Latent Trap 3: skip missing aura instance IDs instead of breaking scan loops.
   - Reasoning: Defensive and small, but it touches scan loop behavior for both helpful and debuff passes. Pair with Potential Bug 3 if already editing that area.

6. Potential Bug 2: bound tooltip line cache.
   - Reasoning: Valid long-session memory risk, but needs policy first: cap size, aura-key-only eviction, or wipe aura keys on world enter. Avoid mixing a cache-policy decision into the first behavior-fix batch.

7. Optimization Candidates 1, 2, and 5.
   - Reasoning: Plausible local wins, but not correctness fixes. Handle only after behavior work passes validation.

8. Minor Cleanups 1, 3, 4, and 5.
   - Reasoning: Straightforward cleanup that is safe to batch after the main fixes, especially when already touching `af_scan.lua`, `af_render.lua`, or `af_logic_ticker.lua`.

9. Minor Cleanup 2: derive frame height from layout-owned constants.
   - Reasoning: Valid ownership issue, but it has higher regression risk because height changes interact with growth anchoring, combat guards, and user-positioning behavior.

10. Latent Trap 2 and Optimization Candidates 3 and 4.
    - Reasoning: Defer unless CDM work or Aura Frames profiling reopens. These touch behavior that module memory explicitly treats as regression-prone or profile-gated.


## Potential Bugs To Verify
1. Stale timer text on pooled icon reuse for zero-duration entries in non-static frames. `update_aura_timer_and_bar()` (`af_render.lua` ~562-581) has no else branch: when `remaining` is nil, there is no `cooldown_duration`, and `entry.duration == 0`, nothing clears `obj.time_text`, so the previous occupant's countdown can persist under a permanent aura. Reachable in a custom frame whose filter matches both timed and permanent buffs (permanent classifies `static` but renders in the custom frame, so `is_static_frame` is false). Ticker likely does not recover it either: `tick_visible_icons()` computes `remaining = nil` for such icons and only clears on `remaining == 0`. In-game check: custom HELPFUL frame, let a countdown icon slot get taken over by a permanent buff, watch for a frozen timer string.
   - Status: Valid. Code confirms custom permanent auras classify as `static` for timer behavior while the owning frame is not the preset static frame, so no current branch clears reused timer text when duration is zero/nil.

2. Session-unbounded tooltip line cache. `M._tooltip_data_lines_cache` (`af_main.lua` ~377) is keyed by `aura:<auraInstanceID>` and `spell:<spellID>`; aura instance IDs increase forever, so long sessions accumulate one lines-table per aura application. Consider wiping aura-keyed entries on `PLAYER_ENTERING_WORLD` (spell-keyed entries make re-warm cheap) or a simple count cap with full wipe.
   - Status: Valid risk. Cache is runtime-only and documented as clearing on reload/logout, but there is currently no session cap or aura-key eviction. Pick a simple cap/wipe policy before changing this.

3. Secret-boolean handling differs between scan passes. Helpful pass (`af_scan.lua` ~885) maps non-boolean `DoesAuraHaveExpirationTime` to unknown (`nil`); debuff pass (~971) checks `type(expires) ~= "boolean"` first and maps it to `false`, which also makes its `issecretvalue` elseif unreachable unless `type()` of a secret boolean returns "boolean". Decide the intended semantics once and align both passes (or comment why they differ).
   - Status: Valid. The debuff path currently treats non-boolean as `false` while helpful treats it as unknown; this is inconsistent even if readable debuffs ultimately belong to the debuff frame.

4. `destroy_custom_frame()` (`af_main.lua` ~1048) leaves `frame._display_count` set and does not clear `_tooltip_cache_retry_pending`; a queued `prewarm_aura_tooltip_cache` retry can run against the destroyed frame's stale icon metadata. Harmless-looking wasted work; set `_display_count = 0` during destroy.
   - Status: Valid. Destroy hides/unregisters the frame but does not clear display count or tooltip retry flags before possible queued retry callbacks.


## Latent Traps
1. Falsy-fallback `x ~= nil and x or y` pattern: `resolve_runtime_config()` bar_mode (`af_logic_main.lua:39`) and `is_bg_enabled` (`af_logic_main.lua:502`). An explicitly-false per-category value falls through to the flat fallback key. Currently benign because the preset DB has no flat `bar_mode`/`bg` keys, but any future flat key silently overrides false. Replace with an explicit nil check.
   - Status: Valid. Low-risk cleanup; preserves current behavior while removing a future false-value trap.

2. `_scratch_viewer_children` reuse contract (`af_scan.lua:346`) requires every caller to finish consuming before any other code path calls `copy_viewer_children()`. Today safe because the hook-profile refresh is deferred (`defer_zero`), but the invariant is only a comment. If CDM work reopens, consider per-callsite scratch tables; the allocation saved is small.
   - Status: Valid but defer. Current code consumes synchronously; change only with other CDM work.

3. Helpful scan loop aborts on `if not iid then break end` (`af_scan.lua:863`); a single aura record missing `auraInstanceID` would silently truncate the whole scan rather than skip. Probably unreachable, but a skip (`i` already incremented) is strictly safer than a break.
   - Status: Valid defensive cleanup. Same issue exists in the debuff scan path.


## Optimization Candidates
1. `update_entry()` recomputes `make_order_key()` (string concat + tostring x3) for every aura on every scan (`af_scan.lua:152`), and combat scans run every 0.2s. Identity fields rarely change for an existing entry; skip recompute when `spell_id`, `name`, `icon` are unchanged from the entry's current values. Likely the cheapest real allocation win in the scan path.
   - Status: Valid candidate. Keep narrow and avoid changing ordering semantics for secret values.

2. `hide_unused_icons()` (`af_render.lua:729`) unconditionally resets ~8 fields and calls `Hide()` on every unused pooled icon on every non-skipped render; with the default 20-icon pool and 3 shown that is 17 no-op teardowns per render. Skip icons already cleared (e.g. guard on `obj.aura_index == nil and not obj:IsShown()`).
   - Status: Valid candidate. Ensure the guard still clears previously shown cooldown/grey/count state before skipping.

3. Helpful scan depth includes CDM and disabled frames. `get_max_icons_for_frame_defs()` (`af_scan.lua:788`) takes the max `max_icons_*` across all FRAME_DEFS, so raising a CDM frame's Max Icons deepens the buff scan even though CDM frames render from viewer children, not scan buckets. Restricting to enabled non-CDM defs is possible but changes `M._aura_map` coverage that the CDM active-aura path reads first; `build_cdm_active_aura_entry()` fallback covers misses. Only do this with the regression test from module memory (Divine Protection cooldown transition) in the loop.
   - Status: Valid but deferred. Module memory explicitly keeps CDM transition behavior as a regression risk; do not change scan depth without in-game CDM coverage.

4. Per-frame UNIT_AURA fan-out: every enabled frame runs `merge_aura_info()` on the same payload and schedules its own `C_Timer.After` bucket (`af_main.lua:885-931`). The scan itself dedupes via the dirty flag, so cost is merge + timer churn x frame count. Module memory already gates a central dispatcher behind profile evidence; this is the first candidate if AF profiling reopens, not something to do now.
   - Status: Valid but deferred. Matches module-memory guidance to profile before introducing a central dispatcher.

5. `get_aura_tooltip_cache_keys()` (`af_main.lua:267`) allocates a table plus key strings per icon per prewarm pass; prewarm runs at the end of every render. Return two values or reuse a scratch table.
   - Status: Valid candidate, but keep numeric-only key rules from module memory.


## Minor Cleanups
1. Duplicate `set_bar_minmax_if_changed()` in `af_render.lua:272` and `af_logic_ticker.lua:17`; both maintain the same `_lstweeks_min_value/_lstweeks_max_value` cache contract. Hoist one copy onto `M` so the contract lives in one place.
   - Status: Valid.

2. Frame-height math in `update_auras()` (`af_logic_main.lua:478-495`) duplicates layout constants (`12`, `14`, `18`, `32`, `44` literals) that `af_icon_layout.lua` owns via `get_bar_layout_params()` and `_layout_cache`. Violates the layout-constants-in-one-place rule; derive the height math from the layout params/cache.
   - Status: Valid, but higher regression risk than it looks because height changes interact with growth anchoring and combat/user-position guards.

3. Two unlabeled GCD thresholds in `af_scan.lua`: `duration <= 1.5` in the SetCooldown hook (line 539) vs `GCD_GREY_THRESHOLD = 2.0` (line 17). If the difference is intentional (hook filters exact GCD, grey check adds margin), name the 1.5 constant and comment the distinction.
   - Status: Valid.

4. Unused cached locals in `af_scan.lua`: `floor` (line 9) and `format` (line 16).
   - Status: Valid.

5. `cache_timing()` (`af_scan.lua:517-530`) calls `get_cd_child_state(child)` twice; reuse the `state` local for the `queue_cooldown_viewer_refresh` category read.
   - Status: Valid.


## Reviewed And Confirmed Deliberate
Checked against module memory and code comments; do not re-flag without new evidence.
- Icon pool fixed at login size; Max Icons slider prints a /reload notice (`af_gui_frame_builders.lua:926,993`). Optional future improvement: grow the pool lazily out of combat instead of requiring reload.

- Conservative display-signature render skip, 0.20s `aura_event_bucket`, visible-icon tick range, and no central aura dispatcher: all profile-backed decisions in `modules/aura_frames.md`.

- Blizzard BuffFrame/DebuffFrame suppression via alpha/mouse only, CDM viewers alpha-hidden not `Hide()`, weak-table child state instead of fields on Blizzard frames: taint-driven, documented.

- Tooltip flow (securecallfunction rich render, line-cache fallback, numeric-only cache keys) matches the taint history in module memory.

- `PLAYER_REGEN_DISABLED` tooltip prewarm relies on `InCombatLockdown()` still being false during that event; correct per WoW event ordering.

- OOC fade signature early-exit, hover restore ticker only when fade is enabled, and `try_cancel_aura_icon` cheap-reject ordering all match their design notes.
