-- ============================================================
-- Tambah Downtime event (manual) untuk GS-KB150B-DEUTZ — Rusak Alternator
-- Sumber: Laporan Harian 25-31 Agustus 2026 (gak sempat dibuka sebagai
-- Downtime waktu kejadian — lihat investigasi_gs_kb150b_deutz_alternator.sql
-- buat data mentahnya). Timeline sudah dicross-check via:
--   - window lebih lebar Laporan Harian equipment ini (gak ada entri
--     sebelum 25 Agu, jadi bukan ada kejadian tersembunyi lebih awal)
--   - equipment lain di rig yang sama (BW KB150.B / MR-KB150B) periode
--     yang sama — progres 50% dicatat konsisten hari ke hari (27 & 28
--     Agu), bukan copy-paste. Catatan: FP-KB150B (Fire Pump) juga sempat
--     "alternator tidak cas" tapi itu KEJADIAN TERPISAH (24-26 Agu, cuma
--     3 hari, equipment beda) — jangan ketuker sama yang ini.
--
-- ⚠️ CATATAN: Laporan Harian cuma rekam TANGGAL, bukan jam persis.
-- start_at/end_at di bawah pakai perkiraan 08:00 WIB (mulai kerja) &
-- 16:00 WIB (akhir kerja) di hari pertama/terakhir — GESER JAMNYA kalau
-- lo tau info lebih presisi. Yang penting buat Availability/MTTR adalah
-- durasi harinya (25-31 Agustus = 6 hari), itu sudah captured benar.
-- ============================================================

INSERT INTO downtime_events (
  equipment_id, equipment_tag, equipment_name, unit_id, unit_name,
  lokasi, start_at, end_at, category, notes, part_order_date, wo_number,
  created_by_name
) VALUES (
  (SELECT id FROM equipment WHERE tag_number = 'GS-KB150B-DEUTZ'),
  'GS-KB150B-DEUTZ',
  'Genset Deutz 74.9KW BW KB150.B',
  (SELECT assigned_unit_id FROM equipment WHERE tag_number = 'GS-KB150B-DEUTZ'),
  (SELECT name FROM parent_units WHERE id = (SELECT assigned_unit_id FROM equipment WHERE tag_number = 'GS-KB150B-DEUTZ')),
  'KAG-07 (Kuang-07)',
  '2026-08-25 01:00:00+00',  -- ~08:00 WIB 25 Agu (perkiraan)
  '2026-08-31 09:00:00+00',  -- ~16:00 WIB 31 Agu (perkiraan, saat v-belt alternator terpasang & test running 25.1V ok)
  'breakdown',
  'Rusak alternator (tidak nge-cas). Dicatat manual dari Laporan Harian 25-31 Agustus 2026 (gak dibuka sebagai Downtime waktu itu — hanya tercatat via status kerja CM). Kronologi harian: 25 Agu rusak alternator; 26 Agu masih rusak; 27-28 Agu trouble shooting & perbaikan, progres 50%; 29 Agu masih rusak, unit lain aman; 30 Agu tunggu part; 31 Agu part terpasang, v-belt alternator pakai yang lama (kepanjangan), test running ok 25.1 volt — selesai & normal.',
  '2026-08-30',
  NULL,
  'Abdul Rachman'
);
