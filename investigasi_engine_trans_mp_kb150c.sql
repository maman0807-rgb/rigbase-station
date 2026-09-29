-- ============================================================
-- Investigasi: ENGINE-MP-KB150C vs TRANS-MP-KB150C — kenapa "lewat
-- jam" PM-nya beda, padahal harusnya nempel di mudpump yang sama
-- (harusnya jam jalan/HM-nya seiring).
-- Jalankan di Supabase SQL Editor, copy-paste HASILNYA balik ke Claude.
-- ============================================================

-- 1) Data kedua equipment: running_hours, last_pm_hours, interval, parent/child
SELECT tag_number, nama_equipment, running_hours, last_pm_hours, last_pm_date,
       pm_interval_hours, pm_cycle_count, parent_equipment_id, assigned_unit_id,
       (running_hours - last_pm_hours) AS terpakai_sejak_pm,
       pm_interval_hours - (running_hours - last_pm_hours) AS sisa_ke_pm_berikutnya
FROM equipment
WHERE tag_number IN ('ENGINE-MP-KB150C','TRANS-MP-KB150C');

-- 2) Cek apakah salah satu terdaftar sebagai anak "Numpang" di tabel pemasangan
--    (kalau numpang, HM-nya harusnya ngikut induk via cascade trigger, bukan independen)
SELECT p.*, e.tag_number AS anak_tag, i.tag_number AS induk_tag
FROM pemasangan p
LEFT JOIN equipment e ON e.tag_number = p.anak_tag
LEFT JOIN equipment i ON i.id = p.induk_id
WHERE p.anak_tag IN ('ENGINE-MP-KB150C','TRANS-MP-KB150C')
   OR i.tag_number IN ('ENGINE-MP-KB150C','TRANS-MP-KB150C');

-- 3) Riwayat PM (Catat PM Selesai) kedua equipment, 6 bulan terakhir
SELECT equipment_tag, start_at, notes, created_by_name
FROM downtime_events
WHERE equipment_id IN (
    SELECT id FROM equipment WHERE tag_number IN ('ENGINE-MP-KB150C','TRANS-MP-KB150C')
  )
  AND category = 'pm'
  AND start_at >= NOW() - INTERVAL '6 months'
ORDER BY start_at DESC;

-- 4) Riwayat RH dari Laporan Harian kedua equipment, 30 hari terakhir --
--    biar kelihatan apa jam jalannya beneran nempel bareng atau kepisah
SELECT e2.tag_number, lh.tanggal, en.status_kerja, en.rh
FROM laporan_harian_entries en
JOIN laporan_harian lh ON lh.id = en.laporan_id
JOIN equipment e2 ON e2.id = en.equipment_id
WHERE e2.tag_number IN ('ENGINE-MP-KB150C','TRANS-MP-KB150C')
  AND lh.tanggal >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY lh.tanggal, e2.tag_number;
