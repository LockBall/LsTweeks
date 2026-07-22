# Condensed Lua Errors

- Source: `internal_dev\working_docs\ToDo\new_issue.txt`
- Parsed records: 1
- Reported occurrences: 2
- Unique messages: 1
- Distinct stack variants: 1
- Locals: representative excerpts included


## Error 1

```text
...AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua:167: attempt to index local 'color' (a secret table value, while execution tainted by 'LsTweeks')
```

- Reported occurrences: 2 across 1 record(s)
- Stack variants: 1
- Message origin: Blizzard UI (Blizzard_SharedXML)
- Captured: Tue Jul 21 19:10:18 2026
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
[Interface/AddOns/LsTweeks/functions/tooltip.lua]:282: in function <Interface/AddOns/LsTweeks/functions/tooltip.lua:273>
[tail call]: ?
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:518: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:511>
... 1 more line(s) omitted
```

### Stack variants

#### Variant 1: 2x; Tue Jul 21 19:10:18 2026
```text
(no caller tail; stack matches the common prefix)
```

Representative locals:
```text
tooltip=LsTweeksNativeTooltip <tooltip.lua:255>{
 processingInfo=<table>
 infoList=<table>
 updateTooltipTimer=0.200000
 supportsDataRefresh=true
 BottomOverlay=Texture <SharedTooltipTemplates.xml:28>
 NineSlice=Frame <SharedTooltipTemplates.xml:19>
 textLeft1Font="GameTooltipHeaderText"
 TextRight1=LsTweeksNativeTooltipTextRight1 <SharedTooltipTemplates.xml:36>
 TopOverlay=Texture <SharedTooltipTemplates.xml:23>
 layoutType="TooltipDefaultLayout"
 TextLeft1=LsTweeksNativeTooltipTextLeft1 <SharedTooltipTemplates.xml:35>
 textRight1Font="GameTooltipHeaderText"
 textLeft2Font="GameTooltipText"
 textRight2Font="GameTooltipText"
 TextRight2=LsTweeksNativeTooltipTextRight2 <SharedTooltipTemplates.xml:42>
 TextLeft2=LsTweeksNativeTooltipTextLeft2 <SharedTooltipTemplates.xml:41>
}
text=<secret string>
color=<secret table>
... 14 more line(s) omitted
```
