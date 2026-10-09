# Tutorials Docker Deploy Pipeline

## What this does

Every push to `main` starts a GitLab pipeline that:

1. **Validates** the changed docker-compose project (YAML structure) — automatic
2. **Pre-flight** checks that the target host is ready — manual, optional
3. **Deploys** the project to the host you pick — manual, one click

All jobs run on **shell runners on the target host itself** (no SSH from CI). The
project is found from the commit: the first folder under `docker-compose/` that the
commit changed. A commit with no `docker-compose/` change has nothing to deploy.

## Hosts

| Host      | IP           | Runner           | Tag         | Accepts |
|-----------|--------------|------------------|-------------|---------|
| hailmary  | 192.168.5.25 | `hailmary-shell` | `hailmary`  | any project except `traefik` |
| endurance | 192.168.5.46 | `endurance-shell`| `endurance` | only `hermes`, `honcho`, `open-webui` |

`endurance-shell` is locked to this project and runs on protected branches only.
`traefik` is never deployed from git (the hosts differ); see
`infra-snapshots/traefik/README.md`.

## Jobs

| Job | Stage | When it appears | How it runs |
|-----|-------|-----------------|-------------|
| `validate:compose`    | validate  | every push to main | automatic |
| `preflight:hailmary`  | preflight | commit changes `docker-compose/**` | manual |
| `deploy:hailmary`     | deploy    | every push to main | manual |
| `preflight:endurance` | preflight | commit changes `docker-compose/{hermes,honcho,open-webui}/**` | manual |
| `deploy:endurance`    | deploy    | same as `preflight:endurance` | manual |

The endurance jobs only appear when an endurance project changed. Before
2026-10-08 they were created on every commit, and playing one for any other project
failed by design and turned the pipeline orange ("Warning").

Manual jobs are `allow_failure: true` (GitLab's default for `when: manual`), so a
pipeline is green even when you never play them.

### validate:compose
Runs `scripts/validate-compose.sh` on the changed project: checks that a compose file
exists and that `docker compose config --no-interpolate` accepts it. It does not
resolve variables: CI checkouts never have the host's `.env` or
`docker-compose.override.yml`.

### preflight:hailmary
Read-only checks on hailmary: Docker daemon, `frontend` network, disk usage of
`/var/lib/docker` (warns above 85%), `~/devops/docker/<project>` exists and is
writable (created if missing), dry-run image pull.

### deploy:hailmary
1. `git fetch` + `git reset --hard origin/main` in `~/devops/github/tutorials` on hailmary
2. rsync `docker-compose/<project>/` → `~/devops/docker/<project>/` (only `*.yml`,
   `*.yaml`, `*.py`, `*.sh`, `*.md`, `*.json`, `Dockerfile`; never `.env`, `data/`, `*_data/`)
3. `docker compose config` with the host's `.env`
4. Create missing bind-mount folders inside the project (as the deploy user)
5. Start: if `start.sh` uses `pp_load` (secrets from Proton Pass) the project is
   started by `start.sh`; otherwise `docker compose up -d`
6. Health: the project's own `health-check.sh` if it has one, else all services must be running

### preflight:endurance / deploy:endurance
Both call `scripts/deploy-endurance.sh` (read its header for the full contract):
- **preflight**: checkout is the pipeline commit, `docker-compose.yml` and `start.sh`
  present, compose valid, Docker + `frontend` network, ≥ 5 GB free, project folder
  writable, vTPM can unseal the host's Proton Pass PAT, Proton Pass login works.
- **deploy**: preflight, then rsync the files with the previous versions kept in
  `~/devops/docker/.deploy-backups/<project>/` (5 newest), rebuild the image if the
  Dockerfile changed, start with the project's `start.sh`, wait up to 180 s for every
  container to be running/healthy. If it is not healthy, the old files are put back
  and the job fails.

Every endurance run is logged to syslog with tag `gitlab-deploy`.

To deploy an endurance project that is not the first changed folder of the commit,
start a pipeline by hand (**Build → Pipelines → Run pipeline**, branch `main`) with the
variable `ENDURANCE_PROJECT=<project>`, then play `deploy:endurance`.

## Workflow

```
YOU run: gacp_tutorials_wcopy <project> "message" [hailmary|endurance]
         ↓
copies ~/devops/docker/<project> → tutorials/docker-compose/<project>
         ↓
git push → GitLab + GitHub
         ↓
validate:compose                      (automatic)
         ↓
[ preflight:hailmary ]   [ preflight:endurance ]    (manual, optional)
         ↓                         ↓
[ deploy:hailmary ]      [ deploy:endurance ]       (manual; endurance jobs only
                                                      for hermes/honcho/open-webui)
```

With a host argument, `gacp_tutorials_wcopy` plays that host's deploy job for you
(typing the host is the approval). Without it, it only pushes; play the job in GitLab.

## Key Files

| File | Purpose |
|------|---------|
| `.gitlab-ci.yml` | Pipeline definition (validate, preflight, deploy) |
| `scripts/validate-compose.sh` | YAML check used by `validate:compose` and endurance preflight |
| `scripts/deploy-endurance.sh` | Preflight/deploy/rollback for endurance |
| `docker-compose/<project>/health-check.sh` | Optional per-project health check used by `deploy:hailmary` |
| `PIPELINE.md` | This file |
