# n8n + Claude Code — Docker Setup Guide

**Author:** Tars (Emmanuel Loaiza)

Self-hosted [n8n](https://n8n.io) workflow automation running via Docker Compose on Ubuntu, integrated with Claude Code CLI running on the host machine. The container is a custom build that bundles n8n, Python 3, and a Garmin sidecar server alongside the standard automation platform.

---

## Table of Contents

1. [Agentic Workflow Overview](#1-agentic-workflow-overview)
2. [n8n Overview](#2-n8n-overview)
3. [MCP Server Overview](#3-mcp-server-overview)
4. [Prerequisites](#4-prerequisites)
5. [Architecture Overview](#5-architecture-overview)
6. [Setup Guide](#6-setup-guide)
   - [6.1 Deploy n8n with Docker](#61-deploy-n8n-with-docker)
   - [6.2 Install Claude Code on Ubuntu](#62-install-claude-code-on-ubuntu)
   - [6.3 Configure n8n SSH Credentials](#63-configure-n8n-ssh-credentials)
   - [6.4 Test the Connection](#64-test-the-connection)
7. [Workflows](#7-workflows)
8. [Container Operations & Backups](#8-container-operations--backups)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Agentic Workflow Overview

This project wasn't built by writing code from scratch in an editor. It was built through **agentic workflow** — a collaborative loop where I described what I wanted in plain language and Claude Code handled the execution: writing configs, creating workflows, wiring up MCP servers, and generating this documentation.

### What "agentic" means here

An **agentic workflow** is one where the AI doesn't just answer questions — it takes actions. Instead of Claude responding with "here's how you might do that," it actually does it: creates files, calls APIs, reads logs, modifies configs, and iterates until the goal is met.

In this setup, that looks like:

```
Me (plain language goal)
        │
        ▼
 Claude Code CLI (the agent)
        │
        ├──► reads/writes files on disk
        ├──► calls MCP tools (UniFi, Graylog, Gmail, Calendar, n8n)
        ├──► executes shell commands on the host
        ├──► creates and validates n8n workflows via n8n-mcp
        └──► updates this documentation in real time
```

### How this project was built

**1. Infrastructure first — with Claude driving**

The Docker setup (`docker-compose.yml`, `.env`, directory structure) was assembled through conversation. I described the goal — "n8n running in Docker, accessible to Claude Code on the host, with a shared folder between them" — and Claude generated the configuration, explained each decision, and flagged security considerations like never committing `.env`.

**2. MCP servers as Claude's reach**

Each MCP server extends what Claude can directly act on. To build and test the UniFi workflow, I didn't log into the UniFi controller manually — Claude used the `mcp__unifi` tools to query the live network, verify data shapes, and validate that the n8n workflow was returning the right fields.

The same pattern applied to n8n itself: the `mcp__n8n-mcp` server let Claude create, validate, deploy, and test n8n workflows without me touching the n8n UI.

**3. Iterative workflow construction**

Each workflow was built in a loop:

- I described the tool I wanted (e.g., "give Claude a way to check which APs have high TX retries")
- Claude used `mcp__n8n-mcp__search_nodes` to find the right n8n nodes
- It drafted the workflow JSON, validated it with `mcp__n8n-mcp__validate_workflow`
- Deployed it live with `mcp__n8n-mcp__n8n_create_workflow`
- Then called the tool through the MCP server to verify the output

**4. Documentation as a first-class output**

This README was written by Claude as part of the same session — not as an afterthought. As each component was built and tested, Claude updated the documentation to reflect actual behavior.

### Why this matters

The result is a system that is both the product and the tool used to build it. Claude Code built the n8n MCP server. The n8n MCP server is now one of Claude's tools. That kind of recursive, self-extending capability is what makes agentic workflow qualitatively different from traditional development.

> The agent didn't just help write code. It helped design the system, configure the infrastructure, test the integrations, and document the result — all from a conversation.

---

## 2. n8n Overview

**n8n** is a workflow automation platform that connects apps and services together so they act automatically on your behalf.

> Think of n8n like a set of LEGO instructions. You snap pieces together — "when THIS happens, do THAT" — and n8n follows the instructions every time, all by itself.

**How does it work?**

n8n uses **workflows** — a chain of steps:

1. **Trigger** — something that starts the workflow (a new email, a schedule, a webhook)
2. **Nodes** — the actions that happen (read an email, write a row to a spreadsheet, send a Slack message)
3. **Connections** — the arrows between steps

**Why self-host?**

- Your data stays on your infrastructure — nothing goes through a third-party cloud
- Full access to environment variables, local files, and internal network services
- Can run code (JavaScript or Python) for anything not covered by built-in nodes
- Persistent data and credentials survive container restarts

In this setup, n8n runs inside Docker (always on, always ready) and connects to Claude Code CLI via SSH, enabling n8n workflows to trigger AI-assisted tasks directly on the host machine.

---

## 3. MCP Server Overview

**MCP** stands for **Model Context Protocol**. It's a plug-in system that lets Claude reach outside of itself and connect to real tools and services.

> Claude is the brain. MCP servers are the hands.

Without MCP, Claude can only read what you type and type back. With MCP servers connected, Claude can **go do stuff** — look up live data, run commands, fetch files, and more.

**How it works:**

1. You set up an MCP server for a tool you want Claude to use (e.g., UniFi, Graylog, Google Calendar).
2. That server sits there waiting, like a translator between Claude and the tool.
3. When Claude needs to do something (e.g., "check which APs have high retries"), it calls the MCP server, which talks to the actual system and returns the answer.

**MCP servers active in this setup:**

| Server | What Claude can do |
|--------|--------------------|
| `mcp__unifi` | Query connected clients, error logs, TX retries, channel conflicts |
| `mcp__graylog-wifi` | Search WiFi logs, filter by severity, query deauth/auth events |
| `mcp__n8n-mcp` | Create, validate, deploy, and test n8n workflows |
| `mcp__claude_ai_Gmail` | Read and draft Gmail messages |
| `mcp__claude_ai_Google_Calendar` | Create and manage Google Calendar events |

---

## 4. Prerequisites

Before starting, ensure the following are installed and available on your Ubuntu host:

| Requirement | Version | Notes |
|---|---|---|
| Ubuntu | 20.04+ | Host machine |
| Docker Engine | 24.0+ | [Install guide](https://docs.docker.com/engine/install/ubuntu/) |
| Docker Compose | v2.0+ | Included with Docker Desktop or install the plugin |
| Node.js | 18+ | Required for Claude Code |
| npm | 9+ | Comes with Node.js |
| Git | any | For cloning and managing configs |

**Install Docker on Ubuntu:**

```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to the docker group (avoid needing sudo)
sudo usermod -aG docker $USER
newgrp docker
```

**Install Node.js (via nvm — recommended):**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
node --version
```

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Ubuntu Host Machine                        │
│                                                                     │
│   ┌──────────────────────────────────────┐                          │
│   │           Docker Engine              │                          │
│   │                                      │                          │
│   │  ┌───────────────────────────────┐   │   ┌──────────────────┐   │
│   │  │    n8n Container (n8n-garmin) │   │   │  Claude Code     │   │
│   │  │                               │   │   │  CLI (host)      │   │
│   │  │  entrypoint.sh starts:        │   │   │                  │   │
│   │  │  1. garmin_server.py :8765    │◄──┼───►  $ claude       │   │
│   │  │  2. n8n :5678                 │   │   └──────┬───────────┘   │
│   │  │                               │   │          │               │
│   │  │  volumes:                     │   │          │ reads/writes  │
│   │  │  ./n8n_data  → .n8n/          │   │          ▼               │
│   │  │  ./shared    → shared/        │   │   ┌──────────────────┐   │
│   │  │  ./workflows/Garmin → garmin/ │   │   │  ./shared/       │   │
│   │  │                               │   │   │  (shared vol.)   │   │
│   │  │  extra_hosts:                 │   │   └──────────────────┘   │
│   │  │  host.docker.internal         │   │                          │
│   │  │  → host-gateway               │   │                          │
│   │  └───────────────────────────────┘   │                          │
│   │                                      │                          │
│   │  Docker network: frontend            │                          │
│   └──────────────────────────────────────┘                          │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │                        .env file                           │    │
│   │  N8N_HOST, N8N_PORT, N8N_ENCRYPTION_KEY, WEBHOOK_URL       │    │
│   │  N8N_BASIC_AUTH_USER / PASSWORD, GENERIC_TIMEZONE          │    │
│   │  UNIFI_USER, UNIFI_PASS                                    │    │
│   │  GRAYLOG_API_TOKEN, GRAYLOG_STREAM_ID                      │    │
│   │  HA_URL, HA_TOKEN                                          │    │
│   │  GARMIN_EMAIL, GARMIN_PASSWORD                             │    │
│   └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘

         Browser ──► http://localhost:5678 ──► n8n UI
```

**How it works:**

- n8n runs inside a custom Docker image (`n8n-garmin`) built from `workflows/Garmin/Dockerfile` — it extends the official n8n image with Python 3, `garth`, and `garminconnect`
- `entrypoint.sh` starts two processes: the Garmin HTTP sidecar (`garmin_server.py` on `127.0.0.1:8765`) and then n8n itself
- n8n is accessible at `http://localhost:5678`
- The `host.docker.internal` alias lets the container call the Ubuntu host (where Claude Code runs)
- The `./shared` folder is mounted in both the container and readable by Claude Code on the host, enabling file-based communication between n8n workflows and Claude
- The `./workflows/Garmin` folder is mounted at `/home/node/garmin/` — scripts, OAuth tokens, and CSV output all live here
- Workflow data, credentials, and the SQLite database are persisted in `./n8n_data`
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` and `N8N_BLOCK_ENV_ACCESS_IN_EXPR=false` allow workflow nodes to read env vars via `$env` expressions
- The external `frontend` Docker network allows integration with reverse proxies (e.g., Nginx, Traefik)

**Directory structure:**

```
n8n/
├── docker-compose.yml           # Service definition (custom build)
├── entrypoint.sh                # Starts Garmin sidecar + n8n
├── .env                         # Environment variables (do NOT commit)
├── n8n_data/                    # Persisted n8n data (DB, credentials, logs)
│   ├── database.sqlite
│   └── nodes/
├── shared/                      # Shared volume between host and container
└── workflows/
    ├── Garmin/                  # Garmin integration (Dockerfile, scripts, CSVs)
    ├── Graylog/                 # Graylog WiFi MCP server workflow
    ├── HomeAssistant/           # ZHA Zigbee monitor workflows
    ├── Proxmox/                 # Proxmox monitoring workflows
    └── Unifi/                   # UniFi MCP server + manual query workflow
```

---

## 6. Setup Guide

### 6.1 Deploy n8n with Docker

**Step 1 — Create the external Docker network:**

```bash
docker network create frontend
```

**Step 2 — Clone or create the project directory:**

```bash
mkdir -p ~/devops/docker/n8n && cd ~/devops/docker/n8n
```

**Step 3 — Create the `.env` file:**

```bash
cat > .env <<EOF
# n8n
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-strong-password-here
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/
GENERIC_TIMEZONE=America/New_York
N8N_COMMUNITY_PACKAGES_ENABLED=true
N8N_ENCRYPTION_KEY=your-random-encryption-key-here
N8N_API_DISABLED=false

# UniFi integration
UNIFI_USER=your-unifi-username
UNIFI_PASS=your-unifi-password

# Graylog integration
GRAYLOG_API_TOKEN=your-graylog-api-token
GRAYLOG_STREAM_ID=your-graylog-stream-id

# Home Assistant integration
HA_URL=http://192.168.x.x:8123
HA_TOKEN=your-ha-long-lived-access-token

# Garmin integration
GARMIN_EMAIL=your-garmin-email@example.com
GARMIN_PASSWORD=your-garmin-password
EOF
```

> **Security:** Never commit `.env` to version control. Add it to `.gitignore`.

Generate a strong encryption key:

```bash
openssl rand -hex 32
```

**Step 4 — Review the `docker-compose.yml`:**

The compose file uses a custom image built from `workflows/Garmin/Dockerfile`, which extends n8n with Python 3 and the Garmin libraries:

```yaml
services:
  n8n:
    build:
      context: .
      dockerfile: workflows/Garmin/Dockerfile
    image: n8n-garmin
    container_name: n8n
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - N8N_BLOCK_ENV_ACCESS_IN_EXPR=false
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      - UNIFI_USER=${UNIFI_USER}
      - UNIFI_PASS=${UNIFI_PASS}
      - GRAYLOG_API_TOKEN=${GRAYLOG_API_TOKEN}
      - GRAYLOG_STREAM_ID=${GRAYLOG_STREAM_ID}
      - HA_URL=${HA_URL}
      - HA_TOKEN=${HA_TOKEN}
      - GARMIN_EMAIL=${GARMIN_EMAIL}
      - GARMIN_PASSWORD=${GARMIN_PASSWORD}
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
      - ./shared:/home/node/shared
      - ./workflows/Garmin:/home/node/garmin
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  frontend:
    external: true
```

> `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` and `N8N_BLOCK_ENV_ACCESS_IN_EXPR=false` allow n8n workflow nodes to access environment variables via `$env` expressions. The `env_file` loads base config while the `environment` block explicitly forwards specific variables into the container.

**Step 5 — Create data directories and build:**

```bash
mkdir -p n8n_data shared
docker compose build
docker compose up -d
```

**Step 6 — Verify it's running:**

```bash
docker compose ps
docker compose logs -f n8n
```

Access n8n at: **http://localhost:5678**

Look for `Garmin server started (PID ...)` in the logs — this confirms the Garmin sidecar launched successfully alongside n8n.

**Common Docker Compose commands:**

```bash
docker compose up -d          # Start in background
docker compose down           # Stop and remove containers
docker compose restart n8n    # Restart the n8n service
docker compose build          # Rebuild the image (after Dockerfile changes)
docker compose pull           # Pull latest base images
docker compose logs -f n8n    # Follow logs
```

---

### 6.2 Install Claude Code on Ubuntu

Claude Code is Anthropic's official CLI tool for AI-assisted development.

**Step 1 — Ensure Node.js 18+ is installed** (see Prerequisites above).

**Step 2 — Install Claude Code globally:**

```bash
npm install -g @anthropic-ai/claude-code
```

**Step 3 — Verify the installation:**

```bash
claude --version
```

**Step 4 — Authenticate with your Anthropic API key:**

```bash
claude
```

On first run, Claude Code will prompt you to authenticate. Follow the browser-based OAuth flow or set your API key directly:

```bash
export ANTHROPIC_API_KEY=your-api-key-here
```

To make it permanent, add it to your shell profile:

```bash
echo 'export ANTHROPIC_API_KEY=your-api-key-here' >> ~/.bashrc
source ~/.bashrc
```

**Step 5 — Test Claude Code:**

```bash
claude --print "Hello, are you working?"
```

> Claude Code runs on the **host machine**, not inside Docker. n8n workflows reach it via `host.docker.internal`.

---

### 6.3 Configure n8n SSH Credentials

To allow n8n to execute commands on the host (e.g., run Claude Code), set up SSH access from the container to the host.

**Step 1 — Enable SSH on the Ubuntu host:**

```bash
sudo apt-get install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

**Step 2 — Generate an SSH key pair for n8n to use:**

```bash
ssh-keygen -t ed25519 -C "n8n-to-host" -f ~/.ssh/n8n_host_key -N ""
```

**Step 3 — Authorize the key for your user:**

```bash
cat ~/.ssh/n8n_host_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Step 4 — Get the private key content:**

```bash
cat ~/.ssh/n8n_host_key
```

Copy the full output (including `-----BEGIN...` and `-----END...` lines).

**Step 5 — Add SSH credentials in n8n:**

1. Open n8n at `http://localhost:5678`
2. Go to **Settings → Credentials → Add Credential**
3. Search for **SSH**
4. Fill in:
   - **Host:** `host.docker.internal`
   - **Port:** `22`
   - **Username:** your Ubuntu username (e.g., `ecloaiza`)
   - **Authentication:** Private Key
   - **Private Key:** paste the content from Step 4
5. Save the credential

---

### 6.4 Test the Connection

**Test SSH from inside the n8n container:**

```bash
docker exec -it n8n sh -c \
  "ssh -o StrictHostKeyChecking=no ecloaiza@host.docker.internal 'echo Connection OK'"
```

**Test via an n8n workflow:**

1. Create a new workflow in n8n
2. Add an **SSH** node
3. Select your SSH credential
4. Set command: `claude --version`
5. Execute — you should see the Claude Code version in the output

**Test the shared folder:**

```bash
# From the host
echo "hello from host" > ./shared/test.txt

# From inside the container
docker exec -it n8n cat /home/node/shared/test.txt
```

---

## 7. Workflows

Each workflow lives in its own subdirectory under `workflows/` with a dedicated README. Below is a summary of what each integration does.

---

### UniFi

**Location:** `workflows/Unifi/` — [README](workflows/Unifi/README.md)

Exposes UniFi network data to Claude via an MCP server. Once active, Claude can answer live questions about your network without you logging into the UniFi controller.

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `UniFi MCP Server.json` | MCP Server Trigger (always-on) | Gives Claude 4 tools: `get_connected_clients`, `get_error_logs`, `get_high_tx_retries`, `get_channel_conflicts` |
| `UniFi.json` | Manual | Simple client query — returns connected devices as JSON |

**Required env vars:** `UNIFI_USER`, `UNIFI_PASS`

**Register in Claude MCP config:**

```json
{
  "mcpServers": {
    "unifi": {
      "type": "sse",
      "url": "http://localhost:5678/mcp/<workflow-id>/sse"
    }
  }
}
```

---

### Graylog

**Location:** `workflows/Graylog/` — [README](workflows/Graylog/README.md)

Exposes WiFi log data stored in Graylog to Claude via an MCP server. Enables natural language queries over your network's WiFi event history.

| Tool | Description |
|------|-------------|
| `get_wifi_errors` | Fetches WiFi logs filtered by syslog severity and time range |
| `search_wifi_logs` | Searches logs with a custom Graylog query string (e.g., `deauth`, `auth fail`) |

**Required env vars:** `GRAYLOG_API_TOKEN`, `GRAYLOG_STREAM_ID`

> The Graylog host URL is hardcoded in the workflow nodes. Update it if your Graylog instance is at a different address.

---

### Home Assistant

**Location:** `workflows/HomeAssistant/` — [README](workflows/HomeAssistant/HA_ZHA_Monitor.md)

Two ZHA (Zigbee) monitoring workflows for Home Assistant:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| Diagnostic (`HA_ZHA_Monitor.json`) | Manual | On-demand markdown health report: ZHA error log, unavailable devices, weak signal devices |
| Alerting (live in n8n) | Manual + Daily 4PM schedule | Sends push notifications via ntfy and Signal when ZHA devices go offline or battery is low |

**Required env vars:** `HA_URL`, `HA_TOKEN`

---

### Garmin

**Location:** `workflows/Garmin/` — [README](workflows/Garmin/README.md)

Daily health data export from Garmin Connect to persistent CSV files. Uses a custom Docker image with Python 3 and a lightweight HTTP sidecar server (`garmin_server.py`) that bridges n8n to the Garmin API.

| File | What it tracks |
|------|----------------|
| `activities.csv` | Workout activities |
| `sleep_epochs.csv` | Nightly sleep summary |
| `hrv.csv` | Nightly HRV status |
| `rhr.csv` | Daily resting heart rate |

**Runs:** Daily at 06:00 America/New_York. Self-healing — always fetches the last 7 days so missed runs auto-catch-up.

**Required env vars:** `GARMIN_EMAIL`, `GARMIN_PASSWORD`

**One-time setup (MFA auth):**

```bash
docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py
```

---

### Proxmox

**Location:** `workflows/Proxmox/` — [README](workflows/Proxmox/README.md)

Proxmox monitoring workflows. See the subdirectory README for details.

---

## 8. Container Operations & Backups

**n8n container lifecycle:**

```bash
# Start
docker compose up -d

# Stop (data is preserved in n8n_data/)
docker compose down

# Stop and remove all data (destructive)
docker compose down -v

# Restart after config changes
docker compose down && docker compose up -d

# Rebuild image (after Dockerfile changes)
docker compose build && docker compose up -d

# Update to latest base image
docker compose pull && docker compose build && docker compose up -d
```

**Check container status:**

```bash
docker compose ps
docker stats n8n
```

**Backup n8n data:**

```bash
# Backup the entire data directory
tar -czf n8n_backup_$(date +%Y%m%d).tar.gz n8n_data/

# Export all workflows to JSON
docker exec n8n n8n export:workflow --all --output=/home/node/shared/
```

**Restore from backup:**

```bash
docker compose down
tar -xzf n8n_backup_20240101.tar.gz
docker compose up -d
```

**Auto-start on system boot:**

The `restart: unless-stopped` policy in `docker-compose.yml` ensures n8n restarts automatically after a reboot, as long as Docker itself starts on boot:

```bash
sudo systemctl enable docker
```

---

## 9. Troubleshooting

**n8n container won't start:**

```bash
# Check logs for errors
docker compose logs n8n

# Verify the frontend network exists
docker network ls | grep frontend

# Create it if missing
docker network create frontend
```

**Image not found / build errors:**

```bash
# Rebuild the image from scratch
docker compose build --no-cache
docker compose up -d
```

**Port 5678 already in use:**

```bash
sudo lsof -i :5678
# Kill the conflicting process or change the port in docker-compose.yml
```

**Cannot reach `host.docker.internal` from container:**

```bash
# Verify the extra_hosts entry is in docker-compose.yml
docker exec -it n8n ping host.docker.internal

# On older Docker versions, manually find the host gateway IP
docker network inspect bridge | grep Gateway
```

**SSH connection refused from n8n to host:**

```bash
# Check SSH is running on the host
sudo systemctl status ssh

# Test SSH manually
ssh -i ~/.ssh/n8n_host_key -o StrictHostKeyChecking=no \
  ecloaiza@host.docker.internal "echo OK"

# Check authorized_keys permissions
ls -la ~/.ssh/authorized_keys  # should be 600
```

**Claude Code not found after SSH:**

SSH sessions may not load your full shell profile. Use the absolute path:

```bash
which claude   # find the path, e.g. /home/ecloaiza/.nvm/versions/node/v20.0.0/bin/claude

# Use full path in n8n SSH node
/home/ecloaiza/.nvm/versions/node/v20.0.0/bin/claude --print "Hello"
```

Or add to `/etc/environment` to make it available system-wide:

```bash
echo 'PATH="/home/ecloaiza/.nvm/versions/node/v20.0.0/bin:$PATH"' | sudo tee -a /etc/environment
```

**Garmin server not starting:**

```bash
# Check logs for "Garmin server started"
docker compose logs n8n | grep -i garmin

# Verify the garmin volume is mounted
docker exec -it n8n ls /home/node/garmin/

# Test the sidecar directly
docker exec -it n8n python3 /home/node/garmin/garmin_fetch.py
```

**Garmin `ECONNREFUSED ::1:8765`:**

The HTTP Request node is using `localhost` which resolves to IPv6 (`::1`). Change the URL to `http://127.0.0.1:8765/fetch`.

**n8n encryption key error after restart:**

If you change `N8N_ENCRYPTION_KEY` after credentials were saved, n8n will fail to decrypt them. Keep a backup of your original key.

**Reset n8n credentials (last resort):**

```bash
docker compose down
rm -rf n8n_data/database.sqlite*
docker compose up -d
```

> This deletes all workflows and credentials. Restore from backup if available.

**View real-time n8n logs:**

```bash
docker compose logs -f n8n
```

**Useful diagnostic commands:**

```bash
docker inspect n8n                    # Full container config
docker exec -it n8n env               # Environment variables inside container
docker exec -it n8n ls /home/node/    # Check volume mounts
docker system df                      # Disk usage by Docker
```
