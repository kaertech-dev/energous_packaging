# Energous Packaging Scan

Flask app for the Energous packaging station: an operator signs in with an employee number, scans units into a tray of 50, and each passing unit is marked as packed in production.

In production it runs on **kts-app** (CT 212) behind the kts-proxy at:

```
http://kts-app.kaertech.local/energous-packaging/
```

Operators open it from the Projects Dashboard at `http://kts-app.kaertech.local/`. The container has no host port; only the proxy reaches it.

## Project Structure

```
energous_packaging/
├── run.py                  # Entry point (gunicorn run:app)
├── requirements.txt
├── Dockerfile              # python:3.11-slim, gunicorn, TZ=Asia/Manila, non-root
├── docker-compose.yml      # service "traceability", container energous_packing, port 5052
├── .env.example            # copy to .env and fill in
├── app/
│   ├── __init__.py         # App factory: ProxyFix, config validation, 503 handler
│   ├── config.py           # Settings from environment (no defaults for secrets)
│   ├── db.py               # PyMySQL connections with timeouts
│   ├── auth.py             # Operator lookup
│   ├── scan.py             # Scan rules
│   ├── admin.py            # Admin dashboard queries
│   ├── routes_scan.py      # Operator login + scan API
│   └── routes_admin.py     # Admin login + dashboard API
├── templates/              # base, login, scan, admin_login, admin
└── static/css/style.css
```

## Configuration

Create `.env` from the example (`Copy-Item .env.example .env` in PowerShell, `cp .env.example .env` on Linux) and set every value:

| Variable | Purpose |
|---|---|
| `SECRET_KEY` | Signs the session cookie. Use a long random value, unique to this app. |
| `ADMIN_PASSWORD` | Password for `/admin/login`. Use a strong value; there is no default. |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` | MySQL connection (production: kts-db, 192.168.20.210). |
| `DB_NAME` | `energous` |

The app **refuses to start** if `SECRET_KEY`, `ADMIN_PASSWORD` or any `DB_*` value except `DB_PORT` is missing. `.env` is ignored by git and excluded from the Docker image; never commit it.

Generate a secret with:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

## Running

### Local development

```bash
pip install -r requirements.txt
python run.py            # http://localhost:5052
```

### Docker

```bash
docker compose up -d --build
```

The container runs gunicorn (2 workers, 60 s timeout) as a non-root user, with `TZ=Asia/Manila` so timestamps match shop time. MySQL connections use a 5 s connect and 10 s read/write timeout. If the database is unreachable, API calls return HTTP 503 with a retry message.

### On kts-app

Deployed from `main` only, after a reviewed PR. On the server, a local `compose.override.yaml` (not in git) removes the host port and joins the `kts-proxy` network:

```yaml
services:
  traceability:
    ports: !reset []
    networks: [default, kts-proxy]
networks:
  kts-proxy:
    external: true
```

The proxy route in `~/apps/kts-proxy/Caddyfile` forwards `/energous-packaging/` to `energous_packing:5052` with `X-Forwarded-Prefix`.

## Serving under a path prefix

The app must work both at `/` (local) and under `/energous-packaging/` (kts-app). Keep to these rules in every change:

1. `ProxyFix(x_prefix=1)` in `app/__init__.py` reads the prefix from the proxy. Do not remove it.
2. `templates/base.html` defines `var APP_ROOT = {{ request.script_root|tojson }};` (empty locally).
3. In JavaScript, build every URL with it: `fetch(APP_ROOT + '/api/scan')`, `location.href = APP_ROOT + '/login'`. **Never** use a bare `'/api/...'` or `'/login'`.
4. In templates and Python, use `url_for(...)` for links, redirects and static files.
5. The session cookie is `packaging_session`, separate from the other apps on the same host.

## Usage

| Path | Purpose |
|---|---|
| `/login` | Operator sign in (employee number) |
| `/` | Scan screen |
| `/admin/login` | Admin sign in (`ADMIN_PASSWORD`) |
| `/admin/` | Admin dashboard |

On kts-app, prefix these with `/energous-packaging`.

## Database

The app reads and writes **production** tables:

| Table | Use |
|---|---|
| `energous.esense_main` | Unit status: `serial_num`, `po_num`, `progtest`, `assembly`, `lasermarking1`, `vi`, `ft1`, `ft2`, `lasermarking2`, `fvi`, `packaging` |
| `energous.esense_packaging` | Packing log: `id` (AI PK), `serial_num`, `po_num`, `operator_en`, `shift`, `date_time`, `test_rep`, `remarks`, `status` |
| `operators.main` | Operator lookup by `operator_en` |

## Scan Logic

1. The operator signs in with an employee number, looked up in `operators.main.operator_en`.
2. A scanned serial is looked up in `energous.esense_main`.
3. If it already has a row in `esense_packaging`, it is rejected as **already packed**.
4. The unit must have passed **all** stations: `progtest`, `assembly`, `lasermarking1`, `vi`, `ft1`, `ft2`, `lasermarking2` and `fvi` (each `= 1`). Otherwise the scan fails and lists the missing stations.
5. On a pass, in one transaction: `packaging = 1` is set in `esense_main` and a row is inserted into `esense_packaging` with `test_rep = 1`, `status = 1`.
6. The tray counter goes up to 50; **New Tray** resets it for the session.

## Admin Dashboard

Protected by `ADMIN_PASSWORD` from `.env`. It shows per-operator scan counts, daily summaries, the full log and a per-operator drill-down.
