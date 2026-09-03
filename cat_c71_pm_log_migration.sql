-- ============================================================
-- Migration: cat_c71_pm_log — histori "PM level selesai" khusus
-- mesin Caterpillar C7.1 (GS-KB150A-CAT / GS-KB150B-CAT).
-- Jalankan di Supabase SQL Editor (project eRAMHoist).
-- Aman re-run (idempoten, semua CREATE pakai IF NOT EXISTS / DROP POLICY IF EXISTS).
--
-- LATAR BELAKANG: kedua unit ini pindah total ke jadwal manual pabrikan
-- Caterpillar (SEBU9241-10, Prime Power) yang rasio interval-nya
-- (1:5:10:20:40:60 dari basis 50 jam, lihat CAT_C71_PM_LADDER di
-- index.html) TIDAK bisa direpresentasikan lewat mekanisme tier generik
-- getPMTypeByCycle() (rasio tetap 1:2:4:8:40 dari pm_interval_hours).
-- Tabel ini TERPISAH TOTAL dari equipment.pm_interval_hours/
-- pm_cycle_count/pm_type dan tabel manapun yang dipakai equipment lain
-- — equipment lain tidak terpengaruh sama sekali oleh migration ini.
--
-- Pola append-only (sama seperti downtime_events/stock_transactions di
-- migration lain): tiap kali level X dicatat selesai, INSERT 1 baris
-- per level dari PM1 s/d X (cascade — checklist-nya kumulatif, jadi PM4
-- selesai berarti PM1+PM2+PM3 ikut selesai juga di HM yang sama). Baris
-- lama TIDAK di-update/dihapus — "terakhir dikerjakan" per level =
-- MAX(done_at_hm) dari baris-baris levelnya, dihitung di index.html
-- saat render (bukan kolom tersendiri), jadi histori lengkap tetap ada
-- kalau suatu saat perlu ditelusuri ulang.
-- ============================================================

CREATE TABLE IF NOT EXISTS cat_c71_pm_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id  UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  level         TEXT NOT NULL CHECK (level IN ('PM1','PM2','PM3','PM4','PM5','PM6')),
  done_at_hm    NUMERIC NOT NULL CHECK (done_at_hm >= 0),
  done_at_date  DATE NOT NULL,
  done_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  done_by_name  TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cat_c71_pm_log_eq_level ON cat_c71_pm_log(equipment_id, level);

ALTER TABLE cat_c71_pm_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cat_c71_pm_log_read" ON cat_c71_pm_log;
CREATE POLICY "cat_c71_pm_log_read" ON cat_c71_pm_log
  FOR SELECT TO authenticated USING (true);

-- Insert dibatasi ke sr_mekanik+ -- samain persis dgn gate tombol "Catat PM Selesai"
-- generik yg sudah ada (isSrMekanikOrAbove() di index.html), karena aksi ini juga
-- "menutup" jadwal PM (dampaknya besar kalau salah catat), bukan sekadar entri gudang.
DROP POLICY IF EXISTS "cat_c71_pm_log_insert" ON cat_c71_pm_log;
CREATE POLICY "cat_c71_pm_log_insert" ON cat_c71_pm_log
  FOR INSERT TO authenticated WITH CHECK (is_sr_mekanik_or_above());

-- Sengaja TIDAK ada UPDATE/DELETE policy -- append-only, sama seperti
-- downtime_events/stock_transactions di migration lain. Kalau ada yang
-- salah catat, insert baris baru dgn notes "koreksi ...", jangan
-- hapus/edit baris lama (jaga jejak audit).

-- Verifikasi terpasang:
SELECT table_name FROM information_schema.tables WHERE table_name = 'cat_c71_pm_log';
