-- ============================================================
-- FASE 38: Pedoman AIR Tahap 4A — Siklus Hidup Aset
--          Izin Operasi, RLA + biaya historis (LCCA), Decommissioning
-- Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0
--
-- Jalankan di Supabase SQL Editor SETELAH fase35–37. Aman re-run.
-- Uji: fase38_air_tahap4a_test.sql (otomatis rollback).
--
-- Keputusan Maman (2026-10-07):
--  * Data SKPI/sertifikat lama dipindah ke izin_operasi (riwayat lengkap).
--    Kolom lama di equipment TETAP terisi otomatis dari izin terbaru (trigger),
--    jadi dashboard, kalender, export & alert Telegram harian tidak diubah.
--  * Unit yang punya riwayat tidak dihapus — diarahkan ke Decommissioning (arsip).
--  * Jenis izin = daftar referensi yang bisa ditambah sendiri.
-- ROLLBACK di bagian bawah.
-- ============================================================


-- ============================================================
-- 1. IZIN OPERASI
-- ============================================================
CREATE TABLE IF NOT EXISTS ref_jenis_izin (
  kode        TEXT PRIMARY KEY,
  nama        TEXT NOT NULL,
  keterangan  TEXT,
  urutan      SMALLINT NOT NULL DEFAULT 50,
  aktif       BOOLEAN NOT NULL DEFAULT true
);
INSERT INTO ref_jenis_izin (kode, nama, keterangan, urutan) VALUES
  ('SKPI',      'SKPI',                         'Sertifikat Kelayakan Penggunaan Peralatan (Migas)', 10),
  ('PLO',       'PLO',                          'Persetujuan Layak Operasi (Permen ESDM 32/2021)', 20),
  ('COI',       'COI',                          'Certificate of Inspection', 30),
  ('KHI',       'KHI',                          'Keterangan Hasil Inspeksi', 40),
  ('COC',       'COC',                          'Certificate of Conformity', 50),
  ('LOAD_TEST', 'Sertifikat Load Test',         'Uji beban peralatan angkat', 60),
  ('NDT',       'Laporan / Sertifikat NDT',     'Non-Destructive Test', 70),
  ('LAINNYA',   'Sertifikat lainnya',           NULL, 99)
ON CONFLICT (kode) DO NOTHING;

CREATE TABLE IF NOT EXISTS izin_operasi (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id     UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  jenis            TEXT NOT NULL REFERENCES ref_jenis_izin(kode),
  nomor            TEXT,
  penerbit         TEXT,
  tgl_terbit       DATE,
  tgl_kedaluwarsa  DATE,                 -- NULL = tanpa masa berlaku
  lampiran         TEXT,                 -- link / nama file di tab Dokumen
  keterangan       TEXT,
  sumber_migrasi   TEXT,                 -- 'equipment_lama' untuk data hasil pindahan
  created_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_izin_equipment ON izin_operasi(equipment_id, jenis);
CREATE INDEX IF NOT EXISTS idx_izin_exp ON izin_operasi(tgl_kedaluwarsa);

-- Sinkron balik ke kolom lama equipment (dipakai 16 tempat + alert Telegram):
--  * SKPI  → nomor_skpi, skpi_start_date, skpi_end_date   (izin SKPI terbaru)
--  * COC   → coc_number                                    (COC terbaru)
--  * lainnya (selain SKPI/COC/PLO) → nomor_sertifikat_lain, tgl_terbit_sertifikat,
--    tgl_expired_sertifikat, lembaga_penerbit: dari izin TERBARU per jenis, diambil
--    yang paling cepat kedaluwarsa (paling mendesak) supaya alert lama tetap relevan.
CREATE OR REPLACE FUNCTION fn_air_sync_izin(p_equipment_id UUID)
RETURNS VOID AS $$
DECLARE s RECORD; c RECORD; o RECORD;
BEGIN
  SELECT nomor, tgl_terbit, tgl_kedaluwarsa INTO s FROM izin_operasi
   WHERE equipment_id = p_equipment_id AND jenis = 'SKPI'
   ORDER BY COALESCE(tgl_terbit, tgl_kedaluwarsa) DESC NULLS LAST, created_at DESC LIMIT 1;
  SELECT nomor INTO c FROM izin_operasi
   WHERE equipment_id = p_equipment_id AND jenis = 'COC'
   ORDER BY tgl_terbit DESC NULLS LAST, created_at DESC LIMIT 1;
  SELECT x.nomor, x.tgl_terbit, x.tgl_kedaluwarsa, x.penerbit INTO o FROM (
    SELECT DISTINCT ON (jenis) * FROM izin_operasi
     WHERE equipment_id = p_equipment_id AND jenis NOT IN ('SKPI','COC','PLO')
     ORDER BY jenis, COALESCE(tgl_terbit, tgl_kedaluwarsa) DESC NULLS LAST, created_at DESC
  ) x ORDER BY x.tgl_kedaluwarsa ASC NULLS LAST LIMIT 1;

  UPDATE equipment SET
    nomor_skpi             = s.nomor,
    skpi_start_date        = s.tgl_terbit,
    skpi_end_date          = s.tgl_kedaluwarsa,
    coc_number             = c.nomor,
    nomor_sertifikat_lain  = o.nomor,
    tgl_terbit_sertifikat  = o.tgl_terbit,
    tgl_expired_sertifikat = o.tgl_kedaluwarsa,
    lembaga_penerbit       = o.penerbit
  WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION fn_air_after_izin()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN PERFORM fn_air_sync_izin(OLD.equipment_id); END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND (TG_OP = 'INSERT' OR NEW.equipment_id <> OLD.equipment_id) THEN
    PERFORM fn_air_sync_izin(NEW.equipment_id);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_after_izin ON izin_operasi;
CREATE TRIGGER trg_air_after_izin
  AFTER INSERT OR UPDATE OR DELETE ON izin_operasi
  FOR EACH ROW EXECUTE FUNCTION fn_air_after_izin();

-- Migrasi satu kali data lama (dilewati kalau unit sudah punya izin hasil migrasi).
-- Trigger dimatikan sementara: nilai kolom lama sudah benar, updated_at tidak berubah.
ALTER TABLE izin_operasi DISABLE TRIGGER trg_air_after_izin;
INSERT INTO izin_operasi (equipment_id, jenis, nomor, penerbit, tgl_terbit, tgl_kedaluwarsa, sumber_migrasi)
SELECT e.id, 'SKPI', e.nomor_skpi, NULL, e.skpi_start_date, e.skpi_end_date, 'equipment_lama'
  FROM equipment e
 WHERE (NULLIF(trim(e.nomor_skpi), '') IS NOT NULL OR e.skpi_end_date IS NOT NULL)
   AND NOT EXISTS (SELECT 1 FROM izin_operasi i WHERE i.equipment_id = e.id AND i.sumber_migrasi = 'equipment_lama' AND i.jenis = 'SKPI');
INSERT INTO izin_operasi (equipment_id, jenis, nomor, sumber_migrasi)
SELECT e.id, 'COC', e.coc_number, 'equipment_lama'
  FROM equipment e
 WHERE NULLIF(trim(e.coc_number), '') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM izin_operasi i WHERE i.equipment_id = e.id AND i.sumber_migrasi = 'equipment_lama' AND i.jenis = 'COC');
INSERT INTO izin_operasi (equipment_id, jenis, nomor, penerbit, tgl_terbit, tgl_kedaluwarsa, sumber_migrasi, keterangan)
SELECT e.id, 'LAINNYA', e.nomor_sertifikat_lain, e.lembaga_penerbit, e.tgl_terbit_sertifikat, e.tgl_expired_sertifikat, 'equipment_lama',
       'Pindahan dari kolom "Sertifikat Lain" — ubah jenisnya bila perlu (COI/KHI/Load Test/NDT)'
  FROM equipment e
 WHERE (NULLIF(trim(e.nomor_sertifikat_lain), '') IS NOT NULL OR e.tgl_expired_sertifikat IS NOT NULL)
   AND NOT EXISTS (SELECT 1 FROM izin_operasi i WHERE i.equipment_id = e.id AND i.sumber_migrasi = 'equipment_lama' AND i.jenis = 'LAINNYA');
ALTER TABLE izin_operasi ENABLE TRIGGER trg_air_after_izin;

INSERT INTO air_config (kunci, nilai, dari_pedoman, keterangan) VALUES
  ('izin_peringatan_hari', '[60,30]', true, 'Alert izin operasi H-60 dan H-30 sebelum kedaluwarsa'),
  ('rla_peringatan_hari', '90', true, 'Alert H-90 sebelum batas layan RLA / jadwal RLA berikutnya')
ON CONFLICT (kunci) DO NOTHING;

CREATE OR REPLACE VIEW v_izin_operasi
WITH (security_invoker = true) AS
SELECT i.*, r.nama AS jenis_nama, e.tag_number, e.nama_equipment, e.assigned_unit_id, e.criticality, e.is_vital,
       (i.tgl_kedaluwarsa - CURRENT_DATE) AS sisa_hari,
       CASE WHEN i.tgl_kedaluwarsa IS NULL THEN 'TANPA_BATAS'
            WHEN i.tgl_kedaluwarsa < CURRENT_DATE THEN 'KEDALUWARSA'
            WHEN i.tgl_kedaluwarsa <= CURRENT_DATE + 60 THEN 'AKAN_HABIS'
            ELSE 'BERLAKU' END AS status,
       -- izin terbaru per jenis per unit (yang lama = riwayat)
       (i.id = (SELECT i2.id FROM izin_operasi i2 WHERE i2.equipment_id = i.equipment_id AND i2.jenis = i.jenis
                 ORDER BY COALESCE(i2.tgl_terbit, i2.tgl_kedaluwarsa) DESC NULLS LAST, i2.created_at DESC LIMIT 1)) AS terbaru
FROM izin_operasi i
JOIN ref_jenis_izin r ON r.kode = i.jenis
JOIN equipment e ON e.id = i.equipment_id;


-- ============================================================
-- 2. RLA — Remaining Life Assessment (mencatat hasil RLA yang sudah dilakukan)
-- ============================================================
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS sisa_umur_layan_sampai DATE,
  ADD COLUMN IF NOT EXISTS rla_tgl_berikutnya     DATE,
  ADD COLUMN IF NOT EXISTS rla_kesimpulan         TEXT;

CREATE TABLE IF NOT EXISTS rla_assessment (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id              UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  tanggal                   DATE NOT NULL DEFAULT CURRENT_DATE,
  pelaksana                 TEXT,          -- internal / vendor / lembaga
  nomor_laporan             TEXT,
  metode                    TEXT,
  umur_desain_tahun         NUMERIC,
  umur_desain_jam           NUMERIC,
  umur_operasi_tahun        NUMERIC,
  umur_operasi_jam          NUMERIC,
  sisa_umur_tahun           NUMERIC,
  sisa_umur_jam             NUMERIC,
  kesimpulan                TEXT NOT NULL CHECK (kesimpulan IN ('LAYAK_LANJUT','LAYAK_DENGAN_SYARAT','TIDAK_LAYAK')),
  syarat_rekomendasi        TEXT,
  batas_layan_baru          DATE,
  tgl_rla_berikutnya        DATE,
  terkait_perpanjangan_izin BOOLEAN NOT NULL DEFAULT false,
  izin_operasi_id           UUID REFERENCES izin_operasi(id) ON DELETE SET NULL,
  lampiran                  TEXT,
  created_by                UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at                TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rla_equipment ON rla_assessment(equipment_id, tanggal DESC);

-- Rekomendasi RLA → item tindak lanjut (PIC, due date, status)
CREATE TABLE IF NOT EXISTS rla_tindakan (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rla_id      UUID NOT NULL REFERENCES rla_assessment(id) ON DELETE CASCADE,
  aksi        TEXT NOT NULL,
  pic         TEXT,
  due_date    DATE,
  status      TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','SELESAI','BATAL')),
  tgl_selesai DATE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rla_tindakan ON rla_tindakan(rla_id);

-- integrity_assessment boleh bersumber dari RLA
ALTER TABLE integrity_assessment DROP CONSTRAINT IF EXISTS integrity_assessment_sumber_check;
ALTER TABLE integrity_assessment ADD CONSTRAINT integrity_assessment_sumber_check
  CHECK (sumber IN ('INSPEKSI','PM','LAPORAN_HARIAN','SOS','RLA','LAINNYA'));

CREATE OR REPLACE FUNCTION fn_air_sync_rla(p_equipment_id UUID)
RETURNS VOID AS $$
DECLARE r RECORD;
BEGIN
  SELECT batas_layan_baru, tgl_rla_berikutnya, kesimpulan INTO r FROM rla_assessment
   WHERE equipment_id = p_equipment_id ORDER BY tanggal DESC, created_at DESC LIMIT 1;
  UPDATE equipment SET sisa_umur_layan_sampai = r.batas_layan_baru,
                       rla_tgl_berikutnya     = r.tgl_rla_berikutnya,
                       rla_kesimpulan         = r.kesimpulan
   WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION fn_air_after_rla()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN PERFORM fn_air_sync_rla(OLD.equipment_id); END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND (TG_OP = 'INSERT' OR NEW.equipment_id <> OLD.equipment_id) THEN
    PERFORM fn_air_sync_rla(NEW.equipment_id);
  END IF;
  -- Kesimpulan tidak/bersyarat layak → usulan penilaian integrity (DRAFT, dikonfirmasi user)
  IF TG_OP = 'INSERT' AND NEW.kesimpulan IN ('TIDAK_LAYAK','LAYAK_DENGAN_SYARAT') THEN
    INSERT INTO integrity_assessment (equipment_id, tanggal, sumber, sumber_ref_id, s1, s2, s3, konfirmasi, temuan, penilai)
    VALUES (NEW.equipment_id, NEW.tanggal, 'RLA', NEW.id::text, false,
            NEW.kesimpulan = 'TIDAK_LAYAK', CASE WHEN NEW.kesimpulan = 'TIDAK_LAYAK' THEN NULL ELSE true END,
            'DRAFT',
            'Usulan otomatis dari RLA ' || COALESCE(NEW.nomor_laporan, '') || ': ' || NEW.kesimpulan
              || COALESCE(' — ' || NEW.syarat_rekomendasi, ''),
            NEW.pelaksana);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_after_rla ON rla_assessment;
CREATE TRIGGER trg_air_after_rla
  AFTER INSERT OR UPDATE OR DELETE ON rla_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_after_rla();


-- ============================================================
-- 3. BIAYA HISTORIS PER UNIT PER TAHUN (bahan LCCA: repair vs replace)
--    Sumber: Input Harian Logbook (daily_logs) — hanya dibaca.
-- ============================================================
CREATE OR REPLACE VIEW v_biaya_pemeliharaan_tahunan
WITH (security_invoker = true) AS
SELECT d.equipment_id,
       EXTRACT(YEAR FROM d.log_date)::int AS tahun,
       count(*)::int AS jumlah_kegiatan,
       sum(COALESCE((d.subtotals ->> 'manpower')::numeric, 0))  AS biaya_manpower,
       sum(COALESCE((d.subtotals ->> 'parts')::numeric, 0))     AS biaya_part,
       sum(COALESCE((d.subtotals ->> 'transport')::numeric, 0)) AS biaya_transport,
       sum(COALESCE((d.subtotals ->> 'vendor')::numeric, 0))    AS biaya_vendor,
       sum(COALESCE(d.total, 0)) AS biaya_total
FROM daily_logs d
WHERE d.equipment_id IS NOT NULL
  AND COALESCE(d.maintenance_type, '') NOT IN ('Peminjaman','Permintaan')
GROUP BY d.equipment_id, EXTRACT(YEAR FROM d.log_date);


-- ============================================================
-- 4. DECOMMISSIONING — arsip, bukan hapus
-- ============================================================
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS decommission_tgl      DATE,
  ADD COLUMN IF NOT EXISTS decommission_ref      TEXT,   -- referensi dokumen persetujuan
  ADD COLUMN IF NOT EXISTS decommission_catatan  TEXT;

-- Daftar hal yang masih terbuka dan menghalangi decommissioning
CREATE OR REPLACE FUNCTION air_decommission_blockers(p_equipment_id UUID)
RETURNS TABLE (jenis TEXT, jumlah INT, keterangan TEXT) AS $$
  SELECT * FROM (
    SELECT 'Downtime masih terbuka', count(*)::int, 'Tutup downtime (isi jam selesai)'
      FROM downtime_events WHERE equipment_id = p_equipment_id AND end_at IS NULL
    UNION ALL
    SELECT 'RCA belum Closed', count(*)::int, 'Selesaikan / tutup RCA'
      FROM rca_records WHERE status <> 'CLOSED' AND (equipment_id = p_equipment_id OR p_equipment_id = ANY(equipment_ids))
    UNION ALL
    SELECT 'Work Order Logbook terbuka', count(*)::int, 'Selesaikan / tolak WO di Logbook'
      FROM work_orders WHERE equipment_id = p_equipment_id AND status IN ('pending_approval','approved')
    UNION ALL
    SELECT 'Reservasi spare part aktif', count(*)::int, 'Ubah ke DIAMBIL / BATAL'
      FROM reservasi_sparepart WHERE equipment_id = p_equipment_id AND status IN ('DIAJUKAN','DISETUJUI')
    UNION ALL
    SELECT 'Tindak lanjut RLA terbuka', count(*)::int, 'Selesaikan / batalkan tindak lanjut RLA'
      FROM rla_tindakan t JOIN rla_assessment r ON r.id = t.rla_id WHERE r.equipment_id = p_equipment_id AND t.status = 'OPEN'
    UNION ALL
    SELECT 'Komponen (child) masih aktif', count(*)::int, 'Lepas komponen (Pemasangan) atau decommission dulu'
      FROM equipment WHERE parent_equipment_id = p_equipment_id AND COALESCE(status_aset, 'ACTIVE') <> 'DECOMMISSIONED'
  ) x WHERE x.count > 0;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;
GRANT EXECUTE ON FUNCTION air_decommission_blockers(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION fn_air_guard_decommission()
RETURNS TRIGGER AS $$
DECLARE b TEXT;
BEGIN
  IF NEW.status_aset = 'DECOMMISSIONED' AND OLD.status_aset IS DISTINCT FROM 'DECOMMISSIONED' THEN
    IF NULLIF(trim(COALESCE(NEW.decommission_ref, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Decommissioning wajib mencantumkan referensi dokumen persetujuan';
    END IF;
    SELECT string_agg(jenis || ' (' || jumlah || ')', ', ') INTO b FROM air_decommission_blockers(NEW.id);
    IF b IS NOT NULL THEN
      RAISE EXCEPTION 'Belum bisa decommission — masih ada: %', b;
    END IF;
    NEW.decommission_tgl := COALESCE(NEW.decommission_tgl, CURRENT_DATE);
    NEW.status_operasi   := 'Scrap';   -- fitur lama (guard Scrap, filter) ikut mengenali
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_guard_decommission ON equipment;
CREATE TRIGGER trg_air_guard_decommission
  BEFORE UPDATE OF status_aset ON equipment
  FOR EACH ROW EXECUTE FUNCTION fn_air_guard_decommission();

-- Unit yang punya riwayat → jangan dihapus (dipakai UI sebelum tombol Hapus)
CREATE OR REPLACE FUNCTION air_equipment_punya_riwayat(p_equipment_id UUID)
RETURNS TEXT AS $$
  SELECT NULLIF(concat_ws(', ',
    CASE WHEN EXISTS (SELECT 1 FROM downtime_events WHERE equipment_id = p_equipment_id) THEN 'downtime' END,
    CASE WHEN EXISTS (SELECT 1 FROM maintenance_log WHERE equipment_id = p_equipment_id) THEN 'maintenance log' END,
    CASE WHEN EXISTS (SELECT 1 FROM daily_logs WHERE equipment_id = p_equipment_id) THEN 'Input Harian' END,
    CASE WHEN EXISTS (SELECT 1 FROM work_orders WHERE equipment_id = p_equipment_id) THEN 'work order' END,
    CASE WHEN EXISTS (SELECT 1 FROM rca_records WHERE equipment_id = p_equipment_id) THEN 'RCA' END,
    CASE WHEN EXISTS (SELECT 1 FROM izin_operasi WHERE equipment_id = p_equipment_id) THEN 'izin operasi' END,
    CASE WHEN EXISTS (SELECT 1 FROM criticality_assessment WHERE equipment_id = p_equipment_id) THEN 'penilaian AIR' END
  ), '');
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;
GRANT EXECUTE ON FUNCTION air_equipment_punya_riwayat(UUID) TO authenticated;


-- ============================================================
-- 5. VIEW PERINGATAN SIKLUS HIDUP (dashboard AIR)
-- ============================================================
CREATE OR REPLACE VIEW v_air_lifecycle_alert
WITH (security_invoker = true) AS
WITH cfg AS (SELECT COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'rla_peringatan_hari'), 90) AS rla_hari)
SELECT 'IZIN'::text AS tipe, v.equipment_id, v.tag_number, v.nama_equipment, v.criticality, v.is_vital,
       v.jenis_nama || COALESCE(' ' || v.nomor, '') AS item, v.tgl_kedaluwarsa AS tanggal, v.sisa_hari, v.status
  FROM v_izin_operasi v
  JOIN equipment e ON e.id = v.equipment_id
 WHERE v.terbaru AND v.status IN ('KEDALUWARSA','AKAN_HABIS') AND COALESCE(e.status_aset, 'ACTIVE') <> 'DECOMMISSIONED'
UNION ALL
SELECT 'BATAS_LAYAN', e.id, e.tag_number, e.nama_equipment, e.criticality, e.is_vital,
       'Batas layan RLA (' || COALESCE(e.rla_kesimpulan, '-') || ')', e.sisa_umur_layan_sampai,
       (e.sisa_umur_layan_sampai - CURRENT_DATE),
       CASE WHEN e.sisa_umur_layan_sampai < CURRENT_DATE THEN 'LEWAT' ELSE 'MENDEKATI' END
  FROM equipment e, cfg
 WHERE e.sisa_umur_layan_sampai IS NOT NULL AND e.sisa_umur_layan_sampai <= CURRENT_DATE + cfg.rla_hari
   AND COALESCE(e.status_aset, 'ACTIVE') <> 'DECOMMISSIONED'
UNION ALL
SELECT 'RLA_BERIKUTNYA', e.id, e.tag_number, e.nama_equipment, e.criticality, e.is_vital,
       'Jadwal RLA berikutnya', e.rla_tgl_berikutnya, (e.rla_tgl_berikutnya - CURRENT_DATE),
       CASE WHEN e.rla_tgl_berikutnya < CURRENT_DATE THEN 'LEWAT' ELSE 'MENDEKATI' END
  FROM equipment e, cfg
 WHERE e.rla_tgl_berikutnya IS NOT NULL AND e.rla_tgl_berikutnya <= CURRENT_DATE + cfg.rla_hari
   AND COALESCE(e.status_aset, 'ACTIVE') <> 'DECOMMISSIONED';


-- ============================================================
-- 6. RLS
-- ============================================================
ALTER TABLE ref_jenis_izin ENABLE ROW LEVEL SECURITY;
ALTER TABLE izin_operasi   ENABLE ROW LEVEL SECURITY;
ALTER TABLE rla_assessment ENABLE ROW LEVEL SECURITY;
ALTER TABLE rla_tindakan   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ref_izin_read"  ON ref_jenis_izin;
CREATE POLICY "ref_izin_read"  ON ref_jenis_izin FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ref_izin_write" ON ref_jenis_izin;
CREATE POLICY "ref_izin_write" ON ref_jenis_izin FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "izin_read"  ON izin_operasi;
CREATE POLICY "izin_read"  ON izin_operasi FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "izin_write" ON izin_operasi;
CREATE POLICY "izin_write" ON izin_operasi FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());

DROP POLICY IF EXISTS "rla_read"  ON rla_assessment;
CREATE POLICY "rla_read"  ON rla_assessment FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "rla_write" ON rla_assessment;
CREATE POLICY "rla_write" ON rla_assessment FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());

DROP POLICY IF EXISTS "rla_tind_read"  ON rla_tindakan;
CREATE POLICY "rla_tind_read"  ON rla_tindakan FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "rla_tind_write" ON rla_tindakan;
CREATE POLICY "rla_tind_write" ON rla_tindakan FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());


-- ============================================================
-- 7. VERIFIKASI
-- ============================================================
-- Hasil migrasi izin lama per jenis:
-- SELECT jenis, count(*) FROM izin_operasi WHERE sumber_migrasi = 'equipment_lama' GROUP BY 1;
-- Izin yang kedaluwarsa / akan habis:
-- SELECT tag_number, item, tanggal, sisa_hari, status FROM v_air_lifecycle_alert ORDER BY tanggal;


-- ============================================================
-- ROLLBACK
-- ============================================================
-- DROP VIEW IF EXISTS v_air_lifecycle_alert, v_biaya_pemeliharaan_tahunan, v_izin_operasi;
-- DROP TRIGGER IF EXISTS trg_air_guard_decommission ON equipment;
-- DROP TRIGGER IF EXISTS trg_air_after_rla ON rla_assessment;
-- DROP TRIGGER IF EXISTS trg_air_after_izin ON izin_operasi;
-- DROP FUNCTION IF EXISTS air_equipment_punya_riwayat(UUID), fn_air_guard_decommission(), air_decommission_blockers(UUID),
--   fn_air_after_rla(), fn_air_sync_rla(UUID), fn_air_after_izin(), fn_air_sync_izin(UUID);
-- DELETE FROM integrity_assessment WHERE sumber = 'RLA';
-- ALTER TABLE integrity_assessment DROP CONSTRAINT IF EXISTS integrity_assessment_sumber_check;
-- ALTER TABLE integrity_assessment ADD CONSTRAINT integrity_assessment_sumber_check
--   CHECK (sumber IN ('INSPEKSI','PM','LAPORAN_HARIAN','SOS','LAINNYA'));
-- DROP TABLE IF EXISTS rla_tindakan, rla_assessment, izin_operasi, ref_jenis_izin;
--   (kolom SKPI/sertifikat lama di equipment tetap berisi nilai terakhir — aman)
-- ALTER TABLE equipment DROP COLUMN IF EXISTS sisa_umur_layan_sampai, DROP COLUMN IF EXISTS rla_tgl_berikutnya,
--   DROP COLUMN IF EXISTS rla_kesimpulan, DROP COLUMN IF EXISTS decommission_tgl, DROP COLUMN IF EXISTS decommission_ref,
--   DROP COLUMN IF EXISTS decommission_catatan;
-- DELETE FROM air_config WHERE kunci IN ('izin_peringatan_hari','rla_peringatan_hari');
