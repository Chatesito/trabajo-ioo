#!/bin/sh
set -e

echo ">> Esperando a PostgreSQL..."
python <<'PY'
import os, time, sys
import psycopg2
url = os.environ["DATABASE_URL"]
for i in range(60):
    try:
        psycopg2.connect(url, connect_timeout=1).close()
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

if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo ">> Asegurando superusuario $DJANGO_SUPERUSER_USERNAME"
    python <<PY
import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
django.setup()
from django.contrib.auth import get_user_model
U = get_user_model()
u, created = U.objects.get_or_create(
    username=os.environ["DJANGO_SUPERUSER_USERNAME"],
    defaults={"email": os.environ.get("DJANGO_SUPERUSER_EMAIL", "")},
)
u.is_staff = True
u.is_superuser = True
u.set_password(os.environ["DJANGO_SUPERUSER_PASSWORD"])
u.save()
print(f"   {'creado' if created else 'actualizado'}: {u.username}")
PY
fi

echo ">> Iniciando: $@"
exec "$@"
