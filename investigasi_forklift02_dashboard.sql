-- ============================================================
-- Investigasi: kenapa FORKLIFT-02 gak muncul di Dashboard eRAMHoist
-- (widget PM Berbasis Jam/KM, Mendekati Maintenance, dll).
-- Jalankan di Supabase SQL Editor, copy-paste HASILNYA balik ke Claude.
-- ============================================================

SELECT id, tag_number, nama_equipment, status_operasi, assigned_unit_id, kategori_id,
       running_hours, pm_type, pm_interval_hours, last_pm_hours, last_pm_date,
       toh_interval_hours, goh_interval_hours, pm_max_interval_days
FROM equipment
WHERE tag_number ILIKE '%FORKLIFT%' OR tag_number ILIKE '%FORKLIP%'
   OR nama_equipment ILIKE '%FORKLIFT%' OR nama_equipment ILIKE '%FORKLIP%';
