# GPS production operations

The GPS backend runs one responsibility per container. GitLab builds and pushes
`registry.gitlab.com/amgad226/gps-backend/backend:main`; production deployment is
started manually over SSH. GitLab never receives VPS credentials.

## Commands

Run from the IaC repository root on the VPS:

```bash
bash ./projects/gps/run_gps.sh status
bash ./projects/gps/run_gps.sh deploy
bash ./projects/gps/run_gps.sh logs
bash ./projects/gps/run_gps.sh logs telemetry-worker notification-worker
bash ./projects/gps/run_gps.sh rollback
```

`deploy` performs preflight validation, installs the env files from
`/home/admin/secrets`, creates a PostgreSQL dump and Redis snapshot under
`/home/admin/backups/gps`, tags the currently running backend image locally for
rollback, pulls `backend:main`, runs the one-shot bootstrap migration, starts the
split services, and waits for health checks. A backend failure triggers an
automatic rollback.

The first deployment can roll back to the legacy monolith through
`docker-compose.legacy.yml`. Later deployments roll back to the preceding split
image. The rollback image is local and must not be pruned until the release is
accepted.

## MQTT retirement

The deployment removes the obsolete `gps-mqtt-broker` container after the split
backend is healthy. After the release has been monitored and MQTT data is no
longer needed, remove its persistent volumes explicitly:

```bash
bash ./projects/gps/run_gps.sh cleanup-mqtt
```

This command is destructive and removes `backend_emqx_data` and
`backend_emqx_log`.

## First pull with the portfolio SQLite file

Older checkouts tracked `projects/portfolio/database.sqlite`. The production
copy contains runtime data and must be backed up before pulling the commit that
removes it from Git. Do not reset or overwrite the server copy. After the backup,
move the runtime file aside, pull with `--ff-only`, then restore the file at the
same path; it is now ignored by Git.

## Network exposure

- `127.0.0.1:3100` — host Nginx to `gps-edge` only.
- `0.0.0.0:5220` — public raw tracker TCP gateway.
- `127.0.0.1:5435` — PostgreSQL administration.
- `127.0.0.1:6381` — Redis administration.

Port `3100` must not have a public UFW rule. The deploy script removes the old
rule when passwordless sudo is available.
