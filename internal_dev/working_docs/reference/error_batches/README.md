# Lua Error Batch Archive

Processed WoW Lua error exports live here with their condensed reports. Directory
state records the current assessment without changing the historical raw export:

- `unreviewed/`: newly archived batches awaiting assessment
- `monitoring/`: unresolved or insufficiently attributed incidents that need new
  recurrence evidence before a safe change can be identified
- `resolved/`: incidents tied to a removed unsafe path, completed mitigation, and
  current durable implementation contract

Moving a batch between states requires updating this index. A recurrence of a
resolved signature enters `unreviewed` as a new dated batch; do not silently
reclassify the historical evidence.

## Monitoring

### Blizzard Damage Meter secret duration

- Batch: `monitoring/2026-08-31_205421_blizzard-damage-meter-secret-duration/`
- Assessment: one occurrence with explicit LsTweeks taint attribution, but only
  Blizzard Damage Meter frames in the captured stack and no direct LsTweeks
  Damage Meter integration found in the repository.
- Next evidence: if it recurs, preserve a fresh batch and correlate it with the
  active LsTweeks feature path and preceding interaction. The existing batch is
  insufficient to identify a safe code change.

## Resolved

### Tooltip secret-value taint history

- Batch: `resolved/2026-08-02_174938_tooltip-taint-history/`
- Resolution: unsafe custom native-tooltip processing and live-text forwarding
  paths were retired. Current tooltip ownership and Secret Value boundaries are
  recorded in `../../proj_mem/functions/tooltip.md`.

### Objective Tracker / Maw Buffs secret-Aura taint

- Batches:
  - `resolved/2026-08-15_102635_objective-tracker-secret-aura-taint/`
  - `resolved/2026-08-16_151225_maw-buffs-secret-aura-taint/`
  - `resolved/2026-08-17_162645_maw-buffs-secret-aura-taint-recurrence/`
  - `resolved/2026-08-17_185132_void-incursion-maw-buffs-secret-aura-taint/`
  - `resolved/2026-08-23_140628_objective-tracker-securecall-recurrence/`
- Resolution: addon-driven native Objective Tracker collapse tainted Blizzard
  section state consumed by later Scenario layout. That path was rejected and
  replaced by the visibility-only fallback documented in
  `../../proj_mem/modules/objectives.md`.

### Aura Frames managed ordering and CDM viewer taint

- Batches:
  - `resolved/2026-08-16_140718_cdm-unit-aura-order-taint/`
  - `resolved/2026-08-16_142606_cdm-forbidden-viewer-table-taint/`
- Resolution: managed preset maps bypass secret-sensitive unit-Aura ordering,
  and CDM transport no longer walks or hooks Blizzard viewer children. The
  durable boundaries and regression contracts live in
  `../../proj_mem/modules/aura_frames.md`.

### Managed Aura frame background forbidden anchor

- Batch: `resolved/2026-08-24_163652_managed-frame-bg-forbidden-anchor/`
- Resolution: managed Icon Mode backgrounds use container-owned peer regions and
  do not anchor safe owner-level textures to forbidden AuraContainer layout. The
  current geometry contract lives in `../../proj_mem/modules/aura_frames.md`.
