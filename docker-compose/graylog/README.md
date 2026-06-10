# Graylog Docker Setup

As complete Docker-based Graylog deployment with MongoDB and OpenSearch for centralized log aggregation and analysis.

## Overview

This project provides a production-ready Graylog stack that collects, indexes, and analyzes logs from all containers on your homelab. Logs are sent via syslog (RFC3164) to a central Graylog instance for storage and searchability.

**Components:**
- **Graylog 7.1.3**: Log management and analytics platform
- **MongoDB 7.0**: Configuration and metadata storage
- **OpenSearch 2.19.0**: Full-text search and log indexing

## Prerequisites

- Docker and Docker Compose (Engine 20.10+)
- Network: Must be connected to the `frontend` Docker network
- 4GB+ free disk space for log storage and indexes
- Port 514 (UDP/TCP) available for syslog ingestion

## Quick Start

1. **Set up environment variables:**
   ```bash
   cp .env.example .env  # or edit .env with your settings
   ```

2. **Create data directories:**
   ```bash
   mkdir -p mongo_data opensearch_data graylog_data
   ```

3. **Start the stack:**
   ```bash
   docker compose up -d
   ```

4. **Access Graylog:**
   - Web UI: `http://localhost:9000`
   - Default credentials: Check `.env` for `GRAYLOG_ROOT_USERNAME` and `GRAYLOG_ROOT_PASSWORD`

## Configuration

### Environment Variables

Required variables in `.env`:

```env
TZ=America/Los_Angeles

# Graylog credentials
GRAYLOG_ROOT_USERNAME=admin
GRAYLOG_ROOT_PASSWORD=<generate-secure-password>
GRAYLOG_ROOT_EMAIL=admin@example.com
GRAYLOG_SECRET=<generate-32-byte-secret>
GRAYLOG_ADMIN_TOKEN=<generate-token>

# OpenSearch settings
OPENSEARCH_BOOTSTRAP_MEMORY_LOCK=true
OPENSEARCH_DISCOVERY_TYPE=single-node
OPENSEARCH_ACTION_AUTO_CREATE_INDEX=+.graylog-*,+.opensearch-dashboards,-.graylog-*,.opensearch-*
OPENSEARCH_DISABLE_SECURITY_PLUGIN=true
```

### Log Forwarding

All Docker containers must send logs to Graylog at `192.168.5.30:514` using RFC3164 format.

Add this to any `docker-compose.yml` service:

```yaml
logging:
  driver: syslog
  options:
    syslog-address: "udp://192.168.5.30:514"
    syslog-format: "rfc3164"
    tag: "service-name"
```

**Note:** `docker compose logs` still works locally—Docker keeps a dual logging cache (local + remote).

## Data Storage

All persistent data is stored as bind mounts in the project directory:

| Directory | Purpose | Mounted To |
|-----------|---------|-----------|
| `mongo_data/` | MongoDB database | `/data/db` |
| `opensearch_data/` | Search indexes | `/usr/share/opensearch/data` |
| `graylog_data/` | Graylog metadata | `/usr/share/graylog/data` |

Data persists across container restarts and recreates.

## Architecture

```
┌─────────────────────────────────────────────┐
│           Docker Containers                 │
│  (all services send logs to syslog driver)  │
└───────────────┬─────────────────────────────┘
                │ syslog (RFC3164)
                │ 192.168.5.30:514
                ▼
        ┌─────────────────┐
        │    Graylog      │ ◄── Web UI (9000)
        │   (syslog UDP)  │
        └────────┬────────┘
                 │ queries/config
        ┌────────┴───────┬─────────────┐
        ▼                ▼             ▼
   ┌─────────┐    ┌────────────┐  ┌─────────┐
   │ MongoDB │    │ OpenSearch │  │ Graylog │
   │ (meta)  │    │ (indexes)  │  │ (data)  │
   └─────────┘    └────────────┘  └─────────┘
```

## Accessing Logs

1. **Web UI**: Open `http://localhost:9000` in a browser
2. **Search**: Use the "Streams" and "Searches" to query incoming logs
3. **Inputs**: Configure inputs to accept logs from different sources (syslog TCP/UDP on ports 514, 1514)

## Networking

- **Network**: Connected to `frontend` (external Docker network)
- **Syslog Ingestion**: Listening on ports 514 (standard) and 1514 (alternate) for both TCP and UDP
- **Web Access**: Port 9000 for the Graylog web interface
- **OpenSearch API**: Port 9200 for direct search queries

## Troubleshooting

### Containers won't start
```bash
docker compose logs syslog_graylog    # Check Graylog logs
docker compose logs syslog_opensearch # Check OpenSearch logs
docker compose logs syslog_mongodb    # Check MongoDB logs
```

### No logs appearing in Graylog
1. Verify logs are being sent: `docker compose logs <container-name>`
2. Check that syslog address is `192.168.5.30:514` (not `192.168.5.16`)
3. Ensure `syslog-format: "rfc3164"` is set (Docker default is RFC5424)
4. Verify Graylog syslog inputs are enabled in the web UI

### Disk space issues
```bash
du -sh ./mongo_data ./opensearch_data ./graylog_data
```

Clean up old indexes in the Graylog web UI: **System → Indices**

## Maintenance

### Backup data
```bash
tar -czf graylog-backup-$(date +%Y%m%d).tar.gz mongo_data opensearch_data graylog_data
```

### Restart services
```bash
docker compose restart
```

### Update Graylog version
Edit `docker-compose.yml` and change the image tag, then:
```bash
docker compose up -d
```

## Project Structure

```
.
├── README.md                  # This file
├── CLAUDE.md                  # Development guidelines
├── docker-compose.yml         # Service definitions
├── .env                       # Environment variables (git ignored)
├── mongo_data/               # MongoDB bind mount
├── opensearch_data/          # OpenSearch bind mount
└── graylog_data/             # Graylog bind mount
```

## Resources

- **Graylog**: https://docs.graylog.org/
- **OpenSearch**: https://opensearch.org/docs/
- **MongoDB**: https://docs.mongodb.com/
- **Syslog RFC3164**: https://tools.ietf.org/html/rfc3164
