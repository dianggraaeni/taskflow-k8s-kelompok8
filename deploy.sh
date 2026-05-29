#!/bin/bash
# =============================================================================
# deploy.sh — Orchestrator Script Kelompok 8
# =============================================================================
# Script ini menjalankan seluruh proses deployment TaskFlow ke Kubernetes
# hanya dengan SATU perintah dari terminal.
#
# Penggunaan:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Prasyarat:
#   - minikube terinstall
#   - kubectl terinstall
# =============================================================================

set -e  # Hentikan script jika ada perintah yang gagal

# --- Warna untuk output yang lebih mudah dibaca ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (reset)

# --- Banner ---
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       TaskFlow Kubernetes — Kelompok 8           ║${NC}"
echo -e "${CYAN}║       Orchestrator Deployment Script             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# LANGKAH 0: Validasi Tools
# =============================================================================
echo -e "${BLUE}[0/5] Memvalidasi tools yang diperlukan...${NC}"

# Cek minikube terinstall
if ! command -v minikube &>/dev/null; then
    echo -e "${RED}✗ minikube tidak ditemukan!${NC}"
    echo "  Install minikube di: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Cek kubectl terinstall
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}✗ kubectl tidak ditemukan!${NC}"
    echo "  Install kubectl di: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo -e "${GREEN}✓ minikube terinstall: $(minikube version --short 2>/dev/null || echo 'OK')${NC}"
echo -e "${GREEN}✓ kubectl terinstall: $(kubectl version --client --short 2>/dev/null | head -1 || echo 'OK')${NC}"

# =============================================================================
# LANGKAH 1: Validasi Status Minikube
# =============================================================================
echo ""
echo -e "${BLUE}[1/5] Memeriksa status Minikube cluster...${NC}"

MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

if [ "$MINIKUBE_STATUS" = "Running" ]; then
    echo -e "${GREEN}✓ Minikube sudah berjalan.${NC}"
else
    echo -e "${YELLOW}⚠ Minikube belum berjalan (status: ${MINIKUBE_STATUS}).${NC}"
    echo -e "${YELLOW}  Mencoba menjalankan minikube...${NC}"
    minikube start --cpus=2 --memory=4096
    echo -e "${GREEN}✓ Minikube berhasil dijalankan.${NC}"
fi

# Pastikan kubectl mengarah ke minikube
kubectl config use-context minikube &>/dev/null || true
echo -e "${GREEN}✓ kubectl sudah dikonfigurasi ke cluster minikube.${NC}"

# =============================================================================
# LANGKAH 2: Membuat Namespace
# =============================================================================
echo ""
echo -e "${BLUE}[2/5] Membuat namespace...${NC}"

kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml

echo -e "${GREEN}✓ Namespace taskflow-dev dan taskflow-prod siap.${NC}"

# =============================================================================
# LANGKAH 3: Deploy ke Production
# =============================================================================
echo ""
echo -e "${BLUE}[3/5] Men-deploy aplikasi ke namespace taskflow-prod...${NC}"

kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

echo -e "${GREEN}✓ Deployment dan Service berhasil di-apply.${NC}"

# =============================================================================
# LANGKAH 4: Tunggu Rollout Selesai
# =============================================================================
echo ""
echo -e "${BLUE}[4/5] Menunggu deployment selesai (max 120 detik)...${NC}"

kubectl rollout status deployment/taskflow-api \
    -n taskflow-prod \
    --timeout=120s

echo -e "${GREEN}✓ Deployment berhasil! Semua Pod sudah Running.${NC}"

# =============================================================================
# LANGKAH 5: Verifikasi & Tampilkan Info Akses
# =============================================================================
echo ""
echo -e "${BLUE}[5/5] Verifikasi status cluster...${NC}"
echo ""

echo -e "${CYAN}--- Pod di taskflow-prod ---${NC}"
kubectl get pods -n taskflow-prod

echo ""
echo -e "${CYAN}--- Service di taskflow-prod ---${NC}"
kubectl get service taskflow-api -n taskflow-prod

echo ""

# Dapatkan URL akses
MINIKUBE_IP=$(minikube ip 2>/dev/null)
ACCESS_URL="http://${MINIKUBE_IP}:30080"

echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ DEPLOYMENT SELESAI!              ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Akses aplikasi di: ${ACCESS_URL}${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║  Atau jalankan:                                  ║${NC}"
echo -e "${GREEN}║    minikube service taskflow-api -n taskflow-prod║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Uji koneksi cepat
echo -e "${BLUE}Menguji koneksi ke aplikasi...${NC}"
if curl -s --max-time 5 "$ACCESS_URL" > /dev/null 2>&1; then
    RESPONSE=$(curl -s --max-time 5 "$ACCESS_URL")
    echo -e "${GREEN}✓ Aplikasi merespons: ${RESPONSE}${NC}"
else
    echo -e "${YELLOW}⚠ Koneksi belum tersedia. Coba akses manual:${NC}"
    echo -e "  minikube service taskflow-api -n taskflow-prod --url"
fi

echo ""
