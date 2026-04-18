# Taller Docker-OO — Clínica (Django + PostgreSQL + Podman)

> **Asignatura:** Ingeniería de Software Orientada a Objetos
> **Universidad:** Universidad Surcolombiana
> **Objetivo del taller:** Realizar un ejercicio de Programación Orientada a Objetos (CRUD con BD relacional) ejecutándose dentro de un contenedor, con persistencia mediante volúmenes, y publicado en Docker Hub.

Este repositorio contiene una pequeña aplicación web de gestión de **pacientes** y **citas** de una clínica, construida con Django 6 siguiendo el paradigma orientado a objetos, con persistencia en PostgreSQL y empaquetada para correr con **Podman** (alternativa libre y compatible con Docker).

---

## 1. Stack

| Capa | Tecnología |
|------|-----------|
| Lenguaje | Python 3.12 |
| Framework | Django 6.0.4 |
| Servidor de aplicación | Gunicorn |
| Servido de estáticos | WhiteNoise |
| Base de datos | PostgreSQL 16 (alpine) |
| Contenedores | Podman + podman-compose |
| Registro de imágenes | Docker Hub |

> Elegimos **Podman** en lugar de Docker porque el equipo trabaja sobre Linux (CachyOS / Fedora-based). Podman es rootless por defecto, no necesita daemon y es 100% compatible con el formato OCI e imágenes de Docker Hub. El profesor autorizó el uso de Podman.

---

## 2. Arquitectura

```
  ┌──────────────────────────────────┐
  │         Navegador (host)         │
  │  http://localhost:8000           │
  └────────────┬─────────────────────┘
               │  port 8000
               ▼
  ┌──────────────────────────────────┐       ┌──────────────────────┐
  │       Contenedor: web            │◄─────►│  Contenedor: db      │
  │   (Django + Gunicorn)            │       │  (PostgreSQL 16)     │
  │   imagen: clinica-ioo:latest     │       │  port: 5432 (int.)   │
  └──────────────────────────────────┘       └──────────┬───────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────────┐
                                              │  Volumen: pgdata     │
                                              │  (persistencia)      │
                                              └──────────────────────┘
```

Dos contenedores en una red privada (`clinica_net`). La base de datos **NO** expone el puerto 5432 al host — solo la app web puede hablarle. El volumen `pgdata` guarda los archivos de PostgreSQL, así los datos sobreviven a `podman-compose down`, reinicios del PC y reconstrucciones de la imagen.

---

## 3. Modelo de dominio (OO)

El taller exige una aplicación orientada a objetos. Modelamos dos entidades en `clinica/models.py`:

```python
class Paciente(models.Model):
    nombre = models.CharField(max_length=150)
    cedula = models.CharField(max_length=20, unique=True, validators=[...])
    telefono = models.CharField(max_length=20, validators=[...])
    email = models.EmailField()

class Cita(models.Model):
    paciente = models.ForeignKey(Paciente, on_delete=models.CASCADE)
    fecha = models.DateTimeField()
    motivo = models.TextField()
```

Cada modelo es una **clase** con atributos tipados, validadores y su método `__str__`. El ORM de Django expone métodos de clase (`Paciente.objects.create`, `.filter`, `.get`, `.save`, `.delete`) que implementan el CRUD completo.

Relación: **1 Paciente → N Citas** (ForeignKey con `on_delete=CASCADE`).

---

## 4. Estructura del proyecto

```
trabajo-ioo/
├── clinica/                  # App Django: modelos, vistas, forms, templates
│   ├── models.py             # Paciente, Cita
│   ├── views.py              # CRUD
│   ├── forms.py
│   └── templates/clinica/
├── core/                     # Configuración del proyecto Django
│   ├── settings.py           # Lee DATABASE_URL, SECRET_KEY vía django-environ
│   ├── urls.py
│   └── wsgi.py
├── manage.py
├── requirements.txt
├── Dockerfile                # Imagen de la app (python:3.12-slim)
├── compose.yml               # Orquestación web + db + volumen
├── entrypoint.sh             # Espera-DB → migrate → collectstatic → gunicorn
├── .dockerignore
├── .env.example              # Plantilla de variables de entorno
└── README.md                 # Este informe
```

---

## 5. Prerrequisitos

En CachyOS / Arch:

```bash
sudo pacman -S podman podman-compose
```

En Fedora:

```bash
sudo dnf install podman podman-compose
```

En Ubuntu/Debian:

```bash
sudo apt install podman podman-compose
```

Verificar:

```bash
podman --version          # >= 4.0
podman-compose --version  # >= 1.0
```

---

## 6. Puesta en marcha (paso a paso)

### 6.1. Clonar el repo

```bash
git clone https://github.com/Chatesito/trabajo-ioo.git
cd trabajo-ioo
```

### 6.2. Crear el archivo `.env`

```bash
cp .env.example .env
```

Editá `.env` y cambiá como mínimo `SECRET_KEY` y `POSTGRES_PASSWORD`. El resto puede quedar como está para desarrollo local.

### 6.3. Construir y levantar

```bash
podman-compose up --build -d
```

Este comando:
1. Construye la imagen `clinica-ioo:latest` a partir del `Dockerfile`.
2. Descarga `postgres:16-alpine` desde Docker Hub.
3. Crea el volumen `pgdata` y la red `clinica_net`.
4. Arranca los dos contenedores.
5. El `entrypoint.sh` del contenedor `web` espera a que Postgres acepte conexiones, corre `migrate` y `collectstatic`, y finalmente lanza Gunicorn.

### 6.4. Verificar

```bash
podman ps
```

Deberías ver `clinica_db` y `clinica_web` en estado `Up`.

Abrir en el navegador:

```
http://localhost:8000
```

### 6.5. (Opcional) Crear superusuario para el admin

```bash
podman-compose exec web python manage.py createsuperuser
```

Luego entrar a `http://localhost:8000/admin`.

---

## 7. Comandos útiles

| Acción | Comando |
|--------|---------|
| Ver logs de la app | `podman-compose logs -f web` |
| Ver logs de la DB | `podman-compose logs -f db` |
| Shell de Django | `podman-compose exec web python manage.py shell` |
| Nueva migración | `podman-compose exec web python manage.py makemigrations` |
| Aplicar migraciones | `podman-compose exec web python manage.py migrate` |
| Parar todo | `podman-compose down` |
| Parar **y** borrar la DB | `podman-compose down -v` ⚠️ |
| Reconstruir sin cache | `podman-compose build --no-cache` |
| Entrar al contenedor web | `podman-compose exec web bash` |
| Entrar a psql | `podman-compose exec db psql -U clinica_user -d clinica` |

---

## 8. Persistencia de datos (requisito del taller)

El taller exige que **la información no se pierda cada vez que se ejecute**. Esto se garantiza con el volumen nombrado `pgdata` declarado en `compose.yml`:

```yaml
services:
  db:
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

Podman crea el volumen la primera vez y lo reutiliza en todos los arranques siguientes. Puede verse con:

```bash
podman volume ls
podman volume inspect trabajo-ioo_pgdata
```

Para **probar la persistencia**:

```bash
# 1. Crear pacientes desde la UI
# 2. Parar los contenedores
podman-compose down

# 3. Volver a levantar
podman-compose up -d

# 4. Los pacientes siguen ahí ✓
```

Solo `podman-compose down -v` borra el volumen (y por lo tanto los datos).

---

## 9. Publicar la imagen en Docker Hub

### 9.1. Crear cuenta y repositorio

1. Crear cuenta en <https://hub.docker.com>.
2. Crear un repositorio público llamado `clinica-ioo`.

### 9.2. Login desde Podman

```bash
podman login docker.io
# Username: donleonz
# Password: ****
```

### 9.3. Etiquetar la imagen

```bash
podman tag localhost/clinica-ioo:latest docker.io/donleonz/clinica-ioo:latest
podman tag localhost/clinica-ioo:latest docker.io/donleonz/clinica-ioo:v1.0
```

### 9.4. Subir a Docker Hub

```bash
podman push docker.io/donleonz/clinica-ioo:latest
podman push docker.io/donleonz/clinica-ioo:v1.0
```

### 9.5. Verificar

La imagen queda disponible en:

```
https://hub.docker.com/r/donleonz/clinica-ioo
```

Cualquier persona puede ahora correrla:

```bash
podman pull docker.io/donleonz/clinica-ioo:latest
```

---

## 10. Variables de entorno

Todas las variables se leen desde `.env` (cargado por `env_file` en `compose.yml` y por `django-environ` dentro de Django).

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `SECRET_KEY` | Clave de firma de Django | `django-insecure-...` |
| `DEBUG` | Modo debug | `True` / `False` |
| `ALLOWED_HOSTS` | Hosts permitidos (coma-separados) | `127.0.0.1,localhost` |
| `POSTGRES_DB` | Nombre de la base | `clinica` |
| `POSTGRES_USER` | Usuario de la base | `clinica_user` |
| `POSTGRES_PASSWORD` | Contraseña de la base | `clinica_pass` |
| `DATABASE_URL` | URL completa para Django | `postgres://clinica_user:clinica_pass@db:5432/clinica` |

---

## 11. Troubleshooting

**"port is already allocated"** → otra cosa está usando el 8000. Cambiá el mapeo en `compose.yml` a `"8080:8000"`.

**Permisos del volumen en SELinux (Fedora)** → si aparece `permission denied` del lado de Postgres, agregá `:Z` al volumen:

```yaml
- pgdata:/var/lib/postgresql/data:Z
```

**`podman-compose` no resuelve `depends_on: condition: service_healthy`** → el `entrypoint.sh` ya espera activamente a que la DB acepte conexiones con un loop de 60 segundos, así que funciona aunque el healthcheck no se respete.

**"database does not exist"** → borrar el volumen y volver a levantar:

```bash
podman-compose down -v && podman-compose up --build -d
```

---

## 12. Equivalencia Podman ↔ Docker

Todos los comandos `podman-compose X` son equivalentes a `docker compose X`. La imagen construida y subida a Docker Hub funciona idéntico con Docker. La elección de Podman es solo operativa (rootless, sin daemon) y no afecta al entregable.

---

## 13. Integrantes

- Jorge León (`@Chatesito`)

---

## 14. Referencias

- Django docs: <https://docs.djangoproject.com/en/6.0/>
- Podman docs: <https://docs.podman.io/>
- podman-compose: <https://github.com/containers/podman-compose>
- WhiteNoise (estáticos): <https://whitenoise.readthedocs.io/>
- PostgreSQL en Docker Hub: <https://hub.docker.com/_/postgres>
