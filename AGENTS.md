# AGENTS.md — VPS Infrastructure as Code

> **Living document for AI agents.** Read this file before modifying anything in this repository. Update it after every critical infrastructure change (new/removed services, architecture changes, network/firewall/SSH/VPN changes, deployment flow changes, new scripts, env/secrets changes, etc.).

---

## 1. Project Overview

This repository is **Infrastructure as Code (IaC)** for provisioning and managing a single VPS that hosts multiple personal projects behind a shared Nginx reverse proxy.

- **Primary domain:** `amjad.cloud` (override with `BASE_DOMAIN` env var in `nginx/setup_nginx.sh`)
- **Main technologies:** Bash, Docker + Docker Compose, Nginx, UFW, Certbot, GitHub Container Registry (GHCR), WireGuard (wg-easy), SQLite, PostgreSQL, MySQL, Redis
- **Deployment model:** Each project is a Docker Compose service; images are pulled from `ghcr.io/amgad226/*` (and `ghcr.io/wg-easy/wg-easy`).

---

## 2. Infrastructure Architecture

```
Internet
   │
   ▼
┌─────────────────────────────────────────────┐
│  UFW Firewall (only 22/80/443 + project ports)
└─────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────┐
│  Nginx (host)                               │
│  • Listens on 80/443                        │
│  • Path-based routes: /portfolio, /vpn, ... │
│  • Subdomain routes: *.amjad.cloud          │
│  • Static dashboard at /var/www/vps-projects│
└─────────────────────────────────────────────┘
   │
   ├──► Docker containers on localhost ports
   │      • Portfolio          127.0.0.1:8088
   │      • GPS Dashboard      127.0.0.1:9100
   │      • GPS Backend API    127.0.0.1:3100
   │      • GPS Backend WS     127.0.0.1:5220
   │      • GPS MQTT broker    0.0.0.0:1883/8883/8083/8084/18083
   │      • WireGuard UI       0.0.0.0:51821 (TCP)
   │      • WireGuard tunnel   0.0.0.0:51820 (UDP)
   │      • Image Compressor   127.0.0.1:5000
   │      • York Certificate   127.0.0.1:3011
   │      • York Streaming     127.0.0.1:3005
   │      • York Frontend      127.0.0.1:3020
   │      • York V1            127.0.0.1:8080
   │      • Source Safe        127.0.0.1:5001
   │      • Map Trips          127.0.0.1:3001
   │
   └──► Internal databases/admin UIs on 127.0.0.1 only
          • PostgreSQL (source-safe) 5432
          • PostgreSQL (york cert)   5433
          • PostgreSQL (york nest)   5434
          • MySQL (york v1)          3307
          • Redis                    6379
          • Redis (york nest)        6380
          • phpMyAdmin (york v1)     8081
          • pgAdmin                  8888
```

- **External dependencies:**
  - GitHub Container Registry (`ghcr.io`) for all container images.
  - Let's Encrypt/Certbot for SSL certificates.
  - DNS A records for `amjad.cloud` and `*.{project}.amjad.cloud` must point to the VPS IP.

---

## 3. Repository Structure

| Path | Purpose |
|------|---------|
| `init.sh` | **Main orchestration script.** Run once (as root) on a fresh VPS. Installs dependencies, validates secrets/databases, optionally starts selected projects, configures firewall, and sets up Nginx. |
| `install/` | Apt-based installers used by `init.sh`. Each defines a shell function that is sourced and called. |
| `install/git.sh` | Installs Git. |
| `install/docker.sh` | Installs Docker, enables service, adds `$SUDO_USER` to `docker` group. |
| `install/tree.sh` | Installs `tree`. |
| `install/nginx.sh` | Installs Nginx. |
| `install/certbot.sh` | Installs Certbot + Nginx plugin. |
| `firewall/ufw.sh` | UFW helpers: `setup_firewall_strict` (resets UFW, denies incoming, allows SSH) and `open_port_if_needed`. |
| `login/ghcr.sh` | Logs Docker into GHCR using the PAT stored in `/home/admin/secrets/PAT_SECRET`. Hardcoded user `Amgad226`. |
| `login/gitlab.sh` | Logs Docker into GitLab Container Registry using the token stored in `/home/admin/secrets/GITLAB_TOKEN`. Hardcoded user `Amgad226`. |
| `nginx/setup_nginx.sh` | Generates Nginx config (`nginx/projects.conf`), deploys it to `/etc/nginx/sites-available/vps-projects`, syncs dashboard HTML to `/var/www/vps-projects`, disables competing default servers, reloads Nginx, and runs Certbot. |
| `nginx/s.sh` | **Interactive helper** to create an extra Nginx site from stubs (not used by automation). |
| `nginx/config/projects.env` | Source of truth for project name → path → port mapping used by `setup_nginx.sh`. Format: `name|path|port|flags`. |
| `nginx/web/index.html` | Static fallback dashboard (manually edited; `setup_nginx.sh` also auto-generates a dynamic version). |
| `secrets/` | **Sensitive files.** Contains `PAT_SECRET` and all `<project>.env` files. This directory is gitignored and must be placed on the VPS at `/home/admin/secrets` (and at `~/secrets` for validation). |
| `scripts/secrets/validate-secrets.sh` | Validates that `/home/admin/secrets` contains every secret env file and registry token used by the projects. |
| `scripts/secrets/validate-sqllite-databases.sh` | Validates `~/sqlite-databases/map-trips/file.db` and sets `chmod 777`. |
| `projects/` | One directory per service. Each contains a `docker-compose.yml` and a `run_*.sh` wrapper that copies its env from `/home/admin/secrets`. `projects/gps` has separate `backend/` (API + Postgres + Redis + MQTT) and `dashboard/` directories. |
| `hooks/pre-commit` | Git hook that blocks `docker-compose*.yml` port lines not bound to `127.0.0.1`. `projects/wg-easy/docker-compose.yml` is excluded because WireGuard must bind to the host interface. Pass `--fix` to auto-correct. |

### Script categories

- **Initialization/provisioning:** `init.sh`, `install/*.sh`, `firewall/ufw.sh`, `login/ghcr.sh`
- **Deployment:** `projects/*/run_*.sh`
- **Reverse proxy/SSL:** `nginx/setup_nginx.sh`, `nginx/s.sh`
- **Validation:** `scripts/secrets/validate-*.sh`
- **Maintenance/helpers:** `hooks/pre-commit`

---

## 4. VPS Provisioning Flow

### Fresh VPS requirements

- Ubuntu/Debian-based OS (uses `apt`, `systemctl`).
- Root access (or passwordless sudo) for the first run.
- A non-root user named **`admin`** is expected by several scripts (GHCR login, secret paths, database paths, fallback in `run_source_safe.sh`).
- A working SSH connection on port 22.

### Pre-run manual steps

1. Create `/home/admin/secrets/` and copy all required secret env files:
   - `PAT_SECRET` — GitHub Personal Access Token for GHCR.
   - `GITLAB_TOKEN` — GitLab Personal Access Token for the GitLab Container Registry.
   - `source-safe.env`, `map-trips.env`, `portfolio.env`, `image-compressor.env`, `wg.env`
   - GPS: `gps-backend.env`, `gps-dashboard.env`
   - York envs: `york-certificate.env`, `york-nest.env`, `york-next.env`, `york-staging-nest.env`, `york-v1.env`
2. Create `/home/admin/sqlite-databases/` and provide:
   - `map-trips/file.db`
3. Ensure DNS A records exist for `amjad.cloud` and `*.{project}.amjad.cloud`.

### Run provisioning

```bash
sudo bash ./init.sh
```

`init.sh` execution order:

1. Interactive phase — asks which services to run (or all).
2. `source ./scripts/secrets/validate-secrets.sh` → `validate_secrets`
3. `source ./scripts/secrets/validate-sqllite-databases.sh` → `validate_sqllite_databases`
4. Sources and runs installers:
   - `install/git.sh` → `install_git`
   - `install/docker.sh` → `install_docker`
   - `install/tree.sh` → `install_tree`
   - `install/nginx.sh` → `install_nginx`
   - `install/certbot.sh` → `install_certbot`
   - `login/ghcr.sh` → `login_to_ghcr`
   - `login/gitlab.sh` → `login_to_gitlab`
   - `bash ./login/ghcr.sh` (legacy duplicate login)
5. `setup_firewall_strict` — resets UFW, denies incoming, allows outgoing, opens 22/tcp.
6. Opens 80/tcp and 443/tcp.
7. For each selected service:
   - Opens the required port(s) in UFW.
   - Runs the project’s `run_*.sh` (copies env from `/home/admin/secrets`, pulls image, starts container).
8. Runs `nginx/setup_nginx.sh` if selected.

### Security hardening performed

- UFW default-deny incoming.
- Docker project ports are required to bind to `127.0.0.1` (enforced by pre-commit hook).
- WireGuard is the only service intentionally bound to `0.0.0.0`.
- Competing Nginx default_server blocks are disabled.

---

## 5. Configuration & Environment

### Environment files

All runtime `.env` files are **stored in `/home/admin/secrets/`** and copied into each project directory by the project’s `run_*.sh` before `docker compose up`.

| Secret file | Copied to | Used by |
|-------------|-----------|---------|
| `/home/admin/secrets/portfolio.env` | `projects/portfolio/.env` | Portfolio |
| `/home/admin/secrets/image-compressor.env` | `projects/image-compressor/.env` | Image Compressor |
| `/home/admin/secrets/wg.env` | `projects/wg-easy/.env` | WireGuard |
| `/home/admin/secrets/gps-backend.env` | `projects/gps/backend/.env` | GPS Backend |
| `/home/admin/secrets/gps-dashboard.env` | `projects/gps/dashboard/.env` | GPS Dashboard |
| `/home/admin/secrets/source-safe.env` | `projects/source-safe/.env` | Source Safe |
| `/home/admin/secrets/map-trips.env` | `projects/map-trips/.env` | Map Trips |
| `/home/admin/secrets/york-certificate.env` | `projects/york/docker/certificate/.env` | York Certificate |
| `/home/admin/secrets/york-nest.env` | `projects/york/docker/nest/.env` | York Nest |
| `/home/admin/secrets/york-next.env` | `projects/york/docker/next/.env` | York Next |
| `/home/admin/secrets/york-staging-nest.env` | `projects/york/docker/staging-nest/.env` | York Staging Nest (manual) |
| `/home/admin/secrets/york-v1.env` | `projects/york/docker/york_v1/.env` | York V1 |

The old `envs/` folder has been removed. `.env` files are gitignored so they are never committed.

### Secrets handling

- Secrets live in `secrets/` (gitignored) and on the VPS at `/home/admin/secrets/` and `~/secrets/`.
- `PAT_SECRET` is the GHCR token.
- `GITLAB_TOKEN` is the GitLab Container Registry token.
- **Do not commit real secrets.** The pre-commit hook only checks Docker port binding, not secrets.
- `scripts/secrets/validate-secrets.sh` checks that every required secret env file exists before provisioning.

### Required manual configuration

- DNS records pointing to the VPS.
- `/home/admin/secrets/PAT_SECRET` with GHCR read access.
- `/home/admin/secrets/GITLAB_TOKEN` with GitLab registry read access.
- All project env files listed above.
- `/home/admin/sqlite-databases/map-trips/file.db`.
- If `BASE_DOMAIN` is not `amjad.cloud`, run `nginx/setup_nginx.sh` with `BASE_DOMAIN=your.domain`.

---

## 6. Services Management

### Portfolio (`projects/portfolio/`)
- **Purpose:** Laravel portfolio app.
- **Image:** `ghcr.io/amgad226/laravel-portfolio:latest`
- **Public port:** `127.0.0.1:8088`
- **Internal port:** PHP-FPM `9000` inside `laravel` container; Nginx container exposes `127.0.0.1:8088:80`.
- **Run:** `bash ./projects/portfolio/run_portfolio.sh`
- **Stop:** `cd projects/portfolio && docker compose down`
- **Deps:** SQLite database mounted from `./database.sqlite`; `start.sh` runs migrations/config cache inside the container.

### GPS Project (`projects/gps/`)
- **Purpose:** GPS backend API + dashboard.
- **Backend image:** `registry.gitlab.com/amgad226/gps-backend/backend:dev`
  - Container: `gps-backend`
  - Public ports: `127.0.0.1:3100` (API), `127.0.0.1:5220` (WS)
  - Internal services: PostGIS on `127.0.0.1:5435`, Redis on `127.0.0.1:6381`, EMQX MQTT broker on host ports `1883/8883/8083/8084/18083`
- **Dashboard image:** `registry.gitlab.com/amgad226/manage-fleet-pro/dashboard:dev`
  - Container: `gps-dashboard`
  - Public port: `127.0.0.1:9100`
- **Run:** `bash ./projects/gps/run_gps.sh`
- **Routes:**
  - Dashboard: `https://amjad.cloud/gps` and `https://gps-dashboard.amjad.cloud`
  - Backend: `https://amjad.cloud/gps-backend` and `https://gps-backend.amjad.cloud`
- **Deps:** `gps-backend.env` and `gps-dashboard.env` copied from `/home/admin/secrets`.

### WireGuard / wg-easy (`projects/wg-easy/`)
- **Purpose:** VPN server and web UI.
- **Image:** `ghcr.io/wg-easy/wg-easy`
- **Public ports:** `51820/udp` (WireGuard tunnel), `51821/tcp` (web UI).
- **Volume:** `../../../wg-easy` mounted to `/etc/wireguard` — persistent peer config lives **outside** the compose project at repo-root-level `wg-easy/`.
- **Run:** `bash ./projects/wg-easy/run_wg.sh`
- **Caps:** `NET_ADMIN`, `SYS_MODULE`; enables `ip_forward`.

### Image Compressor (`projects/image-compressor/`)
- **Purpose:** Flask image compression service.
- **Image:** `ghcr.io/amgad226/image-compressor:latest`
- **Public port:** `127.0.0.1:5000`
- **Run:** `bash ./projects/image-compressor/run_image_compressor.sh`

### Source Safe (`projects/source-safe/`)
- **Purpose:** Source-safe API with Postgres and Redis.
- **Image:** `ghcr.io/amgad226/source-safe:latest`
- **Public port:** `127.0.0.1:5001`
- **Internal DB port:** `127.0.0.1:5432`
- **Internal Redis port:** `127.0.0.1:6379`
- **Run:** `bash ./projects/source-safe/run_source_safe.sh`

### Map Trips (`projects/map-trips/`)
- **Purpose:** Map trips service.
- **Image:** `ghcr.io/amgad226/map-trips:latest`
- **Public port:** `127.0.0.1:3001` (container listens on 3000)
- **Run:** `bash ./projects/map-trips/run_map_trips.sh`
- **Deps:** SQLite volume `/home/admin/sqlite-databases/map-trips:/app/data`; env file copied from `/home/admin/secrets/map-trips.env`.

### York multi-service project (`projects/york/`)
- Started by `bash ./projects/york/run_york.sh`.
- **york_v1** — Laravel + MySQL + phpMyAdmin (`docker/york_v1/`). Public `127.0.0.1:8080`. MySQL on `127.0.0.1:3307`.
- **nest** — NestJS streaming backend (`docker/nest/`). Public `127.0.0.1:3005`. Postgres on `127.0.0.1:5434`, Redis on `127.0.0.1:6380`.
- **certificate** — NestJS certificate backend (`docker/certificate/`). Public `127.0.0.1:3011`. Postgres on `127.0.0.1:5433`, pgAdmin on `127.0.0.1:8888`.
- **next** — Next.js frontend (`docker/next/`). Public `127.0.0.1:3020`.
- **gateway** — Internal Nginx gateway (`docker/gateway/`). Public `127.0.0.1:8090`.
- **staging-nest** — Exists (`docker/staging-nest/`) but is **NOT started by `run_york.sh`**. Start manually if needed on `127.0.0.1:3007`.

---

## 7. Networking & Security

### Open ports (after `init.sh`)

| Port | Protocol | Service | Notes |
|------|----------|---------|-------|
| 22 | TCP | SSH | Always allowed by UFW |
| 80 | TCP | Nginx HTTP | Allowed always |
| 443 | TCP | Nginx HTTPS | Allowed always |
| 5000 | TCP | Image Compressor | If image selected |
| 5001 | TCP | Source Safe | If source-safe selected |
| 3001 | TCP | Map Trips | If map-trips selected |
| 3100 | TCP | GPS Backend API | If GPS selected |
| 5220 | TCP | GPS Backend WS | If GPS selected |
| 9100 | TCP | GPS Dashboard | If GPS selected |
| 1883 | TCP | GPS MQTT (TCP) | If GPS selected |
| 8883 | TCP | GPS MQTT (SSL) | If GPS selected |
| 8083 | TCP | GPS MQTT (WS) | If GPS selected |
| 8084 | TCP | GPS MQTT (WSS) | If GPS selected |
| 18083 | TCP | GPS MQTT Dashboard | If GPS selected |
| 51820 | UDP | WireGuard tunnel | If wg selected |
| 51821 | TCP | WireGuard web UI | If wg selected |
| 3011 | TCP | York Certificate | If york selected |
| 3005 | TCP | York Streaming | If york selected |
| 3020 | TCP | York Frontend | If york selected |
| 8080 | TCP | York V1 | If york selected |
| 3007 | TCP | York Staging Nest | Opened by `init.sh` but service not auto-started |

Internal admin/DB ports (`5432`, `5433`, `5434`, `3307`, `6379`, `6380`, `8081`, `8888`, `8090`) are bound to `127.0.0.1` and **not** opened in UFW.

### Firewall

- Script: `firewall/ufw.sh`
- `setup_firewall_strict` resets UFW and enables default-deny.
- `open_port_if_needed` adds UFW rules idempotently.

### Reverse proxy

- Generated config: `/etc/nginx/sites-available/vps-projects` → `sites-enabled/vps-projects`.
- Path-based routes on `amjad.cloud` and direct IP.
- Subdomain routes on `{project}.amjad.cloud`.
- WebSocket headers included.
- `image-compressor` and `map-trips` have `large` flag → 1 GB upload + 300 s timeouts.

### SSL/TLS

- Certbot email hardcoded in `nginx/setup_nginx.sh`: `amgad.wr.1@gmail.com`.
- Cert-name: `$BASE_DOMAIN`.
- Domains include `$BASE_DOMAIN` plus every `{project}.$BASE_DOMAIN` from `nginx/config/projects.env`.
- `setup_nginx.sh` reinstalls existing certs or requests new ones.
- York gateway SSL config (`nginx-ssl.conf`) references `/etc/letsencrypt/live/amjad.cloud-0001/` — ensure this cert name/path matches what Certbot created.

### SSH

- Port 22 is the only port opened before services are selected.
- No SSH hardening script is included in this repo; assume SSH key-based auth and root-login disabled are configured manually.

### VPN

- WireGuard via `wg-easy`.
- Web UI on `https://wg.amjad.cloud` or `https://<ip>/vpn`.

---

## 8. Deployment Process

1. Push new image to GHCR from the corresponding application repository.
2. On the VPS, run the relevant project `run_*.sh`:
   ```bash
   bash ./projects/<project>/run_<project>.sh
   ```
3. The script copies the env file from `/home/admin/secrets`, runs `docker compose pull`, then `docker compose up -d`.
4. If a project port or route changed, run `bash ./nginx/setup_nginx.sh` to regenerate Nginx config and optionally request new SSL certs.

### Rollback

- No automated rollback. To revert, pull and run the previous image tag manually or use `docker compose down && docker image tag ... && docker compose up -d`.

---

## 9. Maintenance Operations

### Logs

- Docker logs: `docker logs -f <container_name>`
- Nginx access/error: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
- Project logs are inside containers; use `docker compose logs`.

### Backups

- SQLite databases in `/home/admin/sqlite-databases/` should be backed up.
- Docker volumes (`postgres_data`, `redis_data`, `mysql_data`, `certificate_db_data`, etc.) are not automatically backed up by these scripts.

### Monitoring

- No dedicated monitoring stack is deployed. Check service health with `docker ps` and `systemctl status nginx`.

### Troubleshooting

```bash
# Check all containers
docker ps -a

# Check Nginx config
sudo nginx -t

# Reload Nginx after manual changes
sudo systemctl reload nginx

# Check UFW status
sudo ufw status verbose

# Re-run Nginx + SSL setup
bash ./nginx/setup_nginx.sh

# Validate secrets/databases manually
bash ./scripts/secrets/validate-secrets.sh
bash ./scripts/secrets/validate-sqllite-databases.sh
```

---

## 10. Important Commands

```bash
# Full provisioning (run as root)
sudo bash ./init.sh

# Regenerate Nginx reverse proxy + SSL
bash ./nginx/setup_nginx.sh

# Start a single project
bash ./projects/portfolio/run_portfolio.sh
bash ./projects/gps/run_gps.sh
bash ./projects/wg-easy/run_wg.sh
bash ./projects/image-compressor/run_image_compressor.sh
bash ./projects/source-safe/run_source_safe.sh
bash ./projects/map-trips/run_map_trips.sh
bash ./projects/york/run_york.sh

# Stop a project
cd projects/<project> && docker compose down

# Restart Nginx
sudo systemctl restart nginx

# View firewall
sudo ufw status

# Docker cleanup
docker system prune -a --volumes
```

---

## 11. Agent Rules

- **Always read `AGENTS.md`** before modifying infrastructure.
- **Inspect existing scripts** before creating new ones; preserve patterns (env copied from `/home/admin/secrets`, `127.0.0.1` port binding, `docker compose pull`, etc.).
- **Keep scripts idempotent** whenever possible (check if installed before installing, use `open_port_if_needed`, use `ln -sf`, etc.).
- **Do not store secrets inside scripts.** All runtime `.env` files must live in `/home/admin/secrets/` and be copied by `run_*.sh` scripts.
- **Never commit secrets or runtime `.env` files.** They are gitignored; verify with `git status`.
- **Avoid destructive changes** unless explicitly requested. `setup_firewall_strict` resets UFW — call it only during intentional reprovisioning.
- **Update `AGENTS.md`** after every critical infrastructure modification (new services, removed services, port changes, firewall/SSH/VPN changes, deployment flow changes, new scripts, env/secrets changes).
- **Prefer automation over manual server changes.** If you change something on the server, mirror it in the repo.
- **Run `nginx/setup_nginx.sh`** after any change to `nginx/config/projects.env` or project ports/paths.
- **Run the pre-commit hook** (`cp hooks/pre-commit .git/hooks/pre-commit`) to enforce localhost Docker port binding (except WireGuard).
- **Explain the impact** of critical changes in your response and in `AGENTS.md`.
