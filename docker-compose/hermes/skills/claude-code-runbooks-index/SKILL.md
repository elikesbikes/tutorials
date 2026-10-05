---
name: claude-code-runbooks-index
description: Use to find which of Emmanuel's runbooks fits a task.
---

# Index of Emmanuel's Claude Code runbooks

Emmanuel keeps about 60 runbooks ("skills") for Claude Code on tars, in `~/devops/github/adastra/AI/skills`. They are written for Claude Code's tools and some touch credentials, so Hermes does not run them. Use this index to tell him which runbook fits his task, and to draft the steps for him to approve. Never copy or print any secret from them.

## New hosts and services
- tars-newhost: onboard a new VM, LXC or box end to end (vTPM, own Proton Pass PAT, Graylog syslog, CheckMK, MCC, IPAM, Docker and Traefik, docs).
- traefik-host-bootstrap: one-time Traefik setup on a new host.
- authelia-add-host: install or change Authelia (SSO) on a host.
- gitlab-ci-deploy: push-to-deploy pipeline for a Docker project (tars to rocky to hailmary).
- gitlab-ci-ios: pipeline for iOS/Xcode projects built on kipp.
- project-sync, project-replicate: copy Docker projects between hosts, keeping host-specific settings.
- npm-proxy-host: Nginx Proxy Manager hosts (older setup, now mostly Traefik).
- install-wazuh-agent: add a host to Wazuh.

## Secrets and security
- proton-pass-cli, proton-pass-ssh: Proton Pass CLI, PAT login and SSH agent.
- tpm-seal-pat: seal the Proton Pass PAT to a TPM or vTPM.

## Monitoring and networking
- checkmk-manage-services: ignore or change monitored services in CheckMK.
- mcc-monitor-add-component: register a new check in MCC's self-monitor.
- prometheus-targets, grafana-dashboard, uptimekuma: Prometheus, Grafana and Uptime Kuma.
- unifi, unifi-dns: UniFi troubleshooting and local DNS records on the router.
- home-assistant-manager: Home Assistant configuration and deployment.

## Automation, notes and docs
- mcc-n8n-workflow: create or inspect MCC n8n workflows. n8n-code-javascript, n8n-code-python, n8n-expression-syntax, n8n-validation-expert: writing and fixing n8n code.
- ansible: playbooks through Semaphore.
- obsidian-vault-couchdb, obsidian-vault-note: read and write the Obsidian vault through CouchDB (never edit the vault on disk).
- tars-documentation, readme-generator, tech-writer, archify: documentation with revision history and diagrams.
- homelab-service-inventory, homelab-publish, obsidian-todoist-sync, unison, sync-claude-skills.

## Desktop (tars)
- omarchy, opendeck, add-keybind, install-webapp, stt-fix, diagnose-crash, garmin-backend.

## How to use this
When he describes a task, name the matching runbook, say what it covers, and state what you can do read-only now. Anything that changes a server waits for his approval.
