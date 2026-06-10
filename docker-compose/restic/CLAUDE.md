# CLAUDE.md

## Homelab Configuration

**CRITICAL - Follow these defaults if applicable to your project:**

### For Docker Container Projects

**Docker Network:**
- **Network**: `frontend` (already exists on homelab)
- Always attach containers to this network
- Example docker-compose.yml:
  ```yaml
  networks:
    default:
      name: frontend
      external: true
  ```

**Logging:**
- **Syslog Server**: `192.168.5.30` (Graylog, runs on endurance) — port `514/udp`
- ⚠️ **NOT `192.168.5.16`** — that is a reverse proxy. It serves the Graylog
  *web UI* (`:9000`/`:443`) but does **not** forward syslog (`514`), so logs sent
  there are silently dropped. Always send syslog to `192.168.5.30`.
- Use `syslog-format: "rfc3164"` — Graylog's Syslog UDP input parses RFC3164
  (matching the hosts/router); Docker's default rfc5424 is not ingested.
- All Docker containers must send logs here
- Example docker-compose.yml:
  ```yaml
  services:
    myapp:
      logging:
        driver: syslog
        options:
          syslog-address: "udp://192.168.5.30:514"
          syslog-format: "rfc3164"
          tag: "myapp"
  ```
- **`docker compose logs` still works with the syslog driver.** Docker Engine
  20.10+ keeps a local dual-logging cache, so logs land in Graylog *and* remain
  viewable locally — no need to choose. (The local cache is a per-container ring
  buffer, cleared on recreate; Graylog is the durable history.)
- **Cron / background jobs inside a container don't reach the logging driver by
  default.** The driver only captures PID 1's stdout/stderr. A cron job's output
  goes wherever its crontab line redirects it (usually a file), so it never hits
  Graylog. Route job output to the container's stdout so the driver picks it up:
  ```sh
  # in the crontab line — tee to a file AND to PID 1's stdout (the container log stream)
  * * * * * /app/job.sh 2>&1 | tee -a /app/logs/job.log > /proc/1/fd/1
  ```
  This requires the foreground process to be PID 1 (e.g. `exec crond -f`).

**Storage / Volumes:**
- **NEVER use Docker volumes** - Always use bind mounts
- **All bind mounts must be in the project directory**
- Example docker-compose.yml:
  ```yaml
  services:
    myapp:
      volumes:
        - ./data:/app/data           # Bind mount in project folder
        - ./config:/app/config       # NOT /var/lib/docker/volumes
        - ./logs:/app/logs           # Everything relative to compose file
  ```
- Create necessary directories before starting:
  ```bash
  mkdir -p data config logs
  ```

### For Non-Docker Projects
Skip the Docker/syslog requirements above. Follow your project's specific configuration needs.

---

## Code Quality Standards

**When helping with this project:**
- **Production-ready**: Write maintainable code that's understandable 6 months from now
- **Learning-focused**: Explain trade-offs and why you chose an approach
- **No magic**: Prefer explicit over clever. Readable beats concise.
- **Error handling**: Always log with context. Use structured logging for Graylog.
- **Comments**: Explain *why*, not *what*. Document non-obvious decisions.

---

## Secrets & Environment Variables

**CRITICAL - Never hardcode secrets or credentials:**

- **All secrets go in `.env`** (API keys, passwords, tokens, credentials)
- **`.env` is git-ignored** — never committed
- Document required variables in code comments or README
- For Docker: Load via `env_file: .env` in docker-compose.yml
- Example workflow:
  ```bash
  # Edit .env with actual values
  docker-compose up
  ```

---

## Project Structure

**Minimal directory layout:**

```
project-root/
├── CLAUDE.md
├── .env                      # Secrets (git ignore this)
├── docker-compose.yml        # If Docker
├── Dockerfile                # If Docker
├── scripts/                  # Deployment, automation, utilities
├── src/ or app/              # Source code
├── data/                     # Bind mount (Docker)
└── config/                   # Bind mount (Docker)
```

---

## Deployment Workflow

**CRITICAL - Standard deployment for all projects:**

1. **Copy core files to tutorials repo:**
   ```bash
   # Create project folder in tutorials repo
   mkdir -p /home/ecloaiza/devops/github/tutorials/docker-compose/[project-name]
   
   # Copy essential files (adjust based on project):
   cp docker-compose.yml /home/ecloaiza/devops/github/tutorials/docker-compose/[project-name]/
   cp Dockerfile /home/ecloaiza/devops/github/tutorials/docker-compose/[project-name]/
   cp CLAUDE.md /home/ecloaiza/devops/github/tutorials/docker-compose/[project-name]/
   # Add any other core config files needed
   ```

2. **Commit and push using gacp_tutorials:**
   ```bash
   gacp_tutorials "[brief description of changes]"
   ```
   Example: `gacp_tutorials "Add Graylog Slack webhook service"`

3. **Deploy to target host:**
   - **Target**: [tars, gargantua, etc.]
   - **Location**: `/path/to/project`
   - **Deploy method**: [GitHub Actions workflow or manual deploy command]

---

## Project-Specific Invariants (restic multi-job)

This project runs multiple backup jobs against ONE shared restic repository. Do not weaken these without understanding the data-loss consequences:

- **Every `restic forget` MUST carry `--tag "$JOB_NAME"` and `--group-by host,tags`.**
  - `--tag` limits deletion candidates to that one job's snapshots; without it, forget would consider (and could prune) every other job's snapshots.
  - `--group-by host,tags` (not the default `host,paths`) keeps one retention group per job even if `JOB_SOURCES` changes later — path-grouping would orphan the old group and keep its snapshots forever.
  - This lives in `app/scripts/cleanup.sh`. Backups tag via `restic backup --tag "$JOB_NAME"` in `app/scripts/backup.sh`. The two must always stay consistent.

- **Repo lock**: jobs serialize on `flock` over `/app/logs/.repo.lock` (queue with 2h timeout). `backup.sh` holds it and passes `RESTIC_LOCK_HELD=1` to `cleanup.sh`; a standalone `cleanup.sh` takes the lock itself. The Dockerfile installs util-linux `flock` because BusyBox `flock` has no `-w` timeout flag — keep that package.

- **Job confs** (`jobs/*.conf`): `JOB_NAME` must equal the filename stem and match `[A-Za-z0-9_-]+`; `JOB_CRON` is 5 fields (BusyBox crond, no `@daily`); `JOB_SOURCES` paths cannot contain spaces. `entrypoint.sh` validates and warn-skips bad confs.

- **Host-specific files (never sync between hosts):** `.env`, `jobs/*.conf`, `docker-compose.override.yml`, the `backup` symlink, `logs/`. `docker-compose.yml` is host-generic; per-host data-source mounts live in the override file.

- **Health**: `app/status-api/app.py` reads `logs/status/<job>.json` and returns 503 if ANY job is older than its `JOB_MAX_AGE_HOURS` (default 25). A transitional `_legacy` fallback reads the old `logs/status.json` only when no per-job files exist yet.
