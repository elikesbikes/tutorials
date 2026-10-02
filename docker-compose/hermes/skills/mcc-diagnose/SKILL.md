---
name: mcc-diagnose
description: "Diagnose problems in the homelab MCC (Mission Control) on hailmary: read component status, container logs and the runner journal through the read-only `hdiag` tool."
version: 1.0.0
author: homelab
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [DevOps, MCC, Homelab, Diagnostics, Troubleshooting]
---

# MCC diagnostics (read-only)

MCC is the owner's monitoring and automation system on the host `hailmary`. You can LOOK at it, never change it.

## The only tool: `hdiag`

Run it with the terminal tool. It connects to a restricted account that allows exactly these requests, all read-only:

| Command | What you get |
|---|---|
| `hdiag status` | MCC components that are not ok (name, status, severity, host, detail) |
| `hdiag component <name>` | full state of one component (the name must exist) |
| `hdiag container-logs <name>` | last 200 log lines of `tars-mcc-bot`, `case-mcc-bot` or `tars-n8n` |
| `hdiag service-journal mcc-runner.service` | last 200 journal lines of the MCC runner |
| `hdiag help` | the list above |

## Rules

1. Use **only** `hdiag` for hailmary. Do not try other ways in (ssh, curl to hailmary, docker); they will fail and each attempt is logged.
2. Anything else is rejected by the server: no shell syntax, no other containers, no files, no flags. Do not try to work around a rejection; tell the user what you could not see.
3. You cannot fix anything. Explain the cause, give evidence (quote the relevant log lines), and propose a fix for the **owner** to run or approve.
4. Output is redacted, so a value shown as `<redacted...>` is a secret you must not try to recover.
5. Keep requests small: start with `hdiag status`, then drill into one component, then its logs.

## Method for "why is X failing?"

1. `hdiag status`: is X listed? note its severity, how long it has failed (`since`) and the detail.
2. `hdiag component X`: read the full detail and when it last ran.
3. Pick the logs that match X: the runner journal for scheduled jobs and checks, `tars-mcc-bot` / `case-mcc-bot` for the Discord bots, `tars-n8n` for n8n workflows.
4. Match the error to a cause (expired token, missing file, network error, bad input) and say how sure you are. Separate what the logs show from what you are guessing.
5. Suggest the smallest fix and who/what must do it.

## Known context

- A component called `int-garmin` failing with "refresh token expired" needs the owner to log in to Garmin again; it cannot be fixed from here.
- Components with status `skipped` do not run on that host; they are not failures.
- Some checks are marked `warn` (non-urgent) and some `critical`. Report critical ones first.
