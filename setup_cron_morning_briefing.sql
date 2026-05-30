-- ============================================================
-- FASE 2 — Setup Cron untuk Morning Briefing 06:30 WIB
-- ============================================================
-- Schedule: tiap hari 06:30 WIB (23:30 UTC prev day)
-- Cron job: 'rigbase-morning-briefing'
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Hapus job lama dulu kalau ada (idempoten)
SELECT cron.unschedule('rigbase-morning-briefing') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'rigbase-morning-briefing'
);

-- Schedule daily 06:30 WIB = 23:30 UTC (hari sebelumnya)
-- Cron format: minute hour day month day-of-week
SELECT cron.schedule(
  'rigbase-morning-briefing',
  '30 23 * * *',
  $$
    SELECT net.http_post(
      url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/morning-briefing-alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9sbW93enJsb2thamhuaXFpamZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTMzOTgsImV4cCI6MjA5NDQyOTM5OH0.c-0pIiClpZ7_peLgcyMyjtXeJXVNhyD8gssOjCxE-gU'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);

-- Verifikasi job tersimpan
SELECT jobid, schedule, jobname, active
FROM cron.job
WHERE jobname = 'rigbase-morning-briefing';

-- TEST MANUAL (opsional, jalankan sekarang untuk simulate):
-- SELECT net.http_post(
--   url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/morning-briefing-alert',
--   headers := jsonb_build_object(
--     'Content-Type', 'application/json',
--     'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9sbW93enJsb2thamhuaXFpamZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTMzOTgsImV4cCI6MjA5NDQyOTM5OH0.c-0pIiClpZ7_peLgcyMyjtXeJXVNhyD8gssOjCxE-gU'
--   ),
--   body := '{}'::jsonb,
--   timeout_milliseconds := 30000
-- );
