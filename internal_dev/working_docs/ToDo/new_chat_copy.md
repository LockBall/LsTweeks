# New Chat Copy Module
ChatCopySghetti implementation review and in-game acceptance for LsTweeks 00.24.00. Original requirements and reference findings are retained below.


## Table of Contents
- [Formatted Chat Export](#formatted-chat-export)
- [Current API Assessment](#current-api-assessment)
- [ChatCopyPaste Reference Review](#chatcopypaste-reference-review)
- [Approach Research](#approach-research)
- [1. Implementation And Automated Evidence](#1-implementation-and-automated-evidence)
- [2. In-Game Acceptance](#2-in-game-acceptance)


## Formatted Chat Export
- **Goal:** Build an LsTweeks chat copy/export module with a distinct user-facing name instead of depending on the current third-party chat copy/paste addon.

- **UX:** Preserve intentional line breaks, offer readable formatting controls, and expose selected output through an addon-owned text box for manual Ctrl+C.

- **Safety boundary:** Never call restricted `CopyToClipboard` from addon code; Retail blocks it as a Blizzard-UI-only action.

- **Current decision:** Keep the color-preserving popup workflow. The native-selection toggle and supporting code were removed at user request on 2026-10-31: native chat was click-through in their setup; successful selection was in the popup. This does not establish that the underlying Blizzard mechanism cannot work in other configurations.

- inspired by the xisting addon: ChatCopyPaste

- should use a 'copy' icon

- named 'ChatCopySghetti'


## Current API Assessment
- **Reviewed:** 2026-10-30 against the session's refreshed Retail live 12.1.5.70575 source, commit `15881d522c44cd106d3d8660106ec9f9d2f44167`. Compared relevant files with the prior 12.1.0 snapshot `8ea15b61`; chat-line getter declarations, clipboard restrictions, and the scrolling-message copy implementation have no relevant changes. No in-game chat-copy experiment was performed.
- **Clipboard boundary remains:** `Blizzard_APIDocumentationGenerated/OsDocumentation.lua` marks `CopyToClipboard` restricted. Its `removeMarkup` argument does not grant addon permission. Keep manual Ctrl+C in an addon-owned edit box as the export route; direct addon clipboard calls remain excluded by existing runtime evidence.
- **Historical native candidate (retired):** `Blizzard_SharedXML/ScrollingMessageFrame.lua` exposes `SetTextCopyable`, with a secure-mixin forwarding method and a Blizzard mouse-up copy path. This existed before 12.1.5; no external Lua caller was found in the reviewed source. The click-through chat configuration prevented a useful native-selection acceptance result, and the user chose to retain the popup instead.
- **Chat data restrictions:** `ChatInfoDocumentation.lua` marks `C_ChatInfo.GetChatLineText`, `GetChatLineSenderName`, and `GetChatLineSenderGUID` as secret during chat messaging lockdown. Do not parse, concatenate, cache, or export restricted values. `ChatFrameUtil.lua` and Mainline `FloatingChatFrame.lua` use `GetNumMessages`/`GetMessageInfo` to copy displayed history, which is a source-supported collection candidate, not proof all returned content is addon-readable. Establish the actual data boundary before formatting or exporting; omit unavailable content visibly rather than attempting a bypass.
- **Design follow-up when authorized:** distinguish stored messages from visual word wrapping; preserve intentional newlines and define plain-text handling for colors, hyperlinks, textures/atlases, timestamps, and Unicode. Test an empty/history-limited frame, multiple chat tabs, long/multiline messages, restricted content, and manual selection/copy. Keep export user-initiated and session-local unless persistent chat storage is separately requested.
- **Decision:** Use the color-preserving manual text-box export. The native comparison was removed at user request; remaining acceptance covers the popup only.


## ChatCopyPaste Reference Review
- **Evidence:** Inspected installed ChatCopyPaste 1.40 on 2026-10-30: its TOC declares interface 120105; reviewed its README and main Lua file without executing or modifying it. The author's CurseForge page lists version 1.40 and All Rights Reserved. Public attribution is in root `sources.md` Addon References. This review records behavior and design constraints only; independently implement any future module from requirements and Blizzard API contracts. Do not copy its code, icon, bundled font, or libraries.
- **Collection/export:** A hover copy button opens a separate export window for a chat frame. The addon reads retained messages through `GetNumMessages`/`GetMessageInfo` at that point, limits recent history, skips secret message text with a notification, and inserts messages into an edit box. It does not need a separate persistent message archive for this route. URL copying opens the same window with the URL selected and focused for manual Ctrl+C. A commented native-selection line is not evidence of a successful native path.
- **Formatting behavior:** Preserves message text while adding message separators and chat colors, restores the outer color after resets, removes inline textures, applies English-specific plural-escape cleanup, and separately reconstructs some Battle.net whisper display text. It does not provide a general plain-text normalization pipeline. These transformations can affect exported output independently of visual word wrapping.
- **Source-derived edge cases to test independently:** The inclusive recent-history range can include one more message than the configured limit. Separators depend on the original history index rather than the number of exported messages, so capped history or skipped initial secret messages can produce a leading newline. The singular plural-escape branches reference an unrelated identifier, leaving some singular escapes untreated. These are static findings, not an in-game reproduction of the user's reported formatting limitation.
- **Additional scope:** URL recognition uses chat-event filters across many channels, custom hyperlinks, hyperlink-click hooks, and replacement of `ItemRefTooltip.SetHyperlink`; settings also control chat fading. These features expand lifecycle and taint surface beyond user-triggered export. Decide separately whether ChatCopySghetti needs clickable URL rewriting or fade control; neither follows automatically from requiring a copy icon and formatted export.
- **Independent design implications:** Snapshot only readable retained history on user request; cap exact line count and output size; assemble separators from exported entries while preserving intentional internal newlines. Keep skipped-line counts visible, preserve colors in the copy interface, and avoid reconstructing private names. Use existing module/settings conventions and independently sourced artwork. Runtime verification must cover actual clipboard text, not only the on-screen preview.


## Approach Research
- **Recommended export baseline:** User-triggered snapshot of the chosen chat frame's retained messages into an addon-owned multiline edit box, followed by manual Ctrl+C. This directly supports formatting controls and intentional newlines without intercepting incoming chat. It cannot recover expired history or unreadable messages. Keep collection, text normalization, and presentation separate so normalization can be tested independently.
- **Retired native selection experiment:** In the reviewed source, `GatherSelectedText` joins selected visible display lines with newlines. The experiment did not yield usable direct selection in the user's click-through configuration and was removed. This is scoped evidence, not a universal rejection of Blizzard's mechanism.
- **Formatting primitive:** Current `StringUtilDocumentation.lua` exposes `C_StringUtil.StripHyperlinks` with explicit controls for colors, brackets, encoded newlines, atlases, and textures. Evaluate it on readable fixture strings before writing a custom markup parser. Retain readable link labels/brackets and intentional newlines; test actual LF and encoded newline handling separately. Permission to accept secret arguments does not make its output readable or exportable. English-specific plural replacements are not a general localization strategy.
- **Other options:** Continuous event capture or AddMessage hooks add duplicate storage, retention decisions, and more lifecycle/taint exposure; they are unnecessary for the initial retained-history requirement. A disk chat log is an external/manual workflow, not an in-addon formatted-copy interface. Neither is the preferred initial design.
- **Evidence limits:** Web research on 2026-10-30 found a relevant [Raider.IO chat-filter report and maintainer response](https://github.com/RaiderIO/raiderio-addon/issues/389). It supports testing secret guards and delayed chat behavior, but does not establish that all filters are broken or prove the reported upstream taint cause. The session's pinned Blizzard source remains the implementation authority; old community copy snippets are not current compatibility evidence.
- **Selected architecture:** The authorized implementation is ChatCopySghetti's color-preserving popup with manual Ctrl+C. Native comparison is closed. Validate pasted text before adding URL rewriting, persistent history, or richer formatting controls.


## 1. Implementation And Automated Evidence
- **a** Module is registered in the feature registry/TOC and standard settings shell. Copy icons follow module enablement. Defaults: preserved link brackets, 250 retained lines; configurable range 25–1000 and fixed 200000-byte complete-message output bound. Native Blizzard formatter/input template and existing addon factories own supported formatting/UI behavior. No external addon code or assets copied.
- **b** Export is user-triggered and unavailable during combat/chat messaging lockdown; secret/private-name content is omitted visibly. The copy interface preserves inline and readable message RGB colors, resumes message color after inline resets, and isolates each message's color. No persistent history, incoming-chat filters, hyperlink overrides, URL rewriting, timers, or polling. Close/combat/reset/disable clears export text. Native-selection experiment and status were removed.
- **c** Final review: all 28 headless suites passed; the expanded ChatCopySghetti suite passed 20/20 cases after adding coverage for the reported dark-texture tint issue. Coverage includes geometry/reconstruction, resize/minimize/reset, screen bounds, color retention/isolation, unavailable data, skipped-line counts, popup cleanup, lockdown, disabled runtime, and settings synchronization. These checks do not establish actual client clipboard or taint behavior. Durable contracts live in `../proj_mem/modules/chat_copy_sghetti.md`.
- **d** Final checks on 2026-10-31: full LuaLS passed with no diagnostics against live source `15881d52`; fast checks passed syntax, regions, memory sizes, ownership, whitespace, and line endings. The 00.24.00 zip passed package verification with 153 entries. Final test reports remain ignored under tests_tools/.wow-api-test; obsolete iteration logs were removed. No publishing was performed.
- **e** User feedback confirms the revised settings panel looks good. This is visual feedback, not completion of the broader combat, clipboard, reload, or cross-window acceptance cases below.


## 2. In-Game Acceptance
- [ ] **a** Reload, confirm version 00.24.00 and `/lst status ChatCopySghetti`. Check the new sidebar page, shared controls/reset, and Settings Module Enabler at representative UI scales. Test with ChatCopyPaste disabled first to avoid overlapping buttons; compare it separately if needed.
- [ ] **b** Copy from the main tab, another tab, an undocked tab, and a newly opened whisper window. Confirm only the chosen retained history is exported, the exact line cap, chronological order, empty history, and one combined skipped-line total, including history/output limits and unreadable lines. Combat log is deliberately unsupported.
- [ ] **c** Confirm channel/message colors and inline item/player colors match chat inside the copy interface, including text after colored links and the next message. Paste into an external editor: long visually wrapped text, intentional multiline/blank lines, Unicode, colored messages, item/player links, textures/atlases, timestamps, and localized plural text. Compare actual LF/encoded newline behavior and bracket toggle. Report residual markup rather than adding ad hoc replacements.
- [ ] **d** Test Select All/manual selection, Ctrl+C, scrolling a large export, Escape/Close, popup dragging, bottom-right resizing/reflow, repeated exports, reset, reload, and disable/re-enable. Confirm size/position survive close and reload, stay reachable after screen/UI-scale changes, and reset to the default centered layout. Closed/disabled exports must clear their text; no stale focus or invisible hitbox may remain.
- [ ] **e** Enter combat with export open. Confirm popup cleanup, blocked new exports, no protected-action errors, and correct resume after combat. Exercise unreadable/private-name history without inspecting or reconstructing restricted values.
- **f** Native comparison retired by user decision; historical API/reference research above is not a current test requirement.
- **g** After acceptance, consolidate durable findings and retire this review. Publication remains pending acceptance; no upload is part of this implementation.
