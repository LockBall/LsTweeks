# Condensed Lua Errors

- Source: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\internal_dev\working_docs\ToDo\error_batches\2026-08-31_205421_blizzard-damage-meter-secret-duration\raw.txt`
- Parsed records: 1
- Reported occurrences: 1
- Unique messages: 1
- Distinct stack variants: 1
- Locals: omitted; consult the source export when needed


## Error 1

```text
...ns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua:930: attempt to compare local 'durationSeconds' (a secret number value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_DamageMeter)
- Captured: Mon Aug 31 20:52:35 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_DamageMeter

### Common stack prefix

```text
[Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua]:930: in function 'SetSessionDuration'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua]:940: in function 'ShowSessionTimerFromCombatSession'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua]:945: in function 'ShowSessionTimer'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua]:961: in function 'UpdateSessionTimerState'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeter.lua]:204: in function 'func'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeter.lua]:219: in function 'ForEachSessionWindow'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeter.lua]:204: in function 'UpdateSessionTimerState'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeter.lua]:200: in function 'UpdateShownState'
[Interface/AddOns/Blizzard_DamageMeter/DamageMeter.lua]:90: in function <...nterface/AddOns/Blizzard_DamageMeter/DamageMeter.lua:88>
```

### Stack variants

#### Variant 1: 1x; Mon Aug 31 20:52:35 2026
```text
(no caller tail; stack matches the common prefix)
```
