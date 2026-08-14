-- ============================================================
-- Fix bug fase23: ALTER TABLE ... DEFAULT 'pending' otomatis ngisi
-- SEMUA baris lama jadi 'pending' (bukan NULL), jadi UPDATE backfill
-- di fase23 nggak ngefek. Reset semua yang 27 baris jadi 'approved'
-- (data historis sebelum fitur approval ini ada, sengaja diloloskan).
-- ============================================================

UPDATE hm_photo_reports
SET status = 'approved'
WHERE status = 'pending';

-- Verifikasi — harusnya 0 pending sekarang
SELECT status, COUNT(*) FROM hm_photo_reports GROUP BY status;
