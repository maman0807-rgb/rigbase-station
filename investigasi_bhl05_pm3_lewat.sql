-- ============================================================
-- Investigasi: BHL-05 — PM3 tercatat 24 Sep 2025, tapi sekarang
-- kelihatan "lewat PM" padahal ada perubahan HM di sistem.
-- Jalankan di Supabase SQL Editor, copy-paste HASILNYA balik ke Claude.
-- ============================================================

-- 1) Data equipment sekarang: running_hours, last_pm_hours, last_pm_date,
--    interval, cycle count -- ini yang nentuin status "lewat PM" atau enggak
SELECT id, tag_number, nama_equipment, running_hours, last_pm_hours, last_pm_date,
       pm_type, pm_interval_hours, pm_cycle_count, pm_max_interval_days,
       last_toh_hours, last_goh_hours, updated_at
FROM equipment
WHERE tag_number = 'BHL-05';

-- 2) PM via "Catat PM Selesai" (downtime_events category='pm') -- cek PM3 24 Sep 2025
--    beneran ke-log di sini atau enggak
SELECT start_at, end_at, notes, created_by_name, created_at
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number = 'BHL-05')
  AND category = 'pm'
ORDER BY start_at DESC;

-- 3) Entry dari Laporan Harian (semua status_kerja) sekitar 24 Sep 2025 --
--    cek RH yang diinput hari itu & sekitarnya, siapa tau ada entry PM3
--    tapi RH-nya salah ketik / gak sinkron
SELECT lh.tanggal, e.status_kerja, e.rh, e.job_desc, e.notes
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number = 'BHL-05')
  AND lh.tanggal BETWEEN '2025-09-15' AND '2025-10-05'
ORDER BY lh.tanggal;

-- 4) Jejak audit (activity_log) perubahan HM/running_hours equipment ini --
--    cek kapan & oleh siapa HM-nya diubah, nilai lama vs baru
SELECT created_at, user_name, action, details
FROM activity_log
WHERE entity_id = (SELECT id::text FROM equipment WHERE tag_number = 'BHL-05')
   OR entity_label = 'BHL-05'
ORDER BY created_at DESC
LIMIT 30;

-- 5) Foto HM (approved/pending/rejected) -- cek juga jalur ini kalau HM-nya
--    diupdate lewat Foto HM, bukan Laporan Harian / edit manual
SELECT created_at, hm_value, status, reported_by_name, notes, reviewed_by_name, reviewed_at
FROM hm_photo_reports
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number = 'BHL-05')
ORDER BY created_at DESC
LIMIT 20;
