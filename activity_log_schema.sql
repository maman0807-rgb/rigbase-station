-- ============================================================
-- RIGBASE STATION — TABEL ACTIVITY_LOG (Audit Trail)
-- ============================================================
-- Capture semua perubahan: siapa, kapan, action apa, entity yang ke-affect.
-- Idempotent — aman dijalankan ulang.
-- ============================================================

CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_email TEXT,
  user_name TEXT,
  -- Action: 'created', 'updated', 'deleted', 'mutated', 'replaced', 'loaned', 'returned',
  --         'maintenance_added', 'document_uploaded', 'category_*', 'user_*', 'bulk_*'
  action TEXT NOT NULL,
  -- Entity type: 'equipment', 'category', 'user', 'mutation', 'loan', 'maintenance', 'document'
  entity_type TEXT NOT NULL,
  entity_id TEXT,           -- ID record (UUID atau numeric, sebagai string)
  entity_label TEXT,        -- Human-readable label (mis. tag_number)
  details JSONB,            -- Extra context: before/after values, dll
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_user    ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_entity  ON activity_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_created ON activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_action  ON activity_log(action);

-- Row Level Security
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Semua authenticated user bisa baca (audit transparancy)
DROP POLICY IF EXISTS "activity_read_all" ON activity_log;
CREATE POLICY "activity_read_all" ON activity_log
  FOR SELECT TO authenticated USING (true);

-- Authenticated user bisa insert log mereka sendiri
DROP POLICY IF EXISTS "activity_user_insert" ON activity_log;
CREATE POLICY "activity_user_insert" ON activity_log
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Hanya admin yang bisa UPDATE/DELETE (modify audit trail)
DROP POLICY IF EXISTS "activity_admin_modify" ON activity_log;
CREATE POLICY "activity_admin_modify" ON activity_log
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "activity_admin_delete" ON activity_log;
CREATE POLICY "activity_admin_delete" ON activity_log
  FOR DELETE TO authenticated USING (is_admin());

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'activity_log table' AS info,
       (SELECT COUNT(*) FROM activity_log) AS row_count;
-- row_count = 0 (kosong, normal kalau baru pertama kali)
