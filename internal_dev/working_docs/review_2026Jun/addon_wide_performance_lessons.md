# Addon-Wide Performance Lessons

## Skyriding Vigor Lesson

The Skyriding Vigor review showed that repeated "cheap" setup work can dominate
when it runs at progress/ticker cadence. Before optimization, the active fill
progress path rebuilt style/render context on every progress tick. After moving
that setup to the refresh path and reusing slot-local render state, the focused
profile changed materially:

- `sv.update_filling_slot_progress`: 4.311 -> 0.735 sv_msps.

- `sv.get_render_context`: 18.40 -> 2.18 sv_calls/sec, matching refresh cadence
  instead of progress cadence.

- Style/atlas helpers such as `sv.get_bar_style`, `sv.get_frame_atlas`, and
  `sv.get_style_layout_table` dropped roughly to refresh cadence as well.

The important design point was not "cache everything." It was identifying the
mutability boundary first: real in-flight settings changes are rejected, while
Fill Test remains editable only as a controlled simulated state. Starting real
flight stops Fill Test and re-locks settings. That made it safe for the hot
progress path to reuse render state prepared by the normal refresh path.

## Principles For Other Modules

1. Identify hot loops by cadence, not just by individual call cost: frame updates,
   tickers, aura scans, combat event batches, timer updates, and repeated layout
   refreshes.

2. Look for repeated setup work inside those loops: DB reads, default application,
   style validation, layout-table lookup, atlas lookup, option normalization,
   control sync, sorting, filtering, and table creation.

3. Move stable setup to a lower-frequency path where possible: initialization,
   settings mutation, profile switch, event-bucket refresh, full render pass, or
   explicit invalidation.

4. Reuse resolved state locally before introducing broad cache systems. Prefer
   pass-local context, object-local render state, or existing module state over a
   global cache unless invalidation is already clear.

5. Make mutability boundaries explicit. If a setting or profile can change while
   the hot loop is active, either block that edit, force a full refresh, or define
   a targeted invalidation path.

6. Verify shape changes in the profiler. A good optimization should move helper
   calls from hot-loop cadence to setup/refresh cadence, not just slightly lower
   the total row time.

## Review Checklist

- Does the module have an always-running or active-only ticker?

- Does the hot path repeatedly call settings/style/profile/default helpers?

- Are GUI/control sync calls happening during runtime refresh when nothing
  user-facing can change?

- Can a refresh pass compute context once and pass it through child updates?

- Can per-frame/per-slot/per-button state hold the resolved values the hot path
  needs?

- Is there a clear rule for when settings/profile edits are allowed while the
  runtime path is active?

- Did the profile confirm helper calls dropped to the intended cadence?
