# OpenLDAP

Self-hosted [OpenLDAP](https://www.openldap.org/) directory (osixia image) with phpLDAPadmin.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Provides a central LDAP directory for the `home.elikesbikes.com` domain, with a phpLDAPadmin web UI for management. TLS is enabled with client-cert verification (`demand`).

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `openldap-prod-app-1` | `osixia/openldap:1.5.0` | LDAP server |
| `openldap-prod-php-1` | `osixia/phpldapadmin:latest` | Web admin UI |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`

## 4. Configuration

Key settings (defined in the compose file):

| Setting | Value |
|---------|-------|
| `LDAP_ORGANISATION` | `ELIKESBIKES` |
| `LDAP_DOMAIN` | `home.elikesbikes.com` |
| `LDAP_BASE_DN` | `dc=home.elikesbikes,dc=com` |
| `LDAP_ADMIN_PASSWORD` | `admin` (change for production) |

TLS certs (`ldap.crt`, `ldap.key`, `ca.crt`, `dhparam.pem`) are expected in the certs volume.

## 5. Usage

```bash
docker compose up -d
```

## 6. Access

- LDAP: `ldap://<host>:389`, `ldaps://<host>:636`
- phpLDAPadmin: `http://<host>:8080`
