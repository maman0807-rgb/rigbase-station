-- ============================================================
-- Fix: hapus duplikat "PM3 Selesai" (4x, seharusnya 1x) di
-- TRANS-H35KD (Transmisi Rig BW H35KD), tercatat 12 Agu 2026.
-- ============================================================

-- 1) LIHAT DULU — pastikan ini equipment & record yang benar
SELECT id, tag_number, nama_equipment, running_hours, last_pm_hours, pm_cycle_count
FROM equipment
WHERE nama_equipment = 'Transmisi Rig BW H35KD';

SELECT id, equipment_tag, category, start_at, end_at, notes, created_at
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE nama_equipment = 'Transmisi Rig BW H35KD')
  AND category = 'pm'
  AND notes LIKE 'PM3 3562 HM selesai%'
ORDER BY created_at;
-- harusnya muncul 4 baris kembar — catat urutannya

-- 2) HAPUS — sisakan cuma 1 (yang paling awal/created_at pertama), hapus 3 sisanya
DELETE FROM downtime_events
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) AS rn
    FROM downtime_events
    WHERE equipment_id = (SELECT id FROM equipment WHERE nama_equipment = 'Transmisi Rig BW H35KD')
      AND category = 'pm'
      AND notes LIKE 'PM3 3562 HM selesai%'
  ) t
  WHERE rn > 1
);

-- 3) VERIFIKASI — harus tinggal 1 baris
SELECT id, start_at, end_at, notes, created_at
FROM downtime_events
WHERE equipment_id = (SELECT id FROM equipment WHERE nama_equipment = 'Transmisi Rig BW H35KD')
  AND category = 'pm'
  AND notes LIKE 'PM3 3562 HM selesai%';

-- ============================================================
-- 4) CEK pm_cycle_count — kalau ke-klik 4x, cycle_count equipment ini
-- kemungkinan ikut naik 4x (harusnya cuma +1 dari 1 kali PM asli).
-- Jalankan query di langkah (1) lagi, lihat pm_cycle_count sekarang.
-- KALAU memang naik 4x lebih dari seharusnya, koreksi manual:
-- (GANTI <nilai_benar> dengan angka yang seharusnya sebelum jalankan)
-- ============================================================
-- UPDATE equipment SET pm_cycle_count = <nilai_benar>
-- WHERE nama_equipment = 'Transmisi Rig BW H35KD';
