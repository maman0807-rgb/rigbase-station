-- ============================================================
-- RIGBASE STATION — EXTENSION: GUDANG + MAINTENANCE MODULES
-- Migrasi modul Logbook (Firebase) → RigBase (Supabase)
-- ============================================================
-- TAHAP 1: SKEMA. Aman dijalankan ulang (idempoten).
-- Additive only — TIDAK mengubah/menghapus tabel/field existing.
-- Jalankan di Supabase SQL Editor SETELAH supabase_schema.sql.
-- ============================================================

-- ============================================================
-- 1. EXTEND profiles.role → 7 role (dari admin/user)
-- ============================================================
-- Drop check lama, ganti dengan 7 role. Data 'user' lama tetap valid
-- (akan dipetakan ke role spesifik saat migrasi).
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('operator','mekanik','gudang','spv','sr_spv','astmen','admin','user'));

-- Kolom tambahan untuk login internal ala Logbook (employeeId + PIN)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS employee_id TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS department  TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token   TEXT;
CREATE INDEX IF NOT EXISTS idx_profiles_employee ON profiles(employee_id);

-- ============================================================
-- 2. HELPER FUNCTIONS (role-based, mirror firestore.rules)
-- ============================================================
CREATE OR REPLACE FUNCTION current_role_name()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_manager()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('spv','sr_spv','astmen','admin')
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_gudang()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('gudang','spv','sr_spv','astmen','admin')
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_mekanik_or_above()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('mekanik','gudang','spv','sr_spv','astmen','admin')
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================
-- 3. EXTEND equipment — field operasional & PM (dari Logbook)
-- running_hours (sudah ada) = jam jalan. Tambah sisanya:
-- ============================================================
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS hm_awal             NUMERIC DEFAULT 0;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS last_pm_hours       NUMERIC DEFAULT 0;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS last_pm_date        DATE;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS last_goh_date       DATE;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_type             TEXT DEFAULT 'hours'
  CHECK (pm_type IN ('hours','time'));
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_interval_hours   NUMERIC DEFAULT 250;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_interval_months  INT DEFAULT 3;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS predictive_score    INT DEFAULT 0;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_templates        JSONB DEFAULT '{}'::jsonb;
-- code Logbook = tag_number RigBase (sudah ada, unik). Tidak perlu kolom baru.

-- ============================================================
-- 4. TABLE: materials (Gudang) — gabungan stok + katalog
-- ============================================================
CREATE TABLE IF NOT EXISTS materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  part_number   TEXT NOT NULL,
  description   TEXT,
  category      TEXT,                 -- Fast Moving|Consumable|Critical|Lubricant|Slow Moving
  satuan        TEXT,
  stok          NUMERIC DEFAULT 0,
  unit_price    NUMERIC DEFAULT 0,
  safety_stock  NUMERIC DEFAULT 0,
  lead_time_days INT DEFAULT 0,
  related_equipments JSONB DEFAULT '[]'::jsonb,  -- array of equipment id
  kimap         TEXT,
  penyimpanan   TEXT,
  tgl_masuk     TEXT,
  tgl_keluar    TEXT,
  notes         TEXT,
  firestore_id  TEXT,                 -- untuk pemetaan saat migrasi
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  created_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by    UUID REFERENCES profiles(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_materials_partnumber ON materials(part_number);
CREATE INDEX IF NOT EXISTS idx_materials_category   ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_firestore  ON materials(firestore_id);

-- ============================================================
-- 5. TABLE: stock_transactions (audit keluar/masuk stok)
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id   UUID REFERENCES materials(id) ON DELETE SET NULL,
  part_number   TEXT,
  description   TEXT,
  tipe          TEXT CHECK (tipe IN ('masuk','keluar')),
  jumlah        NUMERIC,
  stok_sebelum  NUMERIC,
  stok_sesudah  NUMERIC,
  keterangan    TEXT,
  referensi     TEXT,
  sumber        TEXT,                 -- 'dailyLog' | 'manual' | 'workOrder'
  daily_log_id  UUID,
  user_id       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_name     TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stocktx_material ON stock_transactions(material_id);
CREATE INDEX IF NOT EXISTS idx_stocktx_created  ON stock_transactions(created_at DESC);

-- ============================================================
-- 6. TABLE: manpower_rates (rate per posisi)
-- ============================================================
CREATE TABLE IF NOT EXISTS manpower_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  position      TEXT NOT NULL,
  rate_per_hour NUMERIC DEFAULT 0,
  rate_per_day  NUMERIC DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. TABLE: daily_logs (Maintenance Input Harian)
-- Line items (manpower/parts/transport/vendor) = JSONB snapshot.
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  log_date         DATE NOT NULL,
  equipment_id     UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_name   TEXT,
  maintenance_type TEXT CHECK (maintenance_type IN ('PM','CM','PdM','BD')),
  notes            TEXT,
  manpower         JSONB DEFAULT '[]'::jsonb,
  parts            JSONB DEFAULT '[]'::jsonb,
  transport        JSONB DEFAULT '[]'::jsonb,
  vendor           JSONB DEFAULT '[]'::jsonb,
  subtotals        JSONB DEFAULT '{}'::jsonb,
  parts_by_category JSONB DEFAULT '{}'::jsonb,
  total            NUMERIC DEFAULT 0,
  -- jejak penginput awal (tidak ditimpa saat edit) + editor terakhir
  user_id          UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_name        TEXT,
  created_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by_name  TEXT,
  updated_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by_name  TEXT,
  firestore_id     TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dailylogs_date      ON daily_logs(log_date DESC);
CREATE INDEX IF NOT EXISTS idx_dailylogs_equipment ON daily_logs(equipment_id);
CREATE INDEX IF NOT EXISTS idx_dailylogs_type      ON daily_logs(maintenance_type);

-- ============================================================
-- 8. TABLE: pm_schedules (Jadwal PM per part per equipment)
-- ============================================================
CREATE TABLE IF NOT EXISTS pm_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id    UUID REFERENCES equipment(id) ON DELETE CASCADE,
  equipment_name  TEXT,
  material_id     UUID REFERENCES materials(id) ON DELETE SET NULL,
  part_number     TEXT,
  part_name       TEXT,
  interval_hours  NUMERIC DEFAULT 0,
  last_done_hours NUMERIC DEFAULT 0,
  last_done_date  DATE,
  enabled         BOOLEAN DEFAULT TRUE,
  notes           TEXT,
  firestore_id    TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  created_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by      UUID REFERENCES profiles(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_pmsched_equipment ON pm_schedules(equipment_id);
CREATE INDEX IF NOT EXISTS idx_pmsched_enabled   ON pm_schedules(enabled);

-- ============================================================
-- 9. TRIGGERS updated_at
-- ============================================================
DROP TRIGGER IF EXISTS trg_materials_updated_at ON materials;
CREATE TRIGGER trg_materials_updated_at BEFORE UPDATE ON materials
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_dailylogs_updated_at ON daily_logs;
CREATE TRIGGER trg_dailylogs_updated_at BEFORE UPDATE ON daily_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pmsched_updated_at ON pm_schedules;
CREATE TRIGGER trg_pmsched_updated_at BEFORE UPDATE ON pm_schedules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_manpowerrates_updated_at ON manpower_rates;
CREATE TRIGGER trg_manpowerrates_updated_at BEFORE UPDATE ON manpower_rates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 10. ROW LEVEL SECURITY (mirror firestore.rules Logbook)
-- ============================================================
ALTER TABLE materials          ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE manpower_rates     ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_schedules       ENABLE ROW LEVEL SECURITY;

-- ---------- materials: read auth, write gudang+ ----------
DROP POLICY IF EXISTS "materials_read" ON materials;
CREATE POLICY "materials_read" ON materials
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "materials_write" ON materials;
CREATE POLICY "materials_write" ON materials
  FOR ALL TO authenticated USING (is_gudang()) WITH CHECK (is_gudang());

-- ---------- stock_transactions: read auth, insert auth, modify gudang ----------
DROP POLICY IF EXISTS "stocktx_read" ON stock_transactions;
CREATE POLICY "stocktx_read" ON stock_transactions
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "stocktx_insert" ON stock_transactions;
CREATE POLICY "stocktx_insert" ON stock_transactions
  FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "stocktx_modify" ON stock_transactions;
CREATE POLICY "stocktx_modify" ON stock_transactions
  FOR UPDATE TO authenticated USING (is_gudang()) WITH CHECK (is_gudang());
DROP POLICY IF EXISTS "stocktx_delete" ON stock_transactions;
CREATE POLICY "stocktx_delete" ON stock_transactions
  FOR DELETE TO authenticated USING (is_gudang());

-- ---------- manpower_rates: read auth, write manager ----------
DROP POLICY IF EXISTS "rates_read" ON manpower_rates;
CREATE POLICY "rates_read" ON manpower_rates
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "rates_write" ON manpower_rates;
CREATE POLICY "rates_write" ON manpower_rates
  FOR ALL TO authenticated USING (is_manager()) WITH CHECK (is_manager());

-- ---------- daily_logs: read auth, create/update mekanik+gudang+manager, delete manager ----------
DROP POLICY IF EXISTS "dailylogs_read" ON daily_logs;
CREATE POLICY "dailylogs_read" ON daily_logs
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "dailylogs_insert" ON daily_logs;
CREATE POLICY "dailylogs_insert" ON daily_logs
  FOR INSERT TO authenticated WITH CHECK (is_mekanik_or_above());
DROP POLICY IF EXISTS "dailylogs_update" ON daily_logs;
CREATE POLICY "dailylogs_update" ON daily_logs
  FOR UPDATE TO authenticated USING (is_mekanik_or_above()) WITH CHECK (is_mekanik_or_above());
DROP POLICY IF EXISTS "dailylogs_delete" ON daily_logs;
CREATE POLICY "dailylogs_delete" ON daily_logs
  FOR DELETE TO authenticated USING (is_manager());

-- ---------- pm_schedules: read auth, write manager ----------
DROP POLICY IF EXISTS "pmsched_read" ON pm_schedules;
CREATE POLICY "pmsched_read" ON pm_schedules
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "pmsched_write" ON pm_schedules;
CREATE POLICY "pmsched_write" ON pm_schedules
  FOR ALL TO authenticated USING (is_manager()) WITH CHECK (is_manager());

-- ============================================================
-- SELESAI TAHAP 1 (skema gudang + maintenance).
-- Berikutnya:
--   - Tahap 2: script migrasi data Firebase → tabel ini
--   - Tahap 3: sambungkan app React ke Supabase (helper + auth + realtime)
--   - Tahap 4: bangun FMEA / CSPP / Stress Score
-- ============================================================
