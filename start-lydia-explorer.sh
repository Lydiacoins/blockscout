#!/usr/bin/env bash
# =============================================================================
# Lydia Coin / USAD Blockscout Explorer - One-Click Launch
# =============================================================================
# Usage:  ./start-lydia-explorer.sh
# Stops:  cd docker-compose && docker compose down
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/docker-compose"
BRAND_ASSETS_DIR="${COMPOSE_DIR}/brand-assets"
EXPLORER_URL="http://localhost:4000"
HEALTH_URL="http://localhost:4000/api/v2/stats"
MAX_WAIT=300

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# 1. Prerequisite checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker v20.10+ first."
    exit 1
fi

if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "Docker Compose is not installed. Please install Docker Compose 2.x+."
    exit 1
fi

ok "Docker and Docker Compose found. (${COMPOSE_CMD})"

if ! docker info &>/dev/null; then
    error "Docker daemon is not running. Please start Docker first."
    exit 1
fi
ok "Docker daemon is running."

# ---------------------------------------------------------------------------
# 2. Prepare brand assets (idempotent)
# ---------------------------------------------------------------------------
info "Preparing brand assets..."

mkdir -p "${BRAND_ASSETS_DIR}"

copy_asset() {
    local src="$1"
    local dst="$2"
    if [ -f "${src}" ]; then
        cp "${src}" "${BRAND_ASSETS_DIR}/${dst}"
        ok "  ${dst}"
    else
        warn "  Source not found: ${src}"
    fi
}

copy_asset "${SCRIPT_DIR}/profil son (2).png"               "lydiacoin-logo.png"
copy_asset "${SCRIPT_DIR}/usad 1 2.png"                     "usad-logo.png"
copy_asset "${SCRIPT_DIR}/KAPAK FOTOĞRAFI GÜNCEL HALİ.png"  "usad-banner.png"

ok "Brand assets ready."

# ---------------------------------------------------------------------------
# 3. Launch the stack
# ---------------------------------------------------------------------------
info "Starting Lydia Coin Explorer stack..."

cd "${COMPOSE_DIR}"

info "Pulling latest Docker images..."
${COMPOSE_CMD} pull 2>&1 | tail -3 || true

info "Starting all services..."
${COMPOSE_CMD} up -d --remove-orphans

ok "Docker Compose services started."

# ---------------------------------------------------------------------------
# 4. Health check loop
# ---------------------------------------------------------------------------
info "Waiting for backend to become healthy (up to ${MAX_WAIT}s)..."

elapsed=0
interval=5
healthy=false

while [ ${elapsed} -lt ${MAX_WAIT} ]; do
    if ! docker ps --format '{{.Names}}' | grep -q '^backend$'; then
        sleep ${interval}
        elapsed=$((elapsed + interval))
        continue
    fi

    http_code=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_URL}" 2>/dev/null || echo "000")
    if [ "${http_code}" = "200" ]; then
        healthy=true
        break
    fi

    printf "  Waiting... %ds / %ds (HTTP %s)\r" "${elapsed}" "${MAX_WAIT}" "${http_code}"
    sleep ${interval}
    elapsed=$((elapsed + interval))
done

echo ""

if ${healthy}; then
    ok "Backend API is healthy!"
else
    warn "Backend did not return HTTP 200 within ${MAX_WAIT}s."
    warn "This is normal on first run -- the backend is still syncing/migrating."
    warn "Check logs: cd ${COMPOSE_DIR} && ${COMPOSE_CMD} logs -f backend"
fi

# ---------------------------------------------------------------------------
# 5. Print service status and URLs
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}=========================================================${NC}"
echo -e "${RED}${BOLD}  Lydia Coin Explorer - USAD Stablecoin${NC}"
echo -e "${BOLD}  Future-Ready Stability${NC}"
echo -e "${BOLD}=========================================================${NC}"
echo ""

info "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
    --filter "name=redis-db" \
    --filter "name=db" \
    --filter "name=backend" \
    --filter "name=frontend" \
    --filter "name=proxy" \
    --filter "name=stats" \
    --filter "name=visualizer" \
    --filter "name=sig-provider" \
    --filter "name=user-ops-indexer" \
    --filter "name=nft_media_handler" 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}Access URLs:${NC}"
echo -e "  Explorer:       ${CYAN}${EXPLORER_URL}${NC}"
echo -e "  API:            ${CYAN}${EXPLORER_URL}/api${NC}"
echo -e "  API Docs:       ${CYAN}${EXPLORER_URL}/api-docs${NC}"
echo -e "  Stats:          ${CYAN}http://localhost:8080${NC}"
echo ""
echo -e "${YELLOW}Commands:${NC}"
echo -e "  View logs:      cd ${COMPOSE_DIR} && ${COMPOSE_CMD} logs -f"
echo -e "  Backend logs:   cd ${COMPOSE_DIR} && ${COMPOSE_CMD} logs -f backend"
echo -e "  Stop stack:     cd ${COMPOSE_DIR} && ${COMPOSE_CMD} down"
echo -e "  Restart:        $0"
echo ""
echo -e "  Chain:          Lydia Coin (Chain ID: 1989)"
echo -e "  RPC:            https://rpc.lydiacoins.com"
echo -e "  Native Token:   LYDIA"
echo ""
