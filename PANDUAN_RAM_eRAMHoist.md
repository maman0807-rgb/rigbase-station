# Panduan RAM — eRAMHoist

**User manual operasional** untuk Reliability, Availability, Maintainability fleet Hoist & Heavy Equipment Pertamina EP via aplikasi eRAMHoist.

- **Versi:** 1.0 (2026-05-27, pasca-restruktur hierarki & Fase 6 photo upload)
- **Untuk:** Sr Mekanik · SPV · Sr SPV · Astmen · Admin
- **App URL:** https://eramhoist.vercel.app
- **Referensi angka OEM:** [PANDUAN_INTERVAL_HM.md](./PANDUAN_INTERVAL_HM.md)

---

## 1. Apa itu RAM?

**RAM = Reliability · Availability · Maintainability** — 3 pilar analisa kelayakan operasional equipment.

| Pilar | Pertanyaan utama | Tab di app |
|---|---|---|
| **Reliability** (Keandalan) | "Seberapa sering rusak?" → MTBF, jumlah kerusakan | RAM → Reliability |
| **Availability** (Ketersediaan) | "Berapa % waktu siap pakai?" → uptime vs downtime | RAM → Availability |
| **Maintainability** (Kemudahan dirawat) | "Kapan PM/TOH/GOH? Sisa berapa jam?" | RAM → Maintenance |
| **Kelayakan Armada** | "Layak dirawat atau ganti?" gabungan umur + keandalan | RAM → Kelayakan |

---

## 2. Struktur Data — Armada & Hierarki

### 5 Armada (parent_units.type)

```
Rig                  → 5 unit (BW-100A, H35KD, KB150.A/B/C)
Standalone           → 3 unit (MTU, Slickline, Independent)
Alat Berat           → 1 bucket "Alat Berat Civil" (9 unit)
Kendaraan            → 1 bucket "Kendaraan" (10 unit, KM-based)
Fire & Safety        → 1 bucket "Fire & Safety" (31 unit: 29 FPP + 2 Damkar)
```

### Canonical Hierarchy per rig

```
🛢️  Mobile Rig (MR-*)  ← container utama
├── 📦 Carrier (CARRIER-*)
│   ├── Drilling Console (DC-*)
│   ├── Drawwork (DW-*)
│   ├── Hydraulic Jack (HJ-*)
│   └── Mounting Axle (MA-*)
├── 🗼 Mast (MAST-*)
│   ├── Travelling Block (TB-*)
│   ├── Escape Chair (EC-*)
│   └── Locking Pawl (LP-*)
├── ⚙️ Engine Rig (MOBENG-*)
│   └── Transmisi Rig (TRANS-*)
├── 🛞 Mudpump (MP-*)
│   ├── Engine Mudpump (ENGINE-MP-*)
│   ├── Pump body (PUMP-*)
│   └── Transmisi Mudpump (TRANS-MP-*)
└── ⚡ Genset, BOP, Accumulator, BPM, MGS, Blower, Compressor,
    Stand Lamp, Tower Light, Fire Pump, Portacamp, Handling Tools
    (semua sibling-sibling di bawah MR)
```

### Naming convention pasca-rename (Mei 2026)

- **Genset** dengan suffix merek: `GS-{rig}-{MERK}` mis. `GS-KB150A-DEUTZ`, `GS-100A-FGW`, `GS-MTU-PERKINS`
- **Mudpump backup**: `MP-BACKUP-01` (JWS-400 shared pool), `MP-BACKUP-02` (Omega)
- **Tag konsisten** dengan armada-nya (tag = ID stabil; lokasi fisik di field `lokasi_fisik`)

---

## 3. RELIABILITY — Reliability tab

### Apa yang ditampilkan

- **MTBF (Mean Time Between Failures)** = jam jalan ÷ jumlah kerusakan
- **Kategori failure**: `breakdown` + `troubleshoot` dihitung sebagai kejadian (event)
  - `tunggu_spare` = durasi saja, **bukan event baru** (tidak menurunkan MTBF palsu)
- **MTBF basis HM**: dari `running_hours` ÷ jumlah event
- **MTBF basis kalender**: dari periode dipilih (30/90/365 hari)

### Cara baca

| MTBF (jam) | Status |
|---|---|
| < ½ siklus TOH | 🔴 Keandalan rendah |
| ½ siklus s/d 1 siklus TOH | 🟡 Pantau |
| ≥ 1 siklus TOH | 🟢 Sehat |

---

## 4. AVAILABILITY — Availability tab

### Catat downtime (workflow Fase 6 dengan foto)

#### Skenario multi-day repair

**Hari 1 — Equipment rusak:**

1. RAM → **Availability** → **+ Catat Downtime**
2. Isi:
   - Equipment, Mulai Down (sekarang), **Selesai (kosongkan — masih down)**
   - Penyebab: `Breakdown` / `Troubleshoot`
   - **Catatan**: deskripsi singkat kerusakan (mis. "Engine knocking, dugaan turbo bocor")
3. Scroll ke **📸 FOTO PENDUKUNG**:
   - **Fase**: `Sebelum / Bukti Kerusakan`
   - **Tgl kejadian foto**: hari ini (default)
   - **Caption**: "Oli netes seal turbo"
   - **Pilih foto**: 1-5 foto kondisi rusak
4. **Simpan** → toast "Upload N foto sukses"

**Hari 3 — Part datang:**

1. RAM → Availability → **list "🔴 Sedang Down"** → klik **Edit** record itu
2. Jangan ubah Mulai/Selesai
3. Section 📸 FOTO PENDUKUNG:
   - **Fase**: `Part / Spare Part`
   - **Tgl kejadian foto**: ubah ke tanggal part datang (mis. 29/05/2026)
   - **Caption**: "Turbo baru P/N HX35 dari gudang"
   - **Pilih foto**: foto part
4. **Simpan** → foto ke-2 ditambah ke event yang sama, status tetap 🔴 Sedang Down

**Hari 5 — Perbaikan selesai:**

1. Edit record yang sama
2. Isi **Selesai** dengan tanggal akhir perbaikan
3. Section foto:
   - **Fase**: `Sesudah / Bukti Perbaikan`
   - **Tgl kejadian foto**: hari selesai
   - **Caption**: "Pemasangan + test run OK"
   - Foto: bukti perbaikan
4. **Simpan** → record **closed**, durasi auto-terhitung

### Tampilan di History tab equipment

```
🟢 31 Mei 2026 • SELESAI PERBAIKAN (lama 4.1 hari)
   👷 Diselesaikan oleh: David
   📝 Pemasangan + test run OK
   [📸 31 Mei "after"]   (border hijau)

📦 29 Mei 2026 • Part datang / dipasang
   👷 Oleh: David
   📝 Turbo baru P/N HX35 dari gudang
   [📸 29 Mei "part"]    (border biru)

🔴 27 Mei 2026 • Penyebab: Breakdown
   👷 Dilaporkan oleh: M. Yusuf
   📝 Engine knocking parah, dugaan turbocharger bocor
   [📸 27 Mei "before"]  (border merah)
```

### Aturan foto

- **Max 5 foto** per upload session (bisa multiple session)
- **Auto-compress** otomatis ke ≤300 KB (1280px lebar, JPEG q78)
- **Phase** wajib pilih (Sebelum/Sesudah/Part/Lainnya) — menentukan border warna & posisi di timeline
- **Tgl kejadian foto** ≠ tgl upload (untuk audit jujur — kalau upload telat masih akurat)
- **Caption** optional max 200 char
- Hover thumb → **✕** untuk hapus foto (perlu re-edit lewat form)

### KPI Availability (kartu atas)

| Metric | Definisi |
|---|---|
| Availability rata-rata | (period − total downH) ÷ period × 100% |
| Sedang Down | count event end_at NULL |
| MTTR (Mean Time To Repair) | rata² durasi 1 perbaikan |
| MTBF (kalender) | rata² jarak antar kerusakan |

---

## 5. MAINTAINABILITY — Maintenance & dashboard

### PM (Preventive Maintenance) — basis jam atau km

| Jenis unit | Basis | Field interval | Default |
|---|---|---|---|
| Engine, Genset, Pompa | **jam** | `pm_interval_hours` | 500 jam |
| Kendaraan, Damkar, Slickline truck | **km** | `pm_interval_hours` (sebagai km) | 5.000 km |

### TOH / GOH / Economic Life

Per tier (lihat [PANDUAN_INTERVAL_HM.md](./PANDUAN_INTERVAL_HM.md) section 3):

| Tier | Contoh | PM | TOH | GOH | Eco life |
|---|---|---|---|---|---|
| A | Perkins 1103A, Cummins 4BTA, Deutz BF4M2012 | 500 | 6.000 | 12.000 | 30.000 |
| B | CAT C4.4, Deutz 1013 | 500 | 8.000 | 16.000 | 35.000 |
| C | FG Wilson P220 (Perkins 1106A), CAT DE165ED | 500 | 10.000 | 20.000 | 40.000 |
| D | CAT D3406/C13/C15/D3408 (rig) | 500 | 10.000 | 20.000 | 45.000 |

### Update HM/KM (counter)

**Daily counter update** (admin):
1. Equipment → klik unit → **Edit**
2. Section **C. Status**, field **Running Hours / KM (counter)** → ketik nilai terbaru → **Save**

**Saat PM selesai beneran**:
1. Update `running_hours` dan `last_pm_hours` (jadi sama → sisa PM = interval penuh)
2. Update `last_pm_date` ke tanggal PM

**Mekanik field input** (Logbook):
- HM unit (Genset/Engine/Pompa): via Logbook tab "Isi HM" → approve_hm RPC akumulasi ke `running_hours`
- KM unit: belum ada flow di Logbook (Fase berikutnya)

### Kartu dashboard

| Kartu | Yang ditampilkan |
|---|---|
| ⏱️ PM Berbasis Jam | Unit ber-HM yg sisa PM ≤ 50 jam |
| 🛻 PM Berbasis KM | Unit ber-KM yg sisa PM ≤ 500 km |
| 🔧 Overhaul & Kelayakan | TOH/GOH due ≤ 500 jam atau umur ≥ 80% |

---

## 6. KELAYAKAN ARMADA — Kelayakan tab

### Verdict logic

```
Umur ekonomis    Keandalan (MTBF)
   <80%           <½ TOH        → 🟡 Pantau
   80-99%         <½ TOH        → 🟡 Pantau
   ≥100%          <½ TOH        → 🔴 Kandidat Ganti
   <80%           ≥1 siklus     → 🟢 Sehat
```

Aturan ringkas:
- 🔴 **Kandidat ganti** = umur lewat batas **DAN** keandalan rendah (MTBF < ½ TOH)
- 🟡 **Pantau** = salah satu sumbu bermasalah
- 🟢 **Sehat** = keduanya aman

### Layout 2 section

- **Berbasis JAM** (engine, genset, pump) — pakai HM
- **Berbasis KM** (Kendaraan, Damkar, Slickline truck) — pakai KM

### Highlight saat ini

- **GS-MTU-PERKINS**: rh 36.679 jam, eco_life 30.000 → **UMUR 122%** → 🔴 Kandidat ganti (post-evaluasi)

---

## 7. INSPEKSI — sub-tab Reliability

### Cat3 & Cat4 (PLO Inspection)

- **Cat3**: ringan, periodik (annual?)
- **Cat4**: comprehensive, dengan MPI (Magnetic Particle Inspection) per komponen

### Workflow

1. Buat siklus inspeksi (1 siklus = 1 rig × 1 kategori)
2. Catat temuan per equipment + kategori (Critical / Major / Minor / N/A)
3. Upload foto Before/After per temuan
4. Generate PDF report

Lihat [RIGBASE_INSPECTION_PROMPT.md](./RIGBASE_INSPECTION_PROMPT.md) untuk detail flow.

---

## 8. SOP Harian Mekanik (rangkuman)

### Morning check (operator/mekanik)

1. Cek dashboard eRAMHoist
2. Lihat kartu **PM Berbasis Jam/KM** — ada unit hijau muda (mendekati)?
3. Lihat **Sedang Down** — ada yang perlu follow up?
4. Update HM/KM unit yang baru jalan (lewat Logbook "Isi HM" / via app Edit)

### Saat equipment rusak

1. **Catat Downtime baru** segera (real-time) + foto kondisi rusak
2. Kalau perbaikan multi-day: edit & update foto tiap milestone (part datang, dst)
3. Setelah selesai: isi tanggal Selesai + foto after

### Weekly review (Sr Mekanik)

1. RAM → **Kelayakan** → cek unit 🔴 / 🟡 — ada yg jadi watchlist?
2. RAM → **Availability** → cek MTTR/MTBF trend
3. RAM → **Reliability** → cek pattern kerusakan per equipment

### Monthly (atasan)

1. Print report RAM via tombol Cetak per tab
2. Print riwayat equipment via History tab → Print PDF
3. Review CSPP (📦 Critical Spare Parts) — stok kritis OK?

---

## 9. Common pitfalls (yang harus diingat)

### Edit equipment butuh role admin

RLS `equipment`: write **admin only**. Edit lewat Logbook **gagal diam-diam tanpa error** kalau sesi bukan admin. **Selalu login admin** (Abdul Rachman / Bian) saat seed/edit data master.

### HM Sekarang vs HM saat PM Terakhir

- **HM Sekarang** = `running_hours` = odometer kumulatif (bukan jam harian)
- **HM saat PM Terakhir** = `last_pm_hours` = baseline waktu PM terakhir
- Sisa PM = `(last_pm_hours + pm_interval_hours) − running_hours`
- Kalau baru PM: isi keduanya sama → sisa = interval penuh

### Foto upload — phase wajib pilih

- Default `before` → foto masuk ke event DOWN
- `after` → ke event SELESAI
- `part` → milestone sendiri di antara DOWN dan SELESAI (sort by tgl kejadian)

### Catatan vs Caption foto

- **Catatan downtime_event** = deskripsi awal kerusakan (1x per event)
- **Caption foto** = mini-log per upload (multiple, tiap foto)
- Tampilan History tab: DOWN ambil dari Catatan; PART/SELESAI ambil dari Caption foto

---

## 10. Sumber & Cross-reference

- **OEM tier intervals**: [PANDUAN_INTERVAL_HM.md](./PANDUAN_INTERVAL_HM.md)
- **Inspeksi flow**: [RIGBASE_INSPECTION_PROMPT.md](./RIGBASE_INSPECTION_PROMPT.md)
- **Setup teknis**: [SETUP.md](./SETUP.md)
- **App spec internal**: [PROMPT.md](./PROMPT.md)
- **README publik**: [README.md](./README.md)
- **Supabase project**: `olmowzrlokajhniqijfq` ([dashboard](https://supabase.com/dashboard/project/olmowzrlokajhniqijfq))

---

## 11. Roadmap / Pekerjaan lanjutan

- [ ] **PM-km flow di Logbook** — supaya mekanik bisa catat odometer kendaraan harian
- [ ] **Edit foto** (caption/phase/date) setelah upload — sekarang cuma delete+re-upload
- [ ] **Print report Downtime dengan foto inline** — currently cetak summary tabel saja
- [ ] **Mobile responsive** — optimize untuk HP saat lapangan
- [ ] **Notification ke Telegram** untuk Down baru — Fase 5 (sudah ada cron alert untuk PM-jam)
- [ ] **CSPP enrichment** — auto-suggest part based on equipment kategori

---

*Dokumen ini hidup — update sesuai perubahan app. Versi terbaru selalu di GitHub `main`.*
