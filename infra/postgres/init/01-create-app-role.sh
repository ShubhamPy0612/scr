#!/bin/sh
# SCR Postgres init - v0.1.0 (Phase 0). Runs once, only when the data volume is empty.
set -eu

APP_DB_PASSWORD="$(cat /run/secrets/pg_app_password)"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_password="$APP_DB_PASSWORD" <<'SQL'
CREATE ROLE scr_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'app_password';

REVOKE ALL ON DATABASE :"DBNAME" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE :"DBNAME" TO scr_app;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE SCHEMA app AUTHORIZATION scr_app;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA app;

ALTER ROLE scr_app SET search_path = app;
SQL

echo "scr: app role and schema created"
