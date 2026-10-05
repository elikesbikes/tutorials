---
revision: 1
updated: 2026-10-03 15:20
---

# open-webui (endurance)

Friendly chat front end for the Hermes agent. Open WebUI keeps the chats, folders and search; **Hermes is the backend**, so every answer comes with Hermes' memory (Honcho), skills and tools.

## Table of Contents

1. [How it fits together](#1-how-it-fits-together)
2. [Standards](#2-standards)
3. [Secrets (Proton Pass)](#3-secrets-proton-pass)
4. [Sign-in](#4-sign-in)
5. [Run it](#5-run-it)
6. [Known limits](#6-known-limits)
7. [Revision History](#7-revision-history)

## 1. How it fits together

`https://chattars.home.elikesbikes.com` (Traefik, TLS) -> `open-webui` container -> `http://hermes:8642/v1` (Hermes' OpenAI-compatible API on the internal `frontend` network, never published) -> Hermes (Claude subscription, memory, skills). The model is `hermes-agent`.

## 2. Standards

Follows `CLAUDE-docker2.md`: `frontend` network, Traefik labels from `.env`, no published ports, TZ Pacific, syslog to Graylog (192.168.5.25), bind mount `./data`, non-root (`user: 1000:1000`), secrets from Proton Pass through `start.sh`, pinned image (`v0.11.4`). `ENABLE_PERSISTENT_CONFIG=false` keeps settings and keys out of the database on disk (verified: no secret was found in `./data`).

## 3. Secrets (Proton Pass, HOMELAB vault, all type login, field `password`)

| Item | Used for |
|---|---|
| `hermes - API_SERVER_KEY` | Hermes API key; `OPENAI_API_KEY` here (the same item is passed to the Hermes container) |
| `open-webui - WEBUI_SECRET_KEY` | session signing |
| `open-webui - OIDC_CLIENT_SECRET` | Authelia client secret (Authelia stores only its pbkdf2 hash) |

`.env` holds only `TRAEFIK_HOST` and `TRAEFIK_PORT`.

## 4. Sign-in

Authelia single sign-on only (OIDC client `open-webui` on hailmary's Authelia, two-factor, PKCE S256). The local login form and sign-ups are off; only members of the Authelia group `admins` may log in, and they become Open WebUI admins. The first-admin password sign-up is refused (verified in the code: needs `ENABLE_INITIAL_ADMIN_SIGNUP`, unset).

## 5. Run it

`./start.sh` (needs the vTPM-sealed PAT). Update: change the pinned tag in `docker-compose.yml`, pull, `./start.sh`. Check: `docker ps`, `curl -k https://chattars.home.elikesbikes.com/health`.

## 6. Known limits

Open WebUI sends the whole chat history on each request; whether Hermes treats each Open WebUI chat as one session for Honcho is still being verified. Hermes runs tools inside its own container, never on the device you browse from. The 6.5 GB image is large for endurance's small disk.

## 7. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 1 | 2026-10-03 15:20 | (this revision) | Initial project: Open WebUI in front of the Hermes API, Authelia sign-in only. |
