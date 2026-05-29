# TaskFlow Kubernetes — Kelompok 8

> Week 12 — Kubernetes & Microservices | Mata Kuliah DevOps

## Deskripsi

Proyek ini memindahkan aplikasi TaskFlow ke Kubernetes untuk mengatasi tiga insiden yang terjadi pada infrastruktur lama:

| Insiden | Masalah | Solusi Kubernetes |
|---------|---------|-------------------|
| **#1** | Container crash malam hari, downtime 6 jam | **Self-healing** — Pod otomatis restart |
| **#2** | Deploy fitur baru, aplikasi mati 8 menit | **Rolling update** — zero downtime |
| **#3** | Rollback manual memakan 25 menit | **`kubectl rollout undo`** — < 60 detik |

## Struktur Repository

```
taskflow-k8s-kelompok8/
├── README.md                            ← Dokumentasi utama
├── Dockerfile                           ← Image untuk CI/CD pipeline
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml                       ← Pipeline CI/CD (build + deploy)
├── kubernetes/
│   ├── namespace-dev.yaml               ← Namespace development
│   ├── namespace-prod.yaml              ← Namespace production
│   ├── deployment.yaml                  ← Deployment (2 replicas, rolling update)
│   └── service.yaml                     ← Service NodePort (port 30080)
├── deploy.sh                            ← Script deploy satu perintah
└── docs/
    ├── cicd-ke-kubernetes.md            ← Dokumentasi alur CI/CD
    ├── insiden-1-selfhealing.md         ← Laporan insiden 1
    ├── insiden-2-rolling-update.md      ← Laporan insiden 2
    ├── insiden-3-rollback.md            ← Laporan insiden 3
    ├── insiden-6-isolation.md           ← Laporan isolasi namespace
    └── screenshots/                     ← Screenshot bukti demo
```

## Cara Menjalankan dari Awal

### Prasyarat

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### 1. Start Minikube

```bash
minikube start --cpus=2 --memory=4096
```

### 2. Deploy dengan satu perintah

```bash
chmod +x deploy.sh
./deploy.sh
```

Atau secara manual:

```bash
# Buat namespace
kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml

# Deploy ke production
kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod
kubectl apply -f kubernetes/service.yaml -n taskflow-prod

# Tunggu deployment selesai
kubectl rollout status deployment/taskflow-api -n taskflow-prod

# Akses aplikasi
minikube service taskflow-api -n taskflow-prod --url
```

### 3. Verifikasi

```bash
# Semua resource di production
kubectl get all -n taskflow-prod

# Akses aplikasi
curl http://$(minikube ip):30080
# Output: Halo dari TaskFlow v1!
```

## Alur CI/CD

Pipeline CI/CD berjalan otomatis via GitHub Actions setiap push ke `main`.

### Jobs

| Job | Fungsi |
|-----|--------|
| `build` | Build Docker image, push ke GHCR dengan tag `sha-<commit>` |
| `deploy` | Update image di Kubernetes, rolling update zero downtime |

### Cara Kerja

```text
Developer push kode ke main
        │
        ▼
GitHub Actions Pipeline
  ├── Build Docker image
  ├── Push ke GHCR (ghcr.io/dianggraaeni/taskflow-api:sha-<commit>)
  │
  └── Deploy ke Kubernetes
        ├── kubectl set image ...
        └── Rolling update otomatis → Zero Downtime ✅
```

### Secrets yang Diperlukan

| Secret | Keterangan |
|--------|-----------|
| `KUBECONFIG_BASE64` | Kubeconfig cluster dalam format base64 |
| `GITHUB_TOKEN` | Otomatis tersedia, untuk push image ke GHCR |

> Dokumentasi lengkap CI/CD: [docs/cicd-ke-kubernetes.md](docs/cicd-ke-kubernetes.md)

## Dokumentasi Insiden

| Insiden | Dokumen | Apa yang Dibuktikan |
|---------|---------|---------------------|
| #1 Self-Healing | [docs/insiden-1-selfhealing.md](docs/insiden-1-selfhealing.md) | Pod restart otomatis setelah crash |
| #2 Rolling Update | [docs/insiden-2-rolling-update.md](docs/insiden-2-rolling-update.md) | Update tanpa HTTP error |
| #3 Rollback | [docs/insiden-3-rollback.md](docs/insiden-3-rollback.md) | Rollback < 60 detik |
| #6 Isolasi | [docs/insiden-6-isolation.md](docs/insiden-6-isolation.md) | Namespace dev & prod terpisah |

## Anggota Kelompok

| Anggota | Peran | Tanggung Jawab |
|---------|-------|----------------|
| Acintya Edria Sudarsono | Infrastructure & Orchestrator | Namespace, Deployment, Service, `deploy.sh`, Insiden 1 |
| Dian Anggraeni Putri | CI/CD Pipeline Specialist | GitHub Actions workflow, Secrets, `docs/cicd-ke-kubernetes.md` |
| Callista Meyra Azizah | Traffic Control & Reliability | Rolling update strategy, rollback, Insiden 2 & 3 |
| Tsaldia Hukma Cita | Cluster Architect & Connectivity | Isolasi namespace, bonus DNS internal |