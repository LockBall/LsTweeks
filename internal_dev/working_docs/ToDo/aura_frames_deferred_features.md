# Aura Frames Deferred Features
Design backlog intentionally separated from Aura Frames migration closeout and live acceptance

These items are not required to finish `aura_frames_remaining_work.md`. Reassess
each feature against the current WoW managed-Aura and secret-value constraints
before implementation.


## Deferred Feature Design
- [ ] **a** (Agent) Map Custom Filtered Frames only to live-supported standard Aura filters and managed candidate filters; reject arbitrary predicates requiring protected Aura data
- [ ] **b** (Agent) Implement native numeric rule formatters for compact and decimal timer modes with boundary tests and secret-Aura live validation
- [ ] **c** (Agent) Map sorting only to live-supported AuraContainer methods and remove choices that require addon comparators or unavailable enum members
- [ ] **d** Live-validate restored Test Aura previews on Short, Static / Long, Timed, and Debuff frames in Bar and Icon modes; implementation uses one addon-owned mock with its own Frame BG cell on the side opposite native growth and never injects synthetic data into managed AuraButtons
