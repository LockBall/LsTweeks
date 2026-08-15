# Condensed Lua Errors

- Source: `internal_dev/working_docs/ToDo/new_issue.txt`
- Parsed records: 2
- Reported occurrences: 2
- Unique messages: 1
- Distinct stack variants: 2
- Locals: representative excerpts included


## Error 1

```text
Button:SetShown(): Cannot be called with secrets due to existing script handlers.
```

- Reported occurrences: 2 across 2 record(s)
- Stack variants: 2
- Message origin: unknown
- Captured: Fri Aug 14 20:20:54 2026
- Project frames in captured stacks: yes
- Addons appearing in stacks: Blizzard_AuraContainer, LsTweeks

### Stack variants

#### Variant 1: 1x; Fri Aug 14 20:20:54 2026
```text
[Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua]:79: in function 'CreateFrame'
[Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua]:98: in function 'CreateFrameBatch'
[Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua]:301: in function <...zzard_AuraContainer/Blizzard_CustomAuraContainer.lua:283>
[C]: ?
[C]: in function 'AddAuraGroup'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed.lua]:143: in function 'add_managed_aura_group'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed_debuff.lua]:64: in function 'create_managed_debuff_backend'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:948: in function 'create_aura_frame'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1112: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1109>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1134: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1131>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1310: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1303>
```

Representative locals:
```text
self=<table>{
 parent=<forbidden table>
 accessRestrictions=1
 templateString="CustomAuraButtonTemplate"
 availableFrames=<table>
 activeFrames=<table>
 batchSize=10
 ownedFrames=<table>
}
auraFrame=<forbidden table>
```

#### Variant 2: 1x; Fri Aug 14 20:20:54 2026
```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed.lua]:143: in function 'add_managed_aura_group'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed_debuff.lua]:64: in function 'create_managed_debuff_backend'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:948: in function 'create_aura_frame'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1112: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1109>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1134: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1131>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1310: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1303>
```

Representative locals:
```text
backend=<table>{
 owner=Frame <af_main.lua:919>
 active_aura_button_count=0
 unit="player"
 key="preset:debuff"
 aura_button_activation_count=0
 groups=<table>
 aura_buttons=<table>
 feature_enabled=true
 container=Frame <af_managed.lua:68>
}
key="debuffs"
filter_string="HARMFUL"
options=<table>{
 maxFrameCount=20
}
layout=<table>{
 elementSpacing=1
 layoutIndex=1
 lineSpacing=1
... 8 more line(s) omitted
```
