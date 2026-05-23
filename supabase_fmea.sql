-- ============================================================
-- FMEA — Failure Mode & Effects Analysis (Phase 1)
-- Jalankan di Supabase SQL Editor. Idempoten.
-- Akses: Sr Mekanik ke atas. RPN = severity × occurrence × detection (auto).
-- ============================================================

CREATE TABLE IF NOT EXISTS fmea_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id   UUID REFERENCES equipment(id) ON DELETE CASCADE,
  equipment_tag  TEXT,           -- snapshot
  equipment_name TEXT,           -- snapshot
  fungsi         TEXT,           -- fungsi komponen
  failure_mode   TEXT NOT NULL,  -- mode kegagalan
  effect         TEXT,           -- efek kegagalan
  cause          TEXT,           -- penyebab
  severity       INT NOT NULL CHECK (severity   BETWEEN 1 AND 10),
  occurrence     INT NOT NULL CHECK (occurrence BETWEEN 1 AND 10),
  detection      INT NOT NULL CHECK (detection  BETWEEN 1 AND 10),
  rpn            INT GENERATED ALWAYS AS (severity * occurrence * detection) STORED,
  recommended_action TEXT,
  pic            TEXT,
  status         TEXT DEFAULT 'open' CHECK (status IN ('open','in_progress','closed')),
  notes          TEXT,
  created_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fmea_equipment ON fmea_entries(equipment_id);
CREATE INDEX IF NOT EXISTS idx_fmea_rpn       ON fmea_entries(rpn DESC);

DROP TRIGGER IF EXISTS trg_fmea_updated_at ON fmea_entries;
CREATE TRIGGER trg_fmea_updated_at BEFORE UPDATE ON fmea_entries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE fmea_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fmea_all" ON fmea_entries;
CREATE POLICY "fmea_all" ON fmea_entries
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

-- ============================================================
-- SELESAI. RPN dihitung otomatis oleh DB (generated column).
-- ============================================================
