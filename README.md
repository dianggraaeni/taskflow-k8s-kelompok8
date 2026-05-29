# TaskFlow Kubernetes — Kelompok 8

> Week 12 — Kubernetes & Microservices | Mata Kuliah DevOps

## Deskripsi

Proyek ini memindahkan aplikasi TaskFlow ke Kubernetes untuk mengatasi tiga insiden yang terjadi pada infrastruktur lama:

| Insiden | Masalah | Solusi Kubernetes |
|---------|---------|-------------------|
| **#1** | Container crash malam hari, downtime 6 jam | **Self-healing** — Pod otomatis restart |
| **#2** | Deploy fitur baru, aplikasi mati 8 menit | **Rolling update** — zero downtime |
| **#3** | Rollback manual memakan 25 menit | **`kubectl rollout undo`** — < 60 detik |

---

## Struktur Repository

```
taskflow-k8s-kelompok8/
├── README.md                            ← Dokumentasi utama (ini)
├── Dockerfile                           ← Image untuk CI/CD pipeline
├── deploy.sh                            ← Script deploy satu perintah
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml                       ← Pipeline CI/CD (build + deploy)
├── kubernetes/
│   ├── namespace-dev.yaml               ← Namespace development
│   ├── namespace-prod.yaml              ← Namespace production
│   ├── deployment.yaml                  ← Deployment (2 replicas, rolling update)
│   └── service.yaml                     ← Service NodePort (port 30080)
└── docs/
    ├── cicd-ke-kubernetes.md            ← Dokumentasi alur CI/CD
    ├── insiden-1-selfhealing.md         ← Laporan insiden 1
    ├── insiden-2-rolling-update.md      ← Laporan insiden 2
    ├── insiden-3-rollback.md            ← Laporan insiden 3
    └── insiden-6-isolation.md           ← Laporan isolasi namespace
```

---

## Cara Menjalankan dari Awal

### Prasyarat

Pastikan tools berikut sudah terinstall di laptop kamu:

| Tool | Versi Minimum | Link Install |
|------|---------------|--------------|
| **Docker Desktop** | 24.x | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |
| **Minikube** | 1.30+ | [minikube.sigs.k8s.io/docs/start](https://minikube.sigs.k8s.io/docs/start/) |
| **kubectl** | 1.27+ | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |

Verifikasi instalasi:

```bash
docker --version       # Docker version 24.x.x
minikube version       # minikube version: v1.3x.x
kubectl version --client  # Client Version: v1.2x.x
```

---

### 1. Clone Repository

```bash
git clone https://github.com/dianggraaeni/taskflow-k8s-kelompok8.git
cd taskflow-k8s-kelompok8
```

### 2. Start Minikube

```bash
minikube start --cpus=2 --memory=4096
```

Tunggu hingga muncul pesan:
```
✅  Done! kubectl is now configured to use "minikube" cluster
```

Verifikasi cluster berjalan:
```bash
minikube status
kubectl get nodes
```

### 3. Deploy dengan Satu Perintah

```bash
# Berikan permission eksekusi (hanya perlu sekali)
chmod +x deploy.sh

# Jalankan orchestrator script
./deploy.sh
```

Script `deploy.sh` akan secara otomatis:
1. ✅ Memvalidasi tools (minikube & kubectl)
2. ✅ Mengecek status minikube (start jika belum berjalan)
3. ✅ Membuat namespace `taskflow-dev` dan `taskflow-prod`
4. ✅ Men-deploy aplikasi ke `taskflow-prod`
5. ✅ Menunggu semua Pod Ready
6. ✅ Menampilkan URL akses

#### Alternatif: Deploy Manual

Jika lebih suka manual, jalankan langkah-langkah berikut:

```bash
# Buat namespace
kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml

# Deploy ke production
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

# Tunggu deployment selesai
kubectl rollout status deployment/taskflow-api -n taskflow-prod

# Akses aplikasi
minikube service taskflow-api -n taskflow-prod --url
```

### 4. Verifikasi

```bash
# Semua resource di production
kubectl get all -n taskflow-prod

# Akses aplikasi
curl http://$(minikube ip):30080
# Output yang diharapkan: Halo dari TaskFlow v1!
```

---

## Arsitektur Cluster

```
Minikube Cluster
├── Namespace: taskflow-prod (PRODUCTION)
│   ├── Deployment: taskflow-api
│   │   ├── Pod 1 (taskflow-api)  ← Running
│   │   └── Pod 2 (taskflow-api)  ← Running
│   └── Service: taskflow-api (NodePort :30080)
│
└── Namespace: taskflow-dev (DEVELOPMENT)
    ├── Deployment: taskflow-api
    │   ├── Pod 1 (taskflow-api)  ← Running
    │   └── Pod 2 (taskflow-api)  ← Running
    └── Service: taskflow-api (NodePort :30081)
```

Kedua namespace **terisolasi sepenuhnya** — kekacauan di `taskflow-dev` tidak mempengaruhi `taskflow-prod` sedikitpun.

---

## Alur CI/CD

Pipeline CI/CD berjalan otomatis via GitHub Actions setiap push ke `main`.

### Jobs

| Job | Runner | Fungsi |
|-----|--------|--------|
| `build` | `ubuntu-latest` | Build Docker image, push ke GHCR dengan tag `sha-<commit>` |
| `deploy` | `self-hosted` | Update image di Kubernetes, rolling update zero downtime |

> **Mengapa `self-hosted` runner?** Job deploy perlu mengakses cluster Minikube yang berjalan di laptop lokal. Runner GitHub tidak bisa mengakses localhost, sehingga dibutuhkan self-hosted runner.

### Cara Kerja

```text
Developer push kode ke main
        │
        ▼
GitHub Actions Pipeline
  ├── [build] Build Docker image
  ├── [build] Push ke GHCR (ghcr.io/dianggraaeni/taskflow-api:sha-<commit>)
  │
  └── [deploy] Deploy ke Kubernetes
        ├── kubectl set image ...
        └── Rolling update otomatis → Zero Downtime ✅
```

### Secrets yang Diperlukan

| Secret | Keterangan |
|--------|-----------|
| `KUBECONFIG_BASE64` | Kubeconfig cluster dalam format base64 |
| `GITHUB_TOKEN` | Otomatis tersedia, untuk push image ke GHCR |

> Dokumentasi lengkap CI/CD: [docs/cicd-ke-kubernetes.md](docs/cicd-ke-kubernetes.md)

---

## Dokumentasi Insiden

| Insiden | Dokumen | Apa yang Dibuktikan |
|---------|---------|---------------------|
| #1 Self-Healing | [docs/insiden-1-selfhealing.md](docs/insiden-1-selfhealing.md) | Pod restart otomatis < 15 detik |
| #2 Rolling Update | [docs/insiden-2-rolling-update.md](docs/insiden-2-rolling-update.md) | Update tanpa HTTP error (semua 200 OK) |
| #3 Rollback | [docs/insiden-3-rollback.md](docs/insiden-3-rollback.md) | Rollback < 60 detik vs 25 menit manual |
| #6 Isolasi | [docs/insiden-6-isolation.md](docs/insiden-6-isolation.md) | Namespace dev & prod benar-benar terpisah |

---

## Troubleshooting

### Minikube tidak bisa start
```bash
# Reset minikube
minikube delete
minikube start --cpus=2 --memory=4096
```

### Pod stuck di Pending
```bash
# Cek event untuk melihat penyebab
kubectl describe pod <nama-pod> -n taskflow-prod
kubectl get events -n taskflow-prod
```

### ImagePullBackOff
```bash
# Buat secret untuk GHCR jika menggunakan image privat
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username-github> \
  --docker-password=<personal-access-token> \
  -n taskflow-prod
```

### Tidak bisa akses URL
```bash
# Dapatkan URL yang benar dari minikube
minikube service taskflow-api -n taskflow-prod --url

# Atau buka langsung di browser
minikube service taskflow-api -n taskflow-prod
```

---

## Anggota Kelompok

| Anggota | Peran | Tanggung Jawab |
|---------|-------|----------------|
| Acintya Edria Sudarsono | Infrastructure & Orchestrator | Namespace, Deployment, Service, `deploy.sh`, Insiden 1 |
| Dian Anggraeni Putri | CI/CD Pipeline Specialist | GitHub Actions workflow, Secrets, `docs/cicd-ke-kubernetes.md` |
| Callista Meyra Azizah | Traffic Control & Reliability | Rolling update strategy, rollback, Insiden 2 & 3 |
| Tsaldia Hukma Cita | Cluster Architect & Connectivity | Isolasi namespace, bonus DNS internal |