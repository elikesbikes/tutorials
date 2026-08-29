# Authelia — SSO / forward-auth for the homelab

Authelia protects selected `*.home.elikesbikes.com` services behind Traefik
`forwardauth` middleware. Users authenticate at the portal (1FA + optional OTP);
Traefik forwards each request to `authelia:9091/api/verify` and only proxies it
through on success.

## Topology — two hosts

| Host | IP | Portal | Protects (two_factor) |
|---|---|---|---|
| **endurance** (prod) | this box | `auth-end.home.elikesbikes.com` | `docker.home`, `reviere.home`, `reviere-dev.home` |
| **tars** (dev) | `192.168.5.127` | `auth-dev.home.elikesbikes.com` | `docker.home`, `reviere-dev.home` |

Both are the same compose stack; they differ only in portal hostname and which
reviere domains they cover. Keep the two configs in sync (structure/version),
not identical (host-specific values differ).

## Layout

- `docker-compose.yml` — `authelia` + `redis` services on the external `frontend` network.
- `config/configuration.yml` — main config (Authelia **v4.39**, no deprecation warnings).
- `config/users_database.yml` — file auth backend; argon2id password hashes.
- `config/db.sqlite3` — storage (TOTP secrets, etc.).
- `secrets/` — git-ignored secret files loaded via `AUTHELIA_*_FILE` env vars.

## Runs as non-root (uid 1000)

The container has `user: "1000:1000"` so bind-mounted `config/` files stay
owned by `ecloaiza`, not root. If files ever revert to root ownership:

```bash
sudo chown -R 1000:1000 config
docker compose up -d --force-recreate authelia
```

Port 9091 is unprivileged and `secrets/` is `ecloaiza`-owned (mounted `:ro`), so
non-root is safe. Redis stays on its default `redis` user.

## COOPER service account (`cooper-svc`)

The COOPER dashboard backend reads Reverie's HTTP API server-side and can't do
OTP, so it logs in as a dedicated **password-only** account and reuses the
`authelia_session` cookie (see MCC `docs/cooper.md`).

- User `cooper-svc` in `users_database.yml` (argon2id hash; plaintext lives in
  MCC `.env` as `AUTHELIA_SERVICE_PASSWORD`).
- An access-control rule for `user:cooper-svc` on the reviere domains with
  `policy: one_factor`, placed **above** the `two_factor` rule — so only this
  account skips OTP; browser users still get the full 1FA + OTP flow.
- `setup_cooper_svc.py` applies both idempotently (endurance only — COOPER talks
  to prod `reviere.home`, not `reviere-dev`).

## v4.39 config notes (post-4.38 migration)

These replaced deprecated keys (all warnings now gone):

- `server.address: 'tcp://0.0.0.0:9091'` (was `server.host`/`server.port`).
- `session.cookies:` list with per-cookie `authelia_url` (was `session.name`/`session.domain`).
- No global `default_redirection_url` (moved out; must differ from `authelia_url` if set).
- `notifier.smtp.address: submission://smtp.gmail.com:587` (was `smtp.host`/`smtp.port`).
- Compose env `AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE` (was `AUTHELIA_JWT_SECRET_FILE`).

## Restart / verify

```bash
docker compose up -d --force-recreate authelia
docker logs authelia-authelia-1 --tail 40 | grep -iE "level=(warning|error)|Startup complete"
docker exec authelia-authelia-1 wget -qO- http://localhost:9091/api/health   # -> {"status":"OK"}
```
