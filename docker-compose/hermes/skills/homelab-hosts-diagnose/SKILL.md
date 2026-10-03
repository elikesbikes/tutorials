---
name: homelab-hosts-diagnose
description: "Look at other homelab hosts (kipp, hailmary) read-only: OS, hardware, disk, memory, load, processes, network. Use whenever the owner asks you to check, SSH into, or look at another machine."
version: 1.0.0
author: homelab
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [DevOps, Homelab, Diagnostics, SSH]
---

# Looking at other hosts (read-only)

**You run inside a Docker container on the host `endurance`.** You have no SSH keys of your own and plain `ssh <host>` from your terminal tool always fails (that is by design, do not try to work around it, and do not ask the owner for keys or an SSH agent). The only way to look at another host is `hdiag`, which uses a restricted read-only account on that host.

## Usage: `hdiag <host> <command>`

Hosts: `kipp` (macOS, iOS build host), `hailmary` (Linux, production), `rocky` (Linux, development), `tars` (Linux, the owner's desktop), `murph` (Linux, sandbox VM). Ask a host what it offers with `hdiag <host> help`.

| Command | Where | What you get |
|---|---|---|
| `hostinfo` | all | OS, CPU/chip, memory, uptime (no serial numbers) |
| `os` | all | OS name and version |
| `disk` | all | filesystem usage |
| `memory` | all | memory usage |
| `load` | all | uptime and load averages |
| `processes` | all | top 15 processes by CPU (names only, no command lines) |
| `network` | all | interfaces and addresses |
| `listening` | Linux | listening TCP ports |
| `failed-units` | Linux | failed systemd units |

hailmary additionally has the MCC commands (see the `mcc-diagnose` skill). Commands take no flags or paths; anything else is rejected and logged.

## Rules

1. Use only `hdiag` for other hosts. Never try `ssh`, `curl` to them, or look for keys.
2. You cannot change anything. Report what you see, quote the relevant lines, and propose fixes for the **owner** to run.
3. Output is redacted; `<redacted...>` marks a secret, never try to recover it.
4. If the owner asks for something `hdiag` cannot show (for example macOS listening ports or another host), say so plainly and name the limit rather than improvising.
