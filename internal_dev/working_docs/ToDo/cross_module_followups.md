# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [x] 1. User-created object deletion lifecycle — Aura Frames custom-frame deletion already removes runtime frame/events/fades, DB entry, controls, and GUI selection; added custom aura scan-cache cleanup. Audio Volumes custom Quick Pick deletion already owns runtime restoration and UI-control cleanup. Apply this lifecycle check to future user-created objects.
- [ ] 2. Mid-state feature activation — review event-gated features that can be enabled while their triggering state is already active. They should query current state and apply immediately rather than waiting for a future event; candidates include Aura Frames activity/fade settings and Player Frame out-of-combat fade behavior.
