# CheckMK — Docker Compose

[CheckMK](https://checkmk.com) is an open-source IT monitoring platform for servers, networks, containers, and cloud infrastructure. This stack runs the **Raw Edition** (100% open source, no license required).

---

## Stack

| Component | Image | Purpose |
|---|---|---|
| checkmk | `checkmk/check-mk-raw:2.5.0p4` | Monitoring server + web UI |

---

## Prerequisites

- Docker + Docker Compose
- External Docker network `FRONTEND` already created:
  ```bash
  docker network create FRONTEND
  ```
- Graylog or syslog receiver at `udp://192.168.5.20:1514`

---

## Quick Start

```bash
# 1. Clone / copy this directory
git clone <repo> && cd docker-compose/checkmk

# 2. Create .env with your credentials
cp .env.example .env
nano .env

# 3. Create the bind-mount directory
mkdir -p data/omd

# 4. Start the container
docker compose up -d

# 5. Watch initialization logs (first boot takes ~30s)
docker compose logs -f
```

Access the web UI at: `http://<host-ip>:8080/cmk/`
Login: `cmkadmin` / `<CMK_PASSWORD>`

---

## Environment Variables

Create a `.env` file in this directory (never commit it):

```dotenv
CMK_SITE_ID=cmk
CMK_PASSWORD=changeme
```

| Variable | Required | Description |
|---|---|---|
| `CMK_SITE_ID` | Yes | Name of the monitoring site (used as URL path and data directory) |
| `CMK_PASSWORD` | Yes | Initial password for the `cmkadmin` user (only set on first boot) |

> **Security:** Change `CMK_PASSWORD` before deploying. After first boot, manage passwords through the CheckMK web UI.

---

## Ports

| Host Port | Container Port | Protocol | Purpose |
|---|---|---|---|
| `8080` | `5000` | TCP | Web UI |
| `8000` | `8000` | TCP | Agent receiver (TLS host registration) |

---

## Storage

All data is persisted via bind mount in `./data/omd/` — no Docker volumes are used.

```
data/
└── omd/
    └── <CMK_SITE_ID>/     # site config, RRD data, logs
```

> A `tmpfs` mount is used for `/opt/omd/sites/<site>/tmp` to keep ephemeral I/O off the bind mount.

---

## Networking

Attached to the external `FRONTEND` network so other containers (Traefik, etc.) can reach it by container name.

---

## Logging

Container logs are forwarded to Graylog via syslog with the tag `checkmk`:

```yaml
logging:
  driver: syslog
  options:
    syslog-address: "udp://192.168.5.20:1514"
    tag: "checkmk"
```

---

## Useful Commands

```bash
# View live logs
docker compose logs -f

# Stop / start
docker compose down
docker compose up -d

# Open a shell inside the container
docker exec -it checkmk-prod-1 bash

# CheckMK CLI (run as site user)
docker exec -it checkmk-prod-1 su - cmk -c "cmk -L"
```

---

## Monitored Hosts

Once running, install the CheckMK agent on hosts you want to monitor:

```bash
# Download agent from the web UI:
# Setup → Agents → Linux → checkmk-agent_<version>.deb
wget http://<host-ip>:8080/cmk/check_mk/agents/check-mk-agent_<version>_all.deb
dpkg -i check-mk-agent_<version>_all.deb
```

Then register the host in the web UI under **Setup → Hosts → Add host**.
