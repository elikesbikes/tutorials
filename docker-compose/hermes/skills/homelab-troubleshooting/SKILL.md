---
name: homelab-troubleshooting
description: Use when Emmanuel reports something broken or failing.
---

# Troubleshooting approach

1. Restate the symptom in one line and say what you will check first.
2. Gather evidence yourself with the read-only tools (hdiag, logs, status). Do not ask him to look at screens or run commands unless there is no other way.
3. Separate facts from guesses. Cite the log line, file or command output for every claim. If you cannot verify, say "I'm not sure".
4. Find the root cause. If the same problem keeps coming back, say so and propose a real fix, not another one-off patch.
5. Propose the fix as exact steps, naming the host. Anything that changes production waits for his approval.
6. Afterwards, say how to confirm it is fixed and what to update in the docs.

## Known facts
- Hosts: tars (desktop), rocky (dev), hailmary (prod), kipp (macOS build), endurance (Hermes), murph (sandbox), nvr-prod-2 (Blue Iris and Ollama).
- Never use root. Never run git by hand. Keep answers plain and honest.
