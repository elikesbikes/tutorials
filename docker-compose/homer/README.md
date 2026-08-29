# Homer

Static homelab dashboard using [Homer](https://github.com/bastienwirtz/homer).

## Table of Contents

1. [Overview](#1-overview)
2. [What's Here](#2-whats-here)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)

## 1. Overview

Homer is a simple, static YAML-configured start page for the ELIKESBIKES homelab. It groups links to services across Network, Server, Monitoring, Smart Home, Applications, Docker, and Cloud categories.

## 2. What's Here

| File | Purpose |
|------|---------|
| `home.yml` | Full dashboard configuration (title, theme, links, services) |
| `icons/` | Service icons referenced by the config |

## 3. Configuration

Edit `home.yml` to add/remove service tiles. Each item supports `name`, `logo`, `subtitle`, `tag`, `url`, and `target`. Themes and light/dark colors are set at the top of the file.

## 4. Usage

Homer is a static site — mount `home.yml` as the container's `config.yml`, for example:

```bash
docker run -d -p 8080:8080 \
  -v "$(pwd)/home.yml:/www/assets/config.yml" \
  -v "$(pwd)/icons:/www/assets/icons" \
  b4bz/homer:latest
```

Then browse to `http://<host>:8080`.
