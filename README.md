# Packing Scan — Deployment Guide

## Project Structure
```
packing_scan/
├── run.py                  # Entry point
├── requirements.txt
├── app/
│   ├── __init__.py         # Flask app factory
│   ├── config.py           # App + DB config
│   ├── db.py               # DB connection pool & helpers
│   ├── auth.py             # Operator authentication
│   ├── scan.py             # Scan business logic
│   ├── admin.py            # Admin dashboard queries
│   ├── routes_scan.py      # Scan + auth routes
│   └── routes_admin.py     # Admin routes
├── templates/
│   ├── base.html
│   ├── login.html          # Operator login
│   ├── scan.html           # Main scan UI
│   ├── admin_login.html
│   └── admin.html          # Admin dashboard
└── static/
    └── css/style.css
```

## Database Requirements

### Table: energous.esense_main
Expected columns: serial_num, po_num, progtest, assembly, lasermarking1, vi, ft1, ft2, lasermarking2, fvi, packing

### Table: energous.esense_packing
Expected columns: id (AI PK), serial_num, po_num, operator_en, shift, date_time, test_rep, remarks, status

### Table: operators.main
Expected columns: operator_en (and any other operator info)

## Installation

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. (Optional) Override DB settings via environment
export DB_HOST=192.168.1.38
export DB_USER=labeling
export DB_PASSWORD=labelling
export DB_NAME=energous

# 3. Set a strong secret key for sessions
export SECRET_KEY=your-random-secret-here

# 4. Change the admin password in app/routes_admin.py
#    ADMIN_PASSWORD = "your-secure-password"
```

## Running

### Development
```bash
python run.py
```

### Production (Gunicorn recommended)
```bash
gunicorn -w 4 -b 0.0.0.0:5000 "app:create_app()"
```

## Usage

| URL | Purpose |
|-----|---------|
| `/login` | Operator sign in (employee_num) |
| `/` | Main scan screen |
| `/admin/login` | Admin dashboard login |
| `/admin/` | Admin dashboard |

## Scan Logic

1. Operator logs in with **Employee Number** → looked up in `operators.main.operator_en`
2. On scan: looks up `b2btag_main` by `serial_num`
3. Checks if `progtest=1`, `assembly=1`, `fvi=1`
4. If all pass → sets `packing=1` in `b2btag_main` and inserts into `b2btag_packing` with `test_rep=1`, `status=1`
5. Tray counter increments up to 50; "New Tray" resets the in-session counter

## Admin Dashboard
- Password protected (set `ADMIN_PASSWORD` in `routes_admin.py`)
- Shows: per-operator scan counts, daily summaries, full log table, per-operator drill-down
