# Cross-Module Follow-Ups
Targeted checks discovered during active module reviews. Keep only unresolved patterns that could affect another module; delete this file when its items are resolved or rejected.

## Table of Contents
- [Priority Items](#priority-items)

## Priority Items
- [ ] 1. Secret-value guard completeness — review WoW API values that flow into addon comparisons, arithmetic, string construction, or table keys. Guard every potentially secret value before use, not only adjacent fields from the same API result.
- [ ] 2. Independent `OnUpdate` ownership — review frames whose `OnUpdate` scripts can be assigned by separate subsystems. Keep each owner on a dedicated driver frame or route them through an intentional multiplexer so one lifecycle cannot silently clear another callback.
