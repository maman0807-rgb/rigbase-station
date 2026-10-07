# AIR Tahap 1: Klasifikasi Aset, Criticality, Status Integrity

Acuan: Pedoman Pengelolaan Asset Integrity & Reliability (AIR) No. A4-009/PHE23000/2026-S9 Rev.0 (berlaku 26 Juni 2026).
Prompt kerja: `ERAMHOIST_AIR_TAHAP1_PROMPT.md`.

## Keputusan dari Langkah 0 (2026-10-07)

- Tabel `komponen_master`, `komponen_lifetime`, `komponen_riwayat_ganti`, `komponen_riwayat_pindah`, `insiden_hse`, dan `insiden_tindakan` yang disebut prompt **tidak ada**. Prompt ditulis oleh Claude chat dan nama tabel itu hanya tebakan. Sub-unit atau komponen memakai yang sudah berjalan: `equipment.parent_equipment_id` + tabel `pemasangan`.
- Isi armada adalah rig well service (BW KB150, H35KD, BW-100A) beserta komponennya, MTU, Slickline, dan handling tools. Armadanya bukan didominasi crane/forklift.
- BOP dan Accumulator **tetap dalam lingkup AIR** (kandidat SECE), bukan dikecualikan sebagai Well Integrity.
- Accumulator dikategorikan **STA** karena risiko utamanya ada di botol tekanan. Pompa elektrik dan pompa udara (keduanya wajib ada) tetap terpantau lewat PM dan failure record.
- Prinsip: **perluas yang sudah ada, jangan bikin dobel**.
- Penilai criticality dan integrity: admin + manager (`is_admin() OR is_manager()`).
- Backfill `status_aset`: Standby → STANDBY, Scrap → DECOMMISSIONED, selain itu ACTIVE (sesuai TKO terbaru).
- `criticality_level` lama disembunyikan dari UI (datanya tetap ada). `cof_score` dan Risk Level (PoF×CoF) **tetap tampil** karena masih dipakai di 15 tempat.

## Database: `fase35_air_tahap1.sql`

| Objek | Isi |
|---|---|
| `ref_kategori_aset` | 18 kategori. Pendekatan dari pedoman (`pendekatan_dari_pedoman = true`) atau usulan (LFT, TRK, WIN = Reliability). |
| `air_config` | `criticality_validasi_ulang_bulan` = 24 (pedoman), `peringatan_validasi_hari` = 60 (usulan), `eca_mapping` (usulan, **perlu diverifikasi**) |
| `categories.kategori_aset_default` | Pemetaan kategori eRAMHoist → AIR berdasarkan pola nama. Yang tidak cocok dibiarkan NULL. |
| Kolom `equipment` | `kategori_aset`, `status_aset`, `kepemilikan`, `alasan_di_luar_lingkup`, `dalam_lingkup_air`, `sap_equipment_no`, `taxonomy_level`, `criticality`, `is_vital`, `criticality_metode`, `criticality_tgl_penetapan`, `criticality_tgl_validasi_ulang`, `status_integrity`, `status_integrity_tgl` |
| `criticality_assessment` | Riwayat penilaian. Trigger menghitung hasil (KUALITATIF Q1–Q5 berurutan, ECA dari skor, PHA manual). Penilaian terbaru menentukan nilai di master. |
| `performance_standard` | Batas standar kinerja per kategori equipment atau kategori AIR. Diisi Field. |
| `integrity_assessment` | Riwayat penilaian S1–S3. Trigger menghitung status. Hanya yang `DIKONFIRMASI` yang mengubah master (`DRAFT` disiapkan untuk usulan otomatis). |
| `matriks_tindak_lanjut_air` | 16 sel Tabel 7. Aksi dari pedoman. Prioritas adalah usulan dan bisa diubah di tabel ini. |
| `v_equipment_air_status` | View ringkasan untuk dashboard (`security_invoker`). |

Catatan teknis:
- `is_vital` dan `dalam_lingkup_air` diisi **trigger**, bukan generated column. Dengan begitu, write lama yang mengirim semua kolom tidak error.
- Trigger `trg_air_equipment_defaults` mengisi `status_aset`/`kepemilikan` kalau NULL, dan mengisi `kategori_aset` dari kategori kalau belum diisi manual. Trigger ini berlaku untuk semua jalur: app, Logbook, bot, SQL.
- Backfill tidak mengubah `updated_at` (trigger updated_at dimatikan sementara selama backfill).
- Rollback ada di bagian bawah file migration.

## Uji

- `fase35_air_tahap1_test.sql`: **55 uji** mencakup seluruh jalur Q1–Q5, 25 kombinasi ECA, penolakan input bolong, PHA, sinkron penilaian terbaru, validasi ulang +2 tahun, S1–S3, DRAFT vs konfirmasi, matriks, view, dan cascade delete. Seluruh uji dibatalkan otomatis di akhir, jadi tidak ada data yang tersimpan.
- Sudah dijalankan di Postgres lokal (PGlite) di atas `supabase_schema.sql`: migration lolos dua kali (idempoten), 55/55 lulus.
- Uji UI (jsdom, data contoh): 26/26 lulus. Yang diuji: tab AIR, wizard kualitatif (berhenti otomatis dan jawaban di bawahnya ikut di-reset), wizard ECA, PHA wajib referensi, wizard integrity, dan dashboard (filter lingkup, klik sel heatmap).

## UI (`index.html`)

1. **Daftar equipment**: kolom "AIR" (badge criticality + integrity). Di HP, badge muncul di kartu.
2. **Detail equipment → tab 🧭 AIR**: kartu Criticality / Status Integrity / Tindak Lanjut, klasifikasi aset, riwayat penilaian (admin bisa hapus, draft bisa dikonfirmasi).
3. **Wizard Criticality**: Kualitatif (Q1–Q5, berhenti otomatis), ECA (grid 5×5), PHA (wajib referensi dokumen).
4. **Wizard Status Integrity**: S1–S3 + sumber + temuan.
5. **Form Edit → bagian J. Klasifikasi AIR**: kategori aset, status aset, kepemilikan, alasan di luar lingkup, no. SAP, level taxonomy.
6. **RAM → tab 🧭 AIR**: heatmap 4×4 yang bisa diklik, daftar prioritas, criticality yang perlu validasi ulang, unit belum dinilai, unit yang belum punya kategori aset, filter Dalam lingkup / Semua.
7. **SOS Lab**: banner criticality. Untuk peralatan vital ada pengingat prioritas. Logika Decision Engine SOS **tidak diubah**.

## Belum dikerjakan (ditunda)

- Draft `integrity_assessment` otomatis dari Laporan Harian (unit rusak) dan dari SOS abnormal. Tabel sudah mendukung `konfirmasi = 'DRAFT'`; tinggal pemicunya.
- UI pengelolaan `performance_standard` dan `air_config`. Untuk sementara diubah lewat SQL Editor.

## Yang perlu diverifikasi Maman

1. Pemetaan skor ECA ke criticality (`air_config.eca_mapping`), dibaca dari warna Gambar 5.
2. Prioritas di `matriks_tindak_lanjut_air` (usulan).
3. Hasil pemetaan kategori: query verifikasi (b) di bagian 12 file migration. Kategori NULL perlu diisi manual.

## Koreksi pemetaan kategori (`fase35b_air_pemetaan_kategori.sql`, 2026-10-07)

Nama kategori di DB live berbeda dari file SQL lama, sehingga 15 kategori (159 unit) kosong dan 3 kategori salah petakan. Keputusan Maman:
- Carrier → WIN (bagian bawah rig: axle, drivetrain)
- Alat berat (Backhoe, Bulldozer, Compactor, Excavator, Motor Grader) → GSP
- SCM (alat pendukung operasi gudang) → GSP
- Fire Pump Portable dan Damkar → SNE
- Auxilary System → AUX
- Koreksi: Well Control System → STA, Generator (Slickline) → ELE, Powerpack (Slickline) → ROT

Pola di `fase35_air_tahap1.sql` ikut dibetulkan. Hasilnya: ke-41 kategori live terpetakan benar, baik di environment baru maupun lewat 35b. Equipment yang kategori AIR-nya sudah diubah manual tidak disentuh.
