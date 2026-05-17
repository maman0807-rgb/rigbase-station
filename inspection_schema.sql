-- ============================================================
-- RIGBASE INSPECTION — DATABASE SCHEMA
-- ============================================================
-- Modul: Rekap Inspeksi Cat 3 & Cat 4 (tambahan ke Rigbase Station)
-- Aman dijalankan ulang (idempotent).
-- Reuse helper: set_updated_at() dan is_admin() dari supabase_schema.sql.
-- ============================================================

-- ============================================================
-- 1. TABEL: inspections (siklus inspeksi)
-- ============================================================
CREATE TABLE IF NOT EXISTS inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ID auto-generated (mis. SIKLUS-2026-001)
  inspection_code TEXT UNIQUE NOT NULL,

  -- Referensi ke parent_units yang sudah ada
  parent_unit_id INT NOT NULL REFERENCES parent_units(id),

  -- Kategori inspeksi
  kategori_inspeksi TEXT NOT NULL CHECK (kategori_inspeksi IN ('Cat 3', 'Cat 4')),

  -- Info Client & Specs (snapshot saat inspeksi — bisa beda dari spec equipment)
  client TEXT,
  service TEXT,
  rig_type TEXT,
  manufacturer TEXT,
  year_manufactured INT,
  model_serial TEXT,
  height_of_mast NUMERIC,
  hook_load NUMERIC,
  power_hp NUMERIC,
  place_of_inspection TEXT,

  -- Tanggal
  start_date DATE NOT NULL,
  end_date DATE,  -- NULL = on progress

  -- PI (Perusahaan Inspeksi)
  pi_company TEXT NOT NULL,
  rig_inspector TEXT NOT NULL,

  -- Status & Progress
  status TEXT NOT NULL CHECK (status IN ('On Progress', 'Completed')) DEFAULT 'On Progress',
  progress_akumulatif NUMERIC DEFAULT 0 CHECK (progress_akumulatif >= 0 AND progress_akumulatif <= 100),

  -- Notes
  catatan TEXT,

  -- System
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_inspections_parent_unit ON inspections(parent_unit_id);
CREATE INDEX IF NOT EXISTS idx_inspections_status      ON inspections(status);
CREATE INDEX IF NOT EXISTS idx_inspections_start_date  ON inspections(start_date DESC);
CREATE INDEX IF NOT EXISTS idx_inspections_kategori    ON inspections(kategori_inspeksi);
CREATE INDEX IF NOT EXISTS idx_inspections_pi          ON inspections(pi_company);

-- ============================================================
-- 2. TABEL: inspection_findings (temuan per equipment per siklus)
-- ============================================================
CREATE TABLE IF NOT EXISTS inspection_findings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,

  -- Urutan & Equipment
  no_urut INT NOT NULL,
  equipment_id UUID REFERENCES equipment(id) ON DELETE SET NULL,
  equipment_name_snapshot TEXT NOT NULL,  -- cadangan kalau equipment_id NULL
  qty TEXT,  -- contoh "3ea"

  -- POSISI temuan (untuk equipment kompleks seperti Mast)
  -- Free text — UI validasi: kalau equipment kategori Mast, pilih dari dropdown
  -- (A-Frame, Crown Block, Upper, Lower, Monkey Board)
  bagian TEXT,

  -- Klasifikasi temuan
  category TEXT NOT NULL CHECK (category IN ('N/A', 'Major', 'Critical')),
  finding TEXT,
  mpi_result TEXT CHECK (mpi_result IN ('Discontinuity', 'No Discontinuity', 'N/A')),
  acceptance_criteria TEXT,  -- contoh: "API RP 8B Sect 5.3.2.4"
  recommendation TEXT,

  -- Tracking
  tgl_ditemukan DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('Open', 'Closed')) DEFAULT 'Open',
  tgl_closed DATE,
  pic_perbaikan TEXT,

  -- Foto Before/After (array URL ke bucket inspection-photos, max 4 per slot)
  photos_before JSONB DEFAULT '[]'::JSONB,
  photos_after  JSONB DEFAULT '[]'::JSONB,

  -- Notes
  catatan TEXT,

  -- Auto-link ke maintenance_log saat di-Closed (di-set oleh trigger di bawah)
  maintenance_log_id UUID REFERENCES maintenance_log(id) ON DELETE SET NULL,

  -- System
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_findings_inspection ON inspection_findings(inspection_id);
CREATE INDEX IF NOT EXISTS idx_findings_equipment  ON inspection_findings(equipment_id);
CREATE INDEX IF NOT EXISTS idx_findings_status     ON inspection_findings(status);
CREATE INDEX IF NOT EXISTS idx_findings_category   ON inspection_findings(category);
CREATE INDEX IF NOT EXISTS idx_findings_tgl        ON inspection_findings(tgl_ditemukan DESC);
-- Index untuk deteksi temuan berulang (cuma yang non-N/A)
CREATE INDEX IF NOT EXISTS idx_findings_recurring  ON inspection_findings(equipment_id, bagian) WHERE category != 'N/A';

-- ============================================================
-- 3. TRIGGER: Auto-update updated_at (reuse set_updated_at())
-- ============================================================
DROP TRIGGER IF EXISTS trg_inspections_updated_at ON inspections;
CREATE TRIGGER trg_inspections_updated_at
  BEFORE UPDATE ON inspections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_findings_updated_at ON inspection_findings;
CREATE TRIGGER trg_findings_updated_at
  BEFORE UPDATE ON inspection_findings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 4. TRIGGER: Auto-create maintenance_log saat finding di-Closed
-- ============================================================
CREATE OR REPLACE FUNCTION create_maintenance_from_finding()
RETURNS TRIGGER AS $$
DECLARE
  new_log_id UUID;
BEGIN
  -- Hanya jalan kalau:
  --   1. Status berubah dari Open → Closed
  --   2. equipment_id tersedia (gak NULL)
  --   3. Belum pernah dibuatkan maintenance_log (idempoten — antisipasi reopen-close berulang)
  IF NEW.status = 'Closed'
     AND OLD.status = 'Open'
     AND NEW.equipment_id IS NOT NULL
     AND NEW.maintenance_log_id IS NULL THEN

    INSERT INTO maintenance_log (
      equipment_id, maintenance_date, maintenance_type, pic_mechanic, notes, created_by
    ) VALUES (
      NEW.equipment_id,
      COALESCE(NEW.tgl_closed, CURRENT_DATE),
      'Inspection Closing - ' || NEW.category,
      NEW.pic_perbaikan,
      'Auto-generated dari temuan inspeksi.' ||
        COALESCE(' Bagian: ' || NEW.bagian || '.', '') ||
        COALESCE(' Finding: ' || NEW.finding || '.', '') ||
        COALESCE(' Recommendation: ' || NEW.recommendation || '.', ''),
      NEW.updated_by
    )
    RETURNING id INTO new_log_id;

    NEW.maintenance_log_id := new_log_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_finding_closed ON inspection_findings;
CREATE TRIGGER trg_finding_closed
  BEFORE UPDATE ON inspection_findings
  FOR EACH ROW EXECUTE FUNCTION create_maintenance_from_finding();

-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE inspections         ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_findings ENABLE ROW LEVEL SECURITY;

-- ---------- inspections ----------
DROP POLICY IF EXISTS "inspections_read_all" ON inspections;
CREATE POLICY "inspections_read_all" ON inspections
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "inspections_insert_all" ON inspections;
CREATE POLICY "inspections_insert_all" ON inspections
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "inspections_update_all" ON inspections;
CREATE POLICY "inspections_update_all" ON inspections
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "inspections_delete_admin" ON inspections;
CREATE POLICY "inspections_delete_admin" ON inspections
  FOR DELETE TO authenticated USING (is_admin());

-- ---------- inspection_findings ----------
DROP POLICY IF EXISTS "findings_read_all" ON inspection_findings;
CREATE POLICY "findings_read_all" ON inspection_findings
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "findings_insert_all" ON inspection_findings;
CREATE POLICY "findings_insert_all" ON inspection_findings
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "findings_update_all" ON inspection_findings;
CREATE POLICY "findings_update_all" ON inspection_findings
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "findings_delete_admin" ON inspection_findings;
CREATE POLICY "findings_delete_admin" ON inspection_findings
  FOR DELETE TO authenticated USING (is_admin());

-- ============================================================
-- 6. STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES
  ('inspection-pdfs', 'inspection-pdfs', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES
  ('inspection-photos', 'inspection-photos', true)
ON CONFLICT (id) DO NOTHING;

-- ---------- Storage Policies: inspection-pdfs (private, auth-only) ----------
DROP POLICY IF EXISTS "insp_pdfs_auth_read" ON storage.objects;
CREATE POLICY "insp_pdfs_auth_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'inspection-pdfs');

DROP POLICY IF EXISTS "insp_pdfs_auth_insert" ON storage.objects;
CREATE POLICY "insp_pdfs_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-pdfs');

DROP POLICY IF EXISTS "insp_pdfs_admin_modify" ON storage.objects;
CREATE POLICY "insp_pdfs_admin_modify" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-pdfs' AND is_admin());

DROP POLICY IF EXISTS "insp_pdfs_admin_delete" ON storage.objects;
CREATE POLICY "insp_pdfs_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-pdfs' AND is_admin());

-- ---------- Storage Policies: inspection-photos (public read, auth write) ----------
DROP POLICY IF EXISTS "insp_photos_public_read" ON storage.objects;
CREATE POLICY "insp_photos_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'inspection-photos');

DROP POLICY IF EXISTS "insp_photos_auth_insert" ON storage.objects;
CREATE POLICY "insp_photos_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-photos');

DROP POLICY IF EXISTS "insp_photos_auth_modify" ON storage.objects;
CREATE POLICY "insp_photos_auth_modify" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-photos');

DROP POLICY IF EXISTS "insp_photos_admin_delete" ON storage.objects;
CREATE POLICY "insp_photos_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-photos' AND is_admin());

-- ============================================================
-- 7. VERIFIKASI
-- ============================================================
SELECT 'TABEL' AS info, table_name AS name
FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('inspections','inspection_findings')
UNION ALL
SELECT 'BUCKET', id FROM storage.buckets WHERE id IN ('inspection-pdfs','inspection-photos')
UNION ALL
SELECT 'TRIGGER', tgname FROM pg_trigger
WHERE tgname IN ('trg_inspections_updated_at','trg_findings_updated_at','trg_finding_closed')
ORDER BY info, name;
-- Ekspektasi minimal 7 baris:
--   2 BUCKET (inspection-pdfs, inspection-photos)
--   2 TABEL (inspection_findings, inspections)
--   3 TRIGGER (trg_findings_updated_at, trg_finding_closed, trg_inspections_updated_at)

-- ============================================================
-- ROLLBACK (kalau perlu undo):
-- ============================================================
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_finding_closed         ON inspection_findings;
-- DROP TRIGGER IF EXISTS trg_findings_updated_at    ON inspection_findings;
-- DROP TRIGGER IF EXISTS trg_inspections_updated_at ON inspections;
-- DROP FUNCTION IF EXISTS create_maintenance_from_finding();
-- DROP TABLE IF EXISTS inspection_findings CASCADE;
-- DROP TABLE IF EXISTS inspections         CASCADE;
-- DELETE FROM storage.buckets WHERE id IN ('inspection-pdfs','inspection-photos');
-- COMMIT;
