# AIR Tahap 4A: Siklus Hidup Aset (Izin Operasi, RLA + LCCA, Decommissioning)

Acuan: Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0. Tahap 4 dipecah menjadi 4A (siklus hidup), 4B (penundaan PM + MOC), dan 4C (laporan bulanan & KPI).

## Keputusan Maman (2026-10-07)
- Tahap 4 dipecah 4A → 4B → 4C.
- Data SKPI/sertifikat lama dipindah ke `izin_operasi`. Kolom lama di `equipment` **tetap terisi otomatis** dari izin terbaru, sehingga dashboard, kalender, export, dan alert Telegram harian (`daily-alert-check`) tidak perlu diubah.
- Tombol Hapus equipment tetap ada untuk salah input. Unit yang punya riwayat diarahkan ke Decommissioning.
- Jenis izin dibuat sebagai daftar referensi (`ref_jenis_izin`) yang bisa ditambah: SKPI, PLO, COI, KHI, COC, Load Test, NDT, Lainnya.
- Risk Owner (no. 5) dan sertifikasi personil (no. 6) ditunda.

## Database: `fase38_air_tahap4a.sql`
| Objek | Isi |
|---|---|
| `ref_jenis_izin`, `izin_operasi` | Riwayat izin per unit (nomor, penerbit, terbit, kedaluwarsa, lampiran) |
| Trigger `trg_air_after_izin` | Mengisi kolom lama: SKPI → `nomor_skpi`/`skpi_*`, COC → `coc_number`, izin lain (selain SKPI/COC/PLO, terbaru per jenis, yang paling cepat habis) → `nomor_sertifikat_lain`/`tgl_*_sertifikat`/`lembaga_penerbit` |
| Migrasi satu kali | SKPI, COC, dan "sertifikat lain" (jenis LAINNYA, bisa diubah) dari kolom lama. Idempoten. |
| `v_izin_operasi` | Status: KEDALUWARSA / AKAN_HABIS (≤60 hari) / BERLAKU / TANPA_BATAS, plus flag `terbaru` |
| `rla_assessment`, `rla_tindakan` | Hasil RLA + tindak lanjut rekomendasi. Trigger mengisi `equipment.sisa_umur_layan_sampai`, `rla_tgl_berikutnya`, `rla_kesimpulan`. Kesimpulan bersyarat/tidak layak membuat `integrity_assessment` DRAFT (MEDIUM/LOW, sumber RLA). |
| `v_biaya_pemeliharaan_tahunan` | Biaya per unit per tahun dari Input Harian Logbook (manpower/part/transport/vendor, tanpa Peminjaman/Permintaan). Bahan LCCA. |
| Kolom decommission di `equipment` | `decommission_tgl`, `decommission_ref`, `decommission_catatan` |
| `air_decommission_blockers()` | Downtime terbuka, RCA belum Closed (termasuk lewat `equipment_ids`), WO Logbook terbuka, reservasi aktif, tindak lanjut RLA terbuka, komponen yang masih aktif |
| Trigger `trg_air_guard_decommission` | Menolak DECOMMISSIONED kalau masih ada penghalang atau tanpa dokumen. Kalau lolos, `status_operasi` di-set ke Scrap. |
| `air_equipment_punya_riwayat()` | Dipakai UI sebelum Hapus |
| `v_air_lifecycle_alert` | Izin kedaluwarsa/≤60 hari, batas layan & jadwal RLA ≤90 hari (unit decommissioned tidak ikut) |

## Uji
- `fase38_air_tahap4a_test.sql`: **25 uji**. Lokal (PGlite): migration lolos dua kali, migrasi data lama dicek (isian kosong diabaikan, tidak dobel), 25/25 lulus, regresi Tahap 1–3 (55+28+20) lulus.
- UI (jsdom): 21/21 lulus, termasuk fallback kalau fase38 belum dijalankan. Regresi UI Tahap 1–3 dan Daftar Kerja lulus.

## UI
1. **Tab 📜 Sertifikasi**: daftar izin per jenis (aktif + riwayat), status, tombol + Tambah / + Perpanjang / Edit / Hapus (admin & manager). Refurbish & load test tetap tampil.
2. **Form Edit**: field SKPI/COC/sertifikat lain dihapus dari bagian E (dikelola di tab Sertifikasi). Refurbish tetap ada.
3. **Tab 🧭 AIR**: banner izin bermasalah, kartu **Umur Layan (RLA)** (+ Catat RLA, tindak lanjut bisa dicentang), kartu **Biaya Pemeliharaan per Tahun**, tombol **🗄️ Decommission** (admin), dan banner arsip untuk unit decommissioned.
4. **Hapus equipment**: unit yang punya riwayat dialihkan ke Decommission. Hapus massal melewati unit yang punya riwayat.
5. **RAM → 🧭 AIR**: widget **Izin Operasi & Umur Layan**. Daftar Kerja mendapat item **Perpanjang izin operasi kedaluwarsa**.
6. **Panduan**: langkah 9.
