# SOP Preventive Maintenance PM3 / PM4 / PM5 / PM6
**Fleet Hoist & Heavy Equipment — RAM Field Prabumulih**

> **Status: DRAFT v0.1 (2026-07-31)** — disusun dari praktik standar servis diesel engine industri (Perkins/Caterpillar/Cummins/Deutz), **belum di-review mekanik senior/tim lapangan**. Jangan dipakai sebagai acuan final sebelum di-cek & disahkan. Setelah disahkan, isi checklist part di sini yang jadi dasar input menu **📦 PM Parts** di eRAMHoist.

---

## 1. Prinsip Dasar

Sistem PM di eRAMHoist berjenjang (**escalating/cumulative**) — tiap tier lebih tinggi **mengerjakan SEMUA item tier di bawahnya, DITAMBAH** item baru sesuai kompleksitasnya. Ini bukan 4 servis yang berbeda-beda, tapi 1 servis yang makin dalam cakupannya.

| Tier | Interval (HM) | Kelipatan PM3 | Sifat |
|---|---|---|---|
| **PM3** | 250 | ke-1, 3, 5, 7... | Servis rutin/minor |
| **PM4** | 500 | ke-2, 6, 10... | PM3 + menengah |
| **PM5** | 1000 | ke-4, 12, 20... | PM4 + major |
| **PM6** | 2000 | ke-8, 24, 40... | PM5 + komprehensif (persiapan TOH) |
| **GOH** | 10000 | ke-40 | Overhaul total — **di luar cakupan SOP ini**, lihat `PANDUAN_INTERVAL_HM.md` |

Label PM3-6 ini ditentukan otomatis di eRAMHoist dari **hitungan siklus PM** (`pm_cycle_count`), bukan dari angka HM — jadi tim tinggal lihat badge di Dashboard/tab Maintenance equipment, nggak perlu hitung manual kelipatan mana yang jatuh.

**TOH (Top Overhaul) dan GOH (General Overhaul)** ditangani terpisah dari tier PM3-6 ini — intervalnya beda-beda per kelas engine (Tier A/B/C/D), lihat `PANDUAN_INTERVAL_HM.md`. PM6 di dokumen ini berfungsi sebagai **pemeriksaan komprehensif terakhir sebelum TOH**, bukan pengganti TOH.

---

## 2. PM3 — Servis Rutin (setiap 250 HM)

**Tujuan:** menjaga pelumasan & kebersihan dasar, deteksi dini kebocoran/keausan.

**Checklist kerja:**
- [ ] Ganti oli mesin
- [ ] Ganti filter oli
- [ ] Drain water separator / fuel filter (buang air & kotoran)
- [ ] Cek & bersihkan filter udara (ganti elemen kalau kotor berat)
- [ ] Cek level coolant/air radiator, top up bila kurang
- [ ] Cek kondisi & kekencangan v-belt/fan belt (retak, kendor)
- [ ] Cek kebocoran oli, bahan bakar, coolant (visual di sekeliling mesin)
- [ ] Cek & kencangkan baut-baut kritis (mounting engine, exhaust manifold)
- [ ] Grease/pelumasan titik-titik gemuk (grease nipple)
- [ ] Cek aki: terminal bersih & kencang, level air aki, tegangan
- [ ] Bersihkan sirip radiator dari debu/kotoran
- [ ] Running test: cek tekanan oli & suhu kerja normal
- [ ] Catat hasil di eRAMHoist → **✅ Catat PM Selesai**

**Part/consumable tipikal:** oli mesin, filter oli, grease.

---

## 3. PM4 — Servis Menengah (setiap 500 HM)

**Tujuan:** tambahan dari PM3 — ganti komponen consumable yang siklusnya 2x lebih jarang, mulai cek sistem kelistrikan & pembakaran.

**Checklist kerja (PM3 + tambahan berikut):**
- [ ] *(semua item PM3)*
- [ ] Ganti filter bahan bakar (fuel filter) — bukan cuma drain
- [ ] Ganti elemen filter udara (bukan cuma dibersihkan)
- [ ] Cek & test alternator / charging system (tegangan output saat running)
- [ ] Cek kondisi selang-selang (radiator hose, fuel line) — retak/getas/rembes
- [ ] Cek turbocharger (kalau ada): suara abnormal, kebocoran oli/boost
- [ ] Cek & setel celah klep (valve clearance) — sesuai jadwal OEM engine terkait
- [ ] Analisa oli visual sederhana (warna, kekentalan, ada partikel logam?)
- [ ] Catat hasil di eRAMHoist → **✅ Catat PM Selesai**

**Part/consumable tipikal:** oli mesin, filter oli, filter bahan bakar, filter udara, grease.

---

## 4. PM5 — Servis Major (setiap 1000 HM)

**Tujuan:** tambahan dari PM4 — mulai masuk komponen yang berpengaruh ke performa & efisiensi bahan bakar, ambil sampel oli formal.

**Checklist kerja (PM4 + tambahan berikut):**
- [ ] *(semua item PM4)*
- [ ] Ganti coolant/air radiator total (flush sistem pendingin)
- [ ] Cek & kalibrasi injector (uji tekanan & pola semprot)
- [ ] Ganti oli hidrolik & filter hidrolik (kalau equipment punya sistem hidrolik)
- [ ] Cek kondisi motor starter (arus tarik, kondisi brush)
- [ ] Cek mounting engine (karet/dumper — retak, kendor)
- [ ] Cek sistem exhaust (manifold, muffler, kebocoran gas buang)
- [ ] **Ambil sampel oli untuk SOS Lab** (kirim hasil analisa via modul SOS Lab eRAMHoist)
- [ ] Catat hasil di eRAMHoist → **✅ Catat PM Selesai**

**Part/consumable tipikal:** + coolant, oli hidrolik, filter hidrolik, kit kalibrasi injector.

---

## 5. PM6 — Servis Komprehensif (setiap 2000 HM, pra-TOH)

**Tujuan:** tambahan dari PM5 — pemeriksaan menyeluruh sebagai checkpoint terakhir sebelum equipment masuk jendela TOH, termasuk item preventif yang diganti sebelum benar-benar rusak.

**Checklist kerja (PM5 + tambahan berikut):**
- [ ] *(semua item PM5)*
- [ ] Ganti seluruh belt & hose secara preventif (jangan tunggu sampai rusak)
- [ ] Kalibrasi ulang seluruh injector + fuel pump (bukan cek sebagian seperti PM5)
- [ ] Cek & ganti thermostat
- [ ] Cek sistem kelistrikan menyeluruh (wiring harness, sensor, ECU bila ada)
- [ ] **Wajib** ambil sampel oli SOS Lab + NDT komponen kritis (sesuai jadwal NDT equipment)
- [ ] Evaluasi kondisi umum vs threshold TOH (bandingkan sisa jam ke TOH di eRAMHoist)
- [ ] Dokumentasi foto kondisi komponen utama (untuk rekam jejak sebelum TOH)
- [ ] Catat hasil di eRAMHoist → **✅ Catat PM Selesai**

**Part/consumable tipikal:** + set belt & hose lengkap, thermostat, kit kalibrasi fuel pump.

---

## 6. Cara Pakai di eRAMHoist

1. Dashboard/tab Maintenance equipment menampilkan badge tier (PM3/PM4/PM5/PM6) otomatis + sisa jam.
2. Klik **📦 Siapkan Part** untuk lihat daftar part sesuai tier yang due (ditarik dari menu **PM Parts**, harus diisi admin dulu sesuai checklist di dokumen ini per tier).
3. Setelah PM selesai dikerjakan di lapangan, klik **✅ Catat PM Selesai** — isi HM saat PM, sistem otomatis reset counter & catat siklus berikutnya.

---

## 7. Lembar Pengesahan (isi setelah direview)

| Nama | Jabatan | Tanggal Review | Paraf |
|---|---|---|---|
| | | | |
| | | | |

**Catatan revisi:**
- v0.1 (2026-07-31) — draft awal berdasar standar umum industri, menunggu review lapangan.
