# Condensed Lua Errors

- Source: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\internal_dev\working_docs\ToDo\error_batches\2026-08-16_140718_cdm-unit-aura-order-taint\raw.txt`
- Parsed records: 2
- Reported occurrences: 6
- Unique messages: 1
- Distinct stack variants: 2
- Locals: omitted; consult the source export when needed


## Error 1

```text
GetUnitAuraInstanceIDs(): Auras cannot be accessed when secret while tainted by 'LsTweeks'
```

- Reported occurrences: 6 across 2 record(s)
- Stack variants: 2
- Message origin: unknown
- Captured: Sun Aug 16 13:59:47 2026
- Project frames in captured stacks: yes
- Addons appearing in stacks: LsTweeks

### Common stack prefix

```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_render.lua]:688: in function <...ce/AddOns/LsTweeks/modules/aura_frames/af_render.lua:673>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_render.lua]:770: in function <...ce/AddOns/LsTweeks/modules/aura_frames/af_render.lua:763>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_render.lua]:822: in function 'render_aura_map'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_logic_main.lua]:579: in function 'update_auras'
```

### Stack variants

#### Variant 1: 3x; Sun Aug 16 13:59:47 2026
```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:911: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:909>
```

#### Variant 2: 3x; Sun Aug 16 13:59:47 2026
```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:202: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:172>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:221: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:219>
```
