-- ============================================================
-- FASE 39: Pedoman AIR Tahap 4C — Laporan Kinerja AIR Bulanan
-- Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0
--  * Materi monev kinerja AIR dikirim Regional ke SHU paling lambat
--    tanggal 12 setiap bulan (AIMS). eRAMHoist menyiapkan data level Field.
--  * KPI tidak tercapai → pemilik KPI wajib membuat penjelasan SAMBAL
--    (Siapa, Apa, Mengapa, Bagaimana, Aksi Lanjut).
--
-- Jalankan di Supabase SQL Editor SETELAH fase35–38. Aman re-run.
-- Uji: fase39_air_tahap4c_test.sql (otomatis rollback).
-- Tahap 4B (penundaan PM + MOC) di-HOLD (keputusan Maman 2026-10-08):
-- app masih dipakai sebatas fungsi sendiri, belum ada alur Risk Owner.
-- ROLLBACK di bagian bawah.
-- ============================================================


-- ============================================================
-- 1. DEFINISI KPI (target = USULAN, bisa diubah admin di aplikasi)
-- ============================================================
CREATE TABLE IF NOT EXISTS kpi_air (
  kode              TEXT PRIMARY KEY,
  nama              TEXT NOT NULL,
  kategori_pedoman  TEXT,              -- kelompok KPI di pedoman
  satuan            TEXT,
  target            NUMERIC,           -- NULL = informasi (tidak dinilai tercapai/tidak)
  arah              TEXT NOT NULL DEFAULT 'MIN' CHECK (arah IN ('MIN','MAX')),  -- MIN: ≥ target baik; MAX: ≤ target baik
  sumber            TEXT NOT NULL DEFAULT 'MANUAL' CHECK (sumber IN ('OTOMATIS','MANUAL')),
  keterangan        TEXT,
  urutan            SMALLINT NOT NULL DEFAULT 50,
  aktif             BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO kpi_air (kode, nama, kategori_pedoman, satuan, target, arah, sumber, keterangan, urutan) VALUES
  ('PENILAIAN',   'Equipment sudah dinilai criticality & integrity', 'Enhancement Status Asset Integrity', '%', 100, 'MIN', 'OTOMATIS',
   'Equipment dalam lingkup AIR yang punya penilaian criticality DAN status integrity (per akhir bulan)', 10),
  ('INTEG_VITAL', 'Peralatan vital dalam kondisi baik (High/Medium)', 'Technical Integrity & Equipment Condition', '%', 100, 'MIN', 'OTOMATIS',
   'Dari peralatan SECE/PCE, persentase yang status integrity-nya High/Medium (per akhir bulan)', 20),
  ('IZIN',        'Izin operasi berlaku',                            'Pemenuhan PLO', '%', 100, 'MIN', 'OTOMATIS',
   'Izin aktif (terbaru per jenis per unit) yang belum kedaluwarsa per akhir bulan', 30),
  ('AO',          'Availability fleet (Ao)',                         'Reliability & Clean Handover', '%', 90, 'MIN', 'OTOMATIS',
   'Σ uptime / Σ waktu kalender, semua downtime kecuali gejala — rumus sama dengan halaman Availability', 40),
  ('MTBF',        'MTBF fleet',                                      'Reliability & Clean Handover', 'jam', NULL, 'MIN', 'OTOMATIS',
   'Σ jam operasi / Σ failure (breakdown + troubleshoot) yang mulai di bulan ini', 41),
  ('MTTR',        'MTTR fleet',                                      'Reliability & Clean Handover', 'jam', NULL, 'MAX', 'OTOMATIS',
   'Rata-rata durasi perbaikan failure yang mulai di bulan ini', 42),
  ('FAIL_REC',    'Kegagalan tercatat lengkap (ISO 14224)',          'Integrity Risk Management', '%', 100, 'MIN', 'OTOMATIS',
   'Breakdown/troubleshoot bulan ini yang punya failure mode, dan failure cause bila sudah ditutup', 50),
  ('RCA_TELAT',   'Tindak lanjut RCA lewat due date',                'Integrity Risk Management', 'aksi', 0, 'MAX', 'OTOMATIS',
   'Aksi tindak lanjut RCA yang masih Open dan sudah melewati due date per akhir bulan', 51),
  ('SP_VITAL',    'Spare part Vital habis',                          'Integrity Risk Management', 'part', 0, 'MAX', 'OTOMATIS',
   'Snapshot saat dihitung: part kelas V dengan stok 0 (bukan karena dipinjam)', 52),
  ('ANGGARAN',    'Realisasi anggaran pemeliharaan',                 'Realisasi Anggaran', '%', NULL, 'MIN', 'MANUAL', 'Isi manual', 60),
  ('SAP',         'Pembenahan data SAP',                             'Pembenahan SAP', '%', 100, 'MIN', 'MANUAL', 'Isi manual', 70),
  ('JADWAL',      'PM terlaksana sesuai jadwal',                     'Schedule & Cost Control', '%', 90, 'MIN', 'MANUAL', 'Isi manual', 80),
  ('SAFETY',      'Insiden keselamatan terkait aset',                'Safety & Compliance Performance', 'kejadian', 0, 'MAX', 'MANUAL', 'Isi manual', 90),
  ('LINGKUNGAN',  'Insiden lingkungan terkait aset',                 'Environmental Performance', 'kejadian', 0, 'MAX', 'MANUAL', 'Isi manual', 91)
ON CONFLICT (kode) DO NOTHING;


-- ============================================================
-- 2. REALISASI PER BULAN + SAMBAL
-- ============================================================
CREATE TABLE IF NOT EXISTS laporan_air_bulanan (
  periode         DATE PRIMARY KEY CHECK (periode = date_trunc('month', periode)::date),
  status          TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','FINAL')),
  difinalkan_oleh TEXT,
  tgl_final       TIMESTAMPTZ,
  catatan         TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kpi_air_realisasi (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  periode            DATE NOT NULL CHECK (periode = date_trunc('month', periode)::date),
  kpi_kode           TEXT NOT NULL REFERENCES kpi_air(kode) ON DELETE CASCADE,
  nilai              NUMERIC,
  target_saat_itu    NUMERIC,     -- dibekukan dari kpi_air saat disimpan
  tercapai           BOOLEAN,     -- dihitung trigger
  detail             JSONB,       -- rincian perhitungan otomatis (pembilang/penyebut)
  sambal_siapa       TEXT,
  sambal_apa         TEXT,
  sambal_mengapa     TEXT,
  sambal_bagaimana   TEXT,
  sambal_aksi_lanjut TEXT,
  catatan            TEXT,
  updated_by         UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at         TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (periode, kpi_kode)
);

CREATE OR REPLACE FUNCTION fn_air_kpi_realisasi()
RETURNS TRIGGER AS $$
DECLARE k RECORD; st TEXT;
BEGIN
  SELECT status INTO st FROM laporan_air_bulanan WHERE periode = COALESCE(NEW.periode, OLD.periode);
  IF st = 'FINAL' THEN
    RAISE EXCEPTION 'Laporan periode % sudah FINAL — buka kembali (DRAFT) dulu untuk mengubah', to_char(COALESCE(NEW.periode, OLD.periode), 'Mon YYYY');
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  SELECT target, arah INTO k FROM kpi_air WHERE kode = NEW.kpi_kode;
  IF TG_OP = 'INSERT' OR NEW.target_saat_itu IS NULL THEN NEW.target_saat_itu := k.target; END IF;
  NEW.tercapai := CASE WHEN NEW.nilai IS NULL OR NEW.target_saat_itu IS NULL THEN NULL
                       WHEN k.arah = 'MIN' THEN NEW.nilai >= NEW.target_saat_itu
                       ELSE NEW.nilai <= NEW.target_saat_itu END;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_kpi_realisasi ON kpi_air_realisasi;
CREATE TRIGGER trg_air_kpi_realisasi
  BEFORE INSERT OR UPDATE OR DELETE ON kpi_air_realisasi
  FOR EACH ROW EXECUTE FUNCTION fn_air_kpi_realisasi();

-- FINAL hanya kalau semua KPI tidak tercapai sudah punya SAMBAL lengkap
CREATE OR REPLACE FUNCTION fn_air_laporan_final()
RETURNS TRIGGER AS $$
DECLARE kurang TEXT;
BEGIN
  IF NEW.status = 'FINAL' AND OLD.status IS DISTINCT FROM 'FINAL' THEN
    SELECT string_agg(k.nama, ', ' ORDER BY k.urutan) INTO kurang
      FROM kpi_air_realisasi r JOIN kpi_air k ON k.kode = r.kpi_kode
     WHERE r.periode = NEW.periode AND r.tercapai = false
       AND (NULLIF(trim(COALESCE(r.sambal_siapa, '')), '') IS NULL OR NULLIF(trim(COALESCE(r.sambal_apa, '')), '') IS NULL
         OR NULLIF(trim(COALESCE(r.sambal_mengapa, '')), '') IS NULL OR NULLIF(trim(COALESCE(r.sambal_bagaimana, '')), '') IS NULL
         OR NULLIF(trim(COALESCE(r.sambal_aksi_lanjut, '')), '') IS NULL);
    IF kurang IS NOT NULL THEN
      RAISE EXCEPTION 'SAMBAL belum lengkap untuk KPI tidak tercapai: %', kurang;
    END IF;
    NEW.tgl_final := NOW();
  END IF;
  IF NEW.status = 'DRAFT' THEN NEW.tgl_final := NULL; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_laporan_final ON laporan_air_bulanan;
CREATE TRIGGER trg_air_laporan_final
  BEFORE UPDATE ON laporan_air_bulanan
  FOR EACH ROW EXECUTE FUNCTION fn_air_laporan_final();


-- ============================================================
-- 3. PERHITUNGAN KPI OTOMATIS untuk satu bulan
--    Kondisi "per akhir bulan" memakai riwayat penilaian (bukan nilai saat ini),
--    jadi laporan bulan lalu tetap benar walau dihitung belakangan.
-- ============================================================
-- p_equipment_ids: opsional, batasi ke unit tertentu (mis. per rig / uji). NULL = semua.
CREATE OR REPLACE FUNCTION air_kpi_hitung(p_periode DATE, p_equipment_ids UUID[] DEFAULT NULL)
RETURNS TABLE (kode TEXT, nilai NUMERIC, detail JSONB) AS $$
DECLARE
  v_start TIMESTAMPTZ := date_trunc('month', p_periode);
  v_end   TIMESTAMPTZ := LEAST(date_trunc('month', p_periode) + interval '1 month', NOW());
  v_asof  DATE        := (LEAST(date_trunc('month', p_periode) + interval '1 month', NOW()) - interval '1 second')::date;
  n_scope INT; n_dinilai INT; n_vital INT; n_vital_ok INT; n_izin INT; n_izin_ok INT;
  n_fail INT; n_fail_ok INT; n_rca INT; n_sp INT;
  tot_period NUMERIC; tot_down NUMERIC; tot_op NUMERIC; n_fail_ev INT; avg_rep NUMERIC;
BEGIN
  IF v_start >= NOW() THEN RAISE EXCEPTION 'Periode belum dimulai'; END IF;

  CREATE TEMP TABLE IF NOT EXISTS _kpi_scope (id UUID, masuk TIMESTAMPTZ, crit TEXT, integ TEXT) ON COMMIT DROP;
  DELETE FROM _kpi_scope;
  INSERT INTO _kpi_scope
  SELECT e.id,
         GREATEST(v_start, COALESCE(e.tanggal_masuk_operasi::timestamptz, v_start)),
         (SELECT c.hasil FROM criticality_assessment c WHERE c.equipment_id = e.id AND c.tanggal <= v_asof
           ORDER BY c.tanggal DESC, c.created_at DESC LIMIT 1),
         (SELECT i.status FROM integrity_assessment i WHERE i.equipment_id = e.id AND i.tanggal <= v_asof AND i.konfirmasi = 'DIKONFIRMASI'
           ORDER BY i.tanggal DESC, i.created_at DESC LIMIT 1)
    FROM equipment e
   WHERE COALESCE(e.dalam_lingkup_air, true)
     AND (COALESCE(e.status_aset, 'ACTIVE') <> 'DECOMMISSIONED' OR e.decommission_tgl >= v_start::date)
     AND (e.tanggal_masuk_operasi IS NULL OR e.tanggal_masuk_operasi < v_end::date)
     AND (p_equipment_ids IS NULL OR e.id = ANY(p_equipment_ids));

  SELECT count(*), count(*) FILTER (WHERE crit IS NOT NULL AND integ IS NOT NULL),
         count(*) FILTER (WHERE crit IN ('SECE','PCE')),
         count(*) FILTER (WHERE crit IN ('SECE','PCE') AND integ IN ('HIGH','MEDIUM'))
    INTO n_scope, n_dinilai, n_vital, n_vital_ok FROM _kpi_scope;

  kode := 'PENILAIAN'; nilai := CASE WHEN n_scope > 0 THEN round(n_dinilai * 100.0 / n_scope, 1) END;
  detail := jsonb_build_object('sudah_dinilai', n_dinilai, 'total', n_scope); RETURN NEXT;
  kode := 'INTEG_VITAL'; nilai := CASE WHEN n_vital > 0 THEN round(n_vital_ok * 100.0 / n_vital, 1) END;
  detail := jsonb_build_object('baik', n_vital_ok, 'vital', n_vital); RETURN NEXT;

  -- Izin: terbaru per (unit, jenis) yang sudah terbit per akhir bulan
  SELECT count(*), count(*) FILTER (WHERE x.tgl_kedaluwarsa IS NULL OR x.tgl_kedaluwarsa >= v_asof)
    INTO n_izin, n_izin_ok
    FROM (SELECT DISTINCT ON (i.equipment_id, i.jenis) i.tgl_kedaluwarsa
            FROM izin_operasi i JOIN _kpi_scope s ON s.id = i.equipment_id
           WHERE i.tgl_terbit IS NULL OR i.tgl_terbit <= v_asof
           ORDER BY i.equipment_id, i.jenis, COALESCE(i.tgl_terbit, i.tgl_kedaluwarsa) DESC NULLS LAST, i.created_at DESC) x;
  kode := 'IZIN'; nilai := CASE WHEN n_izin > 0 THEN round(n_izin_ok * 100.0 / n_izin, 1) END;
  detail := jsonb_build_object('berlaku', n_izin_ok, 'total', n_izin); RETURN NEXT;

  -- Availability / MTBF / MTTR (rumus = halaman Availability; gejala tidak dihitung)
  SELECT COALESCE(sum(EXTRACT(EPOCH FROM (v_end - s.masuk)) / 3600.0), 0) INTO tot_period FROM _kpi_scope s WHERE s.masuk < v_end;
  SELECT COALESCE(sum(GREATEST(0, EXTRACT(EPOCH FROM (LEAST(COALESCE(d.end_at, v_end), v_end) - GREATEST(d.start_at, s.masuk))) / 3600.0)), 0)
    INTO tot_down
    FROM downtime_events d JOIN _kpi_scope s ON s.id = d.equipment_id
   WHERE d.category <> 'gejala' AND d.start_at < v_end AND COALESCE(d.end_at, v_end) > s.masuk;
  SELECT count(*), avg(EXTRACT(EPOCH FROM (LEAST(COALESCE(d.end_at, v_end), v_end) - d.start_at)) / 3600.0)
    INTO n_fail_ev, avg_rep
    FROM downtime_events d JOIN _kpi_scope s ON s.id = d.equipment_id
   WHERE d.category IN ('breakdown','troubleshoot') AND d.start_at >= v_start AND d.start_at < v_end;
  tot_op := GREATEST(0, tot_period - tot_down);
  kode := 'AO'; nilai := CASE WHEN tot_period > 0 THEN round(GREATEST(0, (tot_period - tot_down) / tot_period * 100), 2) END;
  detail := jsonb_build_object('jam_periode', round(tot_period), 'jam_downtime', round(tot_down, 1)); RETURN NEXT;
  kode := 'MTBF'; nilai := CASE WHEN n_fail_ev > 0 THEN round(tot_op / n_fail_ev, 1) END;
  detail := jsonb_build_object('jam_operasi', round(tot_op), 'failure', n_fail_ev); RETURN NEXT;
  kode := 'MTTR'; nilai := round(avg_rep, 1);
  detail := jsonb_build_object('failure', n_fail_ev); RETURN NEXT;

  SELECT count(*), count(*) FILTER (WHERE d.failure_mode IS NOT NULL AND (d.end_at IS NULL OR d.end_at >= v_end OR d.failure_cause IS NOT NULL))
    INTO n_fail, n_fail_ok
    FROM downtime_events d JOIN _kpi_scope s ON s.id = d.equipment_id
   WHERE d.category IN ('breakdown','troubleshoot') AND d.start_at >= v_start AND d.start_at < v_end;
  kode := 'FAIL_REC'; nilai := CASE WHEN n_fail > 0 THEN round(n_fail_ok * 100.0 / n_fail, 1) END;
  detail := jsonb_build_object('lengkap', n_fail_ok, 'total', n_fail); RETURN NEXT;

  SELECT count(*) INTO n_rca FROM rca_tindakan t JOIN rca_records r ON r.id = t.rca_id
   WHERE t.due_date < v_asof AND (t.status = 'OPEN' OR (t.status = 'SELESAI' AND t.tgl_selesai > v_asof))
     AND EXISTS (SELECT 1 FROM _kpi_scope s WHERE s.id = r.equipment_id OR s.id = ANY(r.equipment_ids));
  kode := 'RCA_TELAT'; nilai := n_rca; detail := jsonb_build_object('aksi', n_rca); RETURN NEXT;

  SELECT count(*) INTO n_sp FROM v_sparepart_vis WHERE alert_vital_habis AND p_equipment_ids IS NULL;
  kode := 'SP_VITAL'; nilai := n_sp; detail := jsonb_build_object('snapshot', NOW()::date); RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Isi / perbarui nilai KPI otomatis untuk satu bulan (SAMBAL & catatan tidak disentuh).
-- SECURITY INVOKER: RLS kpi_air_realisasi tetap berlaku (admin/manager).
CREATE OR REPLACE FUNCTION air_kpi_isi_otomatis(p_periode DATE, p_equipment_ids UUID[] DEFAULT NULL)
RETURNS INT AS $$
DECLARE v_per DATE := date_trunc('month', p_periode)::date; n INT := 0; r RECORD;
BEGIN
  INSERT INTO laporan_air_bulanan (periode) VALUES (v_per) ON CONFLICT (periode) DO NOTHING;
  FOR r IN SELECT h.* FROM air_kpi_hitung(v_per, p_equipment_ids) h JOIN kpi_air k ON k.kode = h.kode AND k.aktif AND k.sumber = 'OTOMATIS' LOOP
    INSERT INTO kpi_air_realisasi (periode, kpi_kode, nilai, detail, updated_by)
    VALUES (v_per, r.kode, r.nilai, r.detail, auth.uid())
    ON CONFLICT (periode, kpi_kode) DO UPDATE
      SET nilai = EXCLUDED.nilai, detail = EXCLUDED.detail, updated_by = EXCLUDED.updated_by,
          target_saat_itu = (SELECT target FROM kpi_air WHERE kode = EXCLUDED.kpi_kode);
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$ LANGUAGE plpgsql;
-- Versi lama (1 argumen) dari re-run sebelumnya dibuang supaya tidak ambigu
DROP FUNCTION IF EXISTS air_kpi_isi_otomatis(DATE);
DROP FUNCTION IF EXISTS air_kpi_hitung(DATE);
GRANT EXECUTE ON FUNCTION air_kpi_isi_otomatis(DATE, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION air_kpi_hitung(DATE, UUID[]) TO authenticated;


-- ============================================================
-- 4. RLS
-- ============================================================
ALTER TABLE kpi_air             ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpi_air_realisasi   ENABLE ROW LEVEL SECURITY;
ALTER TABLE laporan_air_bulanan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kpi_air_read"  ON kpi_air;
CREATE POLICY "kpi_air_read"  ON kpi_air FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "kpi_air_write" ON kpi_air;
CREATE POLICY "kpi_air_write" ON kpi_air FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "kpi_real_read"  ON kpi_air_realisasi;
CREATE POLICY "kpi_real_read"  ON kpi_air_realisasi FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "kpi_real_write" ON kpi_air_realisasi;
CREATE POLICY "kpi_real_write" ON kpi_air_realisasi FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());

DROP POLICY IF EXISTS "lap_air_read"  ON laporan_air_bulanan;
CREATE POLICY "lap_air_read"  ON laporan_air_bulanan FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "lap_air_write" ON laporan_air_bulanan;
CREATE POLICY "lap_air_write" ON laporan_air_bulanan FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());


-- ============================================================
-- 5. VERIFIKASI
-- ============================================================
-- Hitung KPI bulan lalu (tanpa menyimpan):
-- SELECT * FROM air_kpi_hitung((date_trunc('month', NOW()) - interval '1 month')::date);


-- ============================================================
-- ROLLBACK
-- ============================================================
-- DROP FUNCTION IF EXISTS air_kpi_isi_otomatis(DATE, UUID[]), air_kpi_hitung(DATE, UUID[]);
-- DROP TRIGGER IF EXISTS trg_air_laporan_final ON laporan_air_bulanan;
-- DROP TRIGGER IF EXISTS trg_air_kpi_realisasi ON kpi_air_realisasi;
-- DROP FUNCTION IF EXISTS fn_air_laporan_final(), fn_air_kpi_realisasi();
-- DROP TABLE IF EXISTS kpi_air_realisasi, laporan_air_bulanan, kpi_air;
