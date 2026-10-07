# AIR Tahap 4C: Laporan Kinerja AIR Bulanan (KPI + SAMBAL)

Acuan: Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0. Materi monev kinerja AIR dikirim Regional ke SHU paling lambat **tanggal 12** setiap bulan (AIMS). KPI yang tidak tercapai wajib dijelaskan dengan **SAMBAL**: Siapa, Apa, Mengapa, Bagaimana, Aksi Lanjut.

## Keputusan Maman (2026-10-08)
- **Tahap 4B (penundaan PM + MOC) di-HOLD.** Aplikasi masih dipakai sebatas fungsi sendiri, dan alur persetujuan Risk Owner belum relevan.
- Sertifikasi personil masih ditunda.

## Database: `fase39_air_tahap4c.sql`
| Objek | Isi |
|---|---|
| `kpi_air` | 14 KPI (9 otomatis, 5 manual). Target berupa **usulan**, bisa diubah admin. Ada `arah` MIN (≥) / MAX (≤) dan target NULL untuk KPI yang hanya informasi. |
| `kpi_air_realisasi` | Nilai per bulan + detail perhitungan + SAMBAL. `target_saat_itu` dibekukan. `tercapai` dihitung trigger. Terkunci kalau laporan FINAL. |
| `laporan_air_bulanan` | Status DRAFT/FINAL per bulan. Tidak bisa FINAL kalau ada KPI tidak tercapai yang SAMBAL-nya belum lengkap. |
| `air_kpi_hitung(periode, unit[])` | Hitung KPI otomatis **per akhir bulan** dari riwayat penilaian. Bisa dibatasi ke daftar unit (untuk uji / per rig ke depan). |
| `air_kpi_isi_otomatis(periode, unit[])` | Simpan hasil hitung ke realisasi tanpa menyentuh SAMBAL/catatan (SECURITY INVOKER, RLS tetap berlaku). |

KPI otomatis:
- **PENILAIAN**: % equipment dalam lingkup yang sudah dinilai criticality dan integrity.
- **INTEG_VITAL**: % peralatan SECE/PCE yang berstatus High/Medium.
- **IZIN**: % izin aktif yang belum kedaluwarsa.
- **AO / MTBF / MTTR**: rumus sama dengan halaman Availability (gejala tidak dihitung, periode per alat dari tanggal masuk operasi).
- **FAIL_REC**: % breakdown/troubleshoot yang lengkap failure mode/cause-nya.
- **RCA_TELAT**: tindak lanjut RCA yang lewat due date.
- **SP_VITAL**: part Vital habis (snapshot saat dihitung).

KPI manual: realisasi anggaran, pembenahan SAP, PM sesuai jadwal, insiden keselamatan, insiden lingkungan.

## Uji
- `fase39_air_tahap4c_test.sql`: **20 uji** memakai bulan fiktif Jan 2020 + filter unit uji, jadi data asli tidak ikut. Mencakup semua KPI otomatis dengan angka yang dicocokkan manual (Ao 98,40 / MTBF 921 / MTTR 15), riwayat bulan berikutnya tidak ikut, isi ulang tidak menghapus SAMBAL, FINAL ditolak tanpa SAMBAL, FINAL terkunci lalu dibuka kembali, dan periode mendatang ditolak.
- Lokal (PGlite): lolos dua kali, 20/20, regresi Tahap 1–4A lulus (55+28+20+25).
- UI (jsdom): 16/16, regresi semua UI lulus.

## UI
1. **RAM → 📊 Laporan AIR** (admin & manager; role lain hanya lihat): pilih bulan, 🔄 Hitung KPI otomatis, input KPI manual, SAMBAL per KPI tidak tercapai, ✅ Finalkan / ↩ Buka kembali, 🖨 Cetak berkop surat (KPI + SAMBAL + ringkasan kondisi), 📊 Excel, ⚙️ Target KPI (admin), dan hitung mundur batas tanggal 12.
2. **Pengingat**: item "Finalkan Laporan AIR <bulan lalu>" di Daftar Kerja dan banner Dashboard sampai laporan final (merah kalau terlambat).
3. **Panduan**: langkah 10.

Reminder Telegram belum dibuat karena butuh deploy Edge Function. Untuk sementara pengingat cukup lewat banner Dashboard.
