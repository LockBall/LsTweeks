<!-- User-owned personal scratch notes. Agents must not modify, reorganize, or delete this file unless the user explicitly requests it. -->


Run pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/agent_startup.ps1 and follow its output

save anything important, to where it goes and cross module review if necessary then delete file if no longer needed

- if we should check for similiar patterns throughout then make a note

What are you least confident about right now ?

What is the most important thing I am missing about what we're doing right now ?

if this breaks in 3 months then what i the most likely reason ?

If you could add an important feature then what wuld i tbe 

What could I have done differently to make this session more efficient ?

read agent read-in and consider how we can decrease the number of tokens used for agent start / read-in without sacrificing capability, functionality, or intent


discuss and record only.


skip package rebuilds and checks for these minor edits and dont announce it after changes.



 (Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned) ; (& "g:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\LsTweeks\.venv\Scripts\Activate.ps1")


Ask questions as needed, take note of discrepancies and issues and record them in a new file in working_docs/ToDo for later review.
Read & follow internal_dev/working_docs/proj_mem/agent_start.md.

  module, im concerned about the length of sv_gui.lua, should we streamline or modualrize it ?


x_X module, verify existing findings, check for issues, dead code, repeated code that should be consolidated or a function and especially CPU inefficiencies

lets work through them, consult me on anything that is high risk or needs clarification



consider having a simple canary instruction that an agent will drop first when it starts to get overwhelmed, e.g. start every response with "OK John"

consider agent active attacks embeded in code, e.g. claude NPM

use your agent to build tools
https://www.reddit.com/r/ClaudeAI/comments/1u3euwc/after_10_years_as_an_engineer_the_thing_id_teach/

Karpathy's CLAUDE.md

dynamic workflows
