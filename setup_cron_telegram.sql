-- ============================================================
-- RIGBASE STATION — Setup Cron untuk Daily Alert Telegram
-- ============================================================
-- Schedule: tiap hari 08:00 WIB (01:00 UTC) → panggil daily-alert-check Edge Function
-- ============================================================

-- 1. Enable extensions yang dibutuhkan
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Hapus job lama dulu kalau ada (idempoten)
SELECT cron.unschedule('rigbase-daily-alert') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'rigbase-daily-alert'
);

-- 3. Schedule daily 08:00 WIB
-- Cron format: minute hour day month day-of-week
-- '0 1 * * *' = setiap hari jam 01:00 UTC = 08:00 WIB
SELECT cron.schedule(
  'rigbase-daily-alert',
  '0 1 * * *',
  $$
    SELECT net.http_post(
      url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/daily-alert-check',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9sbW93enJsb2thamhuaXFpamZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NTMzOTgsImV4cCI6MjA5NDQyOTM5OH0.c-0pIiClpZ7_peLgcyMyjtXeJXVNhyD8gssOjCxE-gU'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);

-- 4. Verifikasi job tersimpan
SELECT jobid, schedule, command, jobname, active
FROM cron.job
WHERE jobname = 'rigbase-daily-alert';
-- Harus muncul 1 row dengan active=true

-- ============================================================
-- TEST MANUAL (opsional)
-- Jalankan SELECT net.http_post(...) di atas langsung untuk simulate cron firing.
-- Lihat history call di tabel net._http_response.
-- ============================================================

-- Cek history call (10 terakhir)
-- SELECT id, status_code, content, created
-- FROM net._http_response
-- ORDER BY created DESC LIMIT 10;

-- ============================================================
-- UNSCHEDULE (kalau perlu pause/disable cron):
-- ============================================================
-- SELECT cron.unschedule('rigbase-daily-alert');

-- ============================================================
-- UBAH JADWAL (contoh)
-- ============================================================
-- Hapus dulu, lalu schedule ulang dengan jam baru:
-- SELECT cron.unschedule('rigbase-daily-alert');
-- SELECT cron.schedule('rigbase-daily-alert', '0 22 * * *', $$...$$);  -- 22:00 UTC = 05:00 WIB
