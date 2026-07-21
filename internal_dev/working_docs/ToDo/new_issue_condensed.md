# Condensed Lua Errors

- Source: `internal_dev/working_docs/ToDo/new_issue.txt`
- Parsed records: 8
- Reported occurrences: 15
- Unique messages: 2
- Distinct stack variants: 8
- Locals: omitted; consult the source export when needed


## Error 1

```text
Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua:491: attempt to compare a secret number value (execution tainted by 'LsTweeks')
```

- Reported occurrences: 14 across 7 record(s)
- Stack variants: 7
- Message origin: Blizzard UI (Blizzard_SharedXML)
- Captured: Tue Jul 21 17:28:07 2026 -> Tue Jul 21 17:30:46 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_SharedXML, Blizzard_UIWidgets, Blizzard_GameTooltip, Blizzard_SharedMapDataProviders, Bartender4, Blizzard_QuickJoin

### Common stack prefix

```text
[Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua]:491: in function <Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua:486>
[tail call]: ?
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:213: in function 'DefaultWidgetLayout'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:580: in function 'layoutFunc'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:606: in function 'UpdateWidgetLayout'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:295: in function 'UnregisterForWidgetSet'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:610: in function 'GameTooltip_ClearWidgetSet'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:407: in function <...AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua:393>
```

### Stack variants

#### Variant 1: 7x; Tue Jul 21 17:28:44 2026
```text
[C]: in function 'Hide'
[Interface/AddOns/Bartender4/libs/LibActionButton-1.0/LibActionButton-1.0.lua]:1111: in function <...er4/libs/LibActionButton-1.0/LibActionButton-1.0.lua:1103>
```

#### Variant 2: 2x; Tue Jul 21 17:28:40 2026
```text
[C]: in function 'Hide'
[Interface/AddOns/Blizzard_SharedMapDataProviders/SharedMapPoiTemplates.lua]:159: in function 'CheckHideTooltip'
[Interface/AddOns/Blizzard_SharedMapDataProviders/SharedMapPoiTemplates.lua]:172: in function <...ard_SharedMapDataProviders/SharedMapPoiTemplates.lua:169>
```

#### Variant 3: 1x; Tue Jul 21 17:28:07 2026
```text
[C]: in function 'Hide'
[Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIDataProvider.lua]:212: in function <...zzard_SharedMapDataProviders/AreaPOIDataProvider.lua:194>
```

#### Variant 4: 1x; Tue Jul 21 17:28:47 2026
```text
[C]: in function 'SetOwner'
[Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua]:88: in function 'GameTooltip_SetDefaultAnchor'
[Interface/AddOns/Bartender4/libs/LibActionButton-1.0/LibActionButton-1.0.lua]:2150: in function <...er4/libs/LibActionButton-1.0/LibActionButton-1.0.lua:2147>
[Interface/AddOns/Bartender4/libs/LibActionButton-1.0/LibActionButton-1.0.lua]:1085: in function <...er4/libs/LibActionButton-1.0/LibActionButton-1.0.lua:1083>
```

#### Variant 5: 1x; Tue Jul 21 17:28:54 2026
```text
(no caller tail; stack matches the common prefix)
```

#### Variant 6: 1x; Tue Jul 21 17:30:30 2026
```text
[C]: in function 'Hide'
[Interface/AddOns/Blizzard_QuickJoin/QuickJoinToast.lua]:381: in function <...terface/AddOns/Blizzard_QuickJoin/QuickJoinToast.lua:380>
[C]: ?
```

#### Variant 7: 1x; Tue Jul 21 17:30:46 2026
```text
[C]: in function 'Hide'
[*FloatingChatFrame.xml:319_OnLeave]:2: in function <[string "*FloatingChatFrame.xml:319_OnLeave"]:1>
```


## Error 2

```text
.../Mainline/Blizzard_UIWidgetTemplateTextWithState.lua:35: attempt to perform arithmetic on local 'textHeight' (a secret number value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_UIWidgetTemplateTextWithState.lua)
- Captured: Tue Jul 21 17:28:03 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_UIWidgets, Blizzard_GameTooltip, Blizzard_FrameXMLUtil, Blizzard_SharedMapDataProviders

### Common stack prefix

```text
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateTextWithState.lua]:35: in function 'Setup'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:526: in function 'ProcessWidget'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:562: in function 'ProcessAllWidgets'
[Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua]:275: in function 'RegisterForWidgetSet'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:598: in function 'GameTooltip_AddWidgetSet'
[Interface/AddOns/Blizzard_FrameXMLUtil/AreaPoiUtil.lua]:44: in function <...terface/AddOns/Blizzard_FrameXMLUtil/AreaPoiUtil.lua:3>
[tail call]: ?
[Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIDataProvider.lua]:166: in function <...zzard_SharedMapDataProviders/AreaPOIDataProvider.lua:159>
```

### Stack variants

#### Variant 1: 1x; Tue Jul 21 17:28:03 2026
```text
(no caller tail; stack matches the common prefix)
```
