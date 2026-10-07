# eRAMHoist — Update Kepatuhan Pedoman AIR (Tahap 1–4)

## Konteks

eRAMHoist adalah PWA (Vanilla JS + Supabase + Vercel) untuk pengelolaan equipment dan spare part HHE (Hoist & Heavy Equipment) di PT Pertamina Hulu Rokan, Field Prabumulih (Regional 1 / Sumatera).

PHE menerbitkan **Pedoman Pengelolaan Asset Integrity & Reliability (AIR) No. A4-009/PHE23000/2026-S9 Rev.0**, berlaku 26 Juni 2026. Pedoman ini mencabut dan menggantikan:
- A4-002/PHE23000/2021-S9 (Standarisasi Program Manajemen Integritas Fasilitas Produksi)
- A4-005/PHE23000/2023-S9 (Maintenance & Reliability Management System / MRMS)

Semua aturan bisnis yang dibutuhkan sudah ditulis di dokumen ini. Tidak perlu membaca PDF pedoman.

**Posisi eRAMHoist:** pedoman menetapkan CMMS (SAP) sebagai sistem resmi untuk register aset, criticality, work order, dan reservasi spare part. eRAMHoist adalah alat bantu lapangan dan monitoring. Desainnya harus bisa menyimpan referensi ke SAP (nomor equipment, nomor WO, nomor notification, nomor reservasi) dan menyiapkan data untuk ekspor/sinkron, bukan menggantikan SAP.

---

## Cara kerja (WAJIB diikuti)

1. **Langkah 0** dulu: pelajari kode dan schema yang ada, lalu laporkan.
2. Kerjakan **satu tahap per waktu**. Di awal setiap tahap, tulis rencana (tabel, kolom, trigger, halaman) dan **berhenti untuk diskusi/konfirmasi** sebelum menulis migration.
3. Di akhir setiap tahap, jalankan uji, tulis ringkasan di `docs/AIR_TAHAP{n}.md`, lalu **berhenti di checkpoint**.
4. Jika ada aturan di prompt ini yang bertentangan dengan kondisi kode/data nyata, tanyakan. Jangan berasumsi.

Aturan umum:
- Jangan hapus atau rename kolom/tabel yang sudah ada.
- Kolom baru di tabel lama harus nullable atau punya default, supaya data lama tetap valid.
- Setiap perubahan schema dibuat sebagai file migration SQL terpisah dan bernomor, dengan catatan rollback.
- Ikuti pola RLS dan konvensi penamaan (bahasa Indonesia, snake_case) yang sudah dipakai.
- Nilai yang merupakan **usulan** (bukan ketentuan pedoman) harus disimpan sebagai konfigurasi yang mudah diubah, bukan di-hardcode.

---

## Langkah 0 — Pelajari kode yang sudah ada

1. Baca struktur repo, file SQL/migration, dan schema Supabase.
2. Identifikasi **tabel master equipment/unit HHE** (nama bisa berbeda). Tabel yang sudah diketahui ada: `komponen_master`, `komponen_lifetime`, `komponen_riwayat_ganti`, `komponen_riwayat_pindah`, `insiden_hse`, `insiden_tindakan`, `audit_gudang`, `audit_temuan`, view `v_audit_selisih`. Ada juga modul SOS (oil analysis), Decision Engine, Laporan Harian (Telegram → n8n → Claude API → draft/confirm), PTW/SIKA, dan logika HM parent-child swap (`punya_meter_sendiri`).
3. Identifikasi tabel spare part/stok, tabel PM/work order (jika ada), dan cara pencatatan stok habis vs dipinjam (dulu pernah ada isu keduanya tercampur di dashboard).
4. Laporkan temuan dan pemetaan: tabel mana yang akan disentuh di tiap tahap. **Tunggu konfirmasi.**

---

# TAHAP 1 — Klasifikasi Aset, Criticality, Status Integrity, Matriks Tindak Lanjut

## 1.1 Kategori aset (BAB I pedoman)

Pedoman mengenal 18 kategori aset:

| Kode | Kategori | Pendekatan |
|---|---|---|
| AUX | Auxiliaries | – |
| CIV | Civil & Structure | Integrity |
| DRL | Drilling | – |
| ELE | Electrical | Reliability |
| GSP | General Support | – |
| ICC | Instrument, Control & Custody | Reliability |
| LFT | Lifting | – |
| MAR | Marine | – |
| PIP | Pipeline | Integrity |
| ROT | Rotating | Reliability |
| SNE | Safety & Environment | – |
| STA | Static | Integrity |
| SUB | Subsea Production | – |
| TRK | Truck Fleet | – |
| UTL | Utilities | – |
| VSL | Vessel Fleet | – |
| WCO | Well Completion | – |
| WIN | Well Intervention | – |

- **Integrity Management** (RBI, Corrosion Management, Fitness for Service) untuk Static, Pipeline, Civil & Structure.
- **Reliability Management** (RCM, FMEA, RAM, analisis MTBF/MTTR) untuk Rotating, Electrical, Instrument Control & Custody.
- Kategori bertanda "–" tidak dipetakan eksplisit oleh pedoman. Simpan pendekatan sebagai kolom yang bisa diisi user (default: Reliability untuk LFT dan TRK, karena fokus HHE adalah availability). Ini usulan, tandai sebagai konfigurasi.
- Untuk HHE, kategori yang paling relevan: **Lifting** (crane, hoist, forklift, man-lift) dan **Truck Fleet** (unit angkut operasional). Mesin penggerak bisa dicatat sebagai sub-unit Rotating jika perlu.

**Pengecualian lingkup AIR** (tetap boleh dicatat, tapi ditandai di luar lingkup):
1. Aset non-operasi (contoh dari pedoman: rumah dinas, **kendaraan dinas**)
2. Aset non-milik (sewa), mengikuti klausul kontrak
3. Aset Well Integrity (dikelola Drilling & Well Intervention)
4. Aset BOT/alih kelola yang belum diserahterimakan
5. Aset non-operator/KSO
6. Aset yang dikelola General Services

**Status aset:** ACTIVE, STANDBY, IDLE, ABANDONED, DECOMMISSIONED (pedoman menyebut Active/Stand-by/Idle/Abandoned; Decommissioned untuk akhir siklus).

**Taxonomy ISO 14224** (Gambar 4): level 1–5 = lokasi (penamaan diserahkan ke Zona/WK), level 6 = Equipment Unit, 7 = Sub Unit/Assembly, 8 = Maintainable Item/Component, 9 = Part. Tag numbering mengacu TKO B4-019/PHE23000/2023-S9.

### Schema yang diusulkan
Tabel referensi `ref_kategori_aset` (kode, nama, pendekatan, keterangan), seed 18 baris di atas.

Tambahkan ke master equipment:
- `kategori_aset` (FK ke ref_kategori_aset)
- `status_aset` (ACTIVE/STANDBY/IDLE/ABANDONED/DECOMMISSIONED, default ACTIVE)
- `kepemilikan` (MILIK/SEWA, default MILIK)
- `alasan_di_luar_lingkup` (nullable; NON_OPERASI/SEWA/WELL_INTEGRITY/BOT/KSO/GENERAL_SERVICES)
- `dalam_lingkup_air` (boolean, otomatis false jika alasan_di_luar_lingkup terisi)
- `tag_number` (text, nullable) dan `sap_equipment_no` (text, nullable)

Pemetaan taxonomy: pastikan `komponen_master` bisa ditandai levelnya (7 Sub Unit / 8 Maintainable Item / 9 Part) dan terhubung ke equipment unit (level 6). Jika struktur sekarang belum mendukung, usulkan perubahan minimal.

## 1.2 Criticality equipment

### Aturan bisnis
- 4 kategori: `SECE`, `PCE`, `IMPORTANT`, `SECONDARY`.
- **Peralatan Vital = SECE + PCE.**
- Metode: `PHA` (untuk SECE), `ECA` (untuk non-SECE, mengacu TKO B4-025/PHE23000/2024-S9), atau `KUALITATIF` (Gambar 6, dipakai jika PHA/ECA belum bisa dilakukan karena keterbatasan sumber daya).
- Jika metode `KUALITATIF`, **wajib divalidasi ulang paling lambat 2 tahun** (dengan PHA/ECA, atau kajian kualitatif ulang).
- Penentuan SECE dilakukan Fungsi Pelaksana bersama HSSE dan Risk Owner. Setiap SECE wajib punya Performance Standard.

### Diagram kualitatif (Gambar 6), dievaluasi berurutan
| # | Pertanyaan | Jika YA | Jika TIDAK |
|---|---|---|---|
| Q1 | Apakah barrier menampung bahan mudah terbakar yang dapat menyebabkan skenario MAH (Major Accident Hazard)? | SECE | lanjut Q2 |
| Q2 | Apakah barrier dirancang untuk mencegah atau memitigasi MAH? | SECE | lanjut Q3 |
| Q3 | Apakah kegagalan barrier dapat menyebabkan MAH? | SECE | lanjut Q4 |
| Q4 | Apakah kegagalan barrier berdampak pada produksi? | PCE | lanjut Q5 |
| Q5 | Apakah barrier menampung bahan mudah terbakar? | IMPORTANT | SECONDARY |

### Risk matrix (Gambar 5), untuk metode ECA
Skor = Dampak (1–5) × Probabilitas (1–5).
- Dampak: 1 Insignificant, 2 Minor, 3 Moderate, 4 Significant, 5 Catastrophic.
- Probabilitas: 1 (<10⁻⁴/tahun), 2 (10⁻⁴–10⁻³), 3 (10⁻³–10⁻²), 4 (10⁻²–1), 5 (>1/tahun).
- Kategori risiko: I Rendah (1–3), II Rendah ke Moderate (4), III Moderate (5–9), IV Moderate ke Tinggi (10–12), V Tinggi (15–25).
- Pemetaan ke criticality (dari warna sel matriks): skor 15–25 → PCE; skor 5–12 → IMPORTANT; skor 1–4 → SECONDARY. Baris dampak 5 (Catastrophic) ditandai sebagai kandidat SECE dan perlu konfirmasi lewat PHA. **Pemetaan ini dibaca dari gambar; simpan sebagai konfigurasi dan minta saya verifikasi.**

### Schema yang diusulkan
Tambahkan ke master equipment:
- `criticality` (SECE/PCE/IMPORTANT/SECONDARY, nullable)
- `is_vital` (generated: true jika SECE atau PCE)
- `criticality_metode` (PHA/ECA/KUALITATIF)
- `criticality_tgl_penetapan` (date)
- `criticality_tgl_validasi_ulang` (date; otomatis tgl_penetapan + 2 tahun jika KUALITATIF)

Tabel `criticality_assessment` (riwayat):
- id, equipment_id, tanggal, metode, q1–q5 (boolean, nullable), dampak (1–5), probabilitas (1–5), skor, hasil, penilai, referensi_dokumen, catatan, created_at
- Trigger: KUALITATIF → hasil dari q1–q5; ECA → hasil dari skor sesuai konfigurasi; PHA → manual. Penilaian terbaru meng-update master equipment.

## 1.3 Status Integrity equipment

### Aturan bisnis (Gambar 9 & Tabel 5), dievaluasi berurutan
| # | Pertanyaan | Jika YA |
|---|---|---|
| S1 | Apakah peralatan sudah mengalami kegagalan fungsi/kinerja? | **BREAKDOWN** (Hitam) |
| S2 | Apakah ada anomaly/penurunan fungsi yang **tidak memenuhi** performance standard? | **LOW** (Merah) |
| S3 | Apakah peralatan memenuhi performance standard **namun** ada anomaly/penurunan fungsi? | **MEDIUM** (Kuning) |
| — | Semua TIDAK | **HIGH** (Hijau) |

Tindak lanjut umum: HIGH = sesuai jadwal; MEDIUM = frekuensi inspeksi/pemeliharaan dinaikkan, minor repair jika perlu; LOW dan BREAKDOWN = pemeliharaan/perbaikan/penggantian.

Performance standard ditentukan Zona/Field sendiri per jenis peralatan.

### Schema yang diusulkan
- `performance_standard`: id, jenis_equipment (atau FK), parameter, batas_min, batas_max, satuan, keterangan, aktif.
- `integrity_assessment`: id, equipment_id, tanggal, sumber (INSPEKSI/PM/LAPORAN_HARIAN/SOS/LAINNYA), sumber_ref_id, s1–s3, status (dihitung trigger), temuan, penilai, created_at.
- Kolom `status_integrity` dan `status_integrity_tgl` di master equipment, otomatis dari penilaian terbaru.

Integrasi:
- Laporan Harian yang mencatat unit rusak → draft `integrity_assessment` dengan s1 = true, menunggu konfirmasi user.
- Hasil SOS abnormal/kritis → draft MEDIUM/LOW, menunggu konfirmasi user.

## 1.4 Matriks tindak lanjut (Tabel 7)

Seed `matriks_tindak_lanjut_air` (criticality, status, aksi, prioritas, immediate):

| Criticality | BREAKDOWN (Hitam) | LOW (Merah) | MEDIUM (Kuning) | HIGH (Hijau) |
|---|---|---|---|---|
| SECE (Vital) | Immediate Repair / Replacement | Immediate Repair / Replacement / Adjustment | Close Monitor / Interval Inspection & Maintenance / Adjustment, Minor Repair jika perlu | Standard Inspection & Maintenance (Task & Interval) |
| PCE (Vital) | Immediate Repair / Replacement | Immediate Repair / Replacement / Adjustment | Close Monitor / Interval Inspection & Maintenance / Adjustment, Minor Repair jika perlu | Standard Inspection & Maintenance (Task & Interval) |
| IMPORTANT | Repair / Replacement | Repair / Replacement / Adjustment | Close Monitor / Interval Inspection & Maintenance / Adjustment | Standard Inspection & Maintenance (Task & Interval) |
| SECONDARY | Repair / Replacement | – (tidak ditetapkan pedoman) | – | – |

Prioritas (usulan, simpan sebagai konfigurasi): Vital+Hitam = 1, Vital+Merah = 2, Important+Hitam = 3, Important+Merah = 4, Vital+Kuning = 5, Secondary+Hitam = 6, Important+Kuning = 7, lainnya = 9.

View `v_equipment_air_status`: equipment, kategori_aset, criticality, is_vital, status_integrity, tanggal penilaian terakhir, aksi, prioritas, dalam_lingkup_air, flag `perlu_validasi_criticality` (tgl validasi ulang ≤ hari ini + 60 hari), flag `belum_dinilai`.

## 1.5 UI Tahap 1
1. Badge kategori aset, criticality, dan status integrity (warna sesuai pedoman) di daftar & detail equipment.
2. Wizard penilaian criticality (Q1–Q5 berhenti otomatis begitu hasil ditentukan; mode ECA dengan pemilih dampak × probabilitas).
3. Wizard penilaian integrity (S1–S3).
4. Dashboard AIR: heatmap 4×4 (criticality × status) dengan jumlah unit, klik sel → daftar unit; daftar prioritas tindak lanjut; peringatan unit belum dinilai dan validasi ulang criticality; filter dalam lingkup AIR / semua.
5. Decision Engine: tambahkan criticality dan status integrity sebagai input, tanpa mengubah perilaku lama untuk unit yang belum dinilai.

**CHECKPOINT TAHAP 1** — berhenti, laporkan, tunggu diskusi.

---

# TAHAP 2 — Strategi Pemeliharaan, Failure Recording ISO 14224, RCA

## 2.1 Strategi pemeliharaan per equipment (Gambar 7)
| # | Pertanyaan | Jika YA | Jika TIDAK |
|---|---|---|---|
| M1 | Apakah kegagalan berdampak signifikan terhadap keselamatan, kesehatan, dan lingkungan? | lanjut M3 | lanjut M2 |
| M2 | Apakah kegagalan berdampak signifikan terhadap produksi dan menimbulkan biaya signifikan? | lanjut M3 | **REACTIVE** |
| M3 | Apakah kegagalan dapat dipantau dan diperkirakan kapan terjadinya? | **CBM/PREDICTIVE** | lanjut M4 |
| M4 | Apakah ada pendekatan interval yang dapat mengatasi kegagalan? | **PREVENTIVE (periodik)** | **REDESIGN** |

Data pendukung strategi: IOM (Instruction & Operation Manual) dan data pabrikan. Simpan referensi dokumen IOM per equipment/jenis.

Schema: `maintenance_strategy_assessment` (equipment_id, m1–m4, hasil, dasar (IOM/data pabrikan/FMEA/RCM), penilai, tanggal) + kolom `strategi_pemeliharaan` di master equipment.

## 2.2 Klasifikasi kegiatan pemeliharaan (Gambar 8)
Setiap kegiatan PM/WO diberi jenis:
- **Predictive**: Testing & Inspection, Condition Monitoring
- **Preventive**: Periodic Test, Scheduled Replacement, Scheduled Service
- **Corrective**: Immediate, Deferred, Reactive

Catatan: pedoman memasukkan predictive ke dalam payung Preventive Maintenance. Simpan dua level: `jenis_utama` (PREVENTIVE/CORRECTIVE) dan `sub_jenis` (8 nilai di atas, dengan Predictive sebagai sub-grup Preventive).

Tambahkan juga `sap_wo_no` dan `sap_notification_no` (nullable) pada record kegiatan.

## 2.3 Failure recording ISO 14224
Setiap kegagalan dicatat dengan: failure mode, failure cause, failure code, dan object/maintainable item.

Schema:
- `ref_failure_mode` (kode, deskripsi, berlaku_untuk_kategori/jenis equipment). Seed dengan failure mode umum ISO 14224 yang relevan untuk equipment HHE (contoh: fail to start, breakdown, abnormal output, overheating, external leakage, vibration, noise, structural deficiency, abnormal instrument reading, other). Minta saya review sebelum final.
- `ref_failure_cause` (kode, deskripsi, kelompok: design/fabrication/operation/maintenance/management/misc).
- `failure_event`: id, equipment_id, komponen_id (level 7–9, nullable), tanggal_gagal, tanggal_pulih, failure_mode, failure_cause, failure_code, deskripsi, downtime_jam (generated), jenis_corrective, sumber (LAPORAN_HARIAN/INSPEKSI/SOS/LAINNYA), sumber_ref_id, created_at.
- Integrasi: event dari Laporan Harian dan `komponen_riwayat_ganti` yang disebabkan kerusakan diarahkan ke `failure_event`.

Analitik (view):
- MTBF dan MTTR per equipment dan per jenis/kategori.
- Availability = waktu operasi ÷ waktu kalender, per periode.

## 2.4 Root Cause Analysis
Pemicu RCA:
1. **Otomatis**: 3x repetitive failure pada peralatan sejenis dengan parameter operasi sama. Implementasi: ≥3 `failure_event` dengan jenis equipment + failure_mode yang sama dalam jendela waktu yang bisa dikonfigurasi (usulan default 12 bulan), lalu buat `rca_case` berstatus DRAFT dan beri notifikasi.
2. **LPO**: pedoman mewajibkan pelaporan awal via PROPAR dan ke SKK Migas jika unplanned LPO ≥ 3000 BOPD, atau ≥ 30 MMSCFD, atau ≥ 10% produksi harian WK. Untuk HHE ini jarang, cukup sediakan field LPO dan flag manual.
3. **Manual**: atas kebutuhan fungsi P&P.

Schema `rca_case`: id, pemicu (REPETITIVE/LPO/MANUAL), equipment_ids/failure_event_ids terkait, ringkasan tindakan penanganan, analisis akar penyebab (RCFA), diverifikasi_oleh (Pejabat Berwenang), rencana tindak lanjut (SMART: specific, measurable, achievable, realistic, time-bound; dengan PIC & due date), status (DRAFT/ANALISIS/VERIFIKASI/TINDAK_LANJUT/MONITORING/CLOSED), monitoring efektivitas, lampiran.

UI: halaman RCA (daftar + detail + alur status), widget "kandidat repetitive failure" di dashboard.

**CHECKPOINT TAHAP 2** — berhenti, laporkan, tunggu diskusi.

---

# TAHAP 3 — Spare Part VIS

## Aturan bisnis
- Kelas spare part (Tabel 1):
  - **Vital (V)**: spare part peralatan SECE/PCE; jika tidak tersedia menurunkan standar keselamatan (downgraded situation) dan/atau menyebabkan LPO.
  - **Important (I)**: spare part peralatan di luar SECE/PCE; jika tidak tersedia produksi masih jalan tapi berpotensi kerugian besar (pengurangan kapasitas).
  - **Secondary (S)**: spare part pendukung di luar V dan I.
- Kebutuhan dianalisis dan direkomendasikan untuk **2 tahun** (two years spare part).
- **Zero stock policy tidak berlaku untuk spare part Vital**: stok Vital wajib tersedia di gudang.
- Data yang harus diperbarui: jumlah tersedia, **usia penyimpanan**, dan jenis berdasarkan criticality equipment.
- Reservasi resmi dilakukan lewat CMMS (SAP); eRAMHoist mencatat nomor reservasi.

## Schema yang diusulkan
- Kolom di tabel spare part: `kelas_vis` (V/I/S; usulan otomatis dari criticality equipment terkait, bisa di-override), `stok_minimum`, `stok_maksimum`, `lead_time_hari`, `sap_material_no`.
- Tabel relasi `sparepart_equipment` (spare part ↔ equipment/jenis equipment), jika belum ada.
- Tabel atau kolom batch untuk **tanggal masuk** per penerimaan, agar usia penyimpanan bisa dihitung (FIFO).
- `reservasi_sparepart`: id, sparepart_id, equipment_id, qty, sap_reservation_no, tanggal, status.
- View `v_rekomendasi_2tahun`: konsumsi historis (dari `komponen_riwayat_ganti` dan pengeluaran gudang) → proyeksi kebutuhan 24 bulan per spare part, dibandingkan stok saat ini.
- Alert: spare part Vital dengan stok ≤ minimum atau = 0 (prioritas tinggi); usia simpan melebihi batas (batas per jenis, konfigurasi).

Penting: pastikan perhitungan stok **memisahkan stok habis permanen dan barang yang sedang dipinjam**. Alert zero stock Vital tidak boleh salah memicu karena barang yang dipinjam.

**CHECKPOINT TAHAP 3** — berhenti, laporkan, tunggu diskusi.

---

# TAHAP 4 — Governance: Penundaan PM, MOC, Izin Operasi, Decommissioning, Laporan Bulanan

## 4.1 Penundaan PM
- PM boleh ditunda. Jika equipment **Vital**, wajib ada **kajian risiko + justifikasi teknis terdokumentasi** yang **disetujui Risk Owner** (mengacu TKO SECE B8-015/PHE04000/2021-S9 Rev.01).
- Schema `pm_penundaan`: id, equipment_id, kegiatan_pm_ref, tanggal_jadwal_asal, tanggal_jadwal_baru, alasan, kajian_risiko, justifikasi_teknis, diajukan_oleh, risk_owner, status (DIAJUKAN/DISETUJUI/DITOLAK), tanggal_keputusan, lampiran.
- Aturan: penundaan untuk equipment vital tidak bisa berstatus aktif tanpa persetujuan Risk Owner; non-vital cukup dicatat.

## 4.2 Management of Change (MOC)
- Kategori: PERMANEN, TEMPORARY, DARURAT, CONCURRENT, CREEPING.
- **Temporary**: durasi maksimal **6 bulan** per pengajuan; perpanjangan maksimal **2 kali**, masing-masing ≤ 6 bulan. Sebelum durasi akhir habis, wajib ditutup dengan salah satu: RETURNED (kembali ke desain awal), CONVERTED (jadi permanen), REPLACED (diganti solusi permanen).
- **Darurat**: boleh dieksekusi setelah persetujuan pejabat berwenang via email/notulen rapat; dokumen formal menyusul.
- Contoh temporary: perubahan kondisi operasi, override, by-pass, inhibit, temporary isolation, temporary repair, **idle equipment**.
- Checklist MOC idle equipment: buang energi tersimpan, positive isolation, corrosion control, inspection & monitoring regime.
- Close-out wajib: pemutakhiran data, dokumentasi (foto, catatan komunikasi), bukti laporan implementasi.
- Schema `moc`: id, nomor, equipment_ids, kategori, deskripsi, kajian_risiko, persetujuan (bertahap), tgl_mulai, tgl_berakhir, jumlah_perpanjangan, cara_penutupan, checklist_idle (jsonb), status, lampiran.
- Constraint/trigger: tolak perpanjangan ke-3; tolak durasi temporary > 6 bulan; alert H-30 sebelum berakhir.
- Mengubah status aset menjadi IDLE sebaiknya mengusulkan pembuatan MOC idle.

## 4.3 Izin operasi
Pedoman mewajibkan pemenuhan perizinan seperti KHI (Keterangan Hasil Inspeksi) / COI (Certificate of Inspection) dan PLO (Persetujuan Layak Operasi), mengacu Permen ESDM No. 32 Tahun 2021. Untuk peralatan angkat ini sangat relevan.
- Schema `izin_operasi`: id, equipment_id, jenis (COI/KHI/PLO/LAINNYA), nomor, penerbit, tgl_terbit, tgl_kedaluwarsa, lampiran, status (generated: BERLAKU/AKAN_HABIS/KEDALUWARSA).
- Alert H-60 dan H-30 sebelum kedaluwarsa. Equipment dengan izin kedaluwarsa ditandai jelas di dashboard dan Decision Engine.

## 4.3b Remaining Life Assessment (RLA)
Pedoman mendefinisikan RLA sebagai upaya mengukur dan memprediksi umur sisa mesin/peralatan, supaya penggantian atau perbaikan bisa direncanakan. Lampiran 4 pedoman menetapkan **RLA dan LCCA (Life Cycle Cost Analysis)** sebagai tools AIR pada fase **Operasi** dan **Abandonment**. Perpanjangan sisa umur layan mengacu Kepmen ESDM 183.K/HK.02/DMT/2024. Field kami sudah menjalankan RLA, jadi tahap ini mencatat hasilnya, bukan menghitung RLA dari nol.

Schema `rla_assessment`:
- id, equipment_id, tanggal, pelaksana (internal/vendor/lembaga), nomor_laporan, metode
- umur_desain (tahun/jam), umur_operasi_saat_ini (tahun dan/atau HM dari data hour meter yang ada), sisa_umur_hasil (tahun/jam)
- kesimpulan (LAYAK_LANJUT / LAYAK_DENGAN_SYARAT / TIDAK_LAYAK)
- syarat_atau_rekomendasi (teks), batas_layan_baru (tanggal), tgl_rla_berikutnya
- terkait_perpanjangan_izin (boolean), izin_operasi_id (FK nullable ke `izin_operasi`)
- lampiran

Aturan & integrasi:
- Kolom `sisa_umur_layan_sampai` di master equipment, otomatis dari RLA terbaru.
- Rekomendasi RLA bisa dibuat menjadi item tindak lanjut (PIC, due date, status).
- Kesimpulan TIDAK_LAYAK atau LAYAK_DENGAN_SYARAT → usulkan `integrity_assessment` LOW/MEDIUM untuk dikonfirmasi user.
- Alert H-90 sebelum `batas_layan_baru` dan sebelum `tgl_rla_berikutnya`.
- Dashboard: daftar unit mendekati akhir umur layan, digabung dengan criticality, sebagai dasar usulan penggantian di RKAP.
- LCCA cukup disiapkan kolom biaya historis per unit (biaya pemeliharaan + spare part per tahun) agar nanti bisa dipakai untuk analisa repair vs replace. Diskusikan dulu sebelum dibangun penuh.

## 4.4 Decommissioning
- Sebelum status jadi DECOMMISSIONED: semua work order, preventive task, dan notification terkait harus ditutup.
- Data **tidak dihapus**, hanya diarsip (soft delete/flag) untuk jejak historis dan audit.
- Wajib ada referensi dokumen persetujuan decommissioning.
- Trigger: tolak perubahan status ke DECOMMISSIONED jika masih ada item terbuka; tampilkan daftar item yang menghalangi.

## 4.5 Laporan kinerja AIR bulanan
- Materi monitoring & evaluasi kinerja AIR wajib dikirim Regional ke SHU paling lambat **tanggal 12 setiap bulan** (masuk ke aplikasi AIMS). eRAMHoist menyiapkan data pendukung level Field.
- KPI yang disebut pedoman (pilih yang relevan untuk HHE): Enhancement Status Asset Integrity, Realisasi Anggaran, Pembenahan SAP, Pemenuhan PLO, Pemenuhan Sertifikasi Personil AIR, Safety & Compliance Performance, Integrity Risk Management, Technical Integrity & Equipment Condition, Reliability & Clean Handover, Environmental Performance, Schedule & Cost Control.
- Jika KPI tidak tercapai, pemilik KPI wajib membuat penjelasan **SAMBAL**: Siapa, Apa, Mengapa, Bagaimana, Aksi Lanjut.
- Schema: `kpi_air` (definisi, target, satuan, sumber_data) dan `kpi_air_realisasi` (periode, nilai, tercapai, sambal_siapa, sambal_apa, sambal_mengapa, sambal_bagaimana, sambal_aksi_lanjut).
- Halaman laporan bulanan: ringkasan distribusi status integrity, unit vital bermasalah, MTBF/MTTR, PM compliance, izin operasi, RCA terbuka, MOC aktif; ekspor ke Excel/PDF. Reminder otomatis sebelum tanggal 12 (bisa lewat jalur notifikasi Telegram/WhatsApp yang sudah ada).

## 4.6 Sertifikasi personil (opsional, diskusikan dulu)
Pedoman menyebut KPI pemenuhan sertifikasi personil AIR. Jika berguna, tambahkan `sertifikasi_personil` (nama, jenis sertifikat, nomor, kedaluwarsa) dengan alert serupa izin operasi.

**CHECKPOINT TAHAP 4** — berhenti, laporkan, tunggu diskusi.

---

## Definisi selesai (berlaku per tahap)
- Migration berjalan bersih di database yang sudah berisi data, dengan catatan rollback.
- Semua trigger/aturan diuji dengan seluruh kombinasi input (test SQL atau skrip uji).
- Seed referensi lengkap dan sudah saya review.
- UI bekerja di desktop dan HP (PWA).
- Ringkasan perubahan di `docs/AIR_TAHAP{n}.md`.
