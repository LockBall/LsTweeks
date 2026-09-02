# Condensed Lua Errors

- Source: `raw.txt`
- Parsed records: 1
- Reported occurrences: 1
- Unique messages: 1
- Distinct stack variants: 1
- Locals: omitted; consult the source export when needed


## Error 1

```text
...ce/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua:1688: attempted to index a table that cannot be accessed while tainted (execution tainted by 'LsTweeks')
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_CooldownViewer)
- Captured: Sun Aug 16 14:09:48 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_CooldownViewer

### Common stack prefix

```text
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:1688: in function 'RegisterAuraInstanceIDItemFrame'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:255: in function 'OnAuraInstanceInfoSet'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua]:356: in function 'SetAuraInstanceInfo'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua]:741: in function 'RefreshAuraInstance'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:1256: in function 'RefreshData'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:189: in function 'OnUnitAuraAddedEvent'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:1836: in function 'OnUnitAura'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:1777: in function 'OnEvent'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:2168: in function 'OnEvent'
[Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua]:2245: in function <...ce/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua:2244>
```

### Stack variants

#### Variant 1: 1x; Sun Aug 16 14:09:48 2026
```text
(no caller tail; stack matches the common prefix)
```
