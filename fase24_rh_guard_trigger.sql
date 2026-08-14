-- ============================================================
-- Guard terhadap penurunan running_hours yang ekstrem/tidak wajar.
-- Latar belakang: 2026-08-05 TL-KB150A ke-input rh=1415.2 dari
-- laporan_harian_entries (harusnya ~8941), kemungkinan salah ketik
-- dari laporan yang masuk via bot Telegram (created_by NULL di
-- laporan_harian, jadi bukan lewat form app). Nilai itu kesinkron
-- langsung ke equipment.running_hours tanpa validasi apapun.
--
-- Trigger ini adalah "circuit breaker" terakhir di level database,
-- jadi berlaku utk SEMUA jalur (app, bot, SQL manual) — bukan cuma
-- form di app. Threshold sengaja dibuat JAUH di atas sanity-check
-- yang sudah ada di UI Revisi HM (20% / 1000 jam, lihat submitHMRevise
-- di index.html) supaya koreksi manual yang wajar & sudah dikonfirmasi
-- admin tetap lolos — trigger ini cuma nolak penurunan yang ekstrem
-- (>50% DAN >1500 jam sekaligus, mencakup kasus TL-KB150A yg turun
-- 84% / 7459 jam).
--
-- Kalau memang ada kebutuhan legit menurunkan RH lebih besar dari itu
-- (misal HM meter fisik diganti/direset), lakukan lewat SQL Editor
-- manual dengan catatan alasan di komentar, bukan lewat app.
-- ============================================================

CREATE OR REPLACE FUNCTION guard_running_hours_drop()
RETURNS TRIGGER AS $$
DECLARE
  drop_abs numeric;
  drop_pct numeric;
BEGIN
  IF NEW.running_hours IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.running_hours < 0 THEN
    RAISE EXCEPTION 'RH_INVALID: running_hours tidak boleh negatif (%).', NEW.running_hours;
  END IF;

  IF OLD.running_hours IS NOT NULL AND OLD.running_hours > 0
     AND NEW.running_hours < OLD.running_hours THEN
    drop_abs := OLD.running_hours - NEW.running_hours;
    drop_pct := drop_abs / OLD.running_hours;

    IF drop_pct > 0.5 AND drop_abs > 1500 THEN
      RAISE EXCEPTION 'RH_ANOMALY: % (%) turun ekstrem jadi % (turun % jam / %.0f%%). Ditolak otomatis — kalau ini memang benar, koreksi manual lewat SQL Editor Supabase dgn catatan alasan.',
        NEW.tag_number, NEW.nama_equipment, NEW.running_hours, drop_abs, drop_pct * 100;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_rh_drop ON equipment;
CREATE TRIGGER trg_guard_rh_drop
  BEFORE UPDATE OF running_hours ON equipment
  FOR EACH ROW
  EXECUTE FUNCTION guard_running_hours_drop();

-- Verifikasi trigger terpasang:
SELECT tgname, tgrelid::regclass, tgenabled FROM pg_trigger WHERE tgname = 'trg_guard_rh_drop';
