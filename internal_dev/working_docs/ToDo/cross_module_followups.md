# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [ ] 1. User-created object deletion lifecycle — review Aura Frames custom-frame deletion and any future user-created objects. A deletion should remove runtime state, cached UI/control references, saved selection, and active overrides in one defined ownership path.
- [ ] 2. Mid-state feature activation — review event-gated features that can be enabled while their triggering state is already active. They should query current state and apply immediately rather than waiting for a future event; candidates include Aura Frames activity/fade settings and Player Frame out-of-combat fade behavior.
