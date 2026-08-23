# Condensed Lua Errors

- Source: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\internal_dev\working_docs\ToDo\error_batches\2026-08-23_140628_objective-tracker-securecall-recurrence\raw.txt`
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
- Captured: Sun Aug 23 10:07:20 2026
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

#### Variant 1: 1x; Sun Aug 23 10:07:20 2026
```text
(no caller tail; stack matches the common prefix)
```
