# Cross Module Review
Temporary follow-up notes for patterns found while reviewing one module that may deserve a focused pass across other modules.


## Table of Contents
- [Follow-Ups](#follow-ups)


## Follow-Ups
1. Audit state-machine helper functions for hidden caller-order dependencies like Player Frame latent trap 1. Look for functions that set runtime state to idle/normal while combat, enablement, visibility, or lifecycle flags still indicate a guarded state, and verify they are correct without relying on the caller to immediately run a full refresh.
