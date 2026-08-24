# Condensed Lua Errors

- Source: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\internal_dev\working_docs\ToDo\error_batches\2026-08-24_163652_managed-frame-bg-forbidden-anchor\raw.txt`
- Parsed records: 2
- Reported occurrences: 2
- Unique messages: 1
- Distinct stack variants: 2
- Locals: omitted; consult the source export when needed


## Error 1

```text
Texture:SetPoint(): Anchoring disallowed as dependent object would inherit forbidden aspects: UntrustedLayoutScriptExecution
```

- Reported occurrences: 2 across 2 record(s)
- Stack variants: 2
- Message origin: unknown
- Captured: Mon Aug 24 16:35:44 2026
- Project frames in captured stacks: yes
- Addons appearing in stacks: LsTweeks

### Common stack prefix

```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_background.lua]:317: in function <...ddOns/LsTweeks/modules/aura_frames/af_background.lua:275>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_background.lua]:366: in function 'apply_managed_frame_background'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed_presets.lua]:501: in function <.../LsTweeks/modules/aura_frames/af_managed_presets.lua:490>
```

### Stack variants

#### Variant 1: 1x; Mon Aug 24 16:35:44 2026
```text
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed_presets.lua]:616: in function <.../LsTweeks/modules/aura_frames/af_managed_presets.lua:533>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_managed_presets.lua]:764: in function <.../LsTweeks/modules/aura_frames/af_managed_presets.lua:644>
[tail call]: ?
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1025: in function 'create_aura_frame'
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1197: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1194>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1219: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1216>
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:1409: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:1402>
```

#### Variant 2: 1x; Mon Aug 24 16:35:44 2026
```text
[tail call]: ?
[Interface/AddOns/LsTweeks/modules/aura_frames/af_main.lua]:849: in function <...face/AddOns/LsTweeks/modules/aura_frames/af_main.lua:840>
```
