-- ============================================================
-- FASE 10 — Alert Anti-Mabok (De-dup, Snooze, Threshold)
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Komponen:
-- 1. alert_snooze table — track equipment/kategori yg di-snooze user
-- 2. Helper view alert_log_recent — bantu de-dup 24 jam
-- ============================================================

-- 1. Table alert_snooze
CREATE TABLE IF NOT EXISTS alert_snooze (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  alert_kind   TEXT NOT NULL,  -- 'PM', 'TOH', 'GOH', 'EOL', 'gejala', 'downtime', 'all'
  snooze_until TIMESTAMPTZ NOT NULL,
  reason       TEXT,
  created_by   UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_snooze_until ON alert_snooze(snooze_until);
CREATE INDEX IF NOT EXISTS idx_snooze_equipment ON alert_snooze(equipment_id);
-- Composite index utk lookup snooze aktif per (equipment, kind, snooze_until)
-- Tidak pakai partial index "WHERE snooze_until > NOW()" karena NOW() bukan IMMUTABLE.
CREATE INDEX IF NOT EXISTS idx_snooze_active ON alert_snooze(equipment_id, alert_kind, snooze_until);

-- RLS — Sr Mekanik+ bisa CRUD snooze
ALTER TABLE alert_snooze ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "snooze_all" ON alert_snooze;
CREATE POLICY "snooze_all" ON alert_snooze
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

-- 2. Helper function: cek apakah equipment+kind di-snooze
CREATE OR REPLACE FUNCTION is_alert_snoozed(p_equipment_id UUID, p_kind TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM alert_snooze
    WHERE (equipment_id = p_equipment_id OR equipment_id IS NULL)
      AND (alert_kind = p_kind OR alert_kind = 'all')
      AND snooze_until > NOW()
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- 3. Helper function: cek apakah alert sudah dikirim dalam X jam terakhir (de-dup)
CREATE OR REPLACE FUNCTION was_alert_sent_recently(p_alert_type TEXT, p_message_substr TEXT, p_within_hours INT DEFAULT 24)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM alert_log
    WHERE alert_type = p_alert_type
      AND message ILIKE '%' || p_message_substr || '%'
      AND sent_at > NOW() - (p_within_hours || ' hours')::INTERVAL
      AND status = 'sent'
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- 4. View: snooze aktif (active snoozes)
CREATE OR REPLACE VIEW v_active_snoozes AS
SELECT s.*, e.tag_number, e.nama_equipment,
       EXTRACT(EPOCH FROM (s.snooze_until - NOW())) / 3600 AS hours_remaining
FROM alert_snooze s
LEFT JOIN equipment e ON e.id = s.equipment_id
WHERE s.snooze_until > NOW()
ORDER BY s.snooze_until;

-- Verifikasi:
-- SELECT * FROM v_active_snoozes;
-- SELECT is_alert_snoozed('some-uuid', 'TOH');
-- SELECT was_alert_sent_recently('morning-briefing', 'GS-KB150C', 24);
