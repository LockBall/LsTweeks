# Media And Asset Notes

Durable reference for reusable Blizzard textures and atlases used or considered by LsTweeks UI factories.

## Blizzard Panel Backgrounds

- Retail Frame Stack identifies `CommunitiesFrame.Bg` and `CommunitiesFrame.Inset.Bg` through `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`.
- Outer panel texture: `Interface\FrameGeneral\UI-Background-Rock`. Blizzard uses it for textured panel backgrounds such as `SimplePanelTemplate`, `DefaultPanelTemplate`, and textured portrait/button frames.
- Inner inset/chat texture: `Interface\FrameGeneral\UI-Background-Marble`. Blizzard uses it for `InsetFrameTemplate`; this is the likely Communities chat-area pattern.
- Both are texture file paths, not atlas names. Blizzard declares them with horizontal and vertical tiling, so addon use should pair `SetTexture()` with `SetHorizTile(true)`, `SetVertTile(true)`, and popup-relative anchors.
- When placing one behind an existing addon backdrop, keep the existing border but make its solid background transparent or translucent enough for the tiled texture to remain visible.
- `addon.CreatePopupFrame()` uses Marble as its default through `DEFAULT_POPUP_BACKGROUND_TEXTURE`; callers can replace it with `background_texture` or `background_atlas` and can override horizontal/vertical tiling and tint without editing the factory.
- Source reference: <https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml>
