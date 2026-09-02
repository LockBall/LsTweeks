# Condensed Lua Errors

- Source: `raw.txt`
- Parsed records: 1
- Reported occurrences: 1
- Unique messages: 1
- Distinct stack variants: 1
- Locals: omitted; consult the source export when needed


## Error 1

```text
GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'LsTweeks'
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: unknown
- Captured: Mon Aug 17 18:49:58 2026
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_MawBuffs, Blizzard_ObjectiveTracker, Blizzard_SharedXML

### Common stack prefix

```text
[Interface/AddOns/Blizzard_MawBuffs/Blizzard_MawBuffs.lua]:4: in function 'ShouldShowMawBuffs'
[Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ScenarioObjectiveTracker.lua]:187: in function 'LayoutContents'
[Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua]:147: in function 'Update'
[Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua]:64: in function <...ectiveTracker/Blizzard_ObjectiveTrackerContainer.lua:49>
[tail call]: ?
[tail call]: ?
[Interface/AddOns/Blizzard_SharedXML/MixinUtil.lua]:341: in function <Interface/AddOns/Blizzard_SharedXML/MixinUtil.lua:340>
```

### Stack variants

#### Variant 1: 1x; Mon Aug 17 18:49:58 2026
```text
(no caller tail; stack matches the common prefix)
```
