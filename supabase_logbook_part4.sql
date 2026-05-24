-- ============================================================
-- LOGBOOK PART 4: tabel logbook, work_orders, notifications, counters
-- Jalankan di Supabase SQL Editor. Idempoten.
-- ============================================================

-- 1. logbook (entri harian operator)
CREATE TABLE IF NOT EXISTS logbook (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id   UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_name TEXT,
  reporter_id    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reporter_name  TEXT,
  reporter_role  TEXT,
  shift_hours    NUMERIC,
  condition      TEXT,
  temuan         TEXT,
  status         TEXT DEFAULT 'pending',
  data           JSONB DEFAULT '{}'::jsonb,   -- field fleksibel lain
  firestore_id   TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_logbook_equipment ON logbook(equipment_id);
CREATE INDEX IF NOT EXISTS idx_logbook_status    ON logbook(status);
CREATE INDEX IF NOT EXISTS idx_logbook_created   ON logbook(created_at DESC);

-- 2. work_orders
CREATE TABLE IF NOT EXISTS work_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nomor_wo        TEXT,
  equipment_id    UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_name  TEXT,
  type            TEXT,           -- corrective | preventive
  priority        TEXT,
  description     TEXT,
  estimated_time  NUMERIC,
  current_hm      NUMERIC,
  pm_level        TEXT,
  parts           JSONB DEFAULT '[]'::jsonb,
  status          TEXT DEFAULT 'pending_approval',
  logbook_id      UUID,
  related_request_id UUID,
  mekanik_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  mekanik_name    TEXT,
  spv_id          UUID, spv_note TEXT,
  data            JSONB DEFAULT '{}'::jsonb,
  firestore_id    TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  approved_at     TIMESTAMPTZ, rejected_at TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wo_status    ON work_orders(status);
CREATE INDEX IF NOT EXISTS idx_wo_equipment ON work_orders(equipment_id);
CREATE INDEX IF NOT EXISTS idx_wo_created    ON work_orders(created_at DESC);

-- 3. notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title      TEXT,
  body       TEXT,
  type       TEXT,
  url        TEXT,
  read       BOOLEAN DEFAULT FALSE,
  firestore_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);

-- 4. counters (nomor WO, dll)
CREATE TABLE IF NOT EXISTS counters (
  id TEXT PRIMARY KEY,
  last_number BIGINT DEFAULT 0
);

-- Triggers updated_at
DROP TRIGGER IF EXISTS trg_logbook_updated_at ON logbook;
CREATE TRIGGER trg_logbook_updated_at BEFORE UPDATE ON logbook
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_wo_updated_at ON work_orders;
CREATE TRIGGER trg_wo_updated_at BEFORE UPDATE ON work_orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS
ALTER TABLE logbook       ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE counters      ENABLE ROW LEVEL SECURITY;

-- logbook: read auth, create auth, update auth, delete manager
DROP POLICY IF EXISTS "lb_read" ON logbook;
CREATE POLICY "lb_read" ON logbook FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "lb_insert" ON logbook;
CREATE POLICY "lb_insert" ON logbook FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "lb_update" ON logbook;
CREATE POLICY "lb_update" ON logbook FOR UPDATE TO authenticated USING (true);
DROP POLICY IF EXISTS "lb_delete" ON logbook;
CREATE POLICY "lb_delete" ON logbook FOR DELETE TO authenticated USING (is_manager());

-- work_orders: read auth, create auth, update auth, delete manager
DROP POLICY IF EXISTS "wo_read" ON work_orders;
CREATE POLICY "wo_read" ON work_orders FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "wo_insert" ON work_orders;
CREATE POLICY "wo_insert" ON work_orders FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "wo_update" ON work_orders;
CREATE POLICY "wo_update" ON work_orders FOR UPDATE TO authenticated USING (true);
DROP POLICY IF EXISTS "wo_delete" ON work_orders;
CREATE POLICY "wo_delete" ON work_orders FOR DELETE TO authenticated USING (is_manager());

-- notifications: read/update own, insert auth
DROP POLICY IF EXISTS "notif_read" ON notifications;
CREATE POLICY "notif_read" ON notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "notif_insert" ON notifications;
CREATE POLICY "notif_insert" ON notifications FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "notif_update" ON notifications;
CREATE POLICY "notif_update" ON notifications FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- counters: read & write auth
DROP POLICY IF EXISTS "counters_read" ON counters;
CREATE POLICY "counters_read" ON counters FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "counters_write" ON counters;
CREATE POLICY "counters_write" ON counters FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Realtime untuk yang pakai subscribe
ALTER PUBLICATION supabase_realtime ADD TABLE logbook;
ALTER PUBLICATION supabase_realtime ADD TABLE work_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
-- (kalau "already member" → abaikan)

-- ============================================================
-- SELESAI part 4.
-- ============================================================
