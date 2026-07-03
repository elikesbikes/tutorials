# GitLab

Self-hosted [GitLab CE](https://about.gitlab.com/) with a Docker-executor GitLab Runner, served through Traefik.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

GitLab CE hosts Git repositories and CI/CD, fronted by Traefik at `gitlab.home.elikesbikes.com`. Web traffic (port 80) is proxied by Traefik with SSL terminated upstream; SSH is exposed on host port `2222` (GitLab shell configured for port 2222). A GitLab Runner with the Docker socket handles CI jobs. See `CLAUDE.md` and `health-check.sh` for operational details.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `gitlab` | `gitlab/gitlab-ce:latest` | GitLab server |
| `gitlab-runner` | `gitlab/gitlab-runner:latest` | CI/CD runner |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network
- `./config`, `./data`, `./logs`, `./runner-config` directories

## 4. Configuration

Provide a `.env` file with:

```env
GITLAB_ROOT_PASSWORD=
```

Omnibus config (external URL, proxy headers, SSH port) is set inline via `GITLAB_OMNIBUS_CONFIG`. Logs ship to syslog at `192.168.5.30:514`.

## 5. Usage

```bash
docker compose up -d
./health-check.sh
```

## 6. Access

- Web: `https://gitlab.home.elikesbikes.com`
- SSH (git): `ssh://git@<host>:2222`
