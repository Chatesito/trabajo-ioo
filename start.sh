#!/bin/bash

# ============================================================
# Clínica IOO — Script de Inicio
# Uso: ./start.sh
# Levanta toda la pila (web + db) en Podman, abre el navegador
# y al presionar ENTER detiene todo.
# ============================================================

# Detectar si se ejecutó desde GUI (sin terminal interactiva)
if [ -z "$CLINICA_IOO_LAUNCHED" ] && [ ! -t 0 ]; then
    export CLINICA_IOO_LAUNCHED=1
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    if command -v kitty >/dev/null 2>&1; then
        kitty -e /bin/bash "$SCRIPT_PATH"
    elif command -v konsole >/dev/null 2>&1; then
        konsole -e /bin/bash "$SCRIPT_PATH"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal -- /bin/bash "$SCRIPT_PATH"
    else
        xterm -e /bin/bash "$SCRIPT_PATH"
    fi
    exit 0
fi

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
APP_PORT=8000
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

command_exists() { command -v "$1" >/dev/null 2>&1; }

clear
echo -e "${CYAN}"
echo "   ██████╗██╗     ██╗███╗   ██╗██╗ ██████╗ █████╗ "
echo "  ██╔════╝██║     ██║████╗  ██║██║██╔════╝██╔══██╗"
echo "  ██║     ██║     ██║██╔██╗ ██║██║██║     ███████║"
echo "  ██║     ██║     ██║██║╚██╗██║██║██║     ██╔══██║"
echo "  ╚██████╗███████╗██║██║ ╚████║██║╚██████╗██║  ██║"
echo "   ╚═════╝╚══════╝╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝╚═╝  ╚═╝"
echo -e "  Taller IOO — CRUD Pacientes/Citas${NC}"
echo ""

# ── [1/5] Verificar Podman ───────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Verificando Podman..."
if ! command_exists podman; then
    echo -e "${RED}[ERROR]${NC} Podman no está instalado."
    echo "  Instalalo con: sudo pacman -S podman podman-compose"
    read -r -p "Presioná ENTER para cerrar..."
    exit 1
fi
if ! command_exists podman-compose; then
    echo -e "${RED}[ERROR]${NC} podman-compose no está instalado."
    echo "  Instalalo con: sudo pacman -S podman-compose"
    read -r -p "Presioná ENTER para cerrar..."
    exit 1
fi
echo -e "${GREEN}  ✓ Podman $(podman --version | cut -d' ' -f3)${NC}"
echo -e "${GREEN}  ✓ podman-compose $(podman-compose --version 2>&1 | head -1 | awk '{print $NF}')${NC}"

# ── [2/5] Verificar .env ─────────────────────────────────────
echo -e "${BLUE}[2/5]${NC} Verificando archivo .env..."
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}  ⚠  .env no existe, copiando desde .env.example${NC}"
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
fi
echo -e "${GREEN}  ✓ .env presente${NC}"

# ── [3/5] Levantar contenedores ──────────────────────────────
echo -e "${BLUE}[3/5]${NC} Levantando contenedores (podman-compose)..."
podman-compose up --build -d
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} podman-compose falló."
    read -r -p "Presioná ENTER para cerrar..."
    exit 1
fi

# ── [4/5] Esperar que la app responda ────────────────────────
echo -e "${BLUE}[4/5]${NC} Esperando que la app responda en http://localhost:$APP_PORT ..."
for i in $(seq 1 60); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$APP_PORT/" | grep -qE "^(200|302)$"; then
        echo -e "${GREEN}  ✓ App respondiendo${NC}"
        break
    fi
    sleep 1
    if [ "$i" = "60" ]; then
        echo -e "${RED}[ERROR]${NC} La app no respondió en 60s. Revisá los logs: podman-compose logs"
        read -r -p "Presioná ENTER para cerrar..."
        podman-compose down
        exit 1
    fi
done

# ── [5/5] Abrir navegador ────────────────────────────────────
echo -e "${BLUE}[5/5]${NC} Abriendo navegador..."
URL="http://localhost:$APP_PORT/"
if command_exists brave; then
    brave --new-window "$URL" >/dev/null 2>&1 &
elif command_exists chromium; then
    chromium --new-window "$URL" >/dev/null 2>&1 &
elif command_exists google-chrome; then
    google-chrome --new-window "$URL" >/dev/null 2>&1 &
elif command_exists firefox; then
    firefox --new-window "$URL" >/dev/null 2>&1 &
else
    xdg-open "$URL" >/dev/null 2>&1 &
fi

# ── Resumen ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗"
echo -e "║   Clínica IOO — CORRIENDO                    ║"
echo -e "╠══════════════════════════════════════════════╣"
echo -e "║                                              ║"
echo -e "║   App:       http://localhost:$APP_PORT/pacientes/  ║"
echo -e "║   Admin:     http://localhost:$APP_PORT/admin/      ║"
echo -e "║   Usuario:   Leon                            ║"
echo -e "║   Password:  Leon123@                        ║"
echo -e "║                                              ║"
echo -e "║   Logs:      podman-compose logs -f          ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Presioná ENTER para DETENER todos los servicios${NC}"
read -r

# ── Cleanup ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[DETENIENDO]${NC} Bajando contenedores..."
podman-compose down
echo -e "${GREEN}  ✓ Contenedores detenidos (volumen pgdata preservado)${NC}"

echo ""
echo -e "${GREEN}  ✓ Clínica IOO detenida correctamente.${NC}"
echo ""
echo -e "${CYAN}Presioná ENTER para cerrar esta ventana${NC}"
read -r
