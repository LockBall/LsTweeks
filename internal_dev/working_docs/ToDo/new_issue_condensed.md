# Condensed Lua Errors

- Source: `internal_dev/working_docs/ToDo/new_issue.txt`
- Parsed records: 1
- Reported occurrences: 2
- Unique messages: 1
- Distinct stack variants: 1
- Locals: omitted; consult the source export when needed


## Error 1

```text
...UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua:1030: attempt to perform arithmetic on local 'barWidth' (a secret number value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 2 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_UIWidgetTemplateBase.lua)
- Captured: Sun Jul 26 18:16:47 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_UIWidgets, Blizzard_GameTooltip, Blizzard_FrameXMLUtil, Blizzard_SharedMapDataProviders

### Common stack prefix

```text
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua]:1030: in function 'InitPartitions'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua]:847: in function 'Setup'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateStatusBar.lua]:109: in function 'Setup'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:526: in function 'ProcessWidget'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:562: in function 'ProcessAllWidgets'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:275: in function 'RegisterForWidgetSet'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:598: in function 'GameTooltip_AddWidgetSet'
[Interface/AddOns/Blizzard_FrameXMLUtil/AreaPoiUtil.lua]:44: in function <...terface/AddOns/Blizzard_FrameXMLUtil/AreaPoiUtil.lua:3>
[tail call]: ?
[Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIDataProvider.lua]:166: in function 'OnMouseEnter'
[Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIEventDataProvider.lua]:76: in function <..._SharedMapDataProviders/AreaPOIEventDataProvider.lua:74>
```

### Stack variants

#### Variant 1: 2x; Sun Jul 26 18:16:47 2026
```text
(no caller tail; stack matches the common prefix)
```
