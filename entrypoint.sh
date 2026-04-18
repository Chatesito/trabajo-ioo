#!/bin/sh
set -e

echo ">> Esperando a PostgreSQL..."
python <<'PY'
import os, time, sys
import psycopg2
url = os.environ["DATABASE_URL"]
for i in range(60):
    try:
        psycopg2.connect(url).close()
        print(">> DB lista")
        sys.exit(0)
    except Exception as e:
        time.sleep(1)
print("!! No se pudo conectar a la DB tras 60s", file=sys.stderr)
sys.exit(1)
PY

echo ">> Aplicando migraciones"
python manage.py migrate --noinput

echo ">> Colectando archivos estáticos"
python manage.py collectstatic --noinput

echo ">> Iniciando: $@"
exec "$@"
