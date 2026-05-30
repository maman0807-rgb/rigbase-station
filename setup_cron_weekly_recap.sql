-- ============================================================
-- FASE 4 — Setup Cron untuk Weekly Strategic Recap
-- ============================================================
-- Schedule: setiap Senin 07:00 WIB (Minggu 00:00 UTC)
-- Cron job: 'rigbase-weekly-recap'
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.unschedule('rigbase-weekly-recap') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'rigbase-weekly-recap'
);

-- Setiap Senin 07:00 WIB = Minggu 00:00 UTC
-- Cron format: minute hour day month day-of-week (0 = Sunday, 1 = Monday)
SELECT cron.schedule(
  'rigbase-weekly-recap',
  '0 0 * * 1',  -- Setiap Senin 00:00 UTC = 07:00 WIB
  $$
    SELECT net.http_post(
      url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/weekly-recap-alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9sbW93enJsb2thamhuaXFpamZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTMzOTgsImV4cCI6MjA5NDQyOTM5OH0.c-0pIiClpZ7_peLgcyMyjtXeJXVNhyD8gssOjCxE-gU'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);

SELECT jobid, schedule, jobname, active
FROM cron.job
WHERE jobname = 'rigbase-weekly-recap';

-- TEST MANUAL (run sekarang):
-- SELECT net.http_post(
--   url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/weekly-recap-alert',
--   headers := jsonb_build_object(
--     'Content-Type', 'application/json',
--     'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9sbW93enJsb2thamhuaXFpamZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTMzOTgsImV4cCI6MjA5NDQyOTM5OH0.c-0pIiClpZ7_peLgcyMyjtXeJXVNhyD8gssOjCxE-gU'
--   ),
--   body := '{}'::jsonb,
--   timeout_milliseconds := 30000
-- );
