-- ============================================================
-- Investigasi: kenapa MR-KB150B & BW-100A gak muncul di baris SKPI
-- (Annual Maintenance Calendar, Per Urgency).
-- Kemungkinan penyebab (lihat renderMaintenanceCalendar()):
--   1) skpi_end_date kosong/NULL di equipment-nya
--   2) skpi_end_date-nya di luar window kalender (harus <=365 hari lagi
--      ATAU maks 30 hari udah lewat expired -- di luar itu gak dianggap
--      "urgent", jadi gak dipush ke events)
--   3) equipment-nya sendiri gak ketemu / typo tag
-- Jalankan di Supabase SQL Editor, copy-paste hasilnya balik ke Claude.
-- ============================================================

SELECT tag_number, nama_equipment, status_operasi,
       skpi_end_date, tgl_expired_sertifikat,
       (skpi_end_date - CURRENT_DATE) AS hari_lagi_skpi
FROM equipment
WHERE tag_number ILIKE '%KB150B%' OR tag_number ILIKE '%100A%'
   OR nama_equipment ILIKE '%KB150B%' OR nama_equipment ILIKE '%100A%'
ORDER BY tag_number;
