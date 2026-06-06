-- ============================================================
-- PAYROLL MODULE — SCHEMA untuk eRAMHoist
-- Jalankan di Supabase SQL Editor (aman re-run, idempoten)
-- Reuse: set_updated_at(), is_admin() dari supabase_schema.sql
-- ============================================================

-- ============================================================
-- 1. TAMBAH can_payroll di profiles
-- ============================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_payroll BOOLEAN DEFAULT false;
UPDATE profiles SET can_payroll = true WHERE email = 'maman0807@gmail.com';

-- ============================================================
-- 2. HELPER: is_payroll_user()
-- ============================================================
CREATE OR REPLACE FUNCTION is_payroll_user()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND can_payroll = true
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================
-- 3. TABLE: payroll_employees
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_employees (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nik             TEXT UNIQUE NOT NULL,
  nik_ktp         TEXT,
  npwp            TEXT,
  nama            TEXT NOT NULL,
  email           TEXT,
  no_hp           TEXT,
  jabatan         TEXT NOT NULL,
  departemen      TEXT,
  tanggal_masuk   DATE NOT NULL,
  status_kerja    TEXT NOT NULL CHECK (status_kerja IN ('TETAP','KONTRAK','HARIAN')) DEFAULT 'TETAP',
  status_ptkp     TEXT NOT NULL CHECK (status_ptkp IN ('TK0','TK1','TK2','TK3','K0','K1','K2','K3')) DEFAULT 'TK0',
  pegawai_asing   BOOLEAN DEFAULT false,
  -- Komponen gaji tetap (snapshot di payroll, tapi ini master)
  gaji_pokok      NUMERIC DEFAULT 0,
  tunj_transport  NUMERIC DEFAULT 0,
  tunj_makan      NUMERIC DEFAULT 0,
  tunj_jabatan    NUMERIC DEFAULT 0,
  tunj_lainnya    NUMERIC DEFAULT 0,
  -- BPJS
  bpjs_kes_nomor  TEXT,
  bpjs_tk_nomor   TEXT,
  bpjs_kes_aktif  BOOLEAN DEFAULT true,
  bpjs_tk_aktif   BOOLEAN DEFAULT true,
  tingkat_risiko_jkk TEXT DEFAULT 'SANGAT_TINGGI'
    CHECK (tingkat_risiko_jkk IN ('SANGAT_RENDAH','RENDAH','SEDANG','TINGGI','SANGAT_TINGGI')),
  -- Bank
  nama_bank       TEXT,
  no_rekening     TEXT,
  -- Status
  aktif           BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  created_by      UUID REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_pay_emp_aktif ON payroll_employees(aktif);
CREATE INDEX IF NOT EXISTS idx_pay_emp_dept  ON payroll_employees(departemen);

DROP TRIGGER IF EXISTS trg_pay_emp_updated_at ON payroll_employees;
CREATE TRIGGER trg_pay_emp_updated_at
  BEFORE UPDATE ON payroll_employees
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 4. TABLE: payroll_config (pengaturan perusahaan)
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_config (
  id                   TEXT PRIMARY KEY DEFAULT 'default',
  nama_perusahaan      TEXT DEFAULT 'PT. Contoh Migas',
  alamat_perusahaan    TEXT DEFAULT '',
  npwp_perusahaan      TEXT,
  nama_ttd             TEXT,
  jabatan_ttd          TEXT,
  cap_bpjs_kesehatan   NUMERIC DEFAULT 12000000,
  cap_bpjs_jp          NUMERIC DEFAULT 10547400,
  tanggal_lebaran      DATE,
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO payroll_config (id) VALUES ('default') ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5. TABLE: payroll_overtime (lembur per karyawan per periode)
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_overtime (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id     UUID NOT NULL REFERENCES payroll_employees(id) ON DELETE CASCADE,
  periode         TEXT NOT NULL,  -- format YYYY-MM
  jam_lembur_kerja  NUMERIC DEFAULT 0,
  jam_lembur_libur  NUMERIC DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, periode)
);

CREATE INDEX IF NOT EXISTS idx_pay_ot_periode ON payroll_overtime(periode);

DROP TRIGGER IF EXISTS trg_pay_ot_updated_at ON payroll_overtime;
CREATE TRIGGER trg_pay_ot_updated_at
  BEFORE UPDATE ON payroll_overtime
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 6. TABLE: payroll_kasbon
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_kasbon (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id       UUID NOT NULL REFERENCES payroll_employees(id) ON DELETE CASCADE,
  tanggal           DATE NOT NULL,
  jumlah            NUMERIC NOT NULL CHECK (jumlah > 0),
  cicilan_per_bulan NUMERIC NOT NULL CHECK (cicilan_per_bulan > 0),
  sisa_pinjaman     NUMERIC NOT NULL DEFAULT 0,
  keterangan        TEXT,
  status            TEXT NOT NULL CHECK (status IN ('Aktif','Lunas')) DEFAULT 'Aktif',
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pay_kasbon_emp    ON payroll_kasbon(employee_id);
CREATE INDEX IF NOT EXISTS idx_pay_kasbon_status ON payroll_kasbon(status);

DROP TRIGGER IF EXISTS trg_pay_kasbon_updated_at ON payroll_kasbon;
CREATE TRIGGER trg_pay_kasbon_updated_at
  BEFORE UPDATE ON payroll_kasbon
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 7. TABLE: payroll_periods (periode penggajian)
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_periods (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  periode      TEXT NOT NULL UNIQUE,  -- YYYY-MM
  is_thr       BOOLEAN DEFAULT false,
  status       TEXT NOT NULL CHECK (status IN ('Draft','Final')) DEFAULT 'Draft',
  catatan      TEXT,
  processed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pay_periods_periode ON payroll_periods(periode DESC);

-- ============================================================
-- 8. TABLE: payroll_entries (hasil hitung per karyawan per periode)
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_entries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id       UUID NOT NULL REFERENCES payroll_periods(id) ON DELETE CASCADE,
  employee_id     UUID NOT NULL REFERENCES payroll_employees(id) ON DELETE CASCADE,

  -- Snapshot nama
  nama_snapshot   TEXT,
  jabatan_snapshot TEXT,

  -- Pendapatan bruto
  gaji_pokok      NUMERIC DEFAULT 0,
  tunj_jabatan    NUMERIC DEFAULT 0,
  tunj_transport  NUMERIC DEFAULT 0,
  tunj_makan      NUMERIC DEFAULT 0,
  tunj_lainnya    NUMERIC DEFAULT 0,
  jam_lembur_kerja NUMERIC DEFAULT 0,
  jam_lembur_libur NUMERIC DEFAULT 0,
  upah_lembur     NUMERIC DEFAULT 0,
  thr             NUMERIC DEFAULT 0,
  total_bruto     NUMERIC DEFAULT 0,

  -- Potongan karyawan
  bpjs_kes        NUMERIC DEFAULT 0,
  bpjs_jht        NUMERIC DEFAULT 0,
  bpjs_jp         NUMERIC DEFAULT 0,
  pph21           NUMERIC DEFAULT 0,
  lebih_bayar_pph NUMERIC DEFAULT 0,
  kasbon_cicilan  NUMERIC DEFAULT 0,
  potongan_tetap  NUMERIC DEFAULT 0,
  total_potongan  NUMERIC DEFAULT 0,

  -- Iuran perusahaan
  bpjs_kes_perusahaan NUMERIC DEFAULT 0,
  bpjs_jkk_perusahaan NUMERIC DEFAULT 0,
  bpjs_jkm_perusahaan NUMERIC DEFAULT 0,
  bpjs_jht_perusahaan NUMERIC DEFAULT 0,
  bpjs_jp_perusahaan  NUMERIC DEFAULT 0,

  -- Take Home Pay
  thp             NUMERIC DEFAULT 0,
  total_beban_perusahaan NUMERIC DEFAULT 0,

  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(period_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_pay_entries_period   ON payroll_entries(period_id);
CREATE INDEX IF NOT EXISTS idx_pay_entries_employee ON payroll_entries(employee_id);

-- ============================================================
-- 9. TABLE: payroll_bupot (Bukti Potong A1 tahunan)
-- ============================================================
CREATE TABLE IF NOT EXISTS payroll_bupot (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES payroll_employees(id) ON DELETE CASCADE,
  tahun       INT NOT NULL,
  nomor       TEXT,
  tanggal     DATE,
  pembetulan  BOOLEAN DEFAULT false,
  catatan     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, tahun)
);

DROP TRIGGER IF EXISTS trg_pay_bupot_updated_at ON payroll_bupot;
CREATE TRIGGER trg_pay_bupot_updated_at
  BEFORE UPDATE ON payroll_bupot
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 10. ROW LEVEL SECURITY — semua tabel payroll
--     Hanya is_payroll_user() yang bisa akses
-- ============================================================
ALTER TABLE payroll_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_config    ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_overtime  ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_kasbon    ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_periods   ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_bupot     ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['payroll_employees','payroll_config','payroll_overtime',
                            'payroll_kasbon','payroll_periods','payroll_entries','payroll_bupot']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "payroll_only" ON %I', t);
    EXECUTE format('CREATE POLICY "payroll_only" ON %I FOR ALL TO authenticated
      USING (is_payroll_user()) WITH CHECK (is_payroll_user())', t);
  END LOOP;
END $$;

-- ============================================================
-- 11. VERIFIKASI
-- ============================================================
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'payroll_%'
ORDER BY table_name;
-- Ekspektasi: 7 baris

SELECT email, can_payroll FROM profiles WHERE email = 'maman0807@gmail.com';
-- Ekspektasi: can_payroll = true
