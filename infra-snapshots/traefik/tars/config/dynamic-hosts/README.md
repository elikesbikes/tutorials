# Per-host dynamic config

Traefik dynamic config is split so changes can be pushed from tars to every host
without leaking host-specific routers onto the wrong box.

- `config/dynamic/`            — SHARED. Loaded by every host (middlewares, etc.).
- `config/dynamic-hosts/<host>/` — HOST-SPECIFIC. Only the matching host mounts it.

Each host sets `PROXY_HOST=<host>` in its (git-ignored) `.env`. docker-compose mounts:

    ./config/dynamic         -> /etc/traefik/dynamic/shared
    ./config/dynamic-hosts/${PROXY_HOST} -> /etc/traefik/dynamic/host

The file provider watches `/etc/traefik/dynamic` recursively, loading both.

When onboarding a new Traefik host, create `config/dynamic-hosts/<newhost>/`
with a placeholder file so the directory is tracked in git.
