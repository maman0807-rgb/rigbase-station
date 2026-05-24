-- ============================================================
-- RIGBASE STATION — Trigger Real-time Alert Critical Finding
-- ============================================================
-- Saat ada INSERT temuan ber-kategori 'Critical' di inspection_findings,
-- panggil Edge Function critical-inspection-alert (kirim Telegram).
-- Menangkap SEMUA jalur insert: form manual, import PDF/Excel, SQL langsung.
-- Jalankan di Supabase SQL Editor. Idempoten.
-- ============================================================

-- pg_net untuk HTTP call dari dalam database (kalau belum aktif)
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION notify_critical_finding()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.category = 'Critical' THEN
    PERFORM net.http_post(
      url := 'https://olmowzrlokajhniqijfq.supabase.co/functions/v1/critical-inspection-alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        -- publishable key (publik by design, sama dgn setup_cron_telegram.sql)
        'Authorization', 'Bearer sb_publishable_cbkPjUGchF_PwQo5ZlM3zQ_gRl-phYL'
      ),
      body := jsonb_build_object('record', to_jsonb(NEW)),
      timeout_milliseconds := 5000
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_critical_finding_alert ON inspection_findings;
CREATE TRIGGER trg_critical_finding_alert
AFTER INSERT ON inspection_findings
FOR EACH ROW EXECUTE FUNCTION notify_critical_finding();

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'trg_critical_finding_alert';
-- tgenabled = 'O' artinya aktif.

-- ============================================================
-- TEST (opsional) — akan kirim Telegram beneran:
--   INSERT INTO inspection_findings (inspection_id, no_urut, equipment_name_snapshot, category, finding, tgl_ditemukan, status)
--   VALUES ((SELECT id FROM inspections LIMIT 1), 999, 'TES TRIGGER', 'Critical', 'Cek alert real-time', CURRENT_DATE, 'Open');
-- Lalu hapus lagi baris tes itu.
--
-- Lihat history call: SELECT id, status_code, created FROM net._http_response ORDER BY created DESC LIMIT 5;
-- ============================================================

-- ============================================================
-- NONAKTIFKAN (kalau perlu):
--   DROP TRIGGER IF EXISTS trg_critical_finding_alert ON inspection_findings;
-- ============================================================
