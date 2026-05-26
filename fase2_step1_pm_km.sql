-- ============================================================
-- eRAMHoist Fase 2 - STEP 1: Allow pm_type='km'
-- Untuk Kendaraan, Damkar, Slickline truck (12 unit).
-- Jalankan di Supabase SQL Editor sekali.
-- ============================================================

ALTER TABLE equipment DROP CONSTRAINT IF EXISTS equipment_pm_type_check;
ALTER TABLE equipment ADD  CONSTRAINT equipment_pm_type_check
  CHECK (pm_type IN ('hours','time','km'));

-- Verifikasi
SELECT pm_type, COUNT(*) FROM equipment GROUP BY pm_type ORDER BY pm_type;
-- harusnya: hours=banyak, (km=0 dulu - akan di-PATCH Chanis via REST)
