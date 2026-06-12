-- ============================================================
-- FASE 16: Alignment dengan Pedoman Pemeliharaan Pertamina EP
-- No. A04-005/PEP23000/2023-S9, 22 Mei 2023
-- Jalankan di Supabase SQL Editor (aman re-run, idempoten)
-- ============================================================

-- ============================================================
-- 1. TAMBAH KOLOM DI equipment
-- ============================================================
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS tanggal_masuk_operasi DATE,
  ADD COLUMN IF NOT EXISTS cof_score             INT DEFAULT NULL
    CHECK (cof_score IS NULL OR cof_score BETWEEN 0 AND 5),
  ADD COLUMN IF NOT EXISTS criticality_level     INT DEFAULT NULL
    CHECK (criticality_level IS NULL OR criticality_level BETWEEN 1 AND 4),
  ADD COLUMN IF NOT EXISTS target_mtbf_hours     FLOAT DEFAULT NULL;

COMMENT ON COLUMN equipment.tanggal_masuk_operasi IS 'Tanggal alat mulai beroperasi — basis denominator Availability (bukan tanggal pembelian)';
COMMENT ON COLUMN equipment.cof_score            IS 'Consequence of Failure: 0=Negligible, 1=Minor, 2=Moderate, 3=Significant, 4=Major, 5=Catastrophic';
COMMENT ON COLUMN equipment.criticality_level    IS 'Criticality Level hasil Risk Matrix (PoF x CoF): 1=Low, 2=Medium, 3=High, 4=Extreme';
COMMENT ON COLUMN equipment.target_mtbf_hours    IS 'Target MTBF dalam jam — dasar assessment keandalan equipment';

-- ============================================================
-- 2. TABEL RCA (Root Cause Analysis)
-- ============================================================
CREATE TABLE IF NOT EXISTS rca_records (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id            UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  downtime_event_id       UUID REFERENCES downtime_events(id) ON DELETE SET NULL,
  failure_date            DATE NOT NULL,
  failure_description     TEXT NOT NULL,
  -- 5-Whys
  why_1  TEXT, why_2  TEXT, why_3  TEXT, why_4  TEXT, why_5  TEXT,
  root_cause              TEXT,
  -- Tindakan
  corrective_action       TEXT,
  pic_action              TEXT,
  target_verification_date DATE,
  actual_verification_date DATE,
  -- Status
  status                  TEXT NOT NULL DEFAULT 'Open'
    CHECK (status IN ('Open','In Progress','Verified')),
  -- Metadata
  created_by              UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rca_equipment ON rca_records(equipment_id);
CREATE INDEX IF NOT EXISTS idx_rca_status    ON rca_records(status);
CREATE INDEX IF NOT EXISTS idx_rca_date      ON rca_records(failure_date DESC);

DROP TRIGGER IF EXISTS trg_rca_updated_at ON rca_records;
CREATE TRIGGER trg_rca_updated_at
  BEFORE UPDATE ON rca_records
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 3. RLS: rca_records
-- ============================================================
ALTER TABLE rca_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rca_auth" ON rca_records;
CREATE POLICY "rca_auth" ON rca_records
  FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- ============================================================
-- 4. VERIFIKASI
-- ============================================================
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'equipment'
  AND column_name IN ('tanggal_masuk_operasi','cof_score','criticality_level','target_mtbf_hours')
ORDER BY column_name;
-- Ekspektasi: 4 baris

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'rca_records';
-- Ekspektasi: 1 baris
