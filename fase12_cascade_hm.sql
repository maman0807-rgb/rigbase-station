-- ============================================================
-- FASE 12 — Auto-Cascade HM dari Parent ke Child Equipment
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Problem: Saat tim entry HM untuk MOBENG (parent engine), TRANS
-- (child transmisi) tidak ikut update padahal mereka secara fisik
-- jalan bareng (driven by same engine).
--
-- Solusi:
-- 1. Flag follow_parent_hm (boolean) per equipment, default FALSE
-- 2. PostgreSQL trigger: kalau parent equipment HM update → cascade
--    ke semua child yg follow_parent_hm = TRUE
-- 3. Bulk activate untuk kategori Primover (TRANS/DW yg child Engine)
-- ============================================================

-- 1. Column flag opt-in
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS follow_parent_hm BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN equipment.follow_parent_hm IS
  'Kalau TRUE, saat parent equipment HM update → child ini auto-sync. Cocok untuk TRANS/DW yg driven by parent engine.';

-- 2. Trigger function — cascade HM ke children
CREATE OR REPLACE FUNCTION cascade_hm_to_children()
RETURNS TRIGGER AS $$
DECLARE
  affected INT;
BEGIN
  -- Cascade hanya kalau running_hours benar-benar berubah
  IF NEW.running_hours IS DISTINCT FROM OLD.running_hours THEN
    UPDATE equipment
    SET running_hours = NEW.running_hours,
        updated_at    = NOW()
    WHERE parent_equipment_id = NEW.id
      AND follow_parent_hm = TRUE
      AND id != NEW.id; -- safety: jangan self-update
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected > 0 THEN
      RAISE NOTICE 'cascade_hm: % child equipment di-sync ke HM %', affected, NEW.running_hours;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger di equipment table
DROP TRIGGER IF EXISTS trg_cascade_hm ON equipment;
CREATE TRIGGER trg_cascade_hm
  AFTER UPDATE OF running_hours ON equipment
  FOR EACH ROW
  EXECUTE FUNCTION cascade_hm_to_children();

-- 4. Bulk enable untuk kategori Primover (TRANS-* dan DW-*)
-- Sebagian besar TRANS adalah transmisi dari engine → wajib follow.
-- Bisa override per-unit nanti via UI.
UPDATE equipment
SET follow_parent_hm = TRUE
WHERE parent_equipment_id IS NOT NULL
  AND follow_parent_hm = FALSE
  AND (
    tag_number ILIKE 'TRANS%'        -- transmission
    OR tag_number ILIKE 'DW-%'       -- drawwork
    OR tag_number ILIKE 'GS-%-ENG%'  -- genset engine (kalau child)
  );

-- Verifikasi:
-- SELECT tag_number, follow_parent_hm, parent_equipment_id
-- FROM equipment
-- WHERE follow_parent_hm = TRUE
-- ORDER BY tag_number;

-- Lihat berapa unit yg ter-activate:
-- SELECT COUNT(*) AS cascaded FROM equipment WHERE follow_parent_hm = TRUE;
