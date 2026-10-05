---
name: change-and-deploy
description: Use when Emmanuel asks to change, ship or deploy something.
---

# Change and deploy workflow

His standard flow for every project:

1. Edit on tars (the source). Never edit on rocky or hailmary.
2. Commit and push through the project's `gacp_*` function, with a short message. Never raw git.
3. The pipeline deploys to rocky (dev) automatically. Watch the pipeline and confirm it passed.
4. Test on rocky. Only then ask him to promote to hailmary (prod). The promote is a manual job he plays himself.
5. After promotion, verify the live URL or service really answers. Do not trust the job status alone.
6. Update the docs: the service, project and infra notes in the Obsidian vault (through CouchDB), and the project's own docs in its repo, with a new revision row.

## Rules
- Docker projects follow his Docker standards file. No secrets in `.env`.
- Never run destructive commands on production without explicit approval.
- Say which host or zone you mean. Report what is done and verified, and what is not.

## Hermes today
Hermes has read-only access. Write the plan as exact steps and commands, label which host each runs on, and ask him to approve or run them.
