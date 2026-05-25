-- ============================================================
-- AVAILABILITY — catatan downtime equipment (Phase 1)
-- Jalankan di Supabase SQL Editor. Idempoten. Akses: Sr Mekanik ke atas.
-- Availability dihitung di app dari data ini (durasi auto).
-- ============================================================

CREATE TABLE IF NOT EXISTS downtime_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id   UUID REFERENCES equipment(id) ON DELETE CASCADE,
  equipment_tag  TEXT,
  equipment_name TEXT,
  unit_id        INT REFERENCES parent_units(id) ON DELETE SET NULL,  -- rig (snapshot)
  unit_name      TEXT,
  start_at       TIMESTAMPTZ NOT NULL,
  end_at         TIMESTAMPTZ,                 -- NULL = masih down
  category       TEXT CHECK (category IN ('breakdown','troubleshoot','tunggu_spare','pm','mobilisasi','lainnya')),
  notes          TEXT,
  -- durasi jam (otomatis; NULL kalau belum selesai)
  duration_hours NUMERIC GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (end_at - start_at)) / 3600.0) STORED,
  created_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_downtime_equipment ON downtime_events(equipment_id);
CREATE INDEX IF NOT EXISTS idx_downtime_start     ON downtime_events(start_at DESC);
CREATE INDEX IF NOT EXISTS idx_downtime_open      ON downtime_events(end_at) WHERE end_at IS NULL;

DROP TRIGGER IF EXISTS trg_downtime_updated_at ON downtime_events;
CREATE TRIGGER trg_downtime_updated_at BEFORE UPDATE ON downtime_events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE downtime_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "downtime_all" ON downtime_events;
CREATE POLICY "downtime_all" ON downtime_events
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

-- ============================================================
-- SELESAI. duration_hours dihitung otomatis oleh DB.
-- ============================================================
