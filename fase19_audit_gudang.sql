-- ============================================================
-- FASE 19 — Modul Audit Gudang
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
-- Bergantung pada tabel `materials` & `stock_transactions` (dari
-- supabase_logbook_migration.sql) dan fungsi `is_gudang()`.
-- ============================================================

-- 1. Header sesi audit
CREATE TABLE IF NOT EXISTS audit_gudang (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tanggal_audit  DATE NOT NULL DEFAULT CURRENT_DATE,
  dilakukan_oleh TEXT,
  status         TEXT CHECK (status IN ('draft','selesai')) DEFAULT 'draft',
  catatan_umum   TEXT,
  created_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  selesai_at     TIMESTAMPTZ
);

-- 2. Hasil cocokan per item
CREATE TABLE IF NOT EXISTS audit_temuan (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id      UUID REFERENCES audit_gudang(id) ON DELETE CASCADE,
  material_id   UUID REFERENCES materials(id) ON DELETE SET NULL,
  stock_sistem  NUMERIC NOT NULL DEFAULT 0,
  stock_fisik   NUMERIC,
  selisih       NUMERIC GENERATED ALWAYS AS (stock_fisik - stock_sistem) STORED,
  keterangan    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_temuan_audit    ON audit_temuan(audit_id);
CREATE INDEX IF NOT EXISTS idx_audit_temuan_material ON audit_temuan(material_id);

-- 3. View ringkasan selisih (join ke materials utk nama/part_number)
CREATE OR REPLACE VIEW v_audit_selisih AS
SELECT
  t.id, t.audit_id, t.material_id, t.stock_sistem, t.stock_fisik, t.selisih, t.keterangan,
  a.tanggal_audit, a.dilakukan_oleh, a.status AS audit_status,
  m.part_number, m.description, m.category
FROM audit_temuan t
JOIN audit_gudang a ON a.id = t.audit_id
LEFT JOIN materials m ON m.id = t.material_id
WHERE t.selisih IS NOT NULL AND t.selisih <> 0
ORDER BY a.tanggal_audit DESC;

-- 4. RLS — baca semua authenticated, tulis khusus is_gudang() (gudang/spv/sr_spv/astmen/admin)
ALTER TABLE audit_gudang ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_temuan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_gudang_read" ON audit_gudang;
CREATE POLICY "audit_gudang_read" ON audit_gudang
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "audit_gudang_write" ON audit_gudang;
CREATE POLICY "audit_gudang_write" ON audit_gudang
  FOR ALL TO authenticated USING (is_gudang()) WITH CHECK (is_gudang());

DROP POLICY IF EXISTS "audit_temuan_read" ON audit_temuan;
CREATE POLICY "audit_temuan_read" ON audit_temuan
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "audit_temuan_write" ON audit_temuan;
CREATE POLICY "audit_temuan_write" ON audit_temuan
  FOR ALL TO authenticated USING (is_gudang()) WITH CHECK (is_gudang());

-- Verifikasi:
-- SELECT * FROM v_audit_selisih LIMIT 20;
-- SELECT polname, cmd FROM pg_policies WHERE tablename IN ('audit_gudang','audit_temuan');
