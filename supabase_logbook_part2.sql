-- ============================================================
-- LOGBOOK PART 2: operator_requests + enable realtime
-- Jalankan di Supabase SQL Editor. Idempoten.
-- ============================================================

-- 1. TABLE operator_requests (Permintaan & Laporan operator)
CREATE TABLE IF NOT EXISTS operator_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kategori          TEXT,           -- permintaan_barang | laporan_umum | koordinasi
  judul             TEXT,
  description       TEXT,
  priority          TEXT DEFAULT 'normal',  -- normal | urgent
  status            TEXT DEFAULT 'open',    -- open | diproses | selesai
  equipment_id      UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_name    TEXT,
  requested_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  requested_by_name TEXT,
  requested_by_role TEXT,
  assigned_to       TEXT,
  assigned_to_name  TEXT,
  processed_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  processed_by_name TEXT,
  processed_at      TIMESTAMPTZ,
  completed_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  completed_by_name TEXT,
  completed_at      TIMESTAMPTZ,
  response          TEXT,
  related_work_order_id     UUID,
  related_work_order_number TEXT,
  firestore_id      TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_oreq_requestedby ON operator_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_oreq_status      ON operator_requests(status);

DROP TRIGGER IF EXISTS trg_oreq_updated_at ON operator_requests;
CREATE TRIGGER trg_oreq_updated_at BEFORE UPDATE ON operator_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE operator_requests ENABLE ROW LEVEL SECURITY;

-- read: pengaju lihat sendiri, manager lihat semua
DROP POLICY IF EXISTS "oreq_read" ON operator_requests;
CREATE POLICY "oreq_read" ON operator_requests
  FOR SELECT TO authenticated
  USING (requested_by = auth.uid() OR is_manager());

-- create: siapa saja yang login
DROP POLICY IF EXISTS "oreq_insert" ON operator_requests;
CREATE POLICY "oreq_insert" ON operator_requests
  FOR INSERT TO authenticated WITH CHECK (true);

-- update: manager, atau pengaju selama masih 'open'
DROP POLICY IF EXISTS "oreq_update" ON operator_requests;
CREATE POLICY "oreq_update" ON operator_requests
  FOR UPDATE TO authenticated
  USING (is_manager() OR (requested_by = auth.uid() AND status = 'open'));

-- delete: manager, atau pengaju selama masih 'open'
DROP POLICY IF EXISTS "oreq_delete" ON operator_requests;
CREATE POLICY "oreq_delete" ON operator_requests
  FOR DELETE TO authenticated
  USING (is_manager() OR (requested_by = auth.uid() AND status = 'open'));

-- 2. ENABLE REALTIME untuk tabel yang pakai subscribe
ALTER PUBLICATION supabase_realtime ADD TABLE manpower_rates;
ALTER PUBLICATION supabase_realtime ADD TABLE pm_schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE operator_requests;
-- (kalau error "already member", abaikan — berarti sudah aktif)

-- ============================================================
-- SELESAI part 2.
-- ============================================================
