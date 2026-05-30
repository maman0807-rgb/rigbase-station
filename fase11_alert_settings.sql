-- ============================================================
-- FASE 11 — Alert Settings (admin panel config)
-- ============================================================
-- Table alert_settings: konfigurasi per-jenis alert (ON/OFF, jadwal, threshold)
-- Single-row config (key-value style biar fleksibel)
-- ============================================================

CREATE TABLE IF NOT EXISTS alert_settings (
  id           SERIAL PRIMARY KEY,
  setting_key  TEXT UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  description  TEXT,
  updated_by   UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default settings (idempoten)
INSERT INTO alert_settings (setting_key, setting_value, description)
VALUES
  ('realtime_gejala', '{"enabled": true}'::jsonb, 'Real-time alert ketika gejala baru tercatat'),
  ('realtime_downtime', '{"enabled": true}'::jsonb, 'Real-time alert ketika downtime breakdown/troubleshoot baru'),
  ('realtime_eskalasi', '{"enabled": true}'::jsonb, 'Real-time alert ketika gejala dieskalasi ke breakdown/troubleshoot'),
  ('morning_briefing',  '{"enabled": true, "hour_utc": 23, "minute_utc": 30, "pm_threshold": 50, "overhaul_threshold": 100}'::jsonb, 'Briefing pagi 06:30 WIB - critical only'),
  ('daily_digest',      '{"enabled": true, "hour_utc": 1, "minute_utc": 0, "pm_soon": 500, "toh_soon": 1000, "goh_soon": 2000, "eol_pct": 80}'::jsonb, 'Daily digest 08:00 WIB - PERLU PLAN + NEAR EOL'),
  ('weekly_recap',      '{"enabled": true, "day_of_week": 1, "hour_utc": 0, "minute_utc": 0}'::jsonb, 'Weekly recap Senin 07:00 WIB - strategic level'),
  ('quiet_hours',       '{"enabled": false, "start_utc": 15, "end_utc": 23}'::jsonb, 'Quiet hours - skip real-time alerts (UTC: 15-23 = 22:00-06:00 WIB)')
ON CONFLICT (setting_key) DO NOTHING;

-- RLS: admin only
ALTER TABLE alert_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "settings_read" ON alert_settings;
DROP POLICY IF EXISTS "settings_admin" ON alert_settings;
CREATE POLICY "settings_read" ON alert_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "settings_admin" ON alert_settings
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Helper: get setting
CREATE OR REPLACE FUNCTION get_alert_setting(p_key TEXT)
RETURNS JSONB AS $$
  SELECT setting_value FROM alert_settings WHERE setting_key = p_key;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Helper: check enabled
CREATE OR REPLACE FUNCTION is_alert_enabled(p_key TEXT)
RETURNS BOOLEAN AS $$
  SELECT COALESCE((setting_value->>'enabled')::boolean, true) FROM alert_settings WHERE setting_key = p_key;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Verifikasi:
-- SELECT * FROM alert_settings ORDER BY setting_key;
-- SELECT get_alert_setting('morning_briefing');
-- SELECT is_alert_enabled('weekly_recap');
