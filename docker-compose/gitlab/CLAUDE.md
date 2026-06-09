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
- **Syslog Server**: `192.168.5.16` (Graylog)
- All Docker containers must send logs here
- Example docker-compose.yml:
  ```yaml
  services:
    myapp:
      logging:
        driver: syslog
        options:
          syslog-address: "udp://192.168.5.16:514"
          tag: "myapp"
  ```

**Storage / Volumes:**
- **NEVER use Docker volumes** - Always use bind mounts for persistent data only
- **Move app code/files INTO the container** via Dockerfile
- **Only bind mount data that persists across restarts** (databases, uploads, logs, config)
- Example Dockerfile:
  ```dockerfile
  FROM python:3.11-slim
  WORKDIR /app
  COPY src/ /app/src/        # App code goes in container
  COPY requirements.txt /app/
  RUN pip install -r requirements.txt
  ```
- Example docker-compose.yml:
  ```yaml
  services:
    myapp:
      volumes:
        - ./data:/app/data       # Only persistent data
        - ./config:/app/config   # Only config that changes
  ```
- Create bind mount directories before starting:
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
├── app/                      # App code (COPY into container)
├── data/                     # Bind mount for persistent data
└── config/                   # Bind mount for config files
```

**Note:** 
- `app/` = application source code, copied into container during build (not mounted as volume)
- `data/`, `config/` = bind-mounted directories that persist on host

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