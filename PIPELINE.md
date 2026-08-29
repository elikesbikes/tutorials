# Tutorials Docker Deploy Pipeline

## What this does

When you push a docker-compose project to this repo, GitLab CI/CD automatically:

1. **Validates** the compose file syntax, environment variables, and bind mount paths
2. **Pre-flight checks** ensure the target host is ready (network exists, disk space, write permissions)
3. **Deploys** via one-click buttons, then runs comprehensive health checks
4. **Tests** that services are actually running and responding on their ports

## Pipeline Stages

### 1. Validate Stage (Automatic)
Runs on every push that changes `docker-compose/**/*`:
- **compose syntax**: `docker compose config` validates YAML
- **environment variables**: Checks .env has all required vars
- **bind mounts**: Verifies `./data`, `./config`, etc. exist or can be created
- **symlinks & NFS**: Tests symlinks point to valid targets, NFS mounts are accessible
- **image names**: Validates image name format

Fails fast if config is invalid — prevents broken deployments.

### 2. Pre-flight Stage (Manual)
Runs when you click `preflight:ranger0` or `preflight:endurance`:
- **Docker daemon**: Checks docker is running on target host
- **frontend network**: Ensures the `frontend` network exists
- **disk space**: Warns if `/var/lib/docker` is >85% full
- **project directory**: Creates `/devops/docker/<project>` and tests write permissions
- **image pull**: Dry-run `docker compose pull` to catch registry issues early

Catches host-level problems before full deployment.

### 3. Deploy Stage (Manual)
Runs when you click `deploy:ranger0` or `deploy:endurance`:
- **Sync**: Git pull tutorials repo, rsync docker-compose files
- **Validate on target**: Re-run `docker compose config` on target (in case it drifted)
- **Create mounts**: Ensure bind mount directories exist
- **Start services**: `docker compose up -d`
- **Health check**: Comprehensive checks:
  - All services in `Up` state
  - Check logs for critical errors
  - Test port connectivity (curl to localhost:port)
  - Verify volume accessibility
  - Validate network connections

## Workflow

```
YOU run: gacp_tutorials_wcopy <project> "message"
         ↓
copies /devops/docker/<project> → tutorials/docker-compose/<project>
         ↓
git push → GitHub + GitLab
         ↓
┌─── GitLab Pipeline ───┐
│                       │
│ validate:compose      │  ← Automatic, fails if config is bad
│   (docker compose     │
│    config)            │
│                       │
└───────────────────────┘
         ↓
[ Manual: preflight:ranger0 ]   [ Manual: preflight:endurance ]
  (checks host is ready)           (checks host is ready)
         ↓
[ Manual: deploy:ranger0 ]       [ Manual: deploy:endurance ]
  (git pull → rsync → up -d         (git pull → rsync → up -d
   → health-check)                  → health-check)
```

## Validation Checks in Detail

### Environment Variables
The validate stage extracts all `${VAR}` references from your compose file and checks that `.env` defines them.

Example:
```yaml
environment:
  TZ: ${TZ}                    # ← checks that .env has TZ=...
  PASSWORD: ${GITLAB_ROOT_PASSWORD}  # ← checks that .env has GITLAB_ROOT_PASSWORD=...
```

### Bind Mount Directories
Automatically creates any missing directories referenced in `volumes:`.

Example:
```yaml
volumes:
  - ./config:/etc/gitlab    # ← auto-creates ./config if missing
  - ./data:/var/opt/gitlab  # ← auto-creates ./data if missing
  - ./logs:/var/log/gitlab  # ← auto-creates ./logs if missing
```

### Symlinks and NFS Mounts
Tests that:
- Symlinks point to valid targets
- NFS mounts are mounted and accessible
- All paths are readable and writable

### Health Checks After Deployment
The deploy stage runs comprehensive tests:
- **Port connectivity**: Tries to connect to each exposed port
- **Log inspection**: Warns if logs contain `ERROR`, `FATAL`, `PANIC`, `CRASH`
- **Service state**: Verifies all containers are in `Up` state (120-second timeout)
- **Volume accessibility**: Tests that bind mounts are writable

## What happens if you push FROM the host you deploy to

No problem. The pipeline SSHes back into the same machine:
- `git fetch origin && git reset --hard origin/main` — files already match, nothing changes
- `rsync` — files already identical, nothing copies
- `docker compose up -d` — Docker sees no config change, containers stay running

## Only triggers for docker-compose changes

Pushing to other folders (`linux/`, `AI/`, `network/`, etc.) does NOT trigger the deploy pipeline.
Changes to `validate-compose.sh` or `health-check.sh` also trigger the validate stage.

## Machines

| Job               | Host      | IP             |
|-------------------|-----------|----------------|
| `deploy:ranger0`  | ranger0   | 192.168.5.16   |
| `deploy:endurance`| endurance | 192.168.5.30   |

## Key Files

| File | Purpose |
|------|---------|
| `.gitlab-ci.yml` | Pipeline definition (3 stages: validate, preflight, deploy) |
| `scripts/validate-compose.sh` | Pre-deployment validation — syntax, env vars, mounts, symlinks |
| `scripts/health-check.sh` | Post-deployment health checks — ports, logs, volumes, services |
| `SSH_PRIVATE_KEY` | CI/CD variable in GitLab — private key used to SSH into each host |
| `PIPELINE.md` | This file |
