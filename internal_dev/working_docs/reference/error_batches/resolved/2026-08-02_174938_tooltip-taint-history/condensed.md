# Condensed Lua Errors

- Source: `raw.txt`
- Parsed records: 9
- Reported occurrences: 12
- Unique messages: 4
- Distinct stack variants: 7
- Locals: omitted; consult the source export when needed


## Error 1

```text
...AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua:764: attempt to perform arithmetic on a secret number value (execution tainted by 'LsTweeks')
```

- Reported occurrences: 8 across 6 record(s)
- Stack variants: 4
- Message origin: Blizzard UI (Blizzard_GameTooltip)
- Captured: Sat Aug  1 10:23:15 2026 -> Sat Aug  1 12:31:12 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_GameTooltip, Blizzard_FrameXMLUtil, Blizzard_UIPanels_Game, Blizzard_SharedMapDataProviders

### Common stack prefix

```text
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:764: in function 'EmbeddedItemTooltip_UpdateSize'
```

### Stack variants

#### Variant 1: 5x; Sat Aug  1 12:31:12 2026
```text
[*GameTooltip.xml:96_OnSizeChanged]:1: in function <[string "*GameTooltip.xml:96_OnSizeChanged"]:1>
[C]: in function 'GetWidth'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:764: in function 'EmbeddedItemTooltip_UpdateSize'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:941: in function 'EmbeddedItemTooltip_SetCurrencyByID'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:932: in function 'QuestUtils_AddQuestCurrencyRewardsToTooltip'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:786: in function 'QuestUtils_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:209: in function 'GameTooltip_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:737: in function 'GameTooltip_AddQuest'
[Interface/AddOns/Blizzard_UIPanels_Game/Mainline/WorldMapFrame.lua]:176: in function 'TaskPOI_OnEnter'
[Interface/AddOns/Blizzard_SharedMapDataProviders/WorldQuestDataProvider.lua]:421: in function <...rd_SharedMapDataProviders/WorldQuestDataProvider.lua:420>
```

#### Variant 2: 1x; Sat Aug  1 10:23:15 2026
```text
[*GameTooltip.xml:96_OnSizeChanged]:1: in function <[string "*GameTooltip.xml:96_OnSizeChanged"]:1>
[C]: in function 'GetWidth'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:764: in function 'EmbeddedItemTooltip_UpdateSize'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:847: in function 'EmbeddedItemTooltip_SetItemByQuestReward'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:823: in function 'QuestUtils_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:209: in function 'GameTooltip_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:737: in function 'GameTooltip_AddQuest'
[Interface/AddOns/Blizzard_UIPanels_Game/Mainline/WorldMapFrame.lua]:176: in function 'TaskPOI_OnEnter'
[Interface/AddOns/Blizzard_SharedMapDataProviders/WorldQuestDataProvider.lua]:421: in function <...rd_SharedMapDataProviders/WorldQuestDataProvider.lua:420>
```

#### Variant 3: 1x; Sat Aug  1 10:23:15 2026
```text
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:847: in function 'EmbeddedItemTooltip_SetItemByQuestReward'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:823: in function 'QuestUtils_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:209: in function 'GameTooltip_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:737: in function 'GameTooltip_AddQuest'
[Interface/AddOns/Blizzard_UIPanels_Game/Mainline/WorldMapFrame.lua]:176: in function 'TaskPOI_OnEnter'
[Interface/AddOns/Blizzard_SharedMapDataProviders/WorldQuestDataProvider.lua]:421: in function <...rd_SharedMapDataProviders/WorldQuestDataProvider.lua:420>
```

#### Variant 4: 1x; Sat Aug  1 12:31:12 2026
```text
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:941: in function 'EmbeddedItemTooltip_SetCurrencyByID'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:932: in function 'QuestUtils_AddQuestCurrencyRewardsToTooltip'
[Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua]:786: in function 'QuestUtils_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:209: in function 'GameTooltip_AddQuestRewardsToTooltip'
[Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua]:737: in function 'GameTooltip_AddQuest'
[Interface/AddOns/Blizzard_UIPanels_Game/Mainline/WorldMapFrame.lua]:176: in function 'TaskPOI_OnEnter'
[Interface/AddOns/Blizzard_SharedMapDataProviders/WorldQuestDataProvider.lua]:421: in function <...rd_SharedMapDataProviders/WorldQuestDataProvider.lua:420>
```


## Error 2

```text
Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua:491: attempt to compare a secret number value (execution tainted by 'LsTweeks')
```

- Reported occurrences: 2 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_SharedXML)
- Captured: Sun Aug  2 17:35:08 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: none
- Addons appearing in stacks: Blizzard_SharedXML, Blizzard_UIWidgets, Blizzard_GameTooltip, Blizzard_POIButton, Blizzard_SharedMapDataProviders

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
[C]: in function 'Hide'
[Interface/AddOns/Blizzard_POIButton/POIButton.lua]:539: in function 'OnLeave'
[Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIEventDataProvider.lua]:80: in function <..._SharedMapDataProviders/AreaPOIEventDataProvider.lua:79>
```

### Stack variants

#### Variant 1: 2x; Sun Aug  2 17:35:08 2026
```text
(no caller tail; stack matches the common prefix)
```


## Error 3

```text
...AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua:167: attempt to index local 'color' (a secret table value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_SharedXML)
- Captured: Sat Aug  1 12:43:33 2026
- Explicit taint attribution: LsTweeks
- Project frames in captured stacks: yes
- Addons appearing in stacks: Blizzard_SharedXML, Blizzard_SharedXMLGame, LsTweeks

### Common stack prefix

```text
[Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua]:167: in function 'GameTooltip_AddColoredLine'
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:348: in function 'AddLineDataText'
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:329: in function 'ProcessLineData'
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:315: in function 'ProcessLines'
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:292: in function <...lizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:245>
[C]: in function 'securecallfunction'
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:242: in function <...lizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:241>
[tail call]: ?
[C]: ?
[Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua]:517: in function <...lizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:506>
[C]: in function 'pcall'
[Interface/AddOns/LsTweeks/functions/tooltip.lua]:404: in function <Interface/AddOns/LsTweeks/functions/tooltip.lua:384>
[tail call]: ?
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:519: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:493>
... 1 more line(s) omitted
```

### Stack variants

#### Variant 1: 1x; Sat Aug  1 12:43:33 2026
```text
(no caller tail; stack matches the common prefix)
```


## Error 4

```text
...UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua:1030: attempt to perform arithmetic on local 'barWidth' (a secret number value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 1 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_UIWidgetTemplateBase.lua)
- Captured: Sun Aug  2 17:35:01 2026
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

#### Variant 1: 1x; Sun Aug  2 17:35:01 2026
```text
(no caller tail; stack matches the common prefix)
```
