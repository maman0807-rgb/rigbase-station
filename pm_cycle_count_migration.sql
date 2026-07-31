-- Migration: PM cycle counter — dasar baru penentuan label PM3/PM4/PM5/PM6/GOH
-- Sebelumnya label ditentukan dari NILAI HM ABSOLUT (hm % 250 === 0 dst), yang gagal
-- kalau last_pm_hours bukan kelipatan bulat (hampir selalu, karena PM riil jarang persis di grid).
-- Sekarang label ditentukan dari HITUNGAN SIKLUS PM (berapa kali PM sudah dicatat via "Catat PM Selesai"),
-- jadi tetap benar walau HM-nya berapapun.

ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_cycle_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN equipment.pm_cycle_count IS
  'Hitungan siklus PM sejak baseline (increment +1 tiap "Catat PM Selesai", reset ke 0 kalau GOH). '
  'Dipakai getPMTypeByCycle(pm_cycle_count+1) untuk tentukan label PM3/PM4/PM5/PM6/GOH — bukan dari nilai HM absolut.';

-- Backfill: estimasi siklus yang sudah lewat dari data existing (last_pm_hours / interval, dibulatkan)
-- supaya equipment yang HM-nya sudah tinggi TIDAK dianggap "baru mulai dari PM3 lagi".
-- Equipment tanpa last_pm_hours/interval (belum pernah PM) otomatis dapat 0 — itu memang benar (PM pertama = PM3).
UPDATE equipment
SET pm_cycle_count = ROUND(COALESCE(last_pm_hours, 0) / NULLIF(pm_interval_hours, 0))::int
WHERE pm_interval_hours IS NOT NULL AND pm_interval_hours > 0;

NOTIFY pgrst, 'reload schema';
