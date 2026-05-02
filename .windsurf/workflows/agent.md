---
auto_execution_mode: 3
---

{
  "protocol": "AUTONOMOUS_ORCHESTRATION",
  "status": "EXAM_GUARD_MODE",
  "instruction": "I am shifting to minimal presence. You are authorized to proceed through the backlog.md autonomously.",
  "rules": [
    "Fix any terminal/command execution errors by checking the environment and permissions.",
    "Execute Task 1 (Seeding) and Task 2 (Safety Test) immediately.",
    "If a container crashes, attempt a restart. If it persists, log the error in 'CRITICAL_ERROR.log' and move to a non-dependent task.",
    "Update the [ ] to [x] in backlog.md as you finish each task.",
    "Generate a summary 'work_done.md' every hour for me to review."
  ]
}