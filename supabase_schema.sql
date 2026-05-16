-- ============================================================
-- RIGBASE STATION — DATABASE SCHEMA
-- ============================================================
-- Untuk dijalankan di Supabase SQL Editor.
-- Aman dijalankan ulang (idempoten) karena pakai IF NOT EXISTS
-- dan DROP POLICY IF EXISTS sebelum CREATE POLICY.
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. TABLE: profiles
-- Extend auth.users dengan role & info tambahan.
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT CHECK (role IN ('admin', 'user')) DEFAULT 'user',
  telegram_user_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. TABLE: parent_units
-- 8 unit: 5 Rig + 3 Standalone (MTU, Slickline, Independent).
-- ============================================================
CREATE TABLE IF NOT EXISTS parent_units (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  type TEXT CHECK (type IN ('Rig', 'Standalone')) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. TABLE: categories
-- Kategori equipment. parent_unit_type = filter visibility.
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  parent_unit_type TEXT CHECK (parent_unit_type IN ('Rig', 'Standalone', 'Both')) DEFAULT 'Both',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. TABLE: equipment (main table — 43 fields)
-- ============================================================
CREATE TABLE IF NOT EXISTS equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- A. Identitas
  tag_number TEXT UNIQUE NOT NULL,
  nama_equipment TEXT NOT NULL,
  kategori_id INT REFERENCES categories(id) ON DELETE SET NULL,
  assigned_unit_id INT REFERENCES parent_units(id) ON DELETE SET NULL,
  tipe_kepemilikan TEXT CHECK (tipe_kepemilikan IN ('Permanent', 'Mobile-Backup')) DEFAULT 'Permanent',

  -- B. Spesifikasi
  brand TEXT,
  model TEXT,
  serial_number TEXT,
  tahun_pembuatan INT,
  tahun_commissioning INT,
  year_used INT,
  country_of_origin TEXT,
  spek_khusus TEXT,

  -- C. Status
  status_operasi TEXT CHECK (status_operasi IN ('Aktif','Standby','Repair','Down','Scrap')) DEFAULT 'Aktif',
  kondisi_fisik TEXT CHECK (kondisi_fisik IN ('Good','Fair','Poor')) DEFAULT 'Good',
  lokasi_fisik TEXT,
  running_hours NUMERIC,

  -- D. Maintenance
  last_maintenance_date DATE,
  last_maintenance_type TEXT,
  next_maintenance_date DATE,
  maintenance_interval TEXT,
  pic_mechanic TEXT,
  goh_year INT,

  -- E. Sertifikasi & Refurbish
  nomor_skpi TEXT,
  skpi_start_date DATE,
  skpi_end_date DATE,
  coc_number TEXT,
  arf_lembaga TEXT,
  refurbish_year INT,
  refurbish_by TEXT,
  load_test_result TEXT,
  nomor_sertifikat_lain TEXT,
  tgl_terbit_sertifikat DATE,
  tgl_expired_sertifikat DATE,
  lembaga_penerbit TEXT,

  -- F. Finansial
  tgl_pembelian DATE,
  harga_perolehan NUMERIC,
  nomor_po_invoice TEXT,
  vendor_supplier TEXT,
  cost_center TEXT,

  -- G. Safety
  pressure_test_date DATE,
  pressure_test_result TEXT,

  -- H. Catatan
  remarks TEXT,

  -- System
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_equipment_assigned_unit ON equipment(assigned_unit_id);
CREATE INDEX IF NOT EXISTS idx_equipment_kategori ON equipment(kategori_id);
CREATE INDEX IF NOT EXISTS idx_equipment_status ON equipment(status_operasi);
CREATE INDEX IF NOT EXISTS idx_equipment_tipe ON equipment(tipe_kepemilikan);
CREATE INDEX IF NOT EXISTS idx_equipment_next_maint ON equipment(next_maintenance_date);
CREATE INDEX IF NOT EXISTS idx_equipment_skpi_end ON equipment(skpi_end_date);

-- ============================================================
-- 5. TABLE: maintenance_log
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  maintenance_date DATE NOT NULL,
  maintenance_type TEXT,
  pic_mechanic TEXT,
  notes TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maint_equipment ON maintenance_log(equipment_id);
CREATE INDEX IF NOT EXISTS idx_maint_date ON maintenance_log(maintenance_date);

-- ============================================================
-- 6. TABLE: mutation_log
-- ============================================================
CREATE TABLE IF NOT EXISTS mutation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  from_unit_id INT REFERENCES parent_units(id) ON DELETE SET NULL,
  to_unit_id INT REFERENCES parent_units(id) ON DELETE SET NULL,
  mutation_date DATE NOT NULL,
  reason TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mutation_equipment ON mutation_log(equipment_id);

-- ============================================================
-- 7. TABLE: documents
-- Metadata file (file fisik di Supabase Storage).
-- ============================================================
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documents_equipment ON documents(equipment_id);

-- ============================================================
-- 8. TABLE: alert_log
-- Riwayat alert Telegram (sertifikat expired, maintenance due, dll).
-- ============================================================
CREATE TABLE IF NOT EXISTS alert_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL,
  equipment_id UUID REFERENCES equipment(id) ON DELETE SET NULL,
  message TEXT,
  sent_to TEXT,
  status TEXT,
  sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alert_type ON alert_log(alert_type);
CREATE INDEX IF NOT EXISTS idx_alert_sent_at ON alert_log(sent_at);

-- ============================================================
-- 9. TRIGGER: auto-update updated_at di equipment
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_equipment_updated_at ON equipment;
CREATE TRIGGER trg_equipment_updated_at
  BEFORE UPDATE ON equipment
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 10. TRIGGER: auto-create profile saat user baru sign up
-- Default role = 'user'. Admin pertama harus di-update manual.
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'user'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 11. HELPER FUNCTION: is_admin()
-- Cek apakah user saat ini admin (dipakai di RLS policies).
-- ============================================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================
-- 12. ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS di semua tabel
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_units    ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment       ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE mutation_log    ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_log       ENABLE ROW LEVEL SECURITY;

-- ---------- profiles ----------
DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON profiles;
CREATE POLICY "profiles_select_own_or_admin" ON profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR is_admin());

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid() AND role = (SELECT role FROM profiles WHERE id = auth.uid()));
-- Catatan: user biasa boleh update profil sendiri TAPI tidak boleh ubah role.

DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------- parent_units ----------
DROP POLICY IF EXISTS "parent_units_read_all" ON parent_units;
CREATE POLICY "parent_units_read_all" ON parent_units
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "parent_units_admin_write" ON parent_units;
CREATE POLICY "parent_units_admin_write" ON parent_units
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------- categories ----------
DROP POLICY IF EXISTS "categories_read_all" ON categories;
CREATE POLICY "categories_read_all" ON categories
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "categories_admin_write" ON categories;
CREATE POLICY "categories_admin_write" ON categories
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------- equipment ----------
DROP POLICY IF EXISTS "equipment_read_all" ON equipment;
CREATE POLICY "equipment_read_all" ON equipment
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "equipment_admin_write" ON equipment;
CREATE POLICY "equipment_admin_write" ON equipment
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------- maintenance_log ----------
-- Semua user authenticated boleh SELECT & INSERT.
-- Hanya admin yang boleh UPDATE/DELETE.
DROP POLICY IF EXISTS "maint_read_all" ON maintenance_log;
CREATE POLICY "maint_read_all" ON maintenance_log
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "maint_insert_all" ON maintenance_log;
CREATE POLICY "maint_insert_all" ON maintenance_log
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "maint_admin_modify" ON maintenance_log;
CREATE POLICY "maint_admin_modify" ON maintenance_log
  FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "maint_admin_delete" ON maintenance_log;
CREATE POLICY "maint_admin_delete" ON maintenance_log
  FOR DELETE TO authenticated USING (is_admin());

-- ---------- mutation_log ----------
DROP POLICY IF EXISTS "mutation_read_all" ON mutation_log;
CREATE POLICY "mutation_read_all" ON mutation_log
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "mutation_admin_write" ON mutation_log;
CREATE POLICY "mutation_admin_write" ON mutation_log
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ---------- documents ----------
DROP POLICY IF EXISTS "documents_read_all" ON documents;
CREATE POLICY "documents_read_all" ON documents
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "documents_admin_write" ON documents;
CREATE POLICY "documents_admin_write" ON documents
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ---------- alert_log ----------
DROP POLICY IF EXISTS "alert_read_all" ON alert_log;
CREATE POLICY "alert_read_all" ON alert_log
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "alert_admin_write" ON alert_log;
CREATE POLICY "alert_admin_write" ON alert_log
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ============================================================
-- 13. STORAGE BUCKETS
-- Buat bucket via Dashboard ATAU jalankan SQL ini:
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('equipment-photos', 'equipment-photos', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('equipment-documents', 'equipment-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
-- equipment-photos: public read, authenticated write
DROP POLICY IF EXISTS "photos_public_read" ON storage.objects;
CREATE POLICY "photos_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'equipment-photos');

DROP POLICY IF EXISTS "photos_auth_insert" ON storage.objects;
CREATE POLICY "photos_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'equipment-photos');

DROP POLICY IF EXISTS "photos_admin_modify" ON storage.objects;
CREATE POLICY "photos_admin_modify" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'equipment-photos' AND is_admin());

DROP POLICY IF EXISTS "photos_admin_delete" ON storage.objects;
CREATE POLICY "photos_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'equipment-photos' AND is_admin());

-- equipment-documents: authenticated read & write
DROP POLICY IF EXISTS "docs_auth_read" ON storage.objects;
CREATE POLICY "docs_auth_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'equipment-documents');

DROP POLICY IF EXISTS "docs_auth_insert" ON storage.objects;
CREATE POLICY "docs_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'equipment-documents');

DROP POLICY IF EXISTS "docs_admin_modify" ON storage.objects;
CREATE POLICY "docs_admin_modify" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'equipment-documents' AND is_admin());

DROP POLICY IF EXISTS "docs_admin_delete" ON storage.objects;
CREATE POLICY "docs_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'equipment-documents' AND is_admin());

-- ============================================================
-- SELESAI. Jalankan supabase_seed.sql untuk isi data awal.
-- ============================================================
