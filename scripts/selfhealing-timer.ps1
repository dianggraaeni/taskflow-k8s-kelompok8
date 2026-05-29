# =============================================================================
# selfhealing-timer.ps1 - Pengukur Waktu Recovery Self-Healing
# =============================================================================
# Script ini otomatis:
#   1. Memilih pod yang akan dihapus
#   2. Mencatat waktu TEPAT saat penghapusan (presisi milidetik)
#   3. Polling setiap 0.5 detik sampai pod baru Running
#   4. Menampilkan laporan waktu recovery yang akurat
#
# Penggunaan:
#   powershell -ExecutionPolicy Bypass -File scripts\selfhealing-timer.ps1
# =============================================================================

$NAMESPACE = "taskflow-prod"

function Write-Green($msg)  { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Cyan($msg)   { Write-Host $msg -ForegroundColor Cyan }
function Write-Red($msg)    { Write-Host $msg -ForegroundColor Red }

Write-Cyan "`n=============================================="
Write-Cyan "  Self-Healing Timer - Kelompok 8"
Write-Cyan "==============================================`n"

# --- Langkah 1: Ambil daftar pod yang sedang Running ---
Write-Host "Mengambil daftar Pod di namespace '$NAMESPACE'..."
$rawPods = kubectl get pods -n $NAMESPACE --no-headers 2>&1
$podLines = $rawPods | Where-Object { $_ -match "Running" }
$podNames = $podLines | ForEach-Object { ($_ -split "\s+")[0] }

if (-not $podNames) {
    Write-Red "Tidak ada pod Running di namespace $NAMESPACE!"
    Write-Red "Jalankan dulu: kubectl apply -f kubernetes/deployment.yaml"
    exit 1
}

# --- Langkah 2: Tampilkan pilihan pod ---
Write-Host "`nPod yang tersedia:"
$podList = @($podNames)
for ($i = 0; $i -lt $podList.Count; $i++) {
    Write-Host "  [$i] $($podList[$i])"
}

Write-Host ""
$choice = Read-Host "Pilih nomor pod yang akan dihapus (default: 0)"
if ($choice -eq "") { $choice = "0" }
$targetPod = $podList[[int]$choice]

Write-Yellow "`nPod yang akan dihapus: $targetPod"
Write-Host "Tekan Enter untuk mulai pengukuran... (Ctrl+C untuk batal)"
Read-Host | Out-Null

# --- Langkah 3: Catat waktu penghapusan ---
$timeDelete = Get-Date
$timeDeleteStr = $timeDelete.ToString("HH:mm:ss.fff")
Write-Red "`n[$timeDeleteStr] Menghapus pod: $targetPod"

kubectl delete pod $targetPod -n $NAMESPACE --wait=false 2>&1 | Out-Null
Write-Host "[$timeDeleteStr] Perintah delete dikirim."
Write-Yellow "`nMemantau sampai pod baru Running..."
Write-Host "----------------------------------------------"

# --- Langkah 4: Polling setiap 0.5 detik ---
$timePending  = $null
$timeRunning  = $null
$newPodName   = $null
$seenPods     = @($targetPod)
$allKnownPods = $podList

while ($null -eq $timeRunning) {
    Start-Sleep -Milliseconds 500
    $now = Get-Date
    $nowStr = $now.ToString("HH:mm:ss.fff")

    $currentPods = kubectl get pods -n $NAMESPACE --no-headers 2>&1

    foreach ($line in $currentPods) {
        if (-not $line -or $line -notmatch "\S") { continue }
        $parts = $line -split "\s+"
        if ($parts.Count -lt 3) { continue }

        $pName   = $parts[0]
        $pStatus = $parts[2]  # STATUS column (Running/Pending/Error)

        # Deteksi pod BARU yang belum pernah kita lihat
        if ($pName -ne $targetPod -and $pName -notin $allKnownPods -and $pName -notmatch "^<") {
            $newPodName = $pName
            $allKnownPods += $pName
            $timePending = $now
            $elapsed = [math]::Round(($timePending - $timeDelete).TotalSeconds, 2)
            Write-Yellow "[$nowStr] Pod baru muncul: $newPodName (+${elapsed}s)"
        }

        # Deteksi Running pada pod baru
        if ($pName -eq $newPodName -and $pStatus -eq "Running") {
            $timeRunning = $now
            $elapsed = [math]::Round(($timeRunning - $timeDelete).TotalSeconds, 2)
            Write-Green "[$nowStr] Pod RUNNING! [?] (+${elapsed}s)"
        }
    }

    # Safety timeout 120 detik
    if (($now - $timeDelete).TotalSeconds -gt 120) {
        Write-Red "Timeout! Pod tidak Running dalam 120 detik."
        exit 1
    }
}

# --- Langkah 5: Hitung semua durasi ---
$totalSec   = [math]::Round(($timeRunning - $timeDelete).TotalSeconds, 2)
$pendingSec = if ($timePending) { [math]::Round(($timePending - $timeDelete).TotalSeconds, 2) } else { "N/A" }
$runningSec = [math]::Round(($timeRunning - $timeDelete).TotalSeconds, 2)

$timeDeleteFmt  = $timeDelete.ToString("HH:mm:ss.fff")
$timePendingFmt = if ($timePending) { $timePending.ToString("HH:mm:ss.fff") } else { "N/A" }
$timeRunningFmt = $timeRunning.ToString("HH:mm:ss.fff")

# --- Laporan Akhir ---
Write-Cyan "`n=============================================="
Write-Cyan "         LAPORAN SELF-HEALING"
Write-Cyan "=============================================="
Write-Host ""
Write-Host "  Pod dihapus     : $targetPod"
Write-Host "  Pod pengganti   : $newPodName"
Write-Host ""
Write-Host "  Waktu delete    : $timeDeleteFmt"
Write-Host "  Waktu Pending   : $timePendingFmt  (+${pendingSec}s)"
Write-Host "  Waktu Running   : $timeRunningFmt  (+${runningSec}s)"
Write-Host ""
Write-Green "  [?] TOTAL RECOVERY TIME : $totalSec detik"
Write-Host ""
Write-Cyan "=============================================="
Write-Host ""

# --- Simpan ke file log ---
$logFile = "docs\selfhealing-result.txt"
$logDate = Get-Date -Format "yyyy-MM-dd HH:mm"

$logContent  = "=== HASIL PENGUKURAN SELF-HEALING ===" + "`n"
$logContent += "Tanggal       : $logDate" + "`n"
$logContent += "Namespace     : $NAMESPACE" + "`n"
$logContent += "Pod dihapus   : $targetPod" + "`n"
$logContent += "Pod pengganti : $newPodName" + "`n"
$logContent += "" + "`n"
$logContent += "Waktu delete  : $timeDeleteFmt" + "`n"
$logContent += "Waktu Pending : $timePendingFmt  (+${pendingSec}s)" + "`n"
$logContent += "Waktu Running : $timeRunningFmt  (+${runningSec}s)" + "`n"
$logContent += "" + "`n"
$logContent += "TOTAL RECOVERY TIME: $totalSec detik" + "`n"

$logContent | Out-File -FilePath $logFile -Encoding UTF8

Write-Green "Hasil tersimpan di: $logFile"
Write-Host ""
