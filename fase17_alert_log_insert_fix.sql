-- ============================================================
-- FASE 17 — Fix alert_log INSERT policy
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Masalah: policy lama "alert_admin_write" (FOR ALL, USING/WITH CHECK
-- is_admin()) blokir INSERT dari user NON-admin. Padahal sendTelegramAlert()
-- dan runDailyAlerts() di index.html dipanggil oleh SEMUA role (bukan cuma
-- admin) buat nyatet log alert ke tabel ini — insert-nya gagal silent
-- (client nggak cek error), jadi selama ini row alert_log dari user non-admin
-- kemungkinan besar nggak pernah kesimpan. Ini juga bikin dedup server-side
-- (alert_type='daily-critical') di runDailyAlerts() nggak jalan kalau yang
-- pertama buka dashboard hari itu adalah non-admin.
--
-- Fix: pisah policy — INSERT boleh semua authenticated (append-only log,
-- risiko rendah), UPDATE/DELETE tetap admin-only.
-- ============================================================

DROP POLICY IF EXISTS "alert_admin_write" ON alert_log;

CREATE POLICY "alert_insert_authenticated" ON alert_log
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "alert_admin_modify" ON alert_log
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY "alert_admin_delete" ON alert_log
  FOR DELETE TO authenticated
  USING (is_admin());

-- Verifikasi:
-- SELECT polname, cmd FROM pg_policies WHERE tablename = 'alert_log';
