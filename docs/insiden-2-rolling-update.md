# Laporan Insiden 2 — Rolling Update (Zero Downtime)

## Konteks Insiden
Bulan lalu, TaskFlow mengalami downtime selama 8 menit saat melakukan pembaruan (deployment) fitur baru di jam sibuk. Hal ini terjadi karena proses lama dihentikan sebelum proses baru benar-benar siap melayani traffic.

## Solusi Kubernetes
Kami mengimplementasikan strategi **Rolling Update** pada `deployment.yaml`. Dengan konfigurasi `maxUnavailable: 0`, Kubernetes menjamin tidak ada Pod yang dimatikan sebelum Pod baru berstatus `Ready`.

### Konfigurasi Strategi
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # Membuat 1 pod ekstra saat update
    maxUnavailable: 0    # Memastikan ketersediaan 100% pod lama selama update
```

## Pengujian Zero Downtime
Kami melakukan pengujian dengan menjalankan traffic secara terus-menerus menggunakan script PowerShell saat melakukan pembaruan aplikasi dari v1 ke v2.

### Script Pengujian (PowerShell)
```powershell
while($true) { 
  try { 
    $resp = Invoke-WebRequest -Uri "http://<minikube-ip>:30080" -UseBasicParsing -TimeoutSec 1
    Write-Host "$(Get-Date -Format HH:mm:ss) - HTTP $($resp.StatusCode)" -ForegroundColor Green
  } catch { 
    Write-Host "$(Get-Date -Format HH:mm:ss) - ERROR" -ForegroundColor Red
  }
  Start-Sleep -Milliseconds 500
}
```

## Hasil Pengujian
Berdasarkan log di bawah, terlihat bahwa selama proses transisi berlangsung, semua request tetap mengembalikan status **HTTP 200**. Tidak ada interupsi layanan sama sekali.

![Bukti Rolling Update] <img width="566" height="403" alt="image" src="https://github.com/user-attachments/assets/d2150058-721f-44c8-9aa9-6071e21047f5" />

*(Gambar menunjukkan log HTTP 200 stabil tanpa ada pesan ERROR)*

## Kesimpulan
Dengan Kubernetes, Insiden 2 tidak akan terulang kembali. Tim dapat melakukan rilis fitur kapan saja tanpa perlu khawatir merugikan klien akibat downtime.
```
