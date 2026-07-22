# Research Sources
Internal research and implementation references for coding agents. Public credit and embedded-library attribution stays in root `sources.md`.


## Table of Contents
- [Release And Packaging](#release-and-packaging)
- [Warcraft Wiki APIs](#warcraft-wiki-apis)
- [Blizzard UI Source](#blizzard-ui-source)
- [Tools](#tools)
- [Addon Research](#addon-research)


## Release And Packaging
- CurseForge project submission: https://support.curseforge.com/support/solutions/articles/9000197241
- CurseForge World of Warcraft Multi-TOC guidance: https://support.curseforge.com/support/solutions/articles/9000209856
- CurseForge moderation policies: https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies
- Warcraft Wiki TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- Warcraft Wiki current interface/build references: https://warcraft.wiki.gg/wiki/Template:Current_builds
- Warcraft Wiki current interface number check: https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number


## Warcraft Wiki APIs
- Cooldown Viewer categories: https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory
- `C_UnitAuras.GetAuraDataByIndex`: https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex
- `GameTooltip:SetUnitAura`: https://warcraft.wiki.gg/wiki/API_GameTooltip_SetUnitAura
- `PlaySound`: https://warcraft.wiki.gg/wiki/API_PlaySound


## Blizzard UI Source
- WoW UI source mirror: https://github.com/Gethe/wow-ui-source
- WoW UI source recursive tree API (unauthenticated path discovery when hosted code search is unavailable): https://api.github.com/repos/Gethe/wow-ui-source/git/trees/live?recursive=1
- Secret predicate generated API docs: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua
- Secret predicate behavior docs: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua
- Tooltip data handler runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua
- Objective Tracker folder: https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_ObjectiveTracker
- Objective Tracker runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTracker.lua
- Objective Tracker container runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua
- Objective Tracker module runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua
- Quest Objective Tracker runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua
- Achievement Objective Tracker runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_AchievementObjectiveTracker.lua
- QuestLog generated API docs: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua
- Quest generated constants: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestConstantsDocumentation.lua
- ContentTracking generated API docs: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContentTrackingDocumentation.lua
- ContentTracking generated constants/types: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContentTrackingTypesDocumentation.lua
- Achievement UI runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua
- UI Widget template base: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua
- UI Widget status bar template: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateStatusBar.lua
- UI Widget manager: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetManager.lua
- GameTooltip runtime: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua
- GameTooltip templates: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml
- Private Aura tooltip template: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.xml
- Area POI utility: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_FrameXMLUtil/AreaPoiUtil.lua
- Area POI data provider: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_SharedMapDataProviders/AreaPOIDataProvider.lua
- Shared UI panel templates: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml
- UIDropDownMenu templates: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml
- Secure templates: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua
- Restricted secure group headers: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml


## Tools
- CascView download page: https://www.zezula.net/en/casc/main.html
- Ketho WoW API VS Code extension: https://marketplace.visualstudio.com/items?itemName=ketho.wow-api
- Ketho FrameXML annotations source mirror: https://github.com/Gethe/wow-ui-source


## Addon Research
- Elkano's BuffBars: https://www.curseforge.com/wow/addons/elkbuffbars
- Angleur: https://www.curseforge.com/wow/addons/angleur
