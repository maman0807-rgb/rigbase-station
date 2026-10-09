# n8n "Harian v2 (tanpa Claude)": kode node

Workflow n8n **Laporan Harian** (Telegram → draft eRAMHoist) versi baru. Langkah **Claude API diganti pembaca laporan JS** yang sama dengan app (`js/laporan_harian_v2.js`, 98 tes). Hasilnya gratis, hasil baca selalu sama, dan draft langsung mengisi **form Laporan Harian format baru** (status rig + kolom pekerjaan).

File workflow yang di-import ke n8n (`Harian_v2_tanpa_Claude.json`) **tidak di-commit**, karena berisi chat ID dan ID kredensial n8n. Folder ini hanya menyimpan kode node sebagai arsip.

| File | Node di n8n | Isi |
|---|---|---|
| `1_code_in_javascript_PARSE.js` | Code in JavaScript | Membaca pesan (membuang `/laporan`) dengan parser. Penanda `/*PARSER*/` diganti isi `js/laporan_harian_v2.js`. |
| `2_code_in_javascript1_ENTRIES.js` | Code in JavaScript1 | Hasil baca → baris `laporan_harian_entries` (kolom lama + baru) + teks balasan bot |
| `3_siapkan_header.js` | Siapkan Header (baru) | Kolom header `laporan_harian` (format_versi v2, status_rig) untuk auto-map |
| `4_code_in_javascript2_ROWS.js` | Code in JavaScript2 | Tambahkan `laporan_id` ke tiap baris |
| `5_normalize_cek_existing.js` | Normalize Cek Existing | Ada laporan tanggal ini? (id + status) |
| `6_siapkan_gabungan.js` | Siapkan Gabungan (baru) | Laporan terpotong 2 pesan / terkirim ulang → hanya pekerjaan yang belum ada (nomor + nama) yang ditambahkan |
| `7_pecah_baris_gabungan.js` | Pecah Baris Gabungan (baru) | Satu item per baris → Create a row1 |

Alur: Telegram Trigger → Filter (chat ID + `/laporan`) → Ambil Data Equipment → Edit Fields → Aggregate → **Code (parse)** → **Code1 (entries)** → Cek Laporan Existing (tanggal sama) → If:
- **belum ada** → **Siapkan Header** → Create a row (auto-map) → Code2 → Create a row1 → Send a text message (ringkasan)
- **sudah ada** → **Sudah Final?**
  - final → *Balas: Laporan Sudah Final* (tidak diubah)
  - draft → **Ambil Entry Existing** → **Siapkan Gabungan** → **Ada yang ditambah?** → ya: *Pecah Baris Gabungan* → Create a row1 → Send ("➕ Digabung …") / tidak: *Balas: Tidak Ada yang Baru*

Ini menangani laporan yang terpotong Telegram jadi 2 pesan: bagian ke-2 juga diawali `/laporan` dan mengulang judul/tanggal. Parser juga membaca blok bernomor walau baris "B. PEKERJAAN" tidak ada. Simulasi 6 skenario: 11/11 lulus.

Kalau aturan parser di repo berubah, salin ulang isi `js/laporan_harian_v2.js` ke node *Code in JavaScript* di n8n, di posisi `/*PARSER*/`.
