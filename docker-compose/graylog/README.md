# Graylog — Centralized Log Management

Graylog stack for collecting and searching syslog messages from the homelab.

## Architecture

| Container          | Image                              | Purpose                    |
|--------------------|------------------------------------|----------------------------|
| syslog_graylog     | graylog/graylog:7.0                | Web UI, API, log processing |
| syslog_opensearch  | opensearchproject/opensearch:2.19.0 | Full-text search backend   |
| syslog_mongodb     | mongo:7.0                          | Graylog metadata store     |

## Access

- **Web UI:** https://graylog-tars.home.elikesbikes.com
- **DNS:** `graylog-tars.home.elikesbikes.com` → 192.168.5.127 (UniFi local DNS)
- **Reverse proxy:** Traefik with TLS (certresolver: production)
- **Default user:** admin

## Ports

| Port      | Protocol | Purpose              |
|-----------|----------|----------------------|
| 443       | TCP      | Web UI via Traefik   |
| 514       | TCP/UDP  | Standard syslog      |
| 1514      | TCP/UDP  | Syslog (non-root)    |
| 1515      | UDP      | Custom input         |
| 9200      | TCP      | OpenSearch (internal) |

## Starting the Stack

```bash
~/devops/docker/graylog/start.sh
```

The `start.sh` script:
1. Authenticates to Proton Pass using a PAT (no manual login needed)
2. Fetches `GRAYLOG_PASSWORD_SECRET` and `GRAYLOG_ROOT_PASSWORD_SHA2` from the HOMELAB vault
3. Loads non-secret config from `.env`
4. Runs `docker compose up -d`

### Stopping

```bash
docker compose -f ~/devops/docker/graylog/docker-compose.yml down
```

## Secrets

Managed via Proton Pass (HOMELAB vault). No plaintext secrets on disk.

| Variable                    | Vault Item                                  | Purpose                                |
|-----------------------------|---------------------------------------------|----------------------------------------|
| GRAYLOG_PASSWORD_SECRET     | Graylog - GRAYLOG_PASSWORD_SECRET           | Encryption key for stored credentials  |
| GRAYLOG_ROOT_PASSWORD_SHA2  | Graylog - GRAYLOG_ROOT_PASSWORD_SHA2        | SHA-256 hash of admin password         |

## Data Directories

| Path            | Container mount                    | Content              |
|-----------------|------------------------------------|----------------------|
| `./graylog_data` | `/usr/share/graylog/data`         | Graylog data, journal, config |
| `./mongo_data`   | `/data/db`                        | MongoDB data         |

The `graylog_data` directory must be owned by UID 1100:1100 (the Graylog container user).

```bash
sudo chown -R 1100:1100 ~/devops/docker/graylog/graylog_data
```

## Configuration Notes

- **OpenSearch security plugin is disabled** — `OPENSEARCH_INITIAL_ADMIN_PASSWORD` in `.env` is unused/dead config
- **MongoDB has no auth** — internal Docker network only, no external exposure
- **GRAYLOG_PASSWORD_SECRET cannot be changed** after first run — it encrypts data in MongoDB. Changing it breaks the installation.
- **GRAYLOG_ROOT_PASSWORD_SHA2 only applies on first setup** — after that, password changes must be done through the Graylog UI (System → Users)

## Sending Logs to Graylog

Point syslog clients at `192.168.5.127:514` (standard) or `192.168.5.127:1514` (non-root port).

Example for a Docker container:
```yaml
logging:
  driver: syslog
  options:
    syslog-address: "udp://192.168.5.30:514"
    syslog-format: "rfc3164"
    tag: "my-service"
```
