# Laporan Harian v2: "📋 Tempel Laporan"

Catatan serah terima (2026-10-08) supaya pekerjaan bisa dilanjutkan dari laptop lain.

## Latar belakang
- Tim HHE menyepakati **format rangkuman harian baru** sejak 06/10/2026. Lihat `ERAMHOIST_LAPORAN_HARIAN_V2_PROMPT.md`.
- Perangkum mengirim rangkuman **langsung ke bot Telegram** (chat pribadi, bot yang sama dengan bot alert).
- **n8n tidak dipakai lagi** (dimatikan karena WAHA bermasalah). Akibatnya laporan selama ini harus diketik ulang manual di app.
- Prompt aslinya besar: tabel pekerjaan lintas hari, buffer bot + `/proses`, Daftar Open jam 06.00, dan Claude API. Setelah audit modul yang ada, Maman memilih **opsi A**:

| Opsi | Isi | Status |
|---|---|---|
| **A. Tempel Laporan** | Rangkuman ditempel di app, dibaca parser JS **tanpa AI**, jadi draft Laporan Harian biasa, lalu Simpan Final | **Selesai dibangun & diuji, belum live** |
| B. A + bot | Draft otomatis begitu laporan dikirim ke bot (Supabase Edge Function, tanpa n8n) | Belum |
| C. Prompt penuh | Pekerjaan sebagai data tersendiri lintas hari, Daftar Open pagi, pecah pekerjaan, dll. | Belum |

## Yang dibangun (opsi A)
| File | Isi |
|---|---|
| `js/laporan_harian_v2.js` | Parser murni (UMD: `window.LaporanHarianV2` / `require`). Isinya: normalisasi unit rig + alias, jenis, status, tanggal/jam, meter HM/KM, part, rig stop, validasi flag (`kurang`/`cek`), dan `cocokkanEquipment()` yang hanya mencocokkan kalau kandidatnya jelas. |
| `tests/laporan_harian.test.js` + `tests/fixtures/laporan_2026-10-06.txt` | `node tests/laporan_harian.test.js` → **77/77 lulus** (semua kriteria di Bagian 10 prompt) |
| `fase40_laporan_harian_v2.sql` | **Hanya ADD COLUMN**: `laporan_harian.format_versi`, `status_rig` (jsonb), dan kolom v2 di `laporan_harian_entries` (tipe_v2, jenis, gejala, mulai/selesai_pekerjaan, jam, meter_tipe, rig_stop, pic, no_wo, status_v2/ket/asli, part, flags) |
| `index.html` | Tombol **📋 Tempel Laporan** (pratinjau → Buat Draft), kartu menampilkan kolom v2 (isian kurang ditandai merah), tabel Status Rig, cek isian v2 di Simpan Final, RH: KM tidak masuk ke unit ber-HM, Panduan bagian "📝 Laporan Harian" |

Keputusan desain:
- **Deskripsi bullet → Checklist.** `job_desc` lama disimpan sebagai teks yang dipisah koma, sementara bullet sering mengandung koma. Job desc diisi "jenis – gejala".
- **Jenis → status_kerja lama:** `CM (TS)` → TS, CM → CM, PM → PM, lainnya → Lainnya. Dengan begitu Analisa Laporan, Laporan PLO, dan peringatan "CM/TS tanpa Downtime" tetap jalan.
- **Status rig** disimpan di `laporan_harian.status_rig`, bukan dijadikan entry, supaya statistik per equipment tidak tercemar.
- **Part hanya dicatat.** Stok Gudang tetap dipotong lewat Input Harian Logbook.
- **Simpan Final tetap menyinkronkan RH ke `running_hours`** seperti dulu.
- **Laporan yang sudah FINAL tidak ditimpa** oleh tempelan. Draft di tanggal yang sama boleh diganti setelah konfirmasi.

## Uji yang sudah dijalankan
- Parser: 77/77 lulus.
- UI end-to-end (jsdom, di scratchpad Mac rumah): 25/25 lulus, dan regresi seluruh fitur AIR tetap lulus.

## Langkah melanjutkan
1. **Maman:** jalankan `fase40_laporan_harian_v2.sql` di Supabase SQL Editor.
2. Push ke `main`. Ini harus **setelah** langkah 1, karena daftar Laporan Harian membaca kolom `format_versi`.
3. Uji nyata: tempel laporan 06/10, lalu cek kartu #1/#2. **HM 14200 tertulis di Rig carier dan Tower light** (kemungkinan salah salin), jadi koreksi sebelum final karena RH meng-update HM equipment.
4. Opsi B/C kalau nanti diperlukan.
