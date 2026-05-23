-- ============================================================
-- STRESS SCORE (Mobilisasi) — Phase 1 schema
-- Jalankan di Supabase SQL Editor (project yang sama). Idempoten.
-- Konsep: skor dihitung 1x per perpindahan rig, lalu di-SNAPSHOT ke
-- semua equipment yang ikut bergerak (default: assigned_unit_id rig itu).
-- Akses: Sr Mekanik ke atas (sr_mekanik / spv / sr_spv / astmen / admin).
-- ============================================================

-- 1. Tambah role sr_mekanik ke constraint profiles
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('operator','mekanik','sr_mekanik','gudang','spv','sr_spv','astmen','admin','user'));

-- 2. Helper RLS: Sr Mekanik ke atas
CREATE OR REPLACE FUNCTION is_sr_mekanik_or_above()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin')
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- sr_mekanik juga dapat akses level mekanik di Logbook (biar tidak terkunci)
CREATE OR REPLACE FUNCTION is_mekanik_or_above()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('mekanik','sr_mekanik','gudang','spv','sr_spv','astmen','admin')
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================
-- 3. TABLE: mobilization_records (1 baris per perpindahan rig)
-- ============================================================
CREATE TABLE IF NOT EXISTS mobilization_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- rig / unit yang pindah
  unit_id           INT REFERENCES parent_units(id) ON DELETE SET NULL,
  unit_name         TEXT,                      -- snapshot nama rig
  rig_equipment_id  UUID REFERENCES equipment(id) ON DELETE SET NULL, -- container Mobile Rig (opsional)

  -- JMP data (Section A)
  jmp_number        TEXT,
  origin            TEXT,
  destination       TEXT,
  total_distance    NUMERIC,                   -- km
  survey_date       DATE,
  pdf_file_name     TEXT,
  pdf_storage_path  TEXT,                      -- Supabase Storage (Phase 2)
  blind_spots       INT DEFAULT 0,
  railway_crossings INT DEFAULT 0,
  bridges           INT DEFAULT 0,
  total_road_damage NUMERIC DEFAULT 0,         -- km
  total_lots        INT,
  foco_units        INT,
  crane_capacity    TEXT CHECK (crane_capacity IN ('none','less_25','25_50','more_50')),

  -- Actual data (Section B)
  mob_date          DATE,
  actual_duration   NUMERIC,                   -- jam
  weather           TEXT CHECK (weather IN ('cerah','mendung','hujan_delay','hujan_sering')),
  incident          TEXT CHECK (incident IN ('none','minor','moderate','major')),
  incident_notes    TEXT,

  -- Skor (breakdown 7 faktor + total)
  s1_distance   INT, s2_road     INT, s3_route    INT, s4_transport INT,
  s5_duration   INT, s6_weather  INT, s7_incident INT,
  total_score   INT,
  category      TEXT CHECK (category IN ('low','medium','high','critical')),
  equivalent_hours NUMERIC,

  -- Meta
  source        TEXT DEFAULT 'MANUAL_ENTRY' CHECK (source IN ('MANUAL_ENTRY','PDF_UPLOAD')),
  status        TEXT DEFAULT 'submitted'    CHECK (status IN ('draft','submitted','verified')),
  entered_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  entered_by_name TEXT,
  verified_by   UUID REFERENCES profiles(id) ON DELETE SET NULL,
  verified_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_mobrec_unit ON mobilization_records(unit_id);
CREATE INDEX IF NOT EXISTS idx_mobrec_date ON mobilization_records(mob_date DESC);

-- ============================================================
-- 4. TABLE: mobilization_equipment (snapshot equipment yang ikut)
-- Setiap equipment yang bergerak di 1 mob = 1 baris.
-- ============================================================
CREATE TABLE IF NOT EXISTS mobilization_equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mobilization_id UUID REFERENCES mobilization_records(id) ON DELETE CASCADE,
  equipment_id    UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_tag   TEXT,         -- snapshot (tetap ada walau equipment dihapus)
  equipment_name  TEXT,         -- snapshot
  applied_score   INT,          -- = total_score mob (Phase 1 uniform; future: bobot kerentanan)
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (mobilization_id, equipment_id)
);
CREATE INDEX IF NOT EXISTS idx_mobeq_mob ON mobilization_equipment(mobilization_id);
CREATE INDEX IF NOT EXISTS idx_mobeq_eq  ON mobilization_equipment(equipment_id);

-- ============================================================
-- 5. updated_at trigger (reuse set_updated_at dari migration)
-- ============================================================
DROP TRIGGER IF EXISTS trg_mobrec_updated_at ON mobilization_records;
CREATE TRIGGER trg_mobrec_updated_at BEFORE UPDATE ON mobilization_records
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 6. RLS — read & write hanya Sr Mekanik ke atas
-- ============================================================
ALTER TABLE mobilization_records   ENABLE ROW LEVEL SECURITY;
ALTER TABLE mobilization_equipment ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mobrec_all" ON mobilization_records;
CREATE POLICY "mobrec_all" ON mobilization_records
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

DROP POLICY IF EXISTS "mobeq_all" ON mobilization_equipment;
CREATE POLICY "mobeq_all" ON mobilization_equipment
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

-- ============================================================
-- SELESAI Phase 1. (Akumulasi stress per equipment dihitung di app
-- dari kedua tabel ini — datanya kecil, tidak perlu tabel denormalisasi.)
-- ============================================================
