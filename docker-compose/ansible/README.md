# Ansible (Semaphore UI)

Web-based Ansible automation via [Semaphore UI](https://semaphoreui.com/), backed by MySQL and paired with a companion MCP server for programmatic access.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

This stack runs Semaphore (container `ansible-prod-1`) as a UI for launching Ansible playbooks, with a MySQL 8.0 database for persistence and an `ansible-mcp` server exposing Semaphore to MCP clients.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `mysql` | `mysql:8.0` | Semaphore database |
| `semaphore` | `semaphoreui/semaphore:v2.8.90` | Ansible automation UI |
| `ansible-mcp` | built from `./mcp-server` | MCP bridge to Semaphore |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend` (`docker network create -d bridge frontend`)
- `./inventory/`, `./authorized-keys/`, and `./config/` directories

## 4. Configuration

Provide a `.env` file with:

```env
SEMAPHORE_DB_USER=
SEMAPHORE_DB_PASS=
MYSQL_PASSWORD=
SEMAPHORE_ADMIN_NAME=
SEMAPHORE_ADMIN_EMAIL=
SEMAPHORE_ADMIN_PASSWORD=
SEMAPHORE_ACCESS_KEY_ENCRYPTION=
```

## 5. Usage

```bash
docker compose up -d
docker compose logs -f semaphore
```

## 6. Access

- Semaphore UI: `http://<host>:3010`
- MCP server: `http://<host>:8765`
