-- ============================================================
-- Investigasi: kenapa gap HM Tower Light BW KB150.A (TL-KB150A)
-- sistem 1.418,2 jam vs foto 8.939 jam begitu besar?
-- Jalankan semua, copy-paste HASILNYA (semua tabel) balik ke Claude.
-- ============================================================

-- 1) Data equipment saat ini + kapan terakhir di-update
SELECT id, tag_number, nama_equipment, running_hours, last_pm_hours, last_pm_date,
       pm_type, pm_interval_hours, pm_cycle_count, created_at, updated_at, created_by, updated_by
FROM equipment
WHERE tag_number = 'TL-KB150A';

-- 2) Semua jejak audit (activity_log) yang pernah nyentuh equipment ini --
--    termasuk siapa yang create/update dan kapan, isi running_hours lama/baru kalau ada
SELECT created_at, user_name, action, entity_label, details
FROM activity_log
WHERE entity_id = (SELECT id::text FROM equipment WHERE tag_number = 'TL-KB150A')
   OR entity_label = 'TL-KB150A'
ORDER BY created_at;

-- 3) Semua Foto HM (semua status, bukan cuma pending) buat unit ini
SELECT created_at, hm_value, status, reported_by_name, notes, reviewed_by_name, reviewed_at
FROM hm_photo_reports
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number = 'TL-KB150A')
ORDER BY created_at;

-- 4) Maintenance log manual (jalur lama "+ Tambah")
SELECT maintenance_date, maintenance_type, pic_mechanic, notes, created_at
FROM maintenance_log
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number = 'TL-KB150A')
ORDER BY maintenance_date;

-- 5) PM via "Catat PM Selesai" (downtime_events category='pm')
SELECT start_at, end_at, notes, created_by_name, created_at
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE tag_number = 'TL-KB150A')
  AND category = 'pm'
ORDER BY start_at;

-- 6) Entry dari Laporan Harian (status_kerja apapun, bukan cuma PM) buat unit ini
SELECT lh.tanggal, e.status_kerja, e.rh, e.job_desc, e.notes
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number = 'TL-KB150A')
ORDER BY lh.tanggal;
