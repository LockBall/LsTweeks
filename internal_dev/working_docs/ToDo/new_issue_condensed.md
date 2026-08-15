# Condensed Lua Errors

- Source: `internal_dev/working_docs/ToDo/new_issue.txt`
- Parsed records: 2
- Reported occurrences: 64
- Unique messages: 2
- Distinct stack variants: 2
- Locals: omitted; consult the source export when needed


## Error 1

```text
...Ons/LsTweeks/modules/aura_frames/af_logic_ticker.lua:151: attempt to get length of field 'icons' (a nil value)
```

- Reported occurrences: 63 across 1 record(s)
- Stack variants: 1
- Message origin: unknown
- Captured: Sat Aug 15 15:16:33 2026
- Project frames in captured stacks: yes
- Addons appearing in stacks: LsTweeks

### Common stack prefix

```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_logic_ticker.lua]:151: in function 'tick_visible_icons'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_logic_ticker.lua]:109: in function <...Ons/LsTweeks/modules/aura_frames/af_logic_ticker.lua:108>
```

### Stack variants

#### Variant 1: 63x; Sat Aug 15 15:16:33 2026
```text
(no caller tail; stack matches the common prefix)
```


## Error 2

```text
GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'LsTweeks'
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: unknown
- Captured: Sat Aug 15 15:23:19 2026
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

#### Variant 1: 1x; Sat Aug 15 15:23:19 2026
```text
(no caller tail; stack matches the common prefix)
```
