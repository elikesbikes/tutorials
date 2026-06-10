# Tutorials Docker Deploy Pipeline

## What this does

When you push a docker-compose project to this repo, GitLab detects which project changed
and gives you two one-click deploy buttons — one per host. You choose where to run it.

## Workflow

```
YOU run: gacp_tutorials_wcopy <project> "message"
         ↓
copies /devops/docker/<project> → tutorials/docker-compose/<project>
         ↓
git push → GitHub + GitLab
         ↓
--- GitLab pipeline takes over automatically ---
         ↓
detects which project folder changed
         ↓
[ click deploy:ranger0 ]     [ click deploy:endurance ]
         ↓
SSH into host:
  1. git pull tutorials repo
  2. rsync docker-compose/<project> → /devops/docker/<project>
  3. docker compose up -d
```

## What happens if you push FROM the host you deploy to

No problem. The pipeline SSHes back into the same machine:
- `git reset --hard` — files already match, nothing changes
- `rsync` — files already identical, nothing copies
- `docker compose up -d` — Docker sees no config change, does nothing

## Only triggers for docker-compose changes

Pushing to other folders (`linux/`, `AI/`, `network/`, etc.) does NOT trigger the deploy pipeline.

## Machines

| Job               | Host      | IP             |
|-------------------|-----------|----------------|
| `deploy:ranger0`  | ranger0   | 192.168.5.16   |
| `deploy:endurance`| endurance | 192.168.5.30   |

## Files

| File | Purpose |
|------|---------|
| `.gitlab-ci.yml` | Pipeline definition |
| `SSH_PRIVATE_KEY` | CI/CD variable in GitLab — private key used to SSH into each host |
