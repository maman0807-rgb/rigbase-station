# AIR Tahap 3: Spare Part VIS

Acuan: Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0, Tabel 1. Lanjutan dari `docs/AIR_TAHAP2.md`.

## Keputusan Maman (2026-10-07)
1. `materials.kimap` = No. material SAP. Kolom ini dipakai, tidak dibuat `sap_material_no` baru.
2. **Semua part keluar** dihitung sebagai pemakaian di proyeksi 2 tahun, termasuk Peminjaman dan Permintaan. Pengembalian part dicatat Gudang sebagai stok masuk.
3. Batas usia simpan: Lubricant 24 bulan, Consumable 36 bulan, lainnya 60 bulan (usulan, diatur di `air_config`).

Prinsip: memakai data yang sudah ada (`safety_stock` = stok minimum, `lead_time_days`, `related_equipments`, `cspp_equipment_mapping`, `stock_transactions`). **Kode Logbook tidak diubah.** Logbook hanya membaca dan menulis kolom yang dikenalnya, sehingga kolom baru aman.

## Database: `fase37_air_tahap3.sql`
| Objek | Isi |
|---|---|
| Kolom `materials` | `kelas_vis_override` (V/I/S), `stok_maksimum` |
| `v_material_equipment` | Relasi part ↔ equipment, gabungan `related_equipments` (elemen non-UUID diabaikan) dan `cspp_equipment_mapping` |
| `v_sparepart_vis` | Kelas VIS (otomatis dari criticality equipment terkait + override), status stok (HABIS / **DIPINJAM** / RENDAH / BERLEBIH / AMAN), usia simpan FIFO, pemakaian dan proyeksi 2 tahun, rekomendasi pengadaan, serta flag alert |
| `reservasi_sparepart` | Nomor reservasi SAP per part (status DIAJUKAN/DISETUJUI/DIAMBIL/BATAL) |
| `air_config` | `proyeksi_sparepart_bulan` = 24 (pedoman), `usia_simpan_maks_bulan` (usulan) |

Aturan perhitungan:
- **Kelas otomatis:** terkait equipment SECE/PCE → V, terkait Important → I, selain itu → S.
- **Dipinjam:** stok 0 **dan** ada keluar lewat Input Harian jenis *Peminjaman* sesudah stok masuk terakhir. Begitu ada stok masuk, status kembali normal. Alert "Vital habis" tidak menyala untuk part yang sedang dipinjam.
- **Pemakaian bersih (24 bulan):** keluar dari `dailyLog`, `workOrder`, dan `manual` dikurangi koreksi masuk `dailyLog`/`workOrder` (akibat edit/hapus laporan). Penyesuaian `audit_gudang` tidak dihitung. Rata-rata bulanan dibagi jumlah bulan data yang benar-benar tersedia (maksimal 24).
- **Rekomendasi pengadaan** = kebutuhan 2 tahun + stok minimum − stok.
- **Usia simpan FIFO:** sisa stok dianggap berasal dari penerimaan (masuk manual) terbaru. Kalau riwayat penerimaan tidak menutup stok (stok awal hasil import), dipakai `tgl_masuk` lalu `created_at`, dengan tanda "perkiraan".
- **Alert:** Vital habis, Vital ≤ minimum, Vital tanpa stok minimum, usia simpan lewat batas.

## Uji
- `fase37_air_tahap3_test.sql`: **20 uji** mencakup kelas V/I/S (dua sumber relasi, elemen non-UUID, override, perubahan criticality), habis vs dipinjam vs kembali, Vital di minimum, Vital tanpa minimum, usia FIFO (lewat/tidak/perkiraan), pemakaian bersih (Peminjaman dihitung, koreksi edit dikurangi, audit diabaikan, di luar periode diabaikan), rekomendasi, stok berlebih, dan reservasi.
- Lokal (PGlite): migration lolos dua kali, 20/20 lulus, regresi Tahap 2 28/28 dan Tahap 1 55/55 lulus.
- UI (jsdom): 16/16 lulus, regresi UI Tahap 1 dan 2 lulus.

## UI (eRAMHoist)
1. **CSPP:** panel "🧭 Spare Part VIS" dengan KPI yang bisa diklik (V, Vital habis, Vital ≤ minimum, sedang dipinjam, usia simpan lewat) dan peringatan Vital tanpa stok minimum. Ada filter kelas VIS, kolom VIS dan Usia simpan, serta status 🤝 Dipinjam / 🔵 Di atas maks.
2. **Klik badge VIS:** detail (kelas otomatis, jumlah equipment, pemakaian, kebutuhan) dan edit override + stok maksimum (role gudang ke atas), plus reservasi SAP.
3. **📈 Rekomendasi 2 Tahun:** tabel per part (Vital selalu tampil) dengan export Excel yang memuat estimasi nilai.
4. **RAM → 🧭 AIR:** widget "Spare Part Vital Perlu Tindakan" dengan link ke CSPP.
5. **Panduan:** langkah 8 (Spare Part VIS).

Kalau fase37 belum dijalankan, halaman CSPP tetap berfungsi seperti sebelumnya. Panel VIS hanya tidak muncul.

## Catatan untuk Maman
- Kelas V/I baru akurat setelah **criticality equipment dinilai** (Tahap 1) dan **part dipetakan ke equipment** (Kelola Part Kritis / equipment terkait di Gudang). Part yang belum dipetakan otomatis masuk S.
- Part Vital wajib punya **safety stock** (isi di Gudang Logbook), supaya alert "≤ minimum" bisa bekerja.
