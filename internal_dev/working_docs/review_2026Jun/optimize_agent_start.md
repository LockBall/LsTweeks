I read `review_2026Jun/agent_read-in.md`. Worktree note: `agent_read-in.md` is already modified before I touched anything; I did not edit it.

My take: the startup path is already conceptually right. The best token savings are not from weakening the read-in, but from making the mandatory part smaller and making section reads easier to obey.

Highest-leverage options:

1. Shrink mandatory startup to a “boot contract”
   - Keep `agent_start.md` as only: status check, read `code_map.md`, routing gates, preservation rule, validation expectation.
   - Move most detailed documentation/engineering/style policy into `project.md` or targeted docs.
   - This probably saves a few hundred tokens every session without losing intent, because many rules duplicate platform-level behavior or only matter during doc edits.

2. Make `code_map.md` more index-like
   - It currently mixes routing, command ownership, and compact file descriptions.
   - The default read-in could be reduced if `code_map.md` front-loads only:
     - fast commands
     - module memory routing
     - source outline command
     - public/shared/module file ownership
   - Move fuller helper descriptions to `project.md` or targeted docs.
   - This is likely the biggest mandatory-startup win, because `code_map.md` is read every session.

3. Add a markdown section-read helper
   - The policy says “read targeted sections,” but the command path is mostly `rg -n "^##"` plus manual file reads.
   - A repo helper like `read_section.ps1 <file> <heading>` would make it cheap and reliable to read only `## Shared Architecture` or `## Runtime Visibility And Fade`.
   - This saves more tokens in real tasks than trimming startup prose.

4. Add tighter summaries at the top of large module memories
   - `aura_frames.md` and `skyriding_vigor.md` already have good `##` routing.
   - A very short “Always Know” block before the ToC could let agents avoid reading deeper sections for many review-only tasks.
   - Keep it to hard invariants only, or it becomes another duplicate memory layer.

5. Move review note measurements out of normal agent paths
   - `agent_read-in.md` is useful as a temporary review note, but it should not become a regular read-in document.
   - Its durable conclusions are already promoted, so it can eventually be shortened to measurements plus open follow-ups.

I would not remove `code_map.md` from default startup unless you are willing to trade some initial routing accuracy for lower baseline tokens. A safer target is to compress `agent_start.md` + `code_map.md` by roughly 25-35%, then attack the larger recurring cost with a section-read helper and stricter “outline before full source” habit.