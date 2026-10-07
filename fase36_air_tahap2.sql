-- ============================================================
-- FASE 36: Pedoman AIR Tahap 2 — Strategi Pemeliharaan,
--          Klasifikasi Kegiatan, Failure Recording ISO 14224, RCA
-- Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0
--
-- Jalankan di Supabase SQL Editor SETELAH fase35. Aman re-run.
-- Uji: fase36_air_tahap2_test.sql (otomatis rollback).
--
-- Keputusan Maman (2026-10-07):
--  * downtime_events.wo_number = No. WO SAP (dipakai, tidak dibuat kolom baru)
--  * Klasifikasi kegiatan cukup dari kategori downtime (bukan Logbook)
--  * Pemicu RCA lama (>1x/12 bln per unit) DIGANTI aturan AIR:
--    >=3 failure, kategori equipment sama + failure mode sama, dalam 12 bulan
--  * Status RCA pakai alur baru; data lama dimigrasi
--  * Failure mode wajib saat catat breakdown/troubleshoot, failure cause
--    wajib saat ditutup — ditegakkan di UI (data lama tidak diblokir)
--
-- Tidak menyentuh Logbook. Tidak menghapus kolom lama.
-- ROLLBACK di bagian bawah.
-- ============================================================


-- ============================================================
-- 1. REFERENSI FAILURE MODE (ISO 14224 Annex B, yang relevan HHE/rig)
-- ============================================================
CREATE TABLE IF NOT EXISTS ref_failure_mode (
  kode       TEXT PRIMARY KEY,
  nama       TEXT NOT NULL,
  deskripsi  TEXT,
  urutan     SMALLINT NOT NULL DEFAULT 50,
  aktif      BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO ref_failure_mode (kode, nama, deskripsi, urutan) VALUES
  ('BRD','Breakdown',                      'Rusak total, alat berhenti/tidak bisa beroperasi', 10),
  ('FTS','Fail to start on demand',         'Tidak mau hidup/start saat dibutuhkan (engine, genset, pompa)', 11),
  ('STP','Fail to stop on demand',          'Tidak bisa dimatikan/berhenti saat diperintah', 12),
  ('UST','Spurious stop',                   'Mati/berhenti sendiri tanpa diperintah', 13),
  ('FTF','Fail to function on demand',      'Fungsi tidak bekerja saat dibutuhkan (rem, clutch, safety device, winch)', 14),
  ('FTC','Fail to close on demand',         'Tidak menutup saat diperintah (BOP, valve)', 15),
  ('FTO','Fail to open on demand',          'Tidak membuka saat diperintah (BOP, valve)', 16),
  ('DOP','Delayed operation',               'Respon/aksi lambat dari seharusnya (closing time BOP lambat)', 17),
  ('LCP','Leakage in closed position',      'Bocor saat posisi tertutup (BOP, valve)', 18),
  ('SPO','Spurious operation',              'Bekerja sendiri tanpa perintah', 19),
  ('ELP','External leakage - process medium','Bocor keluar: lumpur, fluida sumur, BBM', 20),
  ('ELU','External leakage - utility medium','Bocor keluar: oli, hidrolik, coolant, udara', 21),
  ('INL','Internal leakage',                'Bocor di dalam (seal, ring, valve internal)', 22),
  ('LOO','Low output',                      'Tenaga/tekanan/flow di bawah standar', 30),
  ('HIO','High output',                     'Output di atas standar (overspeed, overpressure)', 31),
  ('ERO','Erratic output',                  'Output naik-turun/tidak stabil (hunting)', 32),
  ('PDE','Parameter deviation',             'Parameter di luar batas (tekanan oli, suhu, voltage)', 33),
  ('OHE','Overheating',                     'Panas berlebih', 34),
  ('VIB','Vibration',                       'Getaran abnormal', 35),
  ('NOI','Noise',                           'Suara abnormal', 36),
  ('PLU','Plugged / choked',                'Tersumbat (filter, saluran, nozzle)', 37),
  ('AIR','Abnormal instrument reading',     'Indikator/gauge/sensor menunjukkan nilai salah', 38),
  ('STD','Structural deficiency',           'Kerusakan struktur: retak, bengkok, korosi, las putus (mast, substructure)', 40),
  ('SER','Minor in-service problems',       'Masalah kecil: baut kendor, kabel lepas, lampu mati', 41),
  ('OTH','Other',                           'Lainnya — jelaskan di catatan', 90),
  ('UNK','Unknown',                         'Belum diketahui', 99)
ON CONFLICT (kode) DO NOTHING;


-- ============================================================
-- 2. REFERENSI FAILURE CAUSE (ISO 14224 Annex B — root cause)
-- ============================================================
CREATE TABLE IF NOT EXISTS ref_failure_cause (
  kode       TEXT PRIMARY KEY,
  nama       TEXT NOT NULL,
  kelompok   TEXT NOT NULL CHECK (kelompok IN ('DESIGN','FABRICATION','OPERATION','MAINTENANCE','MANAGEMENT','MISC')),
  deskripsi  TEXT,
  aktif      BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO ref_failure_cause (kode, nama, kelompok, deskripsi) VALUES
  ('1.1','Improper capacity',      'DESIGN',      'Kapasitas/ukuran desain tidak sesuai beban kerja'),
  ('1.2','Improper material',      'DESIGN',      'Material tidak sesuai (spek part/bahan salah)'),
  ('2.1','Fabrication error',      'FABRICATION', 'Cacat pabrikasi/manufaktur'),
  ('2.2','Installation error',     'FABRICATION', 'Salah pasang/instalasi (alignment, torsi, orientasi)'),
  ('3.1','Off-design service',     'OPERATION',   'Dioperasikan di luar batas desain (overload, overspeed)'),
  ('3.2','Operating error',        'OPERATION',   'Kesalahan operator/prosedur operasi'),
  ('3.3','Maintenance error',      'MAINTENANCE', 'Kesalahan saat pemeliharaan (salah part, lupa kencang, kontaminasi)'),
  ('3.4','Expected wear and tear', 'MAINTENANCE', 'Aus wajar sesuai umur pakai'),
  ('4.1','Documentation error',    'MANAGEMENT',  'Prosedur/manual/SOP salah atau tidak ada'),
  ('4.2','Management error',       'MANAGEMENT',  'Perencanaan, organisasi, atau keputusan manajemen'),
  ('5.1','No cause found',         'MISC',        'Sudah diinvestigasi, penyebab tidak ditemukan'),
  ('5.2','Common cause',           'MISC',        'Satu penyebab membuat beberapa item gagal sekaligus'),
  ('5.3','Combined causes',        'MISC',        'Gabungan beberapa penyebab'),
  ('5.4','Other',                  'MISC',        'Lainnya — jelaskan di catatan'),
  ('5.5','Unknown',                'MISC',        'Belum diketahui')
ON CONFLICT (kode) DO NOTHING;


-- ============================================================
-- 3. FAILURE RECORDING di downtime_events (kolom opsional di DB;
--    kewajiban isi ditegakkan di UI untuk breakdown/troubleshoot)
-- ============================================================
ALTER TABLE downtime_events
  ADD COLUMN IF NOT EXISTS failure_mode        TEXT REFERENCES ref_failure_mode(kode),
  ADD COLUMN IF NOT EXISTS failure_cause       TEXT REFERENCES ref_failure_cause(kode),
  ADD COLUMN IF NOT EXISTS failure_code        TEXT,
  ADD COLUMN IF NOT EXISTS komponen_id         UUID REFERENCES equipment(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS jenis_corrective    TEXT CHECK (jenis_corrective IN ('IMMEDIATE','DEFERRED','REACTIVE')),
  ADD COLUMN IF NOT EXISTS sap_notification_no TEXT;

COMMENT ON COLUMN downtime_events.wo_number     IS 'No. Work Order SAP (dari Team Planner)';
COMMENT ON COLUMN downtime_events.failure_mode  IS 'AIR/ISO 14224: failure mode (ref_failure_mode)';
COMMENT ON COLUMN downtime_events.failure_cause IS 'AIR/ISO 14224: failure cause (ref_failure_cause), diisi saat ditutup';
COMMENT ON COLUMN downtime_events.komponen_id   IS 'AIR/ISO 14224: sub-unit/komponen (child equipment level 7-9) yang gagal';

CREATE INDEX IF NOT EXISTS idx_downtime_failure_mode ON downtime_events(failure_mode) WHERE failure_mode IS NOT NULL;


-- ============================================================
-- 4. KLASIFIKASI KEGIATAN PEMELIHARAAN (Gambar 8)
--    Dipetakan dari kategori downtime; data lama tidak diubah.
-- ============================================================
CREATE TABLE IF NOT EXISTS ref_jenis_kegiatan (
  kategori_downtime      TEXT PRIMARY KEY,
  termasuk_pemeliharaan  BOOLEAN NOT NULL DEFAULT true,
  jenis_utama            TEXT CHECK (jenis_utama IN ('PREVENTIVE','CORRECTIVE')),
  sub_jenis              TEXT CHECK (sub_jenis IN (
                           'TESTING_INSPECTION','CONDITION_MONITORING',            -- Predictive (payung Preventive)
                           'PERIODIC_TEST','SCHEDULED_REPLACEMENT','SCHEDULED_SERVICE',
                           'IMMEDIATE','DEFERRED','REACTIVE')),
  keterangan             TEXT
);

INSERT INTO ref_jenis_kegiatan (kategori_downtime, termasuk_pemeliharaan, jenis_utama, sub_jenis, keterangan) VALUES
  ('pm',                 true,  'PREVENTIVE', 'SCHEDULED_SERVICE',    'PM terjadwal'),
  ('inspeksi_terjadwal', true,  'PREVENTIVE', 'TESTING_INSPECTION',   'Predictive — inspeksi/test terjadwal'),
  ('gejala',             true,  'PREVENTIVE', 'CONDITION_MONITORING', 'Predictive — temuan kondisi sebelum rusak'),
  ('troubleshoot',       true,  'CORRECTIVE', 'IMMEDIATE',            'Default; bisa di-override per kejadian (jenis_corrective)'),
  ('breakdown',          true,  'CORRECTIVE', 'REACTIVE',             'Default; bisa di-override per kejadian (jenis_corrective)'),
  ('tunggu_spare',       false, NULL, NULL, 'Durasi tunggu, bukan kegiatan'),
  ('mobilisasi',         false, NULL, NULL, 'Bukan kegiatan pemeliharaan'),
  ('lainnya',            false, NULL, NULL, 'Bukan kegiatan pemeliharaan')
ON CONFLICT (kategori_downtime) DO NOTHING;

CREATE OR REPLACE VIEW v_kegiatan_pemeliharaan
WITH (security_invoker = true) AS
SELECT
  d.id, d.equipment_id, d.equipment_tag, d.unit_id, d.start_at, d.end_at, d.duration_hours,
  d.category, d.wo_number AS sap_wo_no, d.sap_notification_no,
  r.jenis_utama,
  CASE WHEN r.jenis_utama = 'CORRECTIVE' THEN COALESCE(d.jenis_corrective, r.sub_jenis) ELSE r.sub_jenis END AS sub_jenis,
  (r.sub_jenis IN ('TESTING_INSPECTION','CONDITION_MONITORING')) AS predictive
FROM downtime_events d
JOIN ref_jenis_kegiatan r ON r.kategori_downtime = d.category AND r.termasuk_pemeliharaan;


-- ============================================================
-- 5. STRATEGI PEMELIHARAAN (Gambar 7)
-- ============================================================
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS strategi_pemeliharaan TEXT
    CHECK (strategi_pemeliharaan IN ('REACTIVE','CBM_PREDICTIVE','PREVENTIVE','REDESIGN')),
  ADD COLUMN IF NOT EXISTS strategi_tgl DATE;

CREATE TABLE IF NOT EXISTS maintenance_strategy_assessment (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id      UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  tanggal           DATE NOT NULL DEFAULT CURRENT_DATE,
  m1 BOOLEAN, m2 BOOLEAN, m3 BOOLEAN, m4 BOOLEAN,
  hasil             TEXT CHECK (hasil IN ('REACTIVE','CBM_PREDICTIVE','PREVENTIVE','REDESIGN')),  -- trigger
  dasar             TEXT CHECK (dasar IN ('IOM','DATA_PABRIKAN','FMEA','RCM','PENGALAMAN','LAINNYA')),
  referensi_dokumen TEXT,
  penilai           TEXT,
  catatan           TEXT,
  created_by        UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_strat_assess_eq ON maintenance_strategy_assessment(equipment_id, tanggal DESC, created_at DESC);

CREATE OR REPLACE FUNCTION fn_air_hitung_strategi()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.m1 IS NULL THEN RAISE EXCEPTION 'M1 wajib dijawab'; END IF;
  IF NOT NEW.m1 THEN
    IF NEW.m2 IS NULL THEN RAISE EXCEPTION 'M2 wajib dijawab'; END IF;
    IF NOT NEW.m2 THEN NEW.hasil := 'REACTIVE'; RETURN NEW; END IF;
  END IF;
  IF NEW.m3 IS NULL THEN RAISE EXCEPTION 'M3 wajib dijawab'; END IF;
  IF NEW.m3 THEN NEW.hasil := 'CBM_PREDICTIVE'; RETURN NEW; END IF;
  IF NEW.m4 IS NULL THEN RAISE EXCEPTION 'M4 wajib dijawab'; END IF;
  NEW.hasil := CASE WHEN NEW.m4 THEN 'PREVENTIVE' ELSE 'REDESIGN' END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_hitung_strategi ON maintenance_strategy_assessment;
CREATE TRIGGER trg_air_hitung_strategi
  BEFORE INSERT OR UPDATE ON maintenance_strategy_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_hitung_strategi();

CREATE OR REPLACE FUNCTION fn_air_sync_strategi(p_equipment_id UUID)
RETURNS VOID AS $$
DECLARE r RECORD;
BEGIN
  SELECT tanggal, hasil INTO r FROM maintenance_strategy_assessment
   WHERE equipment_id = p_equipment_id ORDER BY tanggal DESC, created_at DESC LIMIT 1;
  UPDATE equipment SET strategi_pemeliharaan = r.hasil, strategi_tgl = r.tanggal WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION fn_air_after_strategi()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN PERFORM fn_air_sync_strategi(OLD.equipment_id); END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND (TG_OP = 'INSERT' OR NEW.equipment_id <> OLD.equipment_id) THEN
    PERFORM fn_air_sync_strategi(NEW.equipment_id);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_after_strategi ON maintenance_strategy_assessment;
CREATE TRIGGER trg_air_after_strategi
  AFTER INSERT OR UPDATE OR DELETE ON maintenance_strategy_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_after_strategi();


-- ============================================================
-- 6. RCA — perluas rca_records (bukan tabel baru)
-- ============================================================
ALTER TABLE rca_records
  ADD COLUMN IF NOT EXISTS pemicu               TEXT NOT NULL DEFAULT 'MANUAL'
    CHECK (pemicu IN ('REPETITIVE','LPO','MANUAL')),
  ADD COLUMN IF NOT EXISTS downtime_event_ids   UUID[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS equipment_ids        UUID[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS kategori_id          INT REFERENCES categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS failure_mode         TEXT REFERENCES ref_failure_mode(kode),
  ADD COLUMN IF NOT EXISTS ringkasan_penanganan TEXT,
  ADD COLUMN IF NOT EXISTS diverifikasi_oleh    TEXT,   -- Pejabat Berwenang
  ADD COLUMN IF NOT EXISTS monitoring_efektivitas TEXT,
  ADD COLUMN IF NOT EXISTS lpo                  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lpo_bopd             NUMERIC,
  ADD COLUMN IF NOT EXISTS lpo_mmscfd           NUMERIC,
  ADD COLUMN IF NOT EXISTS lpo_persen_produksi  NUMERIC,
  ADD COLUMN IF NOT EXISTS tgl_closed           DATE;

-- Status: alur baru AIR. Migrasi data lama: Open→ANALISIS, In Progress→TINDAK_LANJUT, Verified→CLOSED
ALTER TABLE rca_records DROP CONSTRAINT IF EXISTS rca_records_status_check;
UPDATE rca_records SET status = 'ANALISIS'      WHERE status = 'Open';
UPDATE rca_records SET status = 'TINDAK_LANJUT' WHERE status = 'In Progress';
UPDATE rca_records SET status = 'CLOSED', tgl_closed = COALESCE(tgl_closed, actual_verification_date)
  WHERE status = 'Verified';
ALTER TABLE rca_records ALTER COLUMN status SET DEFAULT 'DRAFT';
ALTER TABLE rca_records ADD CONSTRAINT rca_records_status_check
  CHECK (status IN ('DRAFT','ANALISIS','VERIFIKASI','TINDAK_LANJUT','MONITORING','CLOSED'));

-- Downtime yang dulu terhubung lewat downtime_event_id ikut masuk array
UPDATE rca_records SET downtime_event_ids = ARRAY[downtime_event_id]
  WHERE downtime_event_id IS NOT NULL AND downtime_event_ids = '{}';
UPDATE rca_records SET equipment_ids = ARRAY[equipment_id]
  WHERE equipment_ids = '{}';

-- Rencana tindak lanjut SMART (banyak aksi per RCA)
CREATE TABLE IF NOT EXISTS rca_tindakan (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rca_id              UUID NOT NULL REFERENCES rca_records(id) ON DELETE CASCADE,
  aksi                TEXT NOT NULL,          -- Specific
  ukuran_keberhasilan TEXT,                   -- Measurable
  pic                 TEXT,
  due_date            DATE,                   -- Time-bound
  status              TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','SELESAI','BATAL')),
  tgl_selesai         DATE,
  created_by          UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rca_tindakan_rca ON rca_tindakan(rca_id);


-- ============================================================
-- 7. PEMICU RCA OTOMATIS — repetitive failure (aturan AIR)
--    >= N failure, kategori equipment sama + failure mode sama,
--    dalam jendela M bulan (konfigurasi di air_config).
--    "Parameter operasi sama" didekati dengan kategori equipment sama.
-- ============================================================
INSERT INTO air_config (kunci, nilai, dari_pedoman, keterangan) VALUES
  ('rca_repetitive_min', '3', true,  'Jumlah failure berulang yang memicu RCA (pedoman: 3x)'),
  ('rca_repetitive_bulan', '12', false, 'Jendela waktu deteksi repetitive failure (usulan 12 bulan)')
ON CONFLICT (kunci) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_air_rca_repetitive()
RETURNS TRIGGER AS $$
DECLARE
  v_kat   INT;
  v_min   INT;
  v_bulan INT;
  v_win   INTERVAL;
  v_max   INT;
  v_ids   UUID[];
  v_eqs   UUID[];
  v_rca   UUID;
  v_nama  TEXT;
BEGIN
  IF NEW.failure_mode IS NULL OR NEW.category NOT IN ('breakdown','troubleshoot') OR NEW.equipment_id IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT kategori_id INTO v_kat FROM equipment WHERE id = NEW.equipment_id;
  IF v_kat IS NULL THEN RETURN NULL; END IF;

  SELECT COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'rca_repetitive_min'), 3),
         COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'rca_repetitive_bulan'), 12)
    INTO v_min, v_bulan;
  v_win := make_interval(months => v_bulan);

  -- Failure sejenis (kategori + mode sama) di sekitar kejadian ini, lalu
  -- hitung jendela M bulan terpadat yang memuat kejadian ini.
  WITH ev AS (
    SELECT d.id, d.equipment_id, d.start_at
      FROM downtime_events d JOIN equipment e ON e.id = d.equipment_id
     WHERE e.kategori_id = v_kat
       AND d.failure_mode = NEW.failure_mode
       AND d.category IN ('breakdown','troubleshoot')
       AND d.start_at >  NEW.start_at - v_win
       AND d.start_at <  NEW.start_at + v_win
  )
  SELECT max(w.cnt) INTO v_max FROM (
    SELECT (SELECT count(*) FROM ev b WHERE b.start_at >= a.start_at AND b.start_at < a.start_at + v_win) AS cnt
      FROM ev a
     WHERE a.start_at <= NEW.start_at AND a.start_at > NEW.start_at - v_win
  ) w;
  IF COALESCE(v_max, 0) < v_min THEN RETURN NULL; END IF;

  SELECT array_agg(d.id ORDER BY d.start_at), array_agg(DISTINCT d.equipment_id) INTO v_ids, v_eqs
    FROM downtime_events d JOIN equipment e ON e.id = d.equipment_id
   WHERE e.kategori_id = v_kat
     AND d.failure_mode = NEW.failure_mode
     AND d.category IN ('breakdown','troubleshoot')
     AND d.start_at >  NEW.start_at - v_win
     AND d.start_at <  NEW.start_at + v_win;

  -- RCA repetitive yang masih terbuka untuk kombinasi ini → perbarui; kalau belum ada → buat DRAFT
  SELECT id INTO v_rca FROM rca_records
   WHERE pemicu = 'REPETITIVE' AND kategori_id = v_kat AND failure_mode = NEW.failure_mode AND status <> 'CLOSED'
   ORDER BY created_at DESC LIMIT 1;

  IF v_rca IS NOT NULL THEN
    UPDATE rca_records SET
      downtime_event_ids = ARRAY(SELECT DISTINCT unnest(downtime_event_ids || v_ids)),
      equipment_ids      = ARRAY(SELECT DISTINCT unnest(equipment_ids || v_eqs))
    WHERE id = v_rca;
  ELSE
    SELECT c.name || ' — ' || m.nama INTO v_nama
      FROM categories c, ref_failure_mode m WHERE c.id = v_kat AND m.kode = NEW.failure_mode;
    INSERT INTO rca_records (equipment_id, downtime_event_id, failure_date, failure_description, status,
                             pemicu, downtime_event_ids, equipment_ids, kategori_id, failure_mode)
    VALUES (NEW.equipment_id, NEW.id, NEW.start_at::date,
            'Repetitive failure ' || v_max || 'x dalam ' || v_bulan || ' bulan: ' || COALESCE(v_nama, NEW.failure_mode),
            'DRAFT', 'REPETITIVE', v_ids, v_eqs, v_kat, NEW.failure_mode);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_rca_repetitive ON downtime_events;
CREATE TRIGGER trg_air_rca_repetitive
  AFTER INSERT OR UPDATE OF failure_mode, category, start_at, equipment_id ON downtime_events
  FOR EACH ROW EXECUTE FUNCTION fn_air_rca_repetitive();

-- Kandidat repetitive (untuk widget dashboard): kombinasi kategori + mode
-- dalam jendela M bulan terakhir, beserta status RCA-nya.
CREATE OR REPLACE VIEW v_air_repetitive_kandidat
WITH (security_invoker = true) AS
WITH cfg AS (
  SELECT COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'rca_repetitive_min'), 3)  AS n_min,
         COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'rca_repetitive_bulan'), 12) AS bulan
)
SELECT e.kategori_id, c.name AS kategori_nama, d.failure_mode, m.nama AS failure_mode_nama,
       count(*)::int AS jumlah, count(DISTINCT d.equipment_id)::int AS jumlah_unit,
       max(d.start_at) AS terakhir, cfg.n_min,
       (SELECT r.id FROM rca_records r WHERE r.pemicu = 'REPETITIVE' AND r.kategori_id = e.kategori_id
          AND r.failure_mode = d.failure_mode AND r.status <> 'CLOSED' ORDER BY r.created_at DESC LIMIT 1) AS rca_id
FROM downtime_events d
JOIN equipment e ON e.id = d.equipment_id
JOIN categories c ON c.id = e.kategori_id
JOIN ref_failure_mode m ON m.kode = d.failure_mode
CROSS JOIN cfg
WHERE d.category IN ('breakdown','troubleshoot')
  AND d.start_at >= NOW() - make_interval(months => cfg.bulan)
GROUP BY e.kategori_id, c.name, d.failure_mode, m.nama, cfg.n_min
HAVING count(*) >= 2;


-- ============================================================
-- 8. RLS
-- ============================================================
ALTER TABLE ref_failure_mode                ENABLE ROW LEVEL SECURITY;
ALTER TABLE ref_failure_cause               ENABLE ROW LEVEL SECURITY;
ALTER TABLE ref_jenis_kegiatan              ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_strategy_assessment ENABLE ROW LEVEL SECURITY;
ALTER TABLE rca_tindakan                    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ref_fm_read"  ON ref_failure_mode;
CREATE POLICY "ref_fm_read"  ON ref_failure_mode FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ref_fm_write" ON ref_failure_mode;
CREATE POLICY "ref_fm_write" ON ref_failure_mode FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "ref_fc_read"  ON ref_failure_cause;
CREATE POLICY "ref_fc_read"  ON ref_failure_cause FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ref_fc_write" ON ref_failure_cause;
CREATE POLICY "ref_fc_write" ON ref_failure_cause FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "ref_jk_read"  ON ref_jenis_kegiatan;
CREATE POLICY "ref_jk_read"  ON ref_jenis_kegiatan FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ref_jk_write" ON ref_jenis_kegiatan;
CREATE POLICY "ref_jk_write" ON ref_jenis_kegiatan FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "strat_assess_read"  ON maintenance_strategy_assessment;
CREATE POLICY "strat_assess_read"  ON maintenance_strategy_assessment FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "strat_assess_write" ON maintenance_strategy_assessment;
CREATE POLICY "strat_assess_write" ON maintenance_strategy_assessment FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());

-- rca_tindakan mengikuti pola rca_records (semua user login)
DROP POLICY IF EXISTS "rca_tindakan_auth" ON rca_tindakan;
CREATE POLICY "rca_tindakan_auth" ON rca_tindakan FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ============================================================
-- 9. VERIFIKASI
-- ============================================================
-- SELECT (SELECT count(*) FROM ref_failure_mode) AS mode, (SELECT count(*) FROM ref_failure_cause) AS cause,
--        (SELECT count(*) FROM ref_jenis_kegiatan) AS jenis;                       -- 26, 15, 8
-- SELECT status, count(*) FROM rca_records GROUP BY 1;                             -- tidak ada Open/In Progress/Verified
-- SELECT category, count(*) FROM downtime_events
--  WHERE category NOT IN (SELECT kategori_downtime FROM ref_jenis_kegiatan) GROUP BY 1;  -- harus kosong


-- ============================================================
-- ROLLBACK (hanya kalau benar-benar perlu)
-- ============================================================
-- DROP VIEW IF EXISTS v_air_repetitive_kandidat, v_kegiatan_pemeliharaan;
-- DROP TRIGGER IF EXISTS trg_air_rca_repetitive ON downtime_events;
-- DROP TRIGGER IF EXISTS trg_air_after_strategi ON maintenance_strategy_assessment;
-- DROP TRIGGER IF EXISTS trg_air_hitung_strategi ON maintenance_strategy_assessment;
-- DROP FUNCTION IF EXISTS fn_air_rca_repetitive(), fn_air_after_strategi(), fn_air_sync_strategi(UUID), fn_air_hitung_strategi();
-- DROP TABLE IF EXISTS rca_tindakan, maintenance_strategy_assessment, ref_jenis_kegiatan;
-- ALTER TABLE rca_records DROP CONSTRAINT IF EXISTS rca_records_status_check;
-- UPDATE rca_records SET status = CASE status WHEN 'CLOSED' THEN 'Verified'
--   WHEN 'TINDAK_LANJUT' THEN 'In Progress' WHEN 'MONITORING' THEN 'In Progress' ELSE 'Open' END;
-- DELETE FROM rca_records WHERE pemicu = 'REPETITIVE' AND why_1 IS NULL AND root_cause IS NULL;  -- DRAFT otomatis
-- ALTER TABLE rca_records ALTER COLUMN status SET DEFAULT 'Open';
-- ALTER TABLE rca_records ADD CONSTRAINT rca_records_status_check CHECK (status IN ('Open','In Progress','Verified'));
-- ALTER TABLE rca_records DROP COLUMN IF EXISTS pemicu, DROP COLUMN IF EXISTS downtime_event_ids,
--   DROP COLUMN IF EXISTS equipment_ids, DROP COLUMN IF EXISTS kategori_id, DROP COLUMN IF EXISTS failure_mode,
--   DROP COLUMN IF EXISTS ringkasan_penanganan, DROP COLUMN IF EXISTS diverifikasi_oleh,
--   DROP COLUMN IF EXISTS monitoring_efektivitas, DROP COLUMN IF EXISTS lpo, DROP COLUMN IF EXISTS lpo_bopd,
--   DROP COLUMN IF EXISTS lpo_mmscfd, DROP COLUMN IF EXISTS lpo_persen_produksi, DROP COLUMN IF EXISTS tgl_closed;
-- ALTER TABLE equipment DROP COLUMN IF EXISTS strategi_pemeliharaan, DROP COLUMN IF EXISTS strategi_tgl;
-- ALTER TABLE downtime_events DROP COLUMN IF EXISTS failure_mode, DROP COLUMN IF EXISTS failure_cause,
--   DROP COLUMN IF EXISTS failure_code, DROP COLUMN IF EXISTS komponen_id, DROP COLUMN IF EXISTS jenis_corrective,
--   DROP COLUMN IF EXISTS sap_notification_no;
-- DROP TABLE IF EXISTS ref_failure_cause, ref_failure_mode;
-- DELETE FROM air_config WHERE kunci IN ('rca_repetitive_min','rca_repetitive_bulan');
