# Objectives Memory

Important `objectives` keys:
- `collapse_all`: when true, starts Blizzard's All Objectives tracker collapsed.

- `collapse_campaign`: when true, starts Blizzard's Campaign module in the All Objectives tracker collapsed.

- `collapse_quests`: when true, starts Blizzard's Quests module in the All Objectives tracker collapsed.

- `collapse_achievements`: when true, starts Blizzard's Achievements module in the All Objectives tracker collapsed.


## Runtime Notes

- `modules/objectives/ob_defaults.lua` owns default DB values. `modules/objectives/ob_main.lua` owns the settings page, startup collapse apply path, and module status fields.

- Objectives intentionally has no module reset panel; the page currently has only one option, and the Settings module enabler already covers module-level disabling.

- Tracker metadata lives in `TRACKER_DEFS` in `modules/objectives/ob_main.lua`; it owns DB keys, labels, status keys, global frame names, and top-to-bottom UI order. Current order: All Objectives, Campaign, Quests, Achievements. The settings UI shows these inside an outlined `Auto-Collapse` group, with Campaign, Quests, and Achievements indented under All Objectives.

- Blizzard's `ObjectiveTrackerFrame`, `CampaignQuestObjectiveTracker`, `QuestObjectiveTracker`, and `AchievementObjectiveTracker` all expose `SetCollapsed`/`IsCollapsed`. Auto-Collapse calls `SetCollapsed(true)` when LsTweeks applies settings, then leaves Blizzard's own manual expand/collapse behavior alone.

- Unchecking an Auto-Collapse option calls that tracker frame's `SetCollapsed(false)` once so the section reopens immediately. Disabling the Objectives module does not force-expand sections; later tracker state is left to Blizzard/user actions.

- Initialization can race `ObjectiveTrackerManager:Init()`, which runs after both `PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED`. Keep the `ADDON_LOADED` and delayed `PLAYER_ENTERING_WORLD` apply paths unless in-game testing proves they are redundant.

- In-game verification passed after the Auto-Collapse group work: checked All Objectives, Campaign, Quests, and Achievements sections start collapsed after reload/login with tracked entries, remain manually expandable/collapsible through Blizzard tracker controls, and reopen once when their option is unchecked. No blocked-action/taint dialogs were observed during the verification pass.
