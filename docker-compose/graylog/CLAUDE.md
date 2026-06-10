# CLAUDE.md

## Homelab Configuration

**CRITICAL - Follow these defaults if applicable to your project:**

### For Docker Container Projects

**Docker Network:**
- **Network**: `FRONTEND` (already exists on homelab)
- Always attach containers to this network
- Example docker-compose.yml:
  ```yaml
  networks:
    default:
      name: FRONTEND
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
