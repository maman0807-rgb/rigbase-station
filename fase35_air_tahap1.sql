-- ============================================================
-- FASE 35: Pedoman AIR Tahap 1 — Klasifikasi Aset, Criticality,
--          Status Integrity, Matriks Tindak Lanjut
-- Pedoman Pengelolaan Asset Integrity & Reliability (AIR)
-- No. A4-009/PHE23000/2026-S9 Rev.0, berlaku 26 Juni 2026
--
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
-- Uji trigger: jalankan fase35_air_tahap1_test.sql (otomatis rollback).
--
-- Prinsip:
--  * Tidak ada kolom/tabel lama yang dihapus atau di-rename.
--    status_operasi, tipe_kepemilikan, cof_score, criticality_level
--    tetap utuh & tetap dipakai fitur lama.
--  * tag_number TIDAK ditambah (sudah ada, UNIQUE NOT NULL).
--  * is_vital & dalam_lingkup_air diisi TRIGGER (bukan generated
--    column) supaya write lama yang kirim semua kolom tetap aman.
--  * Angka USULAN (bukan ketentuan pedoman) disimpan di air_config /
--    matriks_tindak_lanjut_air, bukan di-hardcode.
--
-- ROLLBACK (urutan terbalik) ada di paling bawah file.
-- ============================================================


-- ============================================================
-- 1. REFERENSI KATEGORI ASET (BAB I pedoman, 18 kategori)
-- ============================================================
CREATE TABLE IF NOT EXISTS ref_kategori_aset (
  kode                    TEXT PRIMARY KEY,
  nama                    TEXT NOT NULL,
  pendekatan              TEXT CHECK (pendekatan IN ('INTEGRITY','RELIABILITY')),
  pendekatan_dari_pedoman BOOLEAN NOT NULL DEFAULT false,  -- false = usulan, boleh diubah
  keterangan              TEXT
);

INSERT INTO ref_kategori_aset (kode, nama, pendekatan, pendekatan_dari_pedoman, keterangan) VALUES
  ('AUX','Auxiliaries',                    NULL,          false, NULL),
  ('CIV','Civil & Structure',              'INTEGRITY',   true,  'RBI, Corrosion Management, FFS'),
  ('DRL','Drilling',                       NULL,          false, NULL),
  ('ELE','Electrical',                     'RELIABILITY', true,  'RCM, FMEA, RAM, MTBF/MTTR'),
  ('GSP','General Support',                NULL,          false, NULL),
  ('ICC','Instrument, Control & Custody',  'RELIABILITY', true,  'RCM, FMEA, RAM, MTBF/MTTR'),
  ('LFT','Lifting',                        'RELIABILITY', false, 'Usulan: fokus HHE = availability'),
  ('MAR','Marine',                         NULL,          false, NULL),
  ('PIP','Pipeline',                       'INTEGRITY',   true,  'RBI, Corrosion Management, FFS'),
  ('ROT','Rotating',                       'RELIABILITY', true,  'RCM, FMEA, RAM, MTBF/MTTR'),
  ('SNE','Safety & Environment',           NULL,          false, NULL),
  ('STA','Static',                         'INTEGRITY',   true,  'RBI, Corrosion Management, FFS'),
  ('SUB','Subsea Production',              NULL,          false, NULL),
  ('TRK','Truck Fleet',                    'RELIABILITY', false, 'Usulan: fokus HHE = availability'),
  ('UTL','Utilities',                      NULL,          false, NULL),
  ('VSL','Vessel Fleet',                   NULL,          false, NULL),
  ('WCO','Well Completion',                NULL,          false, NULL),
  ('WIN','Well Intervention',              'RELIABILITY', false, 'Usulan: rig well service, fokus availability')
ON CONFLICT (kode) DO NOTHING;


-- ============================================================
-- 2. KONFIGURASI AIR (nilai usulan yang bisa diubah tanpa ubah kode)
-- ============================================================
CREATE TABLE IF NOT EXISTS air_config (
  kunci       TEXT PRIMARY KEY,
  nilai       JSONB NOT NULL,
  dari_pedoman BOOLEAN NOT NULL DEFAULT false,   -- false = usulan
  keterangan  TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO air_config (kunci, nilai, dari_pedoman, keterangan) VALUES
  ('criticality_validasi_ulang_bulan', '24', true,
   'Metode KUALITATIF wajib divalidasi ulang paling lambat 2 tahun'),
  ('peringatan_validasi_hari', '60', false,
   'Flag perlu_validasi_criticality muncul X hari sebelum jatuh tempo'),
  ('eca_mapping', '{"pce_min":15,"important_min":5,"dampak_kandidat_sece":5}', false,
   'Skor ECA (dampak x probabilitas): >=pce_min PCE, >=important_min IMPORTANT, sisanya SECONDARY. Dibaca dari warna Gambar 5 — PERLU DIVERIFIKASI. Dampak 5 = kandidat SECE (konfirmasi via PHA).')
ON CONFLICT (kunci) DO NOTHING;


-- ============================================================
-- 3. PEMETAAN KATEGORI eRAMHoist → KATEGORI ASET AIR
-- ============================================================
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS kategori_aset_default TEXT REFERENCES ref_kategori_aset(kode);

-- Urutan WHEN penting: yang lebih spesifik di atas.
-- Kategori yang tidak cocok pola manapun dibiarkan NULL → muncul di
-- query verifikasi (bagian 11) untuk diisi manual.
UPDATE categories SET kategori_aset_default = CASE
  WHEN name ILIKE '%fire%' OR name ILIKE '%damkar%'                               THEN 'SNE'
  WHEN name ILIKE '%auxil%' OR name ILIKE '%auxilary%'                             THEN 'AUX'
  WHEN name ILIKE '%backhoe%' OR name ILIKE '%bulldozer%' OR name ILIKE '%compactor%'
    OR name ILIKE '%excavator%' OR name ILIKE '%grader%' OR name = 'SCM'           THEN 'GSP'
  WHEN name ILIKE 'BOP%' OR name ILIKE '%well control%' OR name ILIKE '%accumulator%' OR name ILIKE '%tank%'
    OR name ILIKE '%manifold%' OR name ILIKE '%lubricator%'                        THEN 'STA'
  WHEN name ILIKE '%genset%' OR name ILIKE '%generator%' OR name ILIKE '%lampu%' OR name ILIKE '%light%'
    OR name ILIKE '%stand lamp%'                                                   THEN 'ELE'
  WHEN name ILIKE '%control%' OR name ILIKE '%instrument%'
    OR name ILIKE '%weight indicator%' OR name ILIKE '%console%'                  THEN 'ICC'
  WHEN name ILIKE '%mudpump%' OR name ILIKE '%mud pump%' OR name ILIKE '%engine%'
    OR name ILIKE '%pump%' OR name ILIKE '%compressor%' OR name ILIKE '%kompresor%'
    OR name ILIKE '%transmisi%' OR name ILIKE '%transmission%' OR name ILIKE '%pompa%'
    OR name ILIKE '%powerpack%' OR name ILIKE '%circulating%' OR name ILIKE '%rotating%' THEN 'ROT'
  WHEN name ILIKE '%forklift%' OR name ILIKE '%crane%' OR name ILIKE '%travelling block%'
    OR name ILIKE '%handling%' OR name ILIKE '%elevator%' OR name ILIKE '%slip%'
    OR name ILIKE '%tong%' OR name ILIKE '%winch%' OR name ILIKE '%clamp%'
    OR name ILIKE '%man lift%' OR name ILIKE '%manlift%'                           THEN 'LFT'
  WHEN name ILIKE '%truck%' OR name ILIKE '%truk%' OR name ILIKE '%trailer%'
    OR name ILIKE '%dump%' OR name ILIKE '%tractor%' OR name ILIKE '%prime mover%'
    OR name ILIKE '%primover%'                                                     THEN 'TRK'
  WHEN name ILIKE 'BW%' OR name ILIKE '%drawwork%' OR name ILIKE '%mast%'
    OR name ILIKE '%sub structure%' OR name ILIKE '%substructure%'
    OR name ILIKE '%rotary table%' OR name ILIKE '%swivel%' OR name ILIKE '%slickline%'
    OR name ILIKE '%wireline%' OR name ILIKE '%MTU%' OR name ILIKE '%rig%'
    OR name ILIKE '%carrier%' OR name ILIKE '%hoisting%'                           THEN 'WIN'
  WHEN name ILIKE '%safety%' OR name ILIKE '%escape%'                              THEN 'SNE'
  WHEN name ILIKE '%portacamp%' OR name ILIKE '%camp%'                             THEN 'GSP'
  ELSE NULL END
WHERE kategori_aset_default IS NULL;


-- ============================================================
-- 4. KOLOM BARU DI equipment
-- ============================================================
ALTER TABLE equipment
  -- Klasifikasi
  ADD COLUMN IF NOT EXISTS kategori_aset       TEXT REFERENCES ref_kategori_aset(kode),
  ADD COLUMN IF NOT EXISTS status_aset         TEXT DEFAULT 'ACTIVE'
    CHECK (status_aset IN ('ACTIVE','STANDBY','IDLE','ABANDONED','DECOMMISSIONED')),
  ADD COLUMN IF NOT EXISTS kepemilikan         TEXT DEFAULT 'MILIK'
    CHECK (kepemilikan IN ('MILIK','SEWA')),
  ADD COLUMN IF NOT EXISTS alasan_di_luar_lingkup TEXT
    CHECK (alasan_di_luar_lingkup IN ('NON_OPERASI','SEWA','WELL_INTEGRITY','BOT','KSO','GENERAL_SERVICES')),
  ADD COLUMN IF NOT EXISTS dalam_lingkup_air   BOOLEAN DEFAULT true,     -- diisi trigger
  ADD COLUMN IF NOT EXISTS sap_equipment_no    TEXT,
  ADD COLUMN IF NOT EXISTS taxonomy_level      SMALLINT
    CHECK (taxonomy_level IS NULL OR taxonomy_level BETWEEN 6 AND 9), -- NULL = otomatis (6 induk / 7 anak)
  -- Criticality
  ADD COLUMN IF NOT EXISTS criticality         TEXT
    CHECK (criticality IN ('SECE','PCE','IMPORTANT','SECONDARY')),
  ADD COLUMN IF NOT EXISTS is_vital            BOOLEAN DEFAULT false,    -- diisi trigger
  ADD COLUMN IF NOT EXISTS criticality_metode  TEXT
    CHECK (criticality_metode IN ('PHA','ECA','KUALITATIF')),
  ADD COLUMN IF NOT EXISTS criticality_tgl_penetapan      DATE,
  ADD COLUMN IF NOT EXISTS criticality_tgl_validasi_ulang DATE,
  -- Status integrity
  ADD COLUMN IF NOT EXISTS status_integrity    TEXT
    CHECK (status_integrity IN ('BREAKDOWN','LOW','MEDIUM','HIGH')),
  ADD COLUMN IF NOT EXISTS status_integrity_tgl DATE;

COMMENT ON COLUMN equipment.kategori_aset      IS 'AIR: kategori aset (ref_kategori_aset). Default dari categories.kategori_aset_default';
COMMENT ON COLUMN equipment.status_aset        IS 'AIR: ACTIVE/STANDBY/IDLE/ABANDONED/DECOMMISSIONED. Terpisah dari status_operasi (yang tetap dipakai fitur lama)';
COMMENT ON COLUMN equipment.dalam_lingkup_air  IS 'AIR: otomatis false jika alasan_di_luar_lingkup terisi (trigger)';
COMMENT ON COLUMN equipment.is_vital           IS 'AIR: otomatis true jika criticality SECE/PCE (trigger)';
COMMENT ON COLUMN equipment.taxonomy_level     IS 'ISO 14224 level 6-9. NULL = otomatis: 6 kalau tanpa parent, 7 kalau punya parent_equipment_id';

-- Backfill di bawah tidak boleh mengubah updated_at (itu jejak edit user).
-- Trigger updated_at dimatikan sementara, dinyalakan lagi di akhir bagian 5.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_equipment_updated_at' AND tgrelid = 'equipment'::regclass) THEN
    EXECUTE 'ALTER TABLE equipment DISABLE TRIGGER trg_equipment_updated_at';
  END IF;
END $$;

-- Backfill status_aset dari status_operasi (disetujui: sesuai TKO terbaru).
-- Hanya baris yang masih default ACTIVE & belum pernah diubah manual.
UPDATE equipment SET status_aset = 'STANDBY'
  WHERE status_operasi = 'Standby' AND status_aset = 'ACTIVE';
UPDATE equipment SET status_aset = 'DECOMMISSIONED'
  WHERE status_operasi = 'Scrap'   AND status_aset = 'ACTIVE';

-- Backfill kategori_aset dari pemetaan kategori
UPDATE equipment e SET kategori_aset = c.kategori_aset_default
  FROM categories c
  WHERE e.kategori_id = c.id AND e.kategori_aset IS NULL AND c.kategori_aset_default IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_equipment_criticality      ON equipment(criticality);
CREATE INDEX IF NOT EXISTS idx_equipment_status_integrity ON equipment(status_integrity);


-- ============================================================
-- 5. TRIGGER equipment: default & kolom turunan
--    Berlaku untuk semua jalur (app, Logbook, bot, SQL manual).
-- ============================================================
CREATE OR REPLACE FUNCTION fn_air_equipment_defaults()
RETURNS TRIGGER AS $$
BEGIN
  NEW.status_aset := COALESCE(NEW.status_aset, 'ACTIVE');
  NEW.kepemilikan := COALESCE(NEW.kepemilikan, 'MILIK');
  -- Kategori aset ikut kategori eRAMHoist kalau belum diisi manual
  IF NEW.kategori_aset IS NULL AND NEW.kategori_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.kategori_id IS DISTINCT FROM OLD.kategori_id) THEN
    SELECT kategori_aset_default INTO NEW.kategori_aset
      FROM categories WHERE id = NEW.kategori_id;
  END IF;
  NEW.dalam_lingkup_air := (NEW.alasan_di_luar_lingkup IS NULL);
  NEW.is_vital          := COALESCE(NEW.criticality IN ('SECE','PCE'), false);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_equipment_defaults ON equipment;
CREATE TRIGGER trg_air_equipment_defaults
  BEFORE INSERT OR UPDATE ON equipment
  FOR EACH ROW EXECUTE FUNCTION fn_air_equipment_defaults();

-- Sinkronkan kolom turunan untuk data lama
UPDATE equipment SET
  dalam_lingkup_air = (alasan_di_luar_lingkup IS NULL),
  is_vital = COALESCE(criticality IN ('SECE','PCE'), false)
WHERE dalam_lingkup_air IS DISTINCT FROM (alasan_di_luar_lingkup IS NULL)
   OR is_vital IS DISTINCT FROM COALESCE(criticality IN ('SECE','PCE'), false);

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_equipment_updated_at' AND tgrelid = 'equipment'::regclass) THEN
    EXECUTE 'ALTER TABLE equipment ENABLE TRIGGER trg_equipment_updated_at';
  END IF;
END $$;


-- ============================================================
-- 6. CRITICALITY ASSESSMENT (riwayat penilaian)
-- ============================================================
CREATE TABLE IF NOT EXISTS criticality_assessment (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id      UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  tanggal           DATE NOT NULL DEFAULT CURRENT_DATE,
  metode            TEXT NOT NULL CHECK (metode IN ('PHA','ECA','KUALITATIF')),
  -- KUALITATIF (Gambar 6)
  q1 BOOLEAN, q2 BOOLEAN, q3 BOOLEAN, q4 BOOLEAN, q5 BOOLEAN,
  -- ECA (Gambar 5)
  dampak            SMALLINT CHECK (dampak BETWEEN 1 AND 5),
  probabilitas      SMALLINT CHECK (probabilitas BETWEEN 1 AND 5),
  skor              SMALLINT,          -- diisi trigger
  kandidat_sece     BOOLEAN NOT NULL DEFAULT false,  -- ECA dampak 5 → perlu konfirmasi PHA
  -- Hasil
  hasil             TEXT CHECK (hasil IN ('SECE','PCE','IMPORTANT','SECONDARY')),
  penilai           TEXT,
  referensi_dokumen TEXT,
  catatan           TEXT,
  created_by        UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_crit_assess_eq ON criticality_assessment(equipment_id, tanggal DESC, created_at DESC);

-- Hitung hasil sesuai metode
CREATE OR REPLACE FUNCTION fn_air_hitung_criticality()
RETURNS TRIGGER AS $$
DECLARE
  cfg JSONB;
BEGIN
  NEW.skor := NULL;
  NEW.kandidat_sece := false;

  IF NEW.metode = 'KUALITATIF' THEN
    -- Dievaluasi berurutan; berhenti begitu hasil ditentukan.
    IF NEW.q1 IS NULL THEN RAISE EXCEPTION 'Q1 wajib dijawab'; END IF;
    IF NEW.q1 THEN NEW.hasil := 'SECE'; RETURN NEW; END IF;
    IF NEW.q2 IS NULL THEN RAISE EXCEPTION 'Q2 wajib dijawab'; END IF;
    IF NEW.q2 THEN NEW.hasil := 'SECE'; RETURN NEW; END IF;
    IF NEW.q3 IS NULL THEN RAISE EXCEPTION 'Q3 wajib dijawab'; END IF;
    IF NEW.q3 THEN NEW.hasil := 'SECE'; RETURN NEW; END IF;
    IF NEW.q4 IS NULL THEN RAISE EXCEPTION 'Q4 wajib dijawab'; END IF;
    IF NEW.q4 THEN NEW.hasil := 'PCE'; RETURN NEW; END IF;
    IF NEW.q5 IS NULL THEN RAISE EXCEPTION 'Q5 wajib dijawab'; END IF;
    NEW.hasil := CASE WHEN NEW.q5 THEN 'IMPORTANT' ELSE 'SECONDARY' END;

  ELSIF NEW.metode = 'ECA' THEN
    IF NEW.dampak IS NULL OR NEW.probabilitas IS NULL THEN
      RAISE EXCEPTION 'ECA: dampak dan probabilitas wajib diisi';
    END IF;
    SELECT nilai INTO cfg FROM air_config WHERE kunci = 'eca_mapping';
    cfg := COALESCE(cfg, '{"pce_min":15,"important_min":5,"dampak_kandidat_sece":5}'::jsonb);
    NEW.skor := NEW.dampak * NEW.probabilitas;
    NEW.hasil := CASE
      WHEN NEW.skor >= (cfg->>'pce_min')::int       THEN 'PCE'
      WHEN NEW.skor >= (cfg->>'important_min')::int THEN 'IMPORTANT'
      ELSE 'SECONDARY' END;
    NEW.kandidat_sece := NEW.dampak >= (cfg->>'dampak_kandidat_sece')::int;

  ELSIF NEW.metode = 'PHA' THEN
    IF NEW.hasil IS NULL THEN RAISE EXCEPTION 'PHA: hasil wajib diisi manual'; END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_hitung_criticality ON criticality_assessment;
CREATE TRIGGER trg_air_hitung_criticality
  BEFORE INSERT OR UPDATE ON criticality_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_hitung_criticality();

-- Penilaian terbaru → master equipment
CREATE OR REPLACE FUNCTION fn_air_sync_criticality(p_equipment_id UUID)
RETURNS VOID AS $$
DECLARE
  r RECORD;
  bulan INT;
BEGIN
  SELECT tanggal, metode, hasil INTO r
    FROM criticality_assessment
   WHERE equipment_id = p_equipment_id
   ORDER BY tanggal DESC, created_at DESC
   LIMIT 1;
  SELECT (nilai #>> '{}')::int INTO bulan FROM air_config WHERE kunci = 'criticality_validasi_ulang_bulan';
  bulan := COALESCE(bulan, 24);

  UPDATE equipment SET
    criticality                    = r.hasil,
    criticality_metode             = r.metode,
    criticality_tgl_penetapan      = r.tanggal,
    criticality_tgl_validasi_ulang = CASE WHEN r.metode = 'KUALITATIF'
                                          THEN (r.tanggal + make_interval(months => bulan))::date
                                          ELSE NULL END
  WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION fn_air_after_criticality()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN PERFORM fn_air_sync_criticality(OLD.equipment_id); END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND (TG_OP = 'INSERT' OR NEW.equipment_id <> OLD.equipment_id) THEN
    PERFORM fn_air_sync_criticality(NEW.equipment_id);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_after_criticality ON criticality_assessment;
CREATE TRIGGER trg_air_after_criticality
  AFTER INSERT OR UPDATE OR DELETE ON criticality_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_after_criticality();


-- ============================================================
-- 7. PERFORMANCE STANDARD (ditentukan Field per jenis peralatan)
-- ============================================================
CREATE TABLE IF NOT EXISTS performance_standard (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kategori_id    INT REFERENCES categories(id) ON DELETE CASCADE,   -- jenis equipment eRAMHoist
  kategori_aset  TEXT REFERENCES ref_kategori_aset(kode),           -- atau berlaku per kategori AIR
  parameter      TEXT NOT NULL,
  batas_min      NUMERIC,
  batas_max      NUMERIC,
  satuan         TEXT,
  keterangan     TEXT,
  aktif          BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  CHECK (kategori_id IS NOT NULL OR kategori_aset IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_perf_std_kategori ON performance_standard(kategori_id);


-- ============================================================
-- 8. INTEGRITY ASSESSMENT (Gambar 9 & Tabel 5)
-- ============================================================
CREATE TABLE IF NOT EXISTS integrity_assessment (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id   UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  tanggal        DATE NOT NULL DEFAULT CURRENT_DATE,
  sumber         TEXT NOT NULL DEFAULT 'LAINNYA'
    CHECK (sumber IN ('INSPEKSI','PM','LAPORAN_HARIAN','SOS','LAINNYA')),
  sumber_ref_id  TEXT,
  s1 BOOLEAN, s2 BOOLEAN, s3 BOOLEAN,
  status         TEXT CHECK (status IN ('BREAKDOWN','LOW','MEDIUM','HIGH')),  -- diisi trigger
  -- DRAFT = usulan otomatis (Laporan Harian / SOS) yang belum dikonfirmasi;
  -- hanya DIKONFIRMASI yang meng-update master equipment.
  konfirmasi     TEXT NOT NULL DEFAULT 'DIKONFIRMASI'
    CHECK (konfirmasi IN ('DRAFT','DIKONFIRMASI')),
  temuan         TEXT,
  penilai        TEXT,
  created_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_integ_assess_eq ON integrity_assessment(equipment_id, tanggal DESC, created_at DESC);

CREATE OR REPLACE FUNCTION fn_air_hitung_integrity()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.s1 IS NULL THEN RAISE EXCEPTION 'S1 wajib dijawab'; END IF;
  IF NEW.s1 THEN NEW.status := 'BREAKDOWN'; RETURN NEW; END IF;
  IF NEW.s2 IS NULL THEN RAISE EXCEPTION 'S2 wajib dijawab'; END IF;
  IF NEW.s2 THEN NEW.status := 'LOW'; RETURN NEW; END IF;
  IF NEW.s3 IS NULL THEN RAISE EXCEPTION 'S3 wajib dijawab'; END IF;
  NEW.status := CASE WHEN NEW.s3 THEN 'MEDIUM' ELSE 'HIGH' END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_air_hitung_integrity ON integrity_assessment;
CREATE TRIGGER trg_air_hitung_integrity
  BEFORE INSERT OR UPDATE ON integrity_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_hitung_integrity();

CREATE OR REPLACE FUNCTION fn_air_sync_integrity(p_equipment_id UUID)
RETURNS VOID AS $$
DECLARE r RECORD;
BEGIN
  SELECT tanggal, status INTO r
    FROM integrity_assessment
   WHERE equipment_id = p_equipment_id AND konfirmasi = 'DIKONFIRMASI'
   ORDER BY tanggal DESC, created_at DESC
   LIMIT 1;
  UPDATE equipment SET
    status_integrity     = r.status,
    status_integrity_tgl = r.tanggal
  WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION fn_air_after_integrity()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN PERFORM fn_air_sync_integrity(OLD.equipment_id); END IF;
  IF TG_OP IN ('INSERT','UPDATE') AND (TG_OP = 'INSERT' OR NEW.equipment_id <> OLD.equipment_id) THEN
    PERFORM fn_air_sync_integrity(NEW.equipment_id);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_air_after_integrity ON integrity_assessment;
CREATE TRIGGER trg_air_after_integrity
  AFTER INSERT OR UPDATE OR DELETE ON integrity_assessment
  FOR EACH ROW EXECUTE FUNCTION fn_air_after_integrity();


-- ============================================================
-- 9. MATRIKS TINDAK LANJUT (Tabel 7)
--    aksi = dari pedoman. prioritas = USULAN (boleh diubah di sini).
-- ============================================================
CREATE TABLE IF NOT EXISTS matriks_tindak_lanjut_air (
  criticality      TEXT NOT NULL CHECK (criticality IN ('SECE','PCE','IMPORTANT','SECONDARY')),
  status_integrity TEXT NOT NULL CHECK (status_integrity IN ('BREAKDOWN','LOW','MEDIUM','HIGH')),
  aksi             TEXT,                       -- NULL = tidak ditetapkan pedoman
  prioritas        SMALLINT NOT NULL DEFAULT 9, -- usulan, 1 = paling mendesak
  immediate        BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (criticality, status_integrity)
);

INSERT INTO matriks_tindak_lanjut_air (criticality, status_integrity, aksi, prioritas, immediate) VALUES
  ('SECE','BREAKDOWN','Immediate Repair / Replacement', 1, true),
  ('SECE','LOW',      'Immediate Repair / Replacement / Adjustment', 2, true),
  ('SECE','MEDIUM',   'Close Monitor / Interval Inspection & Maintenance / Adjustment, Minor Repair jika perlu', 5, false),
  ('SECE','HIGH',     'Standard Inspection & Maintenance (Task & Interval)', 9, false),
  ('PCE','BREAKDOWN', 'Immediate Repair / Replacement', 1, true),
  ('PCE','LOW',       'Immediate Repair / Replacement / Adjustment', 2, true),
  ('PCE','MEDIUM',    'Close Monitor / Interval Inspection & Maintenance / Adjustment, Minor Repair jika perlu', 5, false),
  ('PCE','HIGH',      'Standard Inspection & Maintenance (Task & Interval)', 9, false),
  ('IMPORTANT','BREAKDOWN','Repair / Replacement', 3, false),
  ('IMPORTANT','LOW',      'Repair / Replacement / Adjustment', 4, false),
  ('IMPORTANT','MEDIUM',   'Close Monitor / Interval Inspection & Maintenance / Adjustment', 7, false),
  ('IMPORTANT','HIGH',     'Standard Inspection & Maintenance (Task & Interval)', 9, false),
  ('SECONDARY','BREAKDOWN','Repair / Replacement', 6, false),
  ('SECONDARY','LOW',      NULL, 9, false),
  ('SECONDARY','MEDIUM',   NULL, 9, false),
  ('SECONDARY','HIGH',     NULL, 9, false)
ON CONFLICT (criticality, status_integrity) DO NOTHING;


-- ============================================================
-- 10. VIEW RINGKASAN untuk dashboard
-- ============================================================
CREATE OR REPLACE VIEW v_equipment_air_status
WITH (security_invoker = true) AS
SELECT
  e.id, e.tag_number, e.nama_equipment, e.assigned_unit_id, e.kategori_id,
  e.parent_equipment_id, e.status_operasi,
  e.kategori_aset, rk.nama AS kategori_aset_nama, rk.pendekatan,
  e.status_aset, e.kepemilikan, e.alasan_di_luar_lingkup, e.dalam_lingkup_air,
  COALESCE(e.taxonomy_level, CASE WHEN e.parent_equipment_id IS NULL THEN 6 ELSE 7 END)::smallint AS taxonomy_level,
  e.criticality, e.is_vital, e.criticality_metode,
  e.criticality_tgl_penetapan, e.criticality_tgl_validasi_ulang,
  e.status_integrity, e.status_integrity_tgl,
  m.aksi, m.prioritas, COALESCE(m.immediate, false) AS immediate,
  (e.criticality_tgl_validasi_ulang IS NOT NULL AND
   e.criticality_tgl_validasi_ulang <= CURRENT_DATE +
     COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'peringatan_validasi_hari'), 60)
  ) AS perlu_validasi_criticality,
  (e.criticality IS NULL)      AS belum_dinilai_criticality,
  (e.status_integrity IS NULL) AS belum_dinilai_integrity,
  (e.criticality IS NULL OR e.status_integrity IS NULL) AS belum_dinilai
FROM equipment e
LEFT JOIN ref_kategori_aset rk ON rk.kode = e.kategori_aset
LEFT JOIN matriks_tindak_lanjut_air m
       ON m.criticality = e.criticality AND m.status_integrity = e.status_integrity;


-- ============================================================
-- 11. RLS
--     Baca: semua user login. Tulis penilaian: admin + manager.
--     Tulis referensi/konfigurasi: admin saja.
-- ============================================================
ALTER TABLE ref_kategori_aset         ENABLE ROW LEVEL SECURITY;
ALTER TABLE air_config                ENABLE ROW LEVEL SECURITY;
ALTER TABLE criticality_assessment    ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_standard      ENABLE ROW LEVEL SECURITY;
ALTER TABLE integrity_assessment      ENABLE ROW LEVEL SECURITY;
ALTER TABLE matriks_tindak_lanjut_air ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ref_kategori_aset_read"  ON ref_kategori_aset;
CREATE POLICY "ref_kategori_aset_read"  ON ref_kategori_aset FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ref_kategori_aset_write" ON ref_kategori_aset;
CREATE POLICY "ref_kategori_aset_write" ON ref_kategori_aset FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "air_config_read"  ON air_config;
CREATE POLICY "air_config_read"  ON air_config FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "air_config_write" ON air_config;
CREATE POLICY "air_config_write" ON air_config FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "matriks_air_read"  ON matriks_tindak_lanjut_air;
CREATE POLICY "matriks_air_read"  ON matriks_tindak_lanjut_air FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "matriks_air_write" ON matriks_tindak_lanjut_air;
CREATE POLICY "matriks_air_write" ON matriks_tindak_lanjut_air FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "perf_std_read"  ON performance_standard;
CREATE POLICY "perf_std_read"  ON performance_standard FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "perf_std_write" ON performance_standard;
CREATE POLICY "perf_std_write" ON performance_standard FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "crit_assess_read"  ON criticality_assessment;
CREATE POLICY "crit_assess_read"  ON criticality_assessment FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "crit_assess_write" ON criticality_assessment;
CREATE POLICY "crit_assess_write" ON criticality_assessment FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());

DROP POLICY IF EXISTS "integ_assess_read"  ON integrity_assessment;
CREATE POLICY "integ_assess_read"  ON integrity_assessment FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "integ_assess_write" ON integrity_assessment;
CREATE POLICY "integ_assess_write" ON integrity_assessment FOR ALL TO authenticated
  USING (is_admin() OR is_manager()) WITH CHECK (is_admin() OR is_manager());


-- ============================================================
-- 12. VERIFIKASI (jalankan setelah migration)
-- ============================================================
-- a) 18 kategori, 3 config, 16 sel matriks:
-- SELECT (SELECT count(*) FROM ref_kategori_aset) AS kategori,
--        (SELECT count(*) FROM air_config) AS config,
--        (SELECT count(*) FROM matriks_tindak_lanjut_air) AS matriks;
--
-- b) Pemetaan kategori eRAMHoist → AIR (yang NULL perlu diisi manual):
-- SELECT c.name, c.parent_unit_type, c.kategori_aset_default,
--        (SELECT count(*) FROM equipment e WHERE e.kategori_id = c.id) AS jml_equipment
--   FROM categories c ORDER BY c.kategori_aset_default NULLS FIRST, c.name;
--
-- c) Ringkasan status aset hasil backfill:
-- SELECT status_operasi, status_aset, count(*) FROM equipment GROUP BY 1,2 ORDER BY 1,2;


-- ============================================================
-- ROLLBACK (hanya kalau benar-benar perlu membatalkan Tahap 1)
-- ============================================================
-- DROP VIEW IF EXISTS v_equipment_air_status;
-- DROP TRIGGER IF EXISTS trg_air_after_integrity ON integrity_assessment;
-- DROP TRIGGER IF EXISTS trg_air_hitung_integrity ON integrity_assessment;
-- DROP TRIGGER IF EXISTS trg_air_after_criticality ON criticality_assessment;
-- DROP TRIGGER IF EXISTS trg_air_hitung_criticality ON criticality_assessment;
-- DROP TRIGGER IF EXISTS trg_air_equipment_defaults ON equipment;
-- DROP TABLE IF EXISTS matriks_tindak_lanjut_air, integrity_assessment, performance_standard,
--                      criticality_assessment, air_config;
-- DROP FUNCTION IF EXISTS fn_air_after_integrity(), fn_air_sync_integrity(UUID), fn_air_hitung_integrity(),
--                         fn_air_after_criticality(), fn_air_sync_criticality(UUID), fn_air_hitung_criticality(),
--                         fn_air_equipment_defaults();
-- ALTER TABLE equipment
--   DROP COLUMN IF EXISTS status_integrity_tgl, DROP COLUMN IF EXISTS status_integrity,
--   DROP COLUMN IF EXISTS criticality_tgl_validasi_ulang, DROP COLUMN IF EXISTS criticality_tgl_penetapan,
--   DROP COLUMN IF EXISTS criticality_metode, DROP COLUMN IF EXISTS is_vital, DROP COLUMN IF EXISTS criticality,
--   DROP COLUMN IF EXISTS taxonomy_level, DROP COLUMN IF EXISTS sap_equipment_no,
--   DROP COLUMN IF EXISTS dalam_lingkup_air, DROP COLUMN IF EXISTS alasan_di_luar_lingkup,
--   DROP COLUMN IF EXISTS kepemilikan, DROP COLUMN IF EXISTS status_aset, DROP COLUMN IF EXISTS kategori_aset;
-- ALTER TABLE categories DROP COLUMN IF EXISTS kategori_aset_default;
-- DROP TABLE IF EXISTS ref_kategori_aset;
