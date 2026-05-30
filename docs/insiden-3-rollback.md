# Laporan Insiden 3 — Rollback Cepat & Aman

## Konteks Insiden
Bulan lalu, ditemukan bug kritis pada versi baru aplikasi. Proses rollback manual memakan waktu **25 menit** (SSH ke server, stop container, pull image lama, jalankan ulang). Durasi ini terlalu lama untuk sebuah bug kritis.

## Solusi Kubernetes
Kubernetes menyimpan riwayat (history) setiap deployment. Jika ditemukan kesalahan pada versi terbaru, kami cukup menjalankan satu perintah rollback yang akan mengembalikan sistem ke keadaan stabil sebelumnya dalam hitungan detik.

## Langkah Eksekusi Rollback
1. Menjalankan perintah pengembalian:
   ```bash
   kubectl rollout undo deployment/taskflow-api -n taskflow-prod
   ```
2. Memverifikasi status rollback:
   ```bash
   kubectl rollout status deployment/taskflow-api -n taskflow-prod
   ```

## Perbandingan Risiko & Waktu
| Indikator | Cara Lama (Manual) | Dengan Kubernetes |
| :--- | :--- | :--- |
| **Langkah Kerja** | SSH → Stop → Pull → Run | 1 Perintah (`rollout undo`) |
| **Waktu Eksekusi** | ~25 Menit | < 15 Detik |
| **Risiko Human Error** | Tinggi (Salah ketik/config) | Sangat Rendah (Otomatis) |
| **Keamanan** | Harus akses SSH root | Melalui API K8s terautentikasi |

## Bukti Eksekusi
Dibawah ini adalah hasil terminal saat perintah rollback dijalankan. Proses selesai dengan sangat cepat dan aplikasi kembali ke versi stabil.

<img width="959" height="100" alt="image" src="https://github.com/user-attachments/assets/f0b55263-8687-428f-8889-54d2ff568ec7" />

*(Gambar menunjukkan status "successfully rolled out" dalam waktu singkat)*

## Kesimpulan
Fitur `rollout undo` pada Kubernetes menjamin ketahanan sistem. Jika terjadi kesalahan rilis, dampak kerusakan dapat diminimalisir secepat mungkin tanpa proses manual yang lambat dan berisiko.
