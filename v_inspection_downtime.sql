-- ============================================================
-- VIEW: v_inspection_downtime
-- Menghitung per siklus inspeksi: apakah rig masih ditahan
-- (semua temuan harus 'Closed' sebelum rig boleh beroperasi)
-- ============================================================
-- Tabel sumber : inspections + inspection_findings + parent_units
-- Dijalankan   : Supabase SQL Editor
-- Aman re-run  : CREATE OR REPLACE VIEW (idempoten)
-- ============================================================
-- ATURAN BISNIS (fail-safe):
--   open_count > 0  → is_holding = true  → rig DITAHAN
--   open_count = 0  → is_holding = false → rig boleh jalan
--   Kesalahan selalu ke arah MENAHAN, bukan melepas.
--   Status 'Closed' case-sensitive (kapital C) — terkunci di CHECK constraint.
-- ============================================================

CREATE OR REPLACE VIEW v_inspection_downtime AS
SELECT
  s.id               AS inspection_id,
  s.parent_unit_id,
  pu.name            AS rig,
  s.inspection_code,
  s.start_date       AS mulai,

  -- Hitung temuan yang belum ditutup (status != 'Closed')
  -- Fail-safe: semua status selain 'Closed' = masih open
  COUNT(f.id) FILTER (WHERE f.status != 'Closed')        AS open_count,

  -- is_holding: true kalau ada satu saja temuan yang belum closed
  (COUNT(f.id) FILTER (WHERE f.status != 'Closed')) > 0  AS is_holding,

  -- selesai: tanggal closing temuan TERAKHIR, hanya kalau semua sudah closed
  -- NULL = masih ada open findings → rig masih ditahan
  CASE
    WHEN COUNT(f.id) FILTER (WHERE f.status != 'Closed') = 0
    THEN MAX(f.tgl_closed)
    ELSE NULL
  END                AS selesai

FROM inspections s
LEFT JOIN inspection_findings f ON f.inspection_id = s.id
LEFT JOIN parent_units pu       ON pu.id = s.parent_unit_id

-- Hanya siklus yang sudah dimulai (bukan jadwal ke depan)
WHERE s.start_date <= CURRENT_DATE

GROUP BY
  s.id,
  s.parent_unit_id,
  pu.name,
  s.inspection_code,
  s.start_date;

-- ============================================================
-- CATATAN EDGE CASE:
-- Siklus 'On Progress' tapi belum ada findings diinput:
--   → open_count = 0, is_holding = false (LEFT JOIN → NULL row, COUNT skip NULL)
-- Ini bisa terjadi di hari pertama inspeksi sebelum temuan dicatat.
-- Kalau perlu nangkap ini, tambahkan:
--   OR (s.status = 'On Progress' AND COUNT(f.id) = 0)
-- Diskusikan ke Abdul apakah perlu atau tidak.
-- ============================================================

-- ============================================================
-- VERIFIKASI — jalankan setelah CREATE VIEW
-- ============================================================

-- 1. Cek view terbentuk
SELECT *
FROM v_inspection_downtime
ORDER BY mulai DESC
LIMIT 20;

-- 2. Cek siklus yang masih menahan rig
SELECT inspection_code, rig, mulai, open_count, selesai
FROM v_inspection_downtime
WHERE is_holding = true
ORDER BY mulai;

-- 3. Cek siklus yang sudah selesai (semua findings closed)
SELECT inspection_code, rig, mulai, selesai,
       ROUND(EXTRACT(EPOCH FROM (selesai::timestamptz - mulai::timestamptz)) / 3600, 1) AS durasi_jam
FROM v_inspection_downtime
WHERE is_holding = false AND selesai IS NOT NULL
ORDER BY selesai DESC;

-- 4. Cross-check: pastikan status 'Closed' yang dipakai benar (kapital C)
SELECT DISTINCT status FROM inspection_findings;
-- Ekspektasi: 'Open' dan 'Closed'

-- ============================================================
-- MAPPING KE events (referensi untuk kode JS di produksi)
-- Setiap baris view → 1 object event untuk hitungRAM()
-- ============================================================
--
-- Di produksi, fetch view lalu map:
--
--   const { data: inspData } = await supabase
--     .from('v_inspection_downtime')
--     .select('*');
--
--   const inspEvents = (inspData || []).map(row => ({
--     id:             row.inspection_id,
--     source:         'inspeksi',             // read-only di UI
--     unitId:         String(row.parent_unit_id),
--     unitName:       row.rig,
--     inspectionCode: row.inspection_code,
--     penyebab:       'Inspeksi Terjadwal',
--     mulai:          row.mulai,
--     selesai:        row.selesai,            // NULL = masih menahan
--     openCount:      row.open_count,
--     catatan:        row.open_count > 0
--                       ? `${row.open_count} temuan masih Open`
--                       : 'Semua temuan Closed',
--   }));
--
--   // Gabung dengan manual events, lalu lempar ke hitungRAM()
--   const allEvents = [...manualEvents, ...inspEvents];
--   const result = hitungRAM(allEvents, periodDays);
--
-- ============================================================
-- ROLLBACK (kalau perlu hapus view):
-- DROP VIEW IF EXISTS v_inspection_downtime;
-- ============================================================
