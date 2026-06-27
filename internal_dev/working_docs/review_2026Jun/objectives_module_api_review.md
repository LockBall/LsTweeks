# Objectives Module API Review


## Findings

- Ketho FrameXML annotations for Retail expose `ObjectiveTrackerFrame`, `CampaignQuestObjectiveTracker`, `QuestObjectiveTracker`, and `AchievementObjectiveTracker` as global frames in `Blizzard_ObjectiveTracker`.

- Campaign, Quests, and Achievements inherit `ObjectiveTrackerModuleMixin`. The relevant inherited methods are `SetCollapsed(collapsed)`, `ToggleCollapsed()`, `IsCollapsed()`, and `MarkDirty()`. All Objectives is the tracker container and also exposes `SetCollapsed`/`IsCollapsed`.

- `ObjectiveTrackerManager:Init()` adds `AchievementObjectiveTracker` to `ObjectiveTrackerFrame` after `PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED` via `EventUtil.ContinueAfterAllEvents`, so addon startup code can race tracker container setup if it only runs on this addon's `ADDON_LOADED`.


## Implementation Notes

- The first implementation used `hooksecurefunc(AchievementObjectiveTracker, "SetCollapsed", ...)` instead of method replacement, but that prevented normal manual opening. The revised implementation only calls `SetCollapsed(true)` when LsTweeks applies settings and does not hook re-collapse behavior.

- No public CVar was found for per-section Objective Tracker collapse persistence. The feature is therefore a frame-state nudge, not a Blizzard settings write.

- User requirement clarified after initial implementation: the user must be able to manually open and close the Achievements section as normal.

- User requirement clarified after the label change: unchecking Achievements Auto-Collapse should reopen the Achievements section once.

- Follow-up request added matching Auto-Collapse checkboxes, top to bottom, for All Objectives, Campaign, and Quests. The final UI order is All Objectives, Campaign, Quests, Achievements.

- Follow-up UI request changed the labels to plain section names inside a small outlined `Auto-Collapse` group, with Campaign, Quests, and Achievements visually indented as subitems.


## Follow-Up Issues

- In-game verification is still needed with tracked Campaign, Quest, and Achievement entries. Confirm each checked target starts collapsed after reload/login, can then be expanded and collapsed manually with the Blizzard tracker button, and reopens once when unchecked.

- Watch for taint or blocked-action dialogs around the Objective Tracker in combat. The inspected methods are ordinary frame/mixin methods, but combat behavior has not been tested yet.

- Confirm that `AchievementObjectiveTracker:SetCollapsed(true)` does not hide achievement fanfare/turn-in animation in an undesirable way when an achievement completes while the option is enabled.
