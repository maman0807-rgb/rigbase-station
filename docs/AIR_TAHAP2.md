# AIR Tahap 2: Strategi Pemeliharaan, Klasifikasi Kegiatan, Failure Recording, RCA

Acuan: Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0. Lanjutan dari `docs/AIR_TAHAP1.md`.

## Keputusan Maman (2026-10-07)

1. `downtime_events.wo_number` = No. WO SAP. Kolom ini dipakai, tidak dibuat kolom baru.
2. Klasifikasi kegiatan diambil dari **kategori downtime**, bukan dari data Logbook.
3. Pemicu RCA lama (>1× failure/12 bulan per unit, pedoman PEP 2023) **diganti** aturan AIR: ≥3 failure dengan kategori equipment sama + failure mode sama dalam 12 bulan.
4. Status RCA memakai alur baru. Data lama dimigrasi: Open → ANALISIS, In Progress → TINDAK_LANJUT, Verified → CLOSED.
5. Detail kegagalan **wajib**: failure mode saat dicatat, failure cause saat ditutup. Semua entry dilakukan di kantor, karena lapangan hanya melapor lisan.

Prinsip yang dipakai: perluas tabel yang ada (`downtime_events`, `rca_records`), bukan membuat `failure_event`/`rca_case` baru. **Logbook tidak disentuh.**

## Database: `fase36_air_tahap2.sql`

| Objek | Isi |
|---|---|
| `ref_failure_mode` | 26 failure mode ISO 14224 yang relevan untuk rig/HHE, termasuk FTC/FTO/LCP/DOP untuk BOP & valve. **Perlu review Maman.** |
| `ref_failure_cause` | 15 root cause ISO 14224 (desain, pabrikasi/instalasi, operasi, pemeliharaan, manajemen, lain-lain). |
| Kolom `downtime_events` | `failure_mode`, `failure_cause`, `failure_code`, `komponen_id` (child equipment), `jenis_corrective`, `sap_notification_no` |
| `ref_jenis_kegiatan` + view `v_kegiatan_pemeliharaan` | Kategori downtime → Preventive/Corrective + sub-jenis (Gambar 8). `jenis_corrective` per kejadian meng-override default. |
| `maintenance_strategy_assessment` + `equipment.strategi_pemeliharaan` | Wizard M1–M4 (Gambar 7). Trigger menghitung hasil, dan penilaian terbaru menentukan nilai di master. |
| `rca_records` (diperluas) | `pemicu`, `downtime_event_ids[]`, `equipment_ids[]`, `kategori_id`, `failure_mode`, `ringkasan_penanganan`, `diverifikasi_oleh`, `monitoring_efektivitas`, kolom LPO, `tgl_closed`. Status baru DRAFT → … → CLOSED. |
| `rca_tindakan` | Rencana tindak lanjut SMART (aksi, ukuran keberhasilan, PIC, due date, status). |
| Trigger `trg_air_rca_repetitive` | Saat downtime breakdown/troubleshoot diberi failure mode: kalau ada ≥3 kejadian sejenis dalam jendela 12 bulan, trigger membuat RCA DRAFT. Kalau RCA terbuka sudah ada, kejadian baru ditambahkan ke RCA itu. Ikut terpicu juga saat downtime lama diklasifikasi belakangan. |
| View `v_air_repetitive_kandidat` | Kombinasi yang sudah ≥2× (peringatan dini) dan ≥3× (wajib), beserta RCA-nya. |
| `air_config` | `rca_repetitive_min` = 3 (pedoman), `rca_repetitive_bulan` = 12 (usulan). |

Catatan:
- "Parameter operasi sama" dari pedoman didekati dengan **kategori equipment sama**.
- Kewajiban mengisi failure mode/cause ditegakkan di **UI**, bukan di DB. Dengan begitu, edit data lama dan jalur lain (bot, PM selesai) tidak terblokir. Downtime lama yang belum lengkap masuk antrian "belum diklasifikasi".
- MTBF/MTTR/Availability tetap memakai perhitungan yang sudah ada di RAM → Reliability/Availability.

## Uji
- `fase36_air_tahap2_test.sql`: **28 uji** mencakup semua jalur M1–M4, klasifikasi kegiatan, status RCA lama ditolak, repetitive (2× tidak memicu, mode beda/gejala tidak dihitung, ke-3 memicu, ke-4 tidak dobel, setelah CLOSED muncul DRAFT baru, tersebar >12 bulan tidak memicu, klasifikasi di tengah jendela memicu), view kandidat, dan ON DELETE. Dibatalkan otomatis di akhir.
- Lokal (PGlite): migration lolos dua kali, 28/28 lulus, dan regresi Tahap 1 55/55 lulus. Migrasi status RCA lama sudah dicek.
- UI (jsdom): 32/32 lulus untuk Tahap 2, dan regresi Tahap 1 26/26 lulus.

## UI
1. **Form Catat/Edit Downtime**: kotak merah "Detail Kegagalan (ISO 14224)" muncul untuk breakdown/troubleshoot. Isinya failure mode (wajib), komponen (dari child equipment), failure cause (wajib kalau jam selesai diisi), jenis corrective, failure code. Ada juga field No. Notification SAP.
2. **Tombol Selesai** di daftar downtime membuka form kalau mode/cause belum lengkap. **Eskalasi gejala** langsung membuka form supaya failure mode diisi.
3. **Tab 🧭 AIR**: kartu Strategi Pemeliharaan + wizard M1–M4 (M2 dilewati kalau M1 Ya).
4. **Tab 🔎 RCA**: banner aturan AIR (wajib / peringatan dini), riwayat kejadian dengan badge failure mode dan tombol klasifikasi, kartu RCA (pemicu, jumlah unit/kejadian, progres tindak lanjut), tombol "→ status berikutnya" beserta syaratnya, dan form RCA 5 langkah + LPO + tindak lanjut SMART.
5. **RAM → 🧭 AIR**: Repetitive Failure, RCA Aktif, dan antrian "Downtime belum diklasifikasi" dengan tombol Klasifikasi.
6. **Panduan**: section RCA ditulis ulang mengikuti aturan AIR. Section AIR mendapat langkah 6 (strategi) dan 7 (failure recording).

## Perlu review Maman
- Daftar failure mode (26) dan failure cause (15). Bisa ditambah atau dinonaktifkan lewat SQL (`aktif = false`).
- Pemetaan kategori downtime → jenis kegiatan (`ref_jenis_kegiatan`), terutama `gejala` = Predictive/Condition Monitoring.
