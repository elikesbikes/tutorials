# Graylog Docker Stack

A production-ready Docker deployment of Graylog with MongoDB and OpenSearch for centralized log aggregation and analysis across your homelab.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Quick Start](#3-quick-start)
4. [Configuration](#4-configuration)
5. [Architecture](#5-architecture)
6. [Data Storage](#6-data-storage)
7. [Usage](#7-usage)
8. [Networking](#8-networking)
9. [Troubleshooting](#9-troubleshooting)
10. [Maintenance](#10-maintenance)
11. [Project Structure](#11-project-structure)
12. [Resources](#12-resources)

---

## 1. Overview

This project provides a complete Graylog stack that collects, indexes, and analyzes logs from all containers on your homelab. All Docker services send logs via syslog (RFC3164) to the central Graylog instance for aggregation, search, and analysis.

### Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **Graylog** | 7.1.3 | Log management, search, and analytics UI |
| **OpenSearch** | 2.19.0 | Full-text search indexing and log storage |
| **MongoDB** | 7.0 | Configuration and metadata storage |

### Key Features

- **Centralized Logging**: Collect logs from all homelab containers in one place
- **Full-Text Search**: Powerful search capabilities via OpenSearch
- **Web UI**: Intuitive web interface for log exploration and analysis
- **RFC3164 Syslog**: Standard syslog protocol support for universal container compatibility
- **Persistent Storage**: All data stored as bind mounts for easy backup and recovery
- **Dual Logging**: Docker's local logging cache maintained alongside remote syslog

---

## 2. Prerequisites

- **Docker Engine**: 20.10 or later (for dual-logging cache support)
- **Docker Compose**: Latest version
- **Network**: Must be connected to the `frontend` Docker network
- **Disk Space**: 4GB+ for log storage and search indexes
- **Ports**: UDP/TCP port 514 available for syslog ingestion

---

## 3. Quick Start

### 3.1 Set Up Environment Variables

```bash
# Create .env file with required variables
cat > .env << EOF
TZ=America/Los_Angeles

# Graylog credentials (generate secure values)
GRAYLOG_ROOT_USERNAME=admin
GRAYLOG_ROOT_PASSWORD=$(openssl rand -base64 32)
GRAYLOG_ROOT_EMAIL=admin@example.com
GRAYLOG_SECRET=$(openssl rand -base64 32)
GRAYLOG_ADMIN_TOKEN=$(openssl rand -base64 32)

# OpenSearch settings
OPENSEARCH_BOOTSTRAP_MEMORY_LOCK=true
OPENSEARCH_DISCOVERY_TYPE=single-node
OPENSEARCH_ACTION_AUTO_CREATE_INDEX=+.graylog-*,+.opensearch-dashboards,-.graylog-*,.opensearch-*
OPENSEARCH_DISABLE_SECURITY_PLUGIN=true
EOF
```

### 3.2 Create Data Directories

```bash
mkdir -p mongo_data opensearch_data graylog_data
```

### 3.3 Start the Stack

```bash
docker compose up -d
```

Monitor startup:
```bash
docker compose logs -f syslog_graylog
```

### 3.4 Access Graylog

- **Web UI**: http://localhost:9000
- **Username**: `admin` (from `GRAYLOG_ROOT_USERNAME`)
- **Password**: Check your `.env` file for `GRAYLOG_ROOT_PASSWORD`

---

## 4. Configuration

### 4.1 Environment Variables

All sensitive configuration goes in `.env` (git-ignored). Required variables:

```env
TZ=America/Los_Angeles

# Graylog
GRAYLOG_ROOT_USERNAME=admin
GRAYLOG_ROOT_PASSWORD=<32-char-secure-password>
GRAYLOG_ROOT_EMAIL=admin@example.com
GRAYLOG_SECRET=<32-byte-base64-encoded-secret>
GRAYLOG_ADMIN_TOKEN=<API-token>

# OpenSearch
OPENSEARCH_BOOTSTRAP_MEMORY_LOCK=true
OPENSEARCH_DISCOVERY_TYPE=single-node
OPENSEARCH_ACTION_AUTO_CREATE_INDEX=+.graylog-*,+.opensearch-dashboards,-.graylog-*,.opensearch-*
OPENSEARCH_DISABLE_SECURITY_PLUGIN=true
```

### 4.2 Log Forwarding Configuration

To send logs from any Docker service to Graylog, add the logging configuration to your `docker-compose.yml`:

```yaml
services:
  myapp:
    image: myapp:latest
    logging:
      driver: syslog
      options:
        syslog-address: "udp://192.168.5.30:514"
        syslog-format: "rfc3164"
        tag: "myapp"
```

#### Important Notes

⚠️ **Always use `192.168.5.30:514` for syslog — NOT `192.168.5.16`**
- `192.168.5.30` is the Graylog syslog server (endurance)
- `192.168.5.16` is the reverse proxy (only serves Graylog UI on `:9000`)

**Format matters**: Use `rfc3164` (Docker default is RFC5424, which Graylog's syslog input doesn't parse)

**Local logs still work**: Docker 20.10+ maintains a dual-logging cache, so `docker compose logs` works even with the syslog driver.

### 4.3 Cron Jobs and Background Processes

Cron jobs running inside containers don't reach the syslog driver by default (it only captures PID 1's stdout/stderr). To log cron output to Graylog:

```bash
# In crontab, redirect to PID 1's stdout
* * * * * /app/job.sh 2>&1 > /proc/1/fd/1
```

And run cron in foreground mode:
```dockerfile
# In Dockerfile
CMD ["exec", "crond", "-f"]
```

---

## 5. Architecture

```
┌──────────────────────────────────────────┐
│        Docker Containers & Services      │
│  (send logs via syslog to 192.168.5.30)  │
└───────────────┬──────────────────────────┘
                │
                │ syslog RFC3164
                │ udp://192.168.5.30:514
                ▼
        ┌─────────────────┐
        │    Graylog      │◄─── Web UI (port 9000)
        │   7.1.3         │     REST API
        └────────┬────────┘
                 │ reads/writes
        ┌────────┼────────┬──────────────┐
        ▼        ▼        ▼              ▼
   ┌─────────┐ ┌───────────────┐  ┌──────────┐
   │ MongoDB │ │  OpenSearch   │  │ Graylog  │
   │ 7.0     │ │  2.19.0       │  │ Data     │
   │ (meta)  │ │ (indexes)     │  │ (local)  │
   └─────────┘ └───────────────┘  └──────────┘
```

### Data Flow

1. **Container Logs**: Application logs on PID 1 → Docker syslog driver
2. **Syslog Transmission**: RFC3164 format → UDP to `192.168.5.30:514`
3. **Ingestion**: Graylog syslog input receives and parses messages
4. **Indexing**: Logs indexed into OpenSearch for fast searching
5. **Storage**: Metadata in MongoDB, searchable index in OpenSearch
6. **Query**: Web UI queries OpenSearch for logs

---

## 6. Data Storage

All persistent data is stored as **bind mounts** in the project directory for easy backup and recovery:

| Directory | Size | Purpose | Mounted To |
|-----------|------|---------|-----------|
| `mongo_data/` | 100MB–500MB | MongoDB database | `/data/db` |
| `opensearch_data/` | 1GB–10GB+ | Search indexes | `/usr/share/opensearch/data` |
| `graylog_data/` | 10MB–100MB | Graylog config & state | `/usr/share/graylog/data` |

**Durability**: Data persists across container restarts and recreates. Delete directories to reset.

---

## 7. Usage

### 7.1 Access the Web UI

1. Open http://localhost:9000 in your browser
2. Log in with credentials from `.env`
3. Navigate to **System → Inputs** to verify syslog inputs are active
4. Check **Streams** or **Searches** to explore incoming logs

### 7.2 Searching Logs

Use the Graylog search interface to query:

```
source: myapp                    # Logs from service tagged "myapp"
level: ERROR                     # Only error messages
timestamp: [2026-06-10 TO 2026-06-11]  # Date range
message: "database connection"   # Text search
```

### 7.3 Create Streams

Streams allow you to automatically route and group logs:

1. **System → Streams → Create Stream**
2. Add rules: e.g., `source: myapp`
3. View real-time logs from the stream

### 7.4 Set Up Alerts

Configure alerts to notify you of critical events:

1. **Alerts & Events → Manage Alerts**
2. Define conditions (e.g., ERROR count > 10 in 5 minutes)
3. Configure notification channels (email, webhook, etc.)

---

## 8. Networking

### Network Configuration

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Graylog | 9000 | TCP | Web UI and REST API |
| Graylog | 514 | UDP/TCP | Standard syslog input |
| Graylog | 1514 | UDP/TCP | Alternate syslog input |
| Graylog | 1515 | UDP | Custom input |
| OpenSearch | 9200 | TCP | Search API (internal) |
| MongoDB | 27017 | TCP | Database (internal) |

### Docker Network

All services are connected to the `frontend` external network for inter-container communication and homelab integration.

---

## 9. Troubleshooting

### 9.1 Containers Won't Start

Check container logs:

```bash
# Graylog
docker compose logs syslog_graylog

# OpenSearch
docker compose logs syslog_opensearch

# MongoDB
docker compose logs syslog_mongo
```

Common issues:
- **Memory constraints**: OpenSearch needs >2GB RAM
- **Port conflict**: Check if 514, 9000 are in use
- **Network not found**: Create the `frontend` network first:
  ```bash
  docker network create frontend
  ```

### 9.2 No Logs Appearing in Graylog

**Checklist:**

1. **Is the service sending logs?**
   ```bash
   docker compose logs myapp
   ```
   You should see output.

2. **Is the syslog address correct?**
   - ✅ Use `192.168.5.30:514` (Graylog syslog server)
   - ❌ Don't use `192.168.5.16` (reverse proxy doesn't forward syslog)

3. **Is the format RFC3164?**
   ```yaml
   syslog-format: "rfc3164"  # ✅ Correct
   # Default (RFC5424) is NOT parsed by Graylog
   ```

4. **Are Graylog inputs active?**
   - Log into Graylog web UI
   - Go to **System → Inputs**
   - Verify syslog inputs (port 514 TCP/UDP) are **Running**

5. **Is there network connectivity?**
   ```bash
   # From inside a container
   docker compose exec myapp nc -zv 192.168.5.30 514
   ```

### 9.3 High Disk Usage

Check space usage:

```bash
du -sh ./mongo_data ./opensearch_data ./graylog_data
```

**Solutions:**
- **Delete old indexes**: Graylog web UI → **System → Indices** → Delete old ones
- **Adjust retention**: Set index rotation in **System → Indices**
- **Expand storage**: Move bind mount directories to larger disk

### 9.4 OpenSearch Memory Issues

If OpenSearch crashes or won't start:

```bash
# Check memory settings
docker compose logs syslog_opensearch | grep -i memory

# Increase available RAM on host
# Or disable memory locking (less safe):
# OPENSEARCH_BOOTSTRAP_MEMORY_LOCK=false
```

### 9.5 Web UI Slow / Unresponsive

- **Restart OpenSearch**: `docker compose restart syslog_opensearch`
- **Optimize indexes**: Graylog UI → **System → Indices → Optimize**
- **Check resource usage**: `docker stats`

---

## 10. Maintenance

### 10.1 Backup

Create a full backup of all data:

```bash
# Backup to tarball
tar -czf graylog-backup-$(date +\%Y\%m\%d-\%H\%M\%S).tar.gz \
  mongo_data opensearch_data graylog_data

# Backup to remote
rsync -av mongo_data opensearch_data graylog_data user@backup-server:/backups/
```

### 10.2 Restore

Restore from backup:

```bash
# Stop services
docker compose down

# Restore data
tar -xzf graylog-backup-20260610.tar.gz

# Restart
docker compose up -d
```

### 10.3 Update Graylog Version

1. Edit `docker-compose.yml` and change the image tag:
   ```yaml
   services:
     syslog_graylog:
       image: graylog/graylog:7.2.0  # Updated version
   ```

2. Restart:
   ```bash
   docker compose up -d
   ```

3. Monitor startup:
   ```bash
   docker compose logs -f syslog_graylog
   ```

### 10.4 Monitor Disk Growth

Set up automated disk monitoring:

```bash
# Check index growth (run periodically)
docker compose exec syslog_opensearch curl -s localhost:9200/_cat/indices?v

# Clean up indexes older than 30 days
# Configure in Graylog UI: System → Indices → Rotation & Retention
```

### 10.5 Health Check

```bash
# Verify all services are running
docker compose ps

# Check Graylog API
curl -s http://localhost:9000/api/system/overview | jq .

# Check OpenSearch
curl -s localhost:9200/_cluster/health | jq .
```

---

## 11. Project Structure

```
.
├── README.md              # This file
├── CLAUDE.md              # Development guidelines & homelab standards
├── docker-compose.yml     # Service definitions
├── .env                   # Environment variables (git ignored)
├── .gitignore            # Git ignore rules
├── mongo_data/           # MongoDB bind mount (git ignored)
├── opensearch_data/      # OpenSearch bind mount (git ignored)
└── graylog_data/         # Graylog bind mount (git ignored)
```

---

## 12. Resources

- **Graylog Documentation**: https://docs.graylog.org/
- **OpenSearch Documentation**: https://opensearch.org/docs/
- **MongoDB Documentation**: https://docs.mongodb.com/
- **RFC 3164 (Syslog)**: https://tools.ietf.org/html/rfc3164
- **Docker Logging**: https://docs.docker.com/config/containers/logging/

---

## License

This project is part of the homelab infrastructure. See the main repository LICENSE for details.

## Support

For issues or questions:
1. Check the [Troubleshooting](#9-troubleshooting) section
2. Review Graylog logs: `docker compose logs syslog_graylog`
3. Check OpenSearch logs: `docker compose logs syslog_opensearch`
