# PROMPT — Modul "SOS Oil & Fuel Analysis" untuk eRAMHoist

> Tempel prompt ini ke Claude Code di dalam project eRAMHoist.
> Kerjakan BERTAHAP — jangan langsung bangun semua. Berhenti di tiap
> checkpoint untuk konfirmasi sebelum lanjut.

---

## KONTEKS

Aplikasi eRAMHoist mengelola equipment lapangan. Kami berlangganan layanan
analisa SOS (Scheduled Oil Sampling) dari PT Trakindo Utama (lab CAT) untuk
berbagai equipment dan komponen.

**Masalah yang dipecahkan:** Lab hanya memberi rekomendasi PER-SAMPLE
(snapshot kondisi hari itu), tanpa merangkum tren lintas waktu. Tiap report
bisa berkata "No Action Required" padahal sebuah parameter naik pelan-pelan
dari sample ke sample. Modul ini mengisi celah itu: mengubah kumpulan report
menjadi keputusan tindakan ke depan (prognostik), bukan sekadar arsip.

**Pengguna belum ahli baca SOS.** Maka app berperan sebagai PENCATAT +
PENERJEMAH + PEMBERI SINYAL ARAH — BUKAN pemberi vonis. Keputusan akhir tetap
di manusia. Gunakan bahasa "disarankan / indikasi / perlu diperhatikan",
hindari "harus / pasti rusak".

Gunakan stack & konvensi yang sudah ada di project ini.

---

## ARSITEKTUR DATA

Hierarki:

```
Equipment (sudah ada di app)
   └── Component   (tipe: ENGINE | GEARBOX | TRANSMISSION | FUEL)
          └── SOS_Sample   (satu record per tanggal sampling)
```

- Satu Equipment bisa punya beberapa Component.
- Tiap Component punya rangkaian SOS_Sample sendiri (ditrack & dibaca terpisah,
  tapi tampil dalam satu halaman Equipment).

### Field umum SOS_Sample
sampled_date, sample_id, lab_date, meter_hr (jam unit), meter_on_fluid
(jam oli/fluid saat sampling), fluid_change (Y/N), filter_change (Y/N),
fluid_type, fluid_brand, **lab_status** (teks dari Trakindo, mis.
"No Action Required"), **lab_recommendation** (teks dari Trakindo),
**pdf_attachment** (file report asli sebagai arsip).

### Parameter per Component type
Tampilkan HANYA field yang relevan dengan tipe komponen (jangan tampilkan
parameter yang tidak relevan, mis. soot di gearbox).

- **ENGINE:** Fe, Pb, Cu, Cr, Al, Sn, Ni, Si, Na, K + soot, oxidation,
  nitration, sulfation, fuel_dilution, water, TBN, TAN, viscosity_100c,
  pq_index + additives (Ca, P, Zn, Mg, Mo, B)
- **GEARBOX / FINAL DRIVE:** Fe, Cu, Pb, Cr, Si, Al + water, viscosity, pq_index
- **TRANSMISSION / HIDROSTATIK:** Fe, Cu, Al, Cr, Sn, Si + water, viscosity,
  oxidation, pq_index, particle_count
- **FUEL:** water, sediment, particle_count (ISO cleanliness code), microbial,
  density, sulfur — (parameter bahan bakar, BUKAN wear metal oli)

> Catatan: parameter FUEL diisi dari pengetahuan umum analisa bahan bakar.
> Format report fuel Trakindo akan dikonfirmasi belakangan; buat field-nya
> mudah disesuaikan.

---

## MODUL 1 — SOS TRACKER (entry + arsip + tren dasar)

### Sub-fase 1A — bangun sekarang
1. CRUD SOS_Sample dengan **manual entry**. Layout form MENGIKUTI urutan report
   Trakindo (wear metals dulu, lalu oil condition) agar user tinggal menyalin
   baris per baris dari PDF.
2. Upload & simpan **PDF report asli** sebagai lampiran tiap sample (arsip/bukti audit).
3. Rekam **lab_status** & **lab_recommendation** Trakindo apa adanya, tampilkan menonjol.
4. **Deteksi tren dasar:** untuk tiap parameter numerik, bandingkan terhadap
   3–4 sample sebelumnya; tandai "tren naik" bila naik konsisten ≥3 sample.
   Bedakan TREND (naik berkelanjutan) dari EVENT (lonjakan sekali lalu kembali
   normal) — EVENT jangan dihitung sebagai tren, tapi catat sebagai anomali.
5. Tampilan:
   - List Equipment → badge status terakhir (dari lab_status Trakindo).
   - Detail Component → tabel histori (kolom = tanggal sampling, kiri→kanan,
     persis report Trakindo) + grafik tren parameter kunci.
   - Highlight parameter yang sedang "tren naik".
   - Tampilkan **meter_on_fluid** dengan jelas (penting untuk konteks ppm).

**>> CHECKPOINT 1: tunjukkan schema data (Equipment–Component–SOS_Sample +
tabel threshold kosong) untuk direview SEBELUM lanjut UI.**

### Sub-fase 1B — siapkan struktur, isi belakangan
6. Tabel **threshold** terpisah, **editable per Component type & per parameter**
   (kolom: normal_max, warning_max, critical_max). Disimpan di config/DB —
   JANGAN hardcode di logic. Boleh kosong dulu.
7. Bila threshold terisi → hitung status hijau/kuning/merah per parameter +
   status keseluruhan sample.
8. Semua threshold editable lewat UI admin.

---

## MODUL 2 — TREND & DECISION ENGINE (membaca SEMUA sample)

Sub-modul ini membaca SELURUH histori SOS_Sample per Component (bukan per
sample) dan menghasilkan satu rangkuman + rekomendasi forward-looking.
**WAJIB tetap berfungsi walau tabel threshold masih kosong** — arah & laju
hanya butuh histori, bukan ambang absolut.

Untuk tiap Component, hitung dari semua sample-nya (urut by sampled_date):

### 1. ARAH (trend direction) — per parameter numerik
- Klasifikasikan: NAIK / STABIL / TURUN berdasarkan 3–4 sample terakhir.
- Tandai "tren naik valid" hanya jika kenaikan konsisten (bukan naik-turun acak).
- Bedakan EVENT dari TREND (lihat aturan di Modul 1).

### 2. KECEPATAN (rate of change) — per parameter yang trennya naik
- Hitung laju kenaikan dinormalisasi ke jam OPERASI: **Δ per 250 jam**
  (atau per meter_on_fluid bila tersedia) — BUKAN per tanggal kalender,
  karena interval sampling bisa tidak seragam.
- Bila threshold terisi → tambahkan **estimasi "berapa sample / jam lagi
  sampai batas waspada"** dengan ekstrapolasi linear.
- Bila threshold kosong → lewati estimasi ini, JANGAN error; cukup tampilkan
  laju mentahnya.

### 3. POLA / SIGNATURE (kombinasi elemen naik bersamaan)
Mapping per Component type (disimpan editable di config, jangan hardcode):

- **ENGINE:**
  - Fe + Cr naik → top-end (ring/liner/valve) → arah **TOH**
  - Pb + Sn + Cu naik → lower-end (bearing) → arah **GOH**
  - Si + Fe naik → kontaminasi debu/abrasif → cek air filter / intake
  - Na/K + water naik → coolant masuk oli → investigasi head gasket / liner
- **GEARBOX:**
  - Fe + pq_index naik → keausan gear / bearing
  - Si naik → kontaminasi / seal bocor
  - water naik → seal / breather
- **TRANSMISSION:**
  - Cu + Al naik → keausan pump / motor
  - water / particle naik → kontaminasi sistem (PRIORITAS TINGGI, hidrostatik sensitif)
  - viscosity drift → degradasi / oli salah
- **FUEL:**
  - water / microbial / particle naik → fuel polishing atau drain & treat tangki

### 4. KEPUTUSAN RANGKUMAN (decision output) — satu status per Component
Hasil gabungan ARAH + KECEPATAN + POLA (tidak wajib butuh threshold):

- 🟢 **MONITOR** — semua stabil/turun → lanjut interval sampling normal
- 🔵 **WATCH** — 1 parameter mulai naik, belum ada pola → catat, pantau
- 🟡 **TIGHTEN SAMPLING** — tren naik valid pada parameter wear → perketat
  interval sampling (mis. 250 → 125 jam) untuk konfirmasi
- 🟠 **PLAN ACTION** — tren naik + pola signature terbaca → tampilkan arah
  tindakan (TOH / GOH / investigasi kontaminasi) + saran mulai siapkan part &
  jadwal (ingat lead time part bisa 1–2 bulan)
- 🔴 **ACT NOW** — laju cepat / kombinasi serius (mis. coolant masuk oli, atau
  wear + kontaminasi bersamaan) → eskalasi

> Threshold absolut, bila terisi, MEMPERTAJAM kategori ini — bukan prasyarat.

### 5. TAMPILAN
- Panel **"Status & Arah"** di halaman tiap Component: badge status rangkuman,
  daftar parameter yang sedang naik (dengan panah arah + laju), dan kalimat
  rekomendasi forward-looking dalam bahasa awam.
  Contoh: *"Fe & Cr tren naik 4 sample terakhir, laju ~5 ppm/250j → indikasi
  keausan ring/liner. Disarankan mulai rencanakan TOH dan siapkan part."*
- Grafik tren multi-parameter (overlay) dengan titik per sample.
- **Bandingkan side-by-side:** rekomendasi Trakindo (per-sample) vs rangkuman
  App (lintas-sample) — agar selisih snapshot vs tren terlihat jelas.
- Bila status 🟠/🔴 → tombol "Buat rencana TOH/GOH" yang nyambung ke
  maintenance card equipment terkait.

**>> CHECKPOINT 2: tunjukkan rancangan LOGIKA perhitungan tren & kategori
keputusan (boleh pseudo-code) untuk direview SEBELUM implementasi penuh.
Hindari logika yang terlalu sensitif (sering false alarm) maupun terlalu cuek.**

---

## PRINSIP WAJIB (berlaku ke seluruh modul)
1. App memberi SINYAL & ARAH; keputusan akhir di manusia. Jangan auto-vonis overhaul.
2. Modul 2 WAJIB jalan walau threshold kosong — andalkan arah & laju dari histori.
3. Normalisasi laju ke jam operasi, bukan tanggal kalender.
4. Semua threshold, mapping pola, kategori keputusan, dan parameter per tipe
   harus EDITABLE (config/DB) agar modul reusable untuk equipment & program lain.
5. Bedakan selalu EVENT (anomali sesaat) dari TREND (berkelanjutan).

## URUTAN KERJA
1. Schema data → **CHECKPOINT 1** → konfirmasi
2. Modul 1A (entry + arsip + tren dasar + tampilan)
3. Modul 1B (struktur threshold, boleh kosong)
4. Logika Decision Engine (pseudo-code) → **CHECKPOINT 2** → konfirmasi
5. Implementasi Modul 2 + panel "Status & Arah"
