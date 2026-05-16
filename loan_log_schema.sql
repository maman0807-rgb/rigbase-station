-- ============================================================
-- RIGBASE STATION — TABEL LOAN_LOG (Pinjam-Meminjam Equipment)
-- ============================================================
-- Jalankan SETELAH supabase_schema.sql.
-- Aman dijalankan ulang (idempoten).
-- ============================================================

-- Tabel utama
CREATE TABLE IF NOT EXISTS loan_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Equipment yang DIPINJAM (yang sehat, dipindah sementara)
  -- contoh: ACC-H35KD
  lender_equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,

  -- Equipment yang RUSAK (yang butuh pengganti sementara). Nullable kalau gak ada equipment specific.
  -- contoh: ACC-100A
  borrower_equipment_id UUID REFERENCES equipment(id) ON DELETE SET NULL,

  -- Unit ASAL equipment yang dipinjam (yang minjamkan)
  -- contoh: BW-H35KD
  lender_unit_id INT REFERENCES parent_units(id) ON DELETE SET NULL,

  -- Unit yang BUTUH (peminjam)
  -- contoh: BW-100A
  borrower_unit_id INT REFERENCES parent_units(id) ON DELETE SET NULL,

  loan_date DATE NOT NULL,
  return_date DATE,                  -- NULL = masih dipinjam
  reason TEXT,
  return_notes TEXT,
  status TEXT CHECK (status IN ('active','returned')) DEFAULT 'active',

  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  returned_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_loan_status      ON loan_log(status);
CREATE INDEX IF NOT EXISTS idx_loan_lender_eq   ON loan_log(lender_equipment_id);
CREATE INDEX IF NOT EXISTS idx_loan_borrower_eq ON loan_log(borrower_equipment_id);
CREATE INDEX IF NOT EXISTS idx_loan_date        ON loan_log(loan_date);

-- Trigger auto-update updated_at
DROP TRIGGER IF EXISTS trg_loan_log_updated_at ON loan_log;
CREATE TRIGGER trg_loan_log_updated_at
  BEFORE UPDATE ON loan_log
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Row Level Security
ALTER TABLE loan_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "loan_read_all" ON loan_log;
CREATE POLICY "loan_read_all" ON loan_log
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "loan_admin_write" ON loan_log;
CREATE POLICY "loan_admin_write" ON loan_log
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================
-- VERIFIKASI
-- ============================================================
-- Setelah Run, cek:
--   SELECT COUNT(*) FROM loan_log;  -- harusnya 0 (kosong, belum ada pinjaman)
--   SELECT tablename FROM pg_tables WHERE tablename = 'loan_log';  -- harusnya 1 baris
-- ============================================================
