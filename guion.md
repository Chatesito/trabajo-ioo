# Guión del Taller IOO — Podman + Django + PostgreSQL

> Guía completa y detallada de TODO lo que se hizo en el trabajo, pensada para que lo entiendas al 100% y lo puedas sustentar sin depender de apuntes.

---

## Índice

1. [¿Qué es Podman y por qué no Docker?](#1-qué-es-podman-y-por-qué-no-docker)
2. [Conceptos fundamentales](#2-conceptos-fundamentales)
3. [Arquitectura del proyecto](#3-arquitectura-del-proyecto)
4. [Dockerfile — línea por línea](#4-dockerfile--línea-por-línea)
5. [compose.yml — línea por línea](#5-composeyml--línea-por-línea)
6. [entrypoint.sh — línea por línea](#6-entrypointsh--línea-por-línea)
7. [Flujo de ejecución completo](#7-flujo-de-ejecución-completo)
8. [Persistencia con volúmenes](#8-persistencia-con-volúmenes)
9. [Publicación en Docker Hub](#9-publicación-en-docker-hub)
10. [Cheat sheet de comandos](#10-cheat-sheet-de-comandos)
11. [Preguntas probables del profe](#11-preguntas-probables-del-profe)

---

## 1. ¿Qué es Podman y por qué no Docker?

### Docker en una frase

Docker es una herramienta que permite empaquetar una aplicación junto con TODAS sus dependencias (el sistema operativo base, librerías, código, configuración) en una "caja" llamada **imagen**. Esa imagen se puede ejecutar en cualquier máquina que tenga Docker, y va a correr exactamente igual que en la máquina donde se creó. Adiós al "en mi máquina funciona".

### ¿Y Podman?

**Podman es un reemplazo directo de Docker.** Hace exactamente lo mismo, con comandos idénticos (`podman run`, `podman build`, `podman ps`, etc). La diferencia está en CÓMO lo hace por dentro.

| Característica | Docker | Podman |
|----------------|--------|--------|
| Arquitectura | Cliente + **daemon** privilegiado (root) | **Sin daemon**, procesos normales del usuario |
| Seguridad | Requiere grupo `docker` (≈ root) | **Rootless** por defecto |
| Compatibilidad | Formato OCI | Formato OCI (100% compatible) |
| Compose | `docker compose` (plugin v2) | `podman-compose` o `podman compose` |
| Imágenes | De cualquier registry | De cualquier registry (incluido Docker Hub) |

**En cristiano:** cuando corrés `docker run`, hay un proceso llamado `dockerd` corriendo de fondo como **root** que hace el trabajo. Si lo hackean, chau máquina. En Podman no hay ese proceso — tus contenedores corren como procesos tuyos, con tus permisos.

### ¿Por qué lo elegimos?

1. **Autorizado por el profe** — él pide Docker pero aprobó Podman.
2. **Ya estamos en Linux** — Podman brilla en Linux (en Windows/Mac anda pero no tanto).
3. **Sin daemon ni sudo** — más simple de instalar en CachyOS (`sudo pacman -S podman podman-compose` y listo).
4. **Las imágenes son compatibles 1:1** — todo lo que publiquemos a Docker Hub desde Podman funciona con Docker sin tocar nada.

### ¿Qué cambia a nivel de comandos?

Literalmente casi nada. Mirá:

```bash
# Docker                                      # Podman
docker build -t app .                         podman build -t app .
docker run -d -p 8000:8000 app                podman run -d -p 8000:8000 app
docker ps                                     podman ps
docker logs <id>                              podman logs <id>
docker-compose up                             podman-compose up
```

Son alias mentales. Si sabés uno, sabés el otro.

---

## 2. Conceptos fundamentales

Antes de meternos al código, hay 6 conceptos que TENÉS que dominar:

### 2.1. Imagen

Es una **plantilla inmutable** que contiene todo lo necesario para correr una app: sistema operativo base, runtimes (Python, Node, etc), librerías, tu código, configuración. Una imagen **no está corriendo**, es solo un archivo en disco.

Analogía: una imagen es como una **clase** en POO. Un molde.

### 2.2. Contenedor

Es una **instancia corriendo** de una imagen. Podés tener 10 contenedores creados desde la misma imagen.

Analogía: un contenedor es como un **objeto** instanciado de una clase.

```
Imagen (clinica-ioo:latest)
    │
    ├── podman run ──▶  Contenedor 1 (clinica_web)
    └── podman run ──▶  Contenedor 2 (otro-web-de-prueba)
```

### 2.3. Volumen

Los contenedores son **efímeros**: cuando se borran, todo lo que escribieron dentro desaparece. Por eso, para datos que tienen que sobrevivir (una base de datos, por ejemplo), usamos **volúmenes**.

Un volumen es un pedazo de disco del host que Podman administra, y que se **monta** dentro del contenedor en una ruta específica. Sobrevive a `down`, reinicios, rebuilds.

```
┌─────────────────┐            ┌──────────────────┐
│ Contenedor db   │            │ Host (disco)     │
│                 │    mount   │                  │
│ /var/lib/       │◀──────────▶│ /var/lib/        │
│   postgresql/   │            │   containers/... │
│   data/         │            │     pgdata/      │
└─────────────────┘            └──────────────────┘
```

### 2.4. Red

Cuando tenés múltiples contenedores que se hablan entre sí, se ponen en una **red virtual**. Dentro de esa red, cada contenedor **tiene un nombre DNS** igual al nombre del servicio. Por eso en nuestro proyecto el web le habla al db con el hostname literal `db`, no con una IP.

```
Red: clinica_net
├── clinica_web (resuelve "db" → IP interna del contenedor db)
└── clinica_db  (resuelve "web" → IP interna del contenedor web)
```

Si no los pusieras en la misma red, ni se ven.

### 2.5. Puerto: mapeo host ↔ contenedor

Un contenedor es una isla. Si no le abrís una puerta al host, nadie desde afuera lo puede alcanzar. Esa puerta es el **port mapping**:

```
ports:
  - "8000:8000"
   ↑     ↑
   │     └── puerto DENTRO del contenedor (gunicorn escucha acá)
   └──────── puerto en el HOST (tu PC)
```

Entonces cuando tu navegador entra a `http://localhost:8000`, está golpeando el puerto 8000 del host, que Podman redirige al puerto 8000 del contenedor `clinica_web`, donde vive gunicorn.

**En nuestro proyecto, el `db` NO tiene port mapping** — aposta, por seguridad. Solo `web` puede hablarle, y lo hace por la red privada.

### 2.6. Registry

Un **registry** es un servidor donde se guardan y distribuyen imágenes. El más famoso es **Docker Hub** (`docker.io`). Otros: `ghcr.io` (GitHub), `quay.io` (Red Hat), `gcr.io` (Google).

El flujo es:
- `podman pull` → **bajás** una imagen del registry
- `podman push` → **subís** una imagen al registry

Las imágenes se identifican por **tag**: `donleonz/clinica-ioo:latest` significa "la imagen `clinica-ioo` del usuario `donleonz`, versión `latest`".

---

## 3. Arquitectura del proyecto

Este es el mapa mental. Memorizalo, te lo pueden pedir dibujar en la sustentación.

```
┌────────────────────────────────────────────────────────────────┐
│  Host (tu PC con Linux CachyOS)                                │
│                                                                │
│  ┌─────────────────┐                                           │
│  │ Navegador       │  (el user humano)                         │
│  │ http://         │                                           │
│  │ localhost:8000  │                                           │
│  └────────┬────────┘                                           │
│           │                                                    │
│           │ HTTP al puerto 8000 del host                       │
│           ▼                                                    │
│  ╔══════════════════════════════════════════════════════════╗  │
│  ║  PODMAN (runtime rootless)                               ║  │
│  ║                                                          ║  │
│  ║   Port mapping: host:8000 → web:8000                     ║  │
│  ║                                                          ║  │
│  ║  ┌─── Red privada: clinica_net ─────────────────────┐    ║  │
│  ║  │                                                  │    ║  │
│  ║  │  ┌──────────────────┐    ┌──────────────────┐    │    ║  │
│  ║  │  │ clinica_web      │    │ clinica_db       │    │    ║  │
│  ║  │  │                  │───▶│                  │    │    ║  │
│  ║  │  │ Django + gunicorn│    │ PostgreSQL 16    │    │    ║  │
│  ║  │  │ puerto :8000     │    │ puerto :5432     │    │    ║  │
│  ║  │  │                  │    │ (NO mapeado al   │    │    ║  │
│  ║  │  │ Imagen:          │    │  host, privado)  │    │    ║  │
│  ║  │  │ clinica-ioo:     │    │                  │    │    ║  │
│  ║  │  │ latest           │    │ Imagen:          │    │    ║  │
│  ║  │  │                  │    │ postgres:16-     │    │    ║  │
│  ║  │  │                  │    │ alpine           │    │    ║  │
│  ║  │  └──────────────────┘    └────────┬─────────┘    │    ║  │
│  ║  │                                   │              │    ║  │
│  ║  └───────────────────────────────────┼──────────────┘    ║  │
│  ║                                      │                   ║  │
│  ║                          mount en    │                   ║  │
│  ║                    /var/lib/postgresql/data              ║  │
│  ║                                      ▼                   ║  │
│  ║                          ┌────────────────────┐          ║  │
│  ║                          │ Volumen: pgdata    │          ║  │
│  ║                          │ (en disco del host)│          ║  │
│  ║                          └────────────────────┘          ║  │
│  ║                                                          ║  │
│  ╚══════════════════════════════════════════════════════════╝  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Lo clave de este diagrama

1. **Solo el puerto 8000 sale al host.** Postgres no.
2. **La comunicación web ↔ db es SOLO por la red privada** `clinica_net`.
3. **El volumen `pgdata` vive en el HOST**, no dentro de ningún contenedor. Por eso los datos sobreviven a borrar contenedores.
4. **Podman no corre como root.** Los procesos del `clinica_web` y `clinica_db` son procesos tuyos (verificable con `ps aux | grep gunicorn`).

---

## 4. Dockerfile — línea por línea

```dockerfile
# syntax=docker/dockerfile:1.6
```
Le dice al builder qué versión de la sintaxis de Dockerfile usar. Permite usar features modernas. Opcional pero recomendado.

```dockerfile
FROM python:3.12-slim AS runtime
```
- `FROM` define la **imagen base**. Siempre empezás desde algo.
- `python:3.12-slim` es la imagen oficial de Python 3.12, variante "slim" (sin paquetes de más). Pesa ~50MB vs ~100MB de la normal.
- `AS runtime` le pone un alias al stage. Útil para multi-stage builds; acá no lo usamos pero no molesta.

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
```
- `ENV` define variables de entorno dentro del contenedor.
- `PYTHONDONTWRITEBYTECODE=1` → Python no crea archivos `.pyc` (basura en contenedores).
- `PYTHONUNBUFFERED=1` → los `print()` salen al log al instante (sin buffering). Crítico para ver logs en tiempo real.
- `PIP_NO_CACHE_DIR=1` → pip no cachea paquetes descargados (menos espacio en la imagen).
- `PIP_DISABLE_PIP_VERSION_CHECK=1` → pip no gasta tiempo chequeando si hay versión nueva.

```dockerfile
WORKDIR /app
```
Define el directorio de trabajo dentro del contenedor. Los comandos `COPY`, `RUN`, `CMD` siguientes usan esto como base. Equivale a `cd /app`.

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```
- `RUN` ejecuta comandos DURANTE el build de la imagen (no cuando corre el contenedor).
- Instalamos `curl` (útil para healthchecks y debug).
- `--no-install-recommends` → no instala paquetes sugeridos, solo lo pedido.
- `rm -rf /var/lib/apt/lists/*` → borra el índice de apt después de instalar. Reduce el tamaño de la imagen.
- Todo en **un solo `RUN`** para que quede **una sola layer**. Cada `RUN` crea una layer nueva.

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
```
**IMPORTANTE — orden optimizado para caché:**
- Copiamos PRIMERO solo `requirements.txt`.
- Instalamos deps.
- DESPUÉS copiamos el código (siguiente línea).

¿Por qué? Porque Docker/Podman cachea cada layer. Si solo cambiás código Python (sin tocar requirements), el paso de instalar deps se saltea y el build es casi instantáneo. Si mezcláramos todo, cada cambio en el código re-instalaría todas las deps.

```dockerfile
COPY . .
```
Copia TODO el contexto de build (la carpeta actual) a `/app`. El `.dockerignore` define qué NO se copia (archivos de git, `__pycache__`, etc).

```dockerfile
RUN chmod +x /app/entrypoint.sh \
 && mkdir -p /app/staticfiles
```
- Hace ejecutable el script de entrada.
- Crea la carpeta donde Django va a poner los estáticos colectados.

```dockerfile
EXPOSE 8000
```
**Documenta** que la app escucha en el puerto 8000. NO publica el puerto — solo es metadata. El `ports:` del compose.yml es el que realmente lo expone.

```dockerfile
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-"]
```
- `ENTRYPOINT` es el comando que SIEMPRE se ejecuta al arrancar el contenedor.
- `CMD` son los argumentos que se le pasan al `ENTRYPOINT`. Se pueden sobrescribir.
- Al arrancar el contenedor, ejecuta: `/app/entrypoint.sh gunicorn core.wsgi:application ...`
- El entrypoint al final hace `exec "$@"` → reemplaza su proceso por gunicorn.

**Desglose del gunicorn:**
- `core.wsgi:application` → importa el objeto `application` del módulo `core.wsgi`.
- `--bind 0.0.0.0:8000` → escucha en todas las interfaces, puerto 8000. (0.0.0.0 significa "cualquier IP").
- `--workers 3` → 3 procesos worker para manejar requests en paralelo.
- `--access-logfile -` → los logs de acceso van a stdout (para que `podman logs` los vea).

---

## 5. compose.yml — línea por línea

```yaml
services:
```
Define los **servicios** (= contenedores) que compose va a orquestar. Cada uno se levanta, tumba y reinicia como grupo.

### Servicio db

```yaml
  db:
    image: docker.io/library/postgres:16-alpine
```
- `db` → nombre del servicio. Este nombre es también el **hostname DNS** dentro de la red.
- `image: docker.io/library/postgres:16-alpine` → imagen oficial de PostgreSQL 16 variante Alpine Linux (mucho más liviana).
- `library/` es el "user" de las imágenes oficiales en Docker Hub. Se puede omitir pero es explícito.

```yaml
    container_name: clinica_db
    restart: unless-stopped
```
- `container_name` → nombre del contenedor (para `podman ps`, `podman logs`, etc).
- `restart: unless-stopped` → si el contenedor muere (crash), Podman lo levanta automáticamente. No lo levanta si vos le hiciste `stop` explícitamente.

```yaml
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```
Variables de entorno que la imagen oficial de Postgres usa para inicializar la base la primera vez. Los `${VAR}` se leen del archivo `.env`.

```yaml
    volumes:
      - pgdata:/var/lib/postgresql/data
```
- A la izquierda del `:` → nombre del volumen (declarado abajo).
- A la derecha del `:` → ruta DENTRO del contenedor donde se monta.
- Postgres guarda sus datos en `/var/lib/postgresql/data`. Al montar el volumen ahí, los datos sobreviven a todo.

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10
```
Podman chequea cada 5s si la base está lista, usando `pg_isready` (una tool de Postgres). Si devuelve OK, marca el contenedor como "healthy". Tarda máximo 5s × 10 retries = 50s.

```yaml
    networks:
      - clinica_net
```
Pone este contenedor en la red `clinica_net` (declarada al final del archivo).

### Servicio web

```yaml
  web:
    build:
      context: .
      dockerfile: Dockerfile
    image: clinica-ioo:latest
```
- `build` → en vez de bajar una imagen de un registry, la construye localmente.
- `context: .` → la carpeta actual se envía como contexto al builder.
- `dockerfile: Dockerfile` → cuál archivo usar (es el default, pero explícito).
- `image: clinica-ioo:latest` → qué nombre ponerle a la imagen resultante.

```yaml
    container_name: clinica_web
    restart: unless-stopped
    env_file:
      - .env
```
- `env_file: .env` → carga TODAS las variables del archivo `.env` como env vars en el contenedor. Django las lee con `django-environ`.

```yaml
    ports:
      - "8000:8000"
```
Port mapping: `host:contenedor`. El puerto 8000 del host redirige al 8000 del contenedor. Esto es lo que permite que el navegador acceda.

```yaml
    depends_on:
      db:
        condition: service_healthy
```
`web` espera a que `db` esté **healthy** antes de arrancar. Sin esto, `web` arrancaría antes de que Postgres acepte conexiones y se rompería al intentar migrar.

> Nota: `podman-compose` a veces ignora el `condition: service_healthy`. Por eso el `entrypoint.sh` tiene su propia espera activa por psycopg2 — redundancia defensiva.

```yaml
    networks:
      - clinica_net
```
Misma red que `db`.

### Definiciones finales

```yaml
volumes:
  pgdata:

networks:
  clinica_net:
```
- Declara el volumen nombrado `pgdata` (sin config, default driver local).
- Declara la red `clinica_net` (default bridge).

---

## 6. entrypoint.sh — línea por línea

Este script corre cada vez que arranca el contenedor `web`. Su trabajo: dejar todo listo antes de que gunicorn empiece a escuchar.

```bash
#!/bin/sh
set -e
```
- `#!/bin/sh` → shebang; ejecutar con `sh` (el shell POSIX básico, más portable que bash).
- `set -e` → si cualquier comando falla, el script aborta. "Fail fast".

```bash
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
```
- Heredoc de Python que intenta conectarse a Postgres hasta 60 veces (1 vez por segundo).
- Usa `psycopg2` (ya instalado como dep).
- Si en 60s no conecta, aborta.
- Esto es redundante con el `depends_on: service_healthy`, pero hace el sistema robusto.

```bash
echo ">> Aplicando migraciones"
python manage.py migrate --noinput
```
Corre las migraciones de Django. `--noinput` para que no pregunte nada (sería imposible responder en un contenedor).

```bash
echo ">> Colectando archivos estáticos"
python manage.py collectstatic --noinput
```
Junta todos los estáticos de Django (admin, login, etc) en `/app/staticfiles`. WhiteNoise los va a servir.

```bash
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo ">> Asegurando superusuario $DJANGO_SUPERUSER_USERNAME"
    python <<PY
...
u, created = U.objects.get_or_create(username=..., defaults=...)
u.is_staff = True
u.is_superuser = True
u.set_password(os.environ["DJANGO_SUPERUSER_PASSWORD"])
u.save()
PY
fi
```
- Si existen las env vars `DJANGO_SUPERUSER_USERNAME` y `DJANGO_SUPERUSER_PASSWORD`, crea (o actualiza) el superusuario.
- `get_or_create` → idempotente, no duplica.
- `set_password` → hashea la contraseña correctamente (nunca guardes contraseñas en texto plano).

```bash
echo ">> Iniciando: $@"
exec "$@"
```
- `$@` → los argumentos del `CMD` del Dockerfile (gunicorn + sus flags).
- `exec` → reemplaza este proceso por el comando. **Crítico**: sin `exec`, gunicorn sería hijo del script, y las señales (Ctrl+C) no le llegarían bien.

---

## 7. Flujo de ejecución completo

Esto es lo que pasa desde que corrés `podman-compose up --build -d` hasta que ves la página en el navegador:

```
1. Verificar que podman y podman-compose están instalados.
2. Asegurar que existe el archivo .env (copiarlo desde .env.example si no).
3. podman-compose up --build -d
   │
   ├─▶ Podman lee compose.yml
   ├─▶ Construye imagen "clinica-ioo:latest" desde Dockerfile
   │      ├─ Baja python:3.12-slim (si no está)
   │      ├─ Instala curl
   │      ├─ Instala deps de requirements.txt (layer cacheada)
   │      └─ Copia el código
   ├─▶ Baja postgres:16-alpine (si no está)
   ├─▶ Crea red clinica_net (si no existe)
   ├─▶ Crea volumen pgdata (si no existe)
   ├─▶ Arranca contenedor clinica_db
   │      ├─ Primera vez: inicializa la DB con POSTGRES_* env vars
   │      └─ Empieza a responder pg_isready en 5-15s
   ├─▶ Healthcheck de db pasa
   └─▶ Arranca contenedor clinica_web
          │
          └─▶ Ejecuta entrypoint.sh:
                 ├─ Espera a DB (redundante pero OK)
                 ├─ migrate → crea tablas clinica_paciente, clinica_cita, etc
                 ├─ collectstatic → 130 archivos copiados a /app/staticfiles
                 ├─ Crea superuser
                 └─ exec gunicorn
                        └─▶ Escucha en 0.0.0.0:8000 con 3 workers

4. Abrir el navegador en http://localhost:8000/.
5. El navegador hace GET / → Django responde 302 → redirige a /pacientes/.
6. Crear, editar, borrar pacientes y citas desde la interfaz.
7. Detener con `podman-compose down` cuando se termine la demo.
8. Los contenedores se destruyen, PERO el volumen pgdata queda.
9. La próxima vez que se levanten los servicios, los datos están intactos.
```

---

## 8. Persistencia con volúmenes

Esto es **clave** para la sustentación porque es literalmente un requisito del taller.

### El problema

Los contenedores son **inmutables y efímeros**. Si escribís dentro de un contenedor y lo borrás, adiós datos. Para una base de datos esto es inaceptable.

### La solución: volumen nombrado

```yaml
volumes:
  - pgdata:/var/lib/postgresql/data
```

Podman crea un directorio en el disco del host (algo como `~/.local/share/containers/storage/volumes/trabajo-ioo_pgdata/_data/`) y lo **monta** en la ruta interna `/var/lib/postgresql/data` del contenedor.

Resultado: Postgres cree que está escribiendo en su disco interno, pero en realidad escribe al host. Cuando el contenedor se destruye, el directorio del host sigue ahí.

### Demostración durante la sustentación

```bash
# 1. Levantar y crear datos
podman-compose up --build -d
# Crear 3 pacientes desde la UI

# 2. Destruir los contenedores (PERO NO el volumen)
podman-compose down

# 3. Verificar que el volumen sigue ahí
podman volume ls
#   local   trabajo-ioo_pgdata  ← acá está

# 4. Volver a levantar
podman-compose up -d

# 5. Los 3 pacientes siguen ahí ✓
```

### ¿Cómo se borran los datos?

Solo con el flag `-v`:
```bash
podman-compose down -v    # ⚠️ BORRA el volumen
```

---

## 9. Publicación en Docker Hub

### ¿Por qué hay que subirla?

Requisito del taller: cualquiera desde cualquier PC con Podman/Docker pueda correr tu app sin compilar nada, solo con `podman pull` + `podman run`.

### Nuestro flujo

```bash
# 1. Login (una sola vez)
podman login docker.io -u donleonz
# Password: <PAT de Docker Hub>

# 2. Taggear la imagen local con el namespace del registry
podman tag localhost/clinica-ioo:latest docker.io/donleonz/clinica-ioo:latest
podman tag localhost/clinica-ioo:latest docker.io/donleonz/clinica-ioo:v1.0

# 3. Push
podman push docker.io/donleonz/clinica-ioo:latest
podman push docker.io/donleonz/clinica-ioo:v1.0
```

### URL pública

`https://hub.docker.com/r/donleonz/clinica-ioo`

### Cómo la corre otra persona

```bash
podman pull docker.io/donleonz/clinica-ioo:latest
# Pero necesita también el compose.yml y .env con Postgres
```

Por eso, en realidad, para que alguien corra el proyecto completo, necesita **clonar el repo** (para tener `compose.yml` y `.env.example`) y la imagen se baja automáticamente en el `podman-compose up`.

### ¿Qué son los tags?

- `latest` → convención de "la última versión". No significa nada mágico, es solo un nombre.
- `v1.0` → versión específica. Si mañana subís `v1.1`, la gente que fijó `v1.0` no se rompe.

---

## 10. Cheat sheet de comandos

### Ciclo de vida básico

```bash
podman-compose up --build -d    # construir e iniciar en background
podman-compose down             # parar y destruir contenedores (preserva volumen)
podman-compose down -v          # + borrar volumen (⚠️ pierde datos)
podman-compose logs -f web      # logs en vivo del servicio web
podman-compose ps               # ver servicios del compose
```

### Exploración

```bash
podman ps                       # contenedores corriendo
podman ps -a                    # todos (incluidos parados)
podman images                   # imágenes en disco
podman volume ls                # volúmenes
podman network ls               # redes
```

### Debugging

```bash
podman-compose exec web bash                  # shell dentro del contenedor web
podman-compose exec web python manage.py shell  # shell de Django
podman-compose exec db psql -U clinica_user -d clinica  # shell de Postgres
podman logs -f clinica_web                    # logs directos del contenedor
podman inspect clinica_db                     # toda la config del contenedor
```

### Docker Hub

```bash
podman login docker.io -u donleonz
podman tag <local> docker.io/donleonz/<nombre>:<tag>
podman push docker.io/donleonz/<nombre>:<tag>
podman pull docker.io/donleonz/<nombre>:<tag>
```

### Limpieza

```bash
podman system prune              # borra contenedores parados, redes sin uso
podman system prune -a           # + imágenes sin uso
podman volume prune              # borra volúmenes sin uso ⚠️
```

---

## 11. Preguntas probables del profe

### "¿Qué diferencia hay entre imagen y contenedor?"

La imagen es la plantilla, el molde. El contenedor es la instancia corriendo. Desde una imagen podés crear N contenedores.

### "¿Por qué Podman y no Docker?"

Tres razones: (1) Podman es rootless, no necesita un daemon privilegiado. (2) Los comandos son idénticos, es un drop-in replacement. (3) Estamos en Linux donde Podman brilla. Y las imágenes que publicamos funcionan con Docker sin tocar nada porque respetan el formato OCI.

### "¿Cómo garantizan que los datos no se pierden?"

Con un volumen nombrado declarado en `compose.yml`: `pgdata:/var/lib/postgresql/data`. El volumen vive en el disco del host, no dentro del contenedor. Cuando hago `podman-compose down`, los contenedores se destruyen pero el volumen queda. Al volver a levantar, Postgres encuentra sus archivos intactos.

### "¿Qué pasa si hacen `podman-compose down -v`?"

Ahí sí se pierde todo. El `-v` borra los volúmenes explícitamente. Por eso siempre hacemos `down` sin `-v` salvo que queramos resetear los datos.

### "¿Cómo se comunican los contenedores entre ellos?"

Por una red privada virtual de Podman llamada `clinica_net`. Dentro de esa red, el contenedor `web` resuelve el nombre `db` a la IP interna del contenedor de Postgres, gracias a la DNS interna de Podman. Por eso en `DATABASE_URL` ponemos `postgres://user:pass@db:5432/db`, con el literal `db`, no una IP.

### "¿Por qué Postgres no expone su puerto al host?"

Por **seguridad**. Si lo expusiera, cualquiera en la red local podría intentar conectarse a la base. Al dejarlo solo en la red interna, únicamente el contenedor `web` le puede hablar. Es un principio de "least privilege" (mínimo privilegio).

### "¿Qué es orientado a objetos acá?"

Django implementa el patrón Active Record: cada tabla se modela como una **clase Python** que hereda de `Model`. En nuestro caso:
- `Paciente(models.Model)` con atributos (cedula, nombre, etc), validadores como `RegexValidator`, y el método `__str__`.
- `Cita(models.Model)` con relación `ForeignKey` a `Paciente`.
- Las vistas son Class-Based Views (`ListView`, `CreateView`, `UpdateView`, `DeleteView`) que heredan de clases de Django.

### "¿Cómo se aplican las migraciones?"

En el `entrypoint.sh`, antes de arrancar gunicorn, corremos `python manage.py migrate --noinput`. Esto pasa cada vez que levanta el contenedor web. Como las migraciones son idempotentes (Django recuerda cuáles aplicó), no pasa nada si ya están al día.

### "¿Y si el compañero no tiene Podman? ¿Funciona con Docker?"

Sí. El `Dockerfile` y el `compose.yml` son 100% compatibles con Docker. Solo cambiar los comandos: `docker compose up` en vez de `podman-compose up`. No hay que tocar un solo archivo.

### "¿Qué es gunicorn? ¿Por qué no usar `runserver`?"

`runserver` es el servidor de desarrollo de Django. NO es apto para producción: es single-threaded, no maneja bien concurrencia, no es robusto. Gunicorn es un servidor WSGI real, con múltiples workers, pensado para producción. En un contenedor siempre se usa gunicorn, uvicorn, o similar.

### "¿Qué es WhiteNoise?"

Una librería que permite a Django servir archivos estáticos (CSS, JS, imágenes del admin) directamente sin necesidad de un nginx por delante. Útil en contenedores para no complicar la arquitectura. En una aplicación real con mucho tráfico, se usaría un CDN o nginx.

### "Mostrame el Docker Hub"

Entrá a `https://hub.docker.com/r/donleonz/clinica-ioo` — hay dos tags (`latest` y `v1.0`), con el tamaño de la imagen comprimida, fecha de push, etc.

---

## Conclusión

Si tenés este guion claro podés responder cualquier cosa del taller. Los 5 conceptos que si te los preguntan tenés que tener AL PIE DE LA LETRA:

1. **Imagen vs contenedor** — plantilla vs instancia.
2. **Volumen** — persistencia en disco del host, sobrevive al contenedor.
3. **Red** — comunicación privada entre contenedores por DNS.
4. **Port mapping** — la única puerta que el host abre al contenedor.
5. **Registry / Docker Hub** — donde se distribuye la imagen.

El resto es detalle. Si entendés esos 5, todo lo demás se deriva.
