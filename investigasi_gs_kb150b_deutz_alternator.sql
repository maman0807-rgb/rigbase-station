-- ============================================================
-- Investigasi: GS-KB150B-DEUTZ — kapan alternator rusak & kapan selesai
-- Dicek dari 2 sumber: Availability (downtime_events) & Laporan Harian
-- (laporan_harian_entries). Jalankan semua di Supabase SQL Editor,
-- copy-paste HASILNYA (semua tabel) balik ke Claude.
-- ============================================================

-- 0) Pastikan tag equipment persis apa (jaga-jaga kalau typo/beda dikit)
SELECT id, tag_number, nama_equipment, status_operasi, running_hours
FROM equipment
WHERE tag_number ILIKE '%KB150B%DEUTZ%' OR nama_equipment ILIKE '%KB150B%DEUTZ%';

-- 1) Semua Downtime events (Availability) untuk unit ini, cari yang nyebut "alternator"
--    di notes/keterangan apapun kategorinya
SELECT start_at, end_at, category, notes, wo_number, part_order_date, created_by_name, created_at
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
  AND (notes ILIKE '%alternator%' OR notes ILIKE '%altenator%')
ORDER BY start_at;

-- 2) Semua Downtime events untuk unit ini (semua kategori, tanpa filter kata kunci) —
--    buat cross-check kalau kata "alternator" gak ketulis persis di notes
SELECT start_at, end_at, category, notes, wo_number, created_by_name
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
ORDER BY start_at;

-- 3) Laporan Harian — entry yang nyebut "alternator" di job_desc/notes
SELECT lh.tanggal, e.status_kerja, e.rh, e.job_desc, e.notes, e.checklist
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
  AND (e.job_desc ILIKE '%alternator%' OR e.notes ILIKE '%alternator%' OR e.checklist::text ILIKE '%alternator%')
ORDER BY lh.tanggal;

-- 4) Laporan Harian — semua entry CM/TS untuk unit ini (cross-check kalau kata kunci meleset)
SELECT lh.tanggal, e.status_kerja, e.rh, e.job_desc, e.notes
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
  AND e.status_kerja IN ('CM','TS')
ORDER BY lh.tanggal;

-- ============================================================
-- LANJUTAN — Maman ragu beneran 6 hari, cek ulang semua kegiatan
-- di lokasi Kuang-07 & genset yang dimaksud (2026-09-23)
-- ============================================================

-- 5) SEMUA entry Laporan Harian equipment ini (apapun status_kerja-nya, bukan cuma CM/TS),
--    window lebih lebar biar keliatan konteks sebelum & sesudahnya
SELECT lh.tanggal, e.status_kerja, e.rh, e.job_desc, e.notes
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
  AND lh.tanggal BETWEEN '2026-08-20' AND '2026-09-05'
ORDER BY lh.tanggal;

-- 6) Downtime events yang lokasinya nyebut "Kuang" — jaga-jaga kalau kejadian ini
--    udah pernah tercatat di Downtime tapi equipment_id-nya beda/kosong/salah pilih
SELECT equipment_id, equipment_tag, equipment_name, start_at, end_at, category, lokasi, notes
FROM downtime_events
WHERE lokasi ILIKE '%kuang%'
ORDER BY start_at DESC
LIMIT 50;

-- 7) Semua entry Laporan Harian equipment LAIN di rig/unit yang sama (BW KB150.B) selama
--    periode ini — buat cross-check kegiatan di lokasi Kuang-07 & genset yang dimaksud
SELECT e2.tag_number, e2.nama_equipment, lh.tanggal, en.status_kerja, en.job_desc, en.notes
FROM laporan_harian_entries en
JOIN laporan_harian lh ON lh.id = en.laporan_id
JOIN equipment e2 ON e2.id = en.equipment_id
WHERE en.equipment_id IN (
    SELECT id FROM equipment
    WHERE assigned_unit_id = (SELECT assigned_unit_id FROM equipment WHERE tag_number ILIKE '%KB150B%DEUTZ%' LIMIT 1)
  )
  AND lh.tanggal BETWEEN '2026-08-24' AND '2026-09-01'
ORDER BY lh.tanggal, e2.tag_number;
