# Panduan Interval HM (Hour Meter) — eRAMHoist

**Dokumen referensi** untuk interval Preventive Maintenance (PM), Top Overhaul (TOH), General Overhaul (GOH), dan Batas Umur Ekonomis equipment Hoist & Heavy Equipment Pertamina EP.

Disusun **2026-05-26** sebagai hasil riset OEM + industry-typical (web research kombinasi dengan engineering rule-of-thumb). Disetujui Maman (Abdul Rachman).

---

## 1. Konteks & batasan

**Kenyataan:** OEM (Perkins, Caterpillar, Cummins, Deutz, FG Wilson) **tidak mempublikasikan TOH/GOH interval secara terbuka di web**. Yang resmi dipublikasi cuma interval servis rutin (250/500/1000 jam — oli, filter, valve check). Angka TOH/GOH ada di **Operation & Maintenance Manual (OMM)** resmi yang harus diunduh dari portal OEM (perlu registrasi/serial number).

**Akibat:** Angka di tabel ini = **industry-typical estimasi** berdasarkan kelas engine + rule-of-thumb engineering pengeboran/standby genset. **Bukan angka OEM resmi.** Diperbarui kalau Maman mendapat OMM asli per unit.

**Kebijakan saat ini:** angka konservatif (lower bound dari range) → alarm aplikasi lebih awal → lebih aman dari sisi safety/operasional.

---

## 2. Formula & cara baca

Kolom-kolom di tabel `equipment` (DB):
- `running_hours` = jam jalan kumulatif sekarang (HM)
- `last_pm_hours` = HM saat PM terakhir
- `pm_interval_hours` = interval PM (jam)
- `toh_interval_hours` = interval Top Overhaul (jam)
- `goh_interval_hours` = interval General Overhaul (jam)
- `economic_life_hours` = batas umur ekonomis (jam)
- `last_toh_hours`, `last_goh_hours` = HM saat overhaul terakhir

**Formula yang dipakai aplikasi:**

```
Sisa Jam ke PM = pm_interval_hours − (running_hours − last_pm_hours)
Sisa Jam ke TOH = toh_interval_hours − (running_hours − last_toh_hours)
Sisa Jam ke GOH = goh_interval_hours − (running_hours − last_goh_hours)
UMUR % = (running_hours ÷ economic_life_hours) × 100
```

**Tampilan UMUR %:**

| UMUR % | Status | Warna app |
|---|---|---|
| 0–80% | Sehat, jam jalan masih panjang | 🟢 Sehat |
| 80–99% | Mendekati batas ekonomis — pantau intensif | 🟡 Pantau |
| ≥ 100% | Sudah lewat batas — kandidat ganti unit | 🔴 |

**Verdict Kelayakan (gabungan umur + keandalan):**
- 🔴 **Kandidat ganti** = umur lewat batas (replace) **DAN** keandalan rendah (MTBF < ½ siklus TOH)
- 🟡 **Pantau** = salah satu sumbu bermasalah
- 🟢 **Sehat** = keduanya aman

---

## 3. Tier industry-typical (4 kelas)

### Tier A — Small (<80 kW, 3–4 cyl mechanical injection)

Mesin kecil mechanical, standby genset, mudah dirawat tapi umur lebih pendek.

| Field | Nilai (jam) |
|---|---|
| `pm_interval_hours` | **500** |
| `toh_interval_hours` | **6.000** |
| `goh_interval_hours` | **12.000** |
| `economic_life_hours` | **30.000** |

**Contoh engine:** Perkins 1103A, Cummins 4BTA3.9, Deutz BF4M2012, Olympian/Perkins small (65 kVA dan bawahnya).

### Tier B — Medium (80–150 kW, 4–6 cyl)

Kelas intermediate. Engine populer untuk genset 100–150 kVA.

| Field | Nilai (jam) |
|---|---|
| `pm_interval_hours` | **500** |
| `toh_interval_hours` | **8.000** |
| `goh_interval_hours` | **16.000** |
| `economic_life_hours` | **35.000** |

**Contoh engine:** CAT C4.4 100 kVA, Deutz 1013 series 102 kW, Perkins 1104.

### Tier C — Large (150 kW+, 6 cyl turbo)

Kelas besar prime / standby. Engine 6 silinder turbocharged.

| Field | Nilai (jam) |
|---|---|
| `pm_interval_hours` | **500** |
| `toh_interval_hours` | **10.000** |
| `goh_interval_hours` | **20.000** |
| `economic_life_hours` | **40.000** |

**Contoh engine:** Perkins 1106A (FG Wilson P220-3 ~176 kW), CAT DE165ED (~132 kW), CAT C7.1.

### Tier D — Heavy-Duty Rig (prime mover & mudpump engine)

Engine besar dengan duty cycle berat (load swings, mud, heat). Umur lebih panjang krn over-engineered, tapi PM ketat.

| Field | Nilai (jam) |
|---|---|
| `pm_interval_hours` | **500** |
| `toh_interval_hours` | **10.000** |
| `goh_interval_hours` | **20.000** |
| `economic_life_hours` | **45.000** |

**Contoh engine:** CAT D3406 (12L, ~370 kW), CAT C13/C15/C18, CAT D3408. Untuk MOBENG-* (engine carrier rig) dan ENGINE-MP-* (engine mudpump).

---

## 4. Mapping per unit (per 2026-05-26)

### GENSET (13 unit)

| Tag (terbaru) | Engine | Tier | Catatan |
|---|---|---|---|
| GS-100A-OLY | Olympian 60kVA BW-100A | A | eks GS-100A (rename 2026-05-26) |
| GS-100A-FGW | FG Wilson P220-3 (Perkins 1106A, ~176kW) BW-100A | C | eks GS-100A-2; sebelumnya eco_life typo 480k → diperbaiki 40k |
| GS-H35KD | FG Wilson P220-3 H35KD | C | rh 8.653 |
| GS-KB150A-DEUTZ | Deutz BF04M1013EC 102KW KB150.A | B | eks GS-KB150A |
| GS-KB150A-CAT | CAT DE165ED (~132kW) KB150.A | C | eks GS-KB150A-2 |
| GS-KB150B-DEUTZ | Deutz BF4M2012C 74.9KW | A | eks GS-KB150B. **Lokasi fisik = BW-100A** (lihat catatan #3) |
| GS-KB150B-CAT | CAT DE165ED KB150.B | C | eks GS-KB150B-2 |
| GS-KB150B-CUMMINS | Krisbow / Cummins 4BTA3.9-G2 (~50kW) KB150.B | A | eks GS-CAD-2; rh 12.836 → umur 43% |
| GS-KB150C | CAT C4.4 100Kva KB150.C | B | tag tetap (1 dari 2 CAT C4.4 sama merek) |
| GS-KB150C-2 | CAT C4.4 KB150.C (SN 7K304827, NEW Excel #23) | B | tag tetap (rh 13.178); same-brand pair |
| GS-KB150C-DEUTZ | Deutz 1013 KB150.C | A | eks GS-CAD |
| GS-MTU-OLY | Olympian OLYM 65-5 (~50kW, Perkins-based) | A | |
| GS-MTU-PERKINS | Perkins 1103A-33T (Genset Perkins MTU) | A | **rh 36.679 → UMUR 122% 🔴 KANDIDAT GANTI** |
| GS-DEUTZ-01 | Deutz BF04M1013EC (placeholder #31 Excel) | B | Data spec menunggu dari Maman |

**Rename batch 2026-05-26:** 8 tag genset diperluas dengan suffix merek (–OLY/–FGW/–DEUTZ/–CAT/–CUMMINS) supaya jelas mana unit untuk pair `tag` vs `tag-2`. GS-CAD direname jadi GS-KB150C-DEUTZ; GS-CAD-2 jadi GS-KB150B-CUMMINS (sesuai lokasi fisik Excel #30). FK by ID — hierarki anak tidak terganggu.

### ENGINE — Rig Carrier & Mudpump (15 unit)

Semua **Tier D**:

| Tag | Engine | rh sekarang | UMUR % |
|---|---|---|---|
| MOBENG-100A | CAT D3406 (Engine BW-100A) | 4.656 | 10% |
| MOBENG-H35KD | CAT D3406 (Engine BW H35KD) | 3.412 | 8% |
| MOBENG-KB150A | CAT D3406 (Engine BW KB150.A) | 0 | — |
| MOBENG-KB150B | CAT D3406 (Engine BW KB150.B) | 466 | 1% |
| MOBENG-KB150C | CAT D3406 (Engine BW KB150.C) | 0 | — |
| ENGINE-MP-100A | CAT C13 (MP-100A) | 0 | — |
| ENGINE-MP-ACID-01 | CAT C11 (Mudpump Acid) | 1.239 | 3% |
| ENGINE-MP-BACKUP-01 | (Backup pool) | 0 | — |
| ENGINE-MP-H35KD | CAT C15 (MP-H35KD, MCW04569) | 3.698 | 8% |
| ENGINE-MP-KB150A | CAT D3408 | 0 | — |
| ENGINE-MP-KB150B | CAT D3406 | 0 | — |
| ENGINE-MP-KB150B-2 | CAT D3406 (Mudpump GD, NEW Excel #15) | 1.597 | 4% |
| ENGINE-MP-KB150C | CAT D3406 (Mudpump SPM) | 0 | — |
| ENGINE-MP-YARD-01 | CAT C15 (JWS-400 Yard Standalone, NEW Excel #14) | 239 | 1% |
| GEG-MudPump-5 | MudPump LWS-440 | 0 | — |

### KENDARAAN — pm_type='km' (12 unit)

Beda basis (km bukan jam). Interval default seragam:

| Field | Nilai (km) |
|---|---|
| `pm_interval_hours` (sebagai km) | **5.000 km** |
| `running_hours` (sebagai counter km) | nilai odometer |

**Unit:** DMK-T-03, DMK-T-04, SLT-01-BG8066CZ, SLT-02, HT-BG8077CE, HT-BG8078CE, CT-BG8200CE, ML-BG9040CZ, ML-BG9886SIA, ST-BG8047CZ, DT-BG9017CZ, DT-BG8013CZ.

TOH/GOH/economic_life untuk kendaraan **belum diisi** (perlu reference per merek mobil — Hino/Nissan UD/Isuzu/Mitsubishi/MAN). Bisa dikerjakan terpisah saat data ditemukan.

---

## 5. Cara update bila OMM resmi ditemukan

**SQL Editor (Supabase) - per unit:**

```sql
UPDATE equipment
SET pm_interval_hours  = <nilai_oem>,
    toh_interval_hours = <nilai_oem>,
    goh_interval_hours = <nilai_oem>,
    economic_life_hours = <nilai_oem>,
    updated_at = now()
WHERE tag_number = '<TAG>';
```

**Atau via app:** Equipment → klik unit → Edit → section D2 "PM, Overhaul & Kelayakan" → isi field-nya → Save.

**Setelah PM/TOH/GOH dilakukan beneran:** update `last_pm_hours`, `last_pm_date`, `last_toh_hours`, `last_goh_hours`, `last_goh_date` untuk reset baseline supaya sisa interval terhitung benar.

---

## 6. Sumber & referensi

### Sumber utama (Perkins)
- [Perkins Operation and Maintenance Manuals](https://www.perkins.com/en_GB/aftermarket/operation-maintenance-manuals.html)
- [Perkins 1103A-33TG Diesel Engines](https://www.perkins.com/en_GB/products/new/perkins/electric-power-generation/diesel-engines/1000002507.html)
- [Perkins maintenance schedule](https://www.perkins.com/en_GB/aftermarket/maintenance/preventive-maintenance/scheduled-maintenance.html)
- [Perkins standby diesel generators](https://www.perkins.com/en_GB/aftermarket/maintenance/maintenance-advice/standby-diesel-generators.html)

### Sumber pendukung (Caterpillar, Cummins, Deutz, FG Wilson)
- [Cat C3.3 & C4.4 Operation and Maintenance Manual (PDF)](https://csdieselgenerators.com/Images/Generators/2690/Cat-Operation-and-Maintenance-Manual-C3.3-and-C4.4-rental-generator-sets.pdf)
- [Cat C4.4 Marine Genset spec sheet (PDF)](https://www.teknoxgroup.com/fileadmin/user_upload/c4.4_marine_genset__36ekW_.pdf)
- [Cummins 4BTA3.9-G2 datasheet (PDF)](https://vinagenset.com/wp-content/uploads/4BTA3.9-G2.pdf)
- [Cummins 4BTA3.9 product page](https://www.cummins.com/generators/4bta39)
- [Deutz BF4M2012C Genset manual (PDF)](https://deutz.com.ua/wp-content/uploads/2019/04/BF4M2012C-50Hz-Genset.pdf)
- [Deutz 2012 series Operation Manual (PDF)](https://assets.website-files.com/5bb5d8791d0d562cacebb00f/5c0563c642e49e06110defa8_Deutz-2012-Operation-Manual.pdf)
- [FG Wilson Overhaul kits](https://www.fgwilson.com/en_GB/support/major-overhaul-kits.html)
- [FG Wilson P220-3 product page](https://www.fgwilson.com/en_GB/products/new/fg-wilson/diesel-generators/small-range-220-kva/1000004204.html)

### Industry rule-of-thumb
- [B10 & B50 Life of Diesel Engines (DieselHub)](https://www.dieselhub.com/tech/b10-b50-life.html)
- [Welland Power - About Perkins 1103A-33G](https://support.wellandpower.net/hc/en-us/articles/360002172497-All-About-the-Perkins-1103A-33G-Engine)
- [Hosempower - Perkins Generator Maintenance Schedule](https://www.hosempower.com/blog/perkins-generator-maintenance-schedule_b23)

### Statistical reference
- [Statistical Methods for Planning Diesel Engine Overhauls (Univ. Michigan)](https://deepblue.lib.umich.edu/bitstream/handle/2027.42/86221/Perakis3.pdf)

---

## 7. Catatan eksekusi DB

Script-script PATCH yang dijalankan via REST service key (audit trail):

1. **Fase 0 seed HM rig fleet (9 unit)** — file: `seed_running_hours.sql`
2. **Step 1 hygiene + melengkapi (6 unit)** — manual REST PATCH
3. **Fase 1 schema (Step 2)** — file: `fase1_step2_schema.sql` (ALTER + 3 parent_units + 18 kategori baru)
4. **Fase 1 records (Step 3)** — 59 NEW via REST POST
5. **Fase 2 schema (pm_type='km')** — file: `fase2_step1_pm_km.sql` (ALTER CHECK + 12 PATCH)
6. **Genset Tier A/B/C (13 unit)** — temp script `patch_gensets.js`
7. **Engine Tier D (15 unit)** — manual REST PATCH

Snapshot live DB sebelum & sesudah Fase 1:
- `equipment_live_20260526.json` (194 record pre-Fase1)
- `equipment_live_20260526_postFase1.json` (253 record post-Fase1 + tier updates)

---

## 8. Pekerjaan lanjutan (untuk Maman / Bian)

1. **Update intervals dari OMM asli** kalau ditemukan (terutama MTU/Olympian/Krisbow yang spec-nya jarang publik).
2. **Isi `last_toh_hours`, `last_goh_hours`** dari catatan kantor agar Sisa TOH/GOH terhitung benar (saat ini default 0 → ditampilkan "lewat banyak" untuk unit lama).
3. **Mapping tag 5 FP-* rig** ke Excel #33–37 (manual via app).
4. **Mapping tag 3 TL-* ke rig mana** untuk Excel #20–22 (manual via app).
5. **Lengkapi GS-DEUTZ-01** (placeholder #31, masih kosong SN/HM/lokasi).
6. **Mode "Update Counter Quick"** untuk admin (optional UI enhancement) — biar update HM/KM harian lebih cepat tanpa buka form Edit penuh.
7. **TOH/GOH/eco_life untuk Kendaraan KM** — perlu reference per merek mobil (Hino/Nissan UD/Isuzu/Mitsubishi/MAN).

---

## 9. Catatan / Anomali yang belum diselesaikan

### Catatan #1 — Anomali tag `Trns-JWS-400-2`

Ada record `Trns-JWS-400-2` (Transmisi Mud Pump JWS-400) di DB **tanpa pasangan base `Trns-JWS-400`**. Suffix `-2` mengindikasikan duplikat tapi base-nya tidak ada — kemungkinan sisa dari restruktur DB sebelumnya.

**Status:** bukan duplikat (cuma 1 record), tidak ada anak, rh=0. **Tidak urgent.**

**Opsi:**
- Biarkan apa adanya (tag `-2` tapi tunggal).
- Rename ke `Trns-JWS-400` (lebih bersih, perlu cek dulu tidak bentrok dgn record lain).
- Hapus bila memang sudah tidak relevan.

Tunggu keputusan Maman.

### Catatan #3 — Konflik lokasi GS-KB150B-DEUTZ (eks GS-KB150B)

Tag `GS-KB150B-DEUTZ` (Genset Deutz BF4M2012C, SN 60386305) menurut DB ada di rig **BW KB150.B**. Tapi menurut Excel pagi #26, fisiknya saat ini ada di **BW-100A** — sudah dikonfirmasi Maman: "lokasi DB salah, Excel benar".

**Status saat ini:** HM 3.979 sudah ter-seed; tag masih encoded "KB150B" (tidak diubah karena rename tag = ID-level change yang lebih besar dampaknya).

**Opsi solusi:**
- **(a) Update field lokasi & assigned_unit_id saja** — tag tetap `GS-KB150B-DEUTZ`, tapi `lokasi_fisik='BW-100A'` dan `assigned_unit_id=1` (BW-100A). Tag jadi historical, lokasi reflect fisik sekarang.
- **(b) Rename tag** ke `GS-100A-DEUTZ` — lebih konsisten tapi semua referensi historis (dokumen, laporan PDF lama) menggunakan tag lama. Plus sudah ada `GS-100A-OLY` & `GS-100A-FGW` — kalau ditambah `-DEUTZ` jadi 3 genset di BW-100A (mungkin memang demikian fisiknya).
- **(c) Biarkan, kasih remarks** "lokasi fisik aktual: BW-100A (pindah dari KB150.B)".

Pilih sesuai operational reality. Saran saya: **(a)** — update assigned_unit_id + lokasi_fisik tapi pertahankan tag, biar history dokumen tetap konsisten.

Tunggu keputusan Maman.

---

## 10. Log perubahan tag (audit trail)

| Tanggal | Tag lama | Tag baru | Alasan |
|---|---|---|---|
| 2026-05-26 | GS-100A | GS-100A-OLY | Disambig merek (Olympian) |
| 2026-05-26 | GS-100A-2 | GS-100A-FGW | Disambig merek (FG Wilson) |
| 2026-05-26 | GS-KB150A | GS-KB150A-DEUTZ | Disambig merek (Deutz) |
| 2026-05-26 | GS-KB150A-2 | GS-KB150A-CAT | Disambig merek (CAT DE165ED) |
| 2026-05-26 | GS-KB150B | GS-KB150B-DEUTZ | Disambig merek (Deutz) |
| 2026-05-26 | GS-KB150B-2 | GS-KB150B-CAT | Disambig merek (CAT DE165ED) |
| 2026-05-26 | GS-CAD | GS-KB150C-DEUTZ | Tag GS-CAD nggak intuitif → reflect lokasi+merek |
| 2026-05-26 | GS-CAD-2 | GS-KB150B-CUMMINS | Reflect lokasi fisik Excel #30 + merek Cummins |
| 2026-05-26 | ENGINE-MP-KB150B-2 | (deleted) | Merge ke ENGINE-MP-KB150B (SN cuma beda 1 digit nol, ternyata sama fisik). HM 1.597 dipindah ke ENGINE-MP-KB150B + SN dikoreksi 3ZJ061815 → 3ZJ61815 |
