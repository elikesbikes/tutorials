# n8n + Claude Code — Docker Setup Guide

Self-hosted [n8n](https://n8n.io) workflow automation running via Docker Compose on Ubuntu, integrated with Claude Code CLI running on the host machine.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Setup Guide](#3-setup-guide)
   - [3.1 Deploy n8n with Docker](#31-deploy-n8n-with-docker)
   - [3.2 Install Claude Code on Ubuntu](#32-install-claude-code-on-ubuntu)
   - [3.3 Configure n8n SSH Credentials](#33-configure-n8n-ssh-credentials)
   - [3.4 Test the Connection](#34-test-the-connection)
4. [Basic Use](#4-basic-use)
5. [Session Management](#5-session-management)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites

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

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Ubuntu Host Machine                       │
│                                                                 │
│   ┌─────────────────────────────────┐                           │
│   │        Docker Engine            │                           │
│   │                                 │                           │
│   │  ┌──────────────────────────┐   │                           │
│   │  │    n8n Container         │   │   ┌─────────────────┐    │
│   │  │                          │   │   │  Claude Code    │    │
│   │  │  image: n8nio/n8n:latest │   │   │  CLI (host)     │    │
│   │  │  port: 5678              │◄──┼───►                 │    │
│   │  │                          │   │   │  $ claude       │    │
│   │  │  volumes:                │   │   └────────┬────────┘    │
│   │  │  ./n8n_data → .n8n/      │   │            │             │
│   │  │  ./shared   → shared/    │   │            │ reads/writes│
│   │  │                          │   │            ▼             │
│   │  │  extra_hosts:            │   │   ┌─────────────────┐    │
│   │  │  host.docker.internal    │   │   │  ./shared/      │    │
│   │  │  → host-gateway          │   │   │  (shared vol.)  │    │
│   │  └──────────────────────────┘   │   └─────────────────┘    │
│   │                                 │                           │
│   │  Docker network: frontend       │                           │
│   └─────────────────────────────────┘                           │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    .env file                             │  │
│   │  N8N_HOST, N8N_PORT, N8N_ENCRYPTION_KEY, WEBHOOK_URL    │  │
│   │  N8N_BASIC_AUTH_USER / PASSWORD, GENERIC_TIMEZONE       │  │
│   │  UNIFI_USER, UNIFI_PASS                                  │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

         Browser ──► http://localhost:5678 ──► n8n UI
```

**How it works:**
- n8n runs inside Docker and is accessible at `http://localhost:5678`
- The `host.docker.internal` alias lets the container call the Ubuntu host (where Claude Code runs)
- The `./shared` folder is mounted in both the container (`/home/node/shared`) and readable by Claude Code on the host, enabling file-based communication between n8n workflows and Claude
- Workflow data, credentials, and the SQLite database are persisted in `./n8n_data`
- `UNIFI_USER` and `UNIFI_PASS` are passed into the container via the `environment:` block so n8n workflows can interact with a UniFi controller
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` allows workflow nodes to read those env vars via `$env` expressions
- The external `frontend` Docker network allows integration with reverse proxies (e.g. Nginx, Traefik)

**Directory structure:**

```
n8n/
├── docker-compose.yml       # Service definition
├── .env                     # Environment variables (do NOT commit)
├── n8n_data/                # Persisted n8n data (DB, credentials, logs)
│   ├── database.sqlite
│   └── nodes/
├── shared/                  # Shared volume between host and container
└── workflows/               # Exported workflow JSON backups
```

---

## 3. Setup Guide

### 3.1 Deploy n8n with Docker

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

# UniFi integration (used by n8n workflows)
UNIFI_USER=your-unifi-username
UNIFI_PASS=your-unifi-password
EOF
```

> **Security:** Never commit `.env` to version control. Add it to `.gitignore`.

Generate a strong encryption key:

```bash
openssl rand -hex 32
```

**Step 4 — Create the `docker-compose.yml`:**

```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      - UNIFI_USER=${UNIFI_USER}
      - UNIFI_PASS=${UNIFI_PASS}
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
      # Mount a local folder so Claude Code can read/write shared files
      - ./shared:/home/node/shared
    # Allow n8n to reach Claude Code CLI running on the host machine
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  frontend:
    external: true
```

> `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` allows n8n workflow nodes to access environment variables (like `UNIFI_USER`/`UNIFI_PASS`) via `$env` expressions. The `env_file` loads base config while the `environment` block explicitly forwards specific variables into the container.

**Step 5 — Create data directories and start:**

```bash
mkdir -p n8n_data shared
docker compose up -d
```

**Step 6 — Verify it's running:**

```bash
docker compose ps
docker compose logs -f n8n
```

Access n8n at: **http://localhost:5678**

**Common Docker Compose commands:**

```bash
docker compose up -d          # Start in background
docker compose down           # Stop and remove containers
docker compose restart n8n    # Restart the n8n service
docker compose pull n8n       # Pull the latest image
docker compose logs -f n8n    # Follow logs
```

---

### 3.2 Install Claude Code on Ubuntu

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

### 3.3 Configure n8n SSH Credentials

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

### 3.4 Test the Connection

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

## 4. Basic Use

**Access the n8n UI:**
- URL: `http://localhost:5678`
- Default credentials: set in your `.env` file

**Run Claude Code from an n8n workflow:**

Use the **SSH node** with the host credential and run commands like:

```bash
# Run Claude non-interactively
claude --print "Summarize this file" < /home/node/shared/input.txt > /home/node/shared/output.txt

# Run a specific task
claude --print "Review this code for bugs" < /home/node/shared/code.py
```

**Pass files between n8n and Claude Code:**

The `./shared` directory is the bridge:

| Path in n8n workflow | Path on host |
|---|---|
| `/home/node/shared/` | `./shared/` |

Write input files from n8n → Claude reads from `./shared/` → writes output → n8n reads result.

**Export a workflow backup:**

```bash
mkdir -p workflows
docker exec n8n n8n export:workflow --all --output=/home/node/shared/
mv shared/*.json workflows/
```

---

## 5. Session Management

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

# Update to latest n8n image
docker compose pull n8n
docker compose up -d
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

## 6. Troubleshooting

**n8n container won't start:**

```bash
# Check logs for errors
docker compose logs n8n

# Verify the frontend network exists
docker network ls | grep frontend

# Create it if missing
docker network create frontend
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
