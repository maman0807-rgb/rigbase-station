-- ============================================================
-- eRAMHoist Fase 21 — CSPP Enrichment (mapping part kritis per kategori equipment)
-- Minimal v1: link materials (spare parts) ke kategori equipment,
-- supaya CSPP bisa di-filter "part kritis relevan buat kategori X"
-- (mis. Generator Set) tanpa scroll manual di list gudang campur semua.
-- Jalankan SEKALI di Supabase SQL Editor.
-- ============================================================

CREATE TABLE IF NOT EXISTS cspp_kategori_mapping (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kategori_id      INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  material_id      UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  qty_recommended  NUMERIC DEFAULT 1,
  notes            TEXT,
  created_by       UUID REFERENCES profiles(id),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (kategori_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_cspp_map_kategori ON cspp_kategori_mapping(kategori_id);

ALTER TABLE cspp_kategori_mapping ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cspp_map_read ON cspp_kategori_mapping;
CREATE POLICY cspp_map_read ON cspp_kategori_mapping FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS cspp_map_write ON cspp_kategori_mapping;
CREATE POLICY cspp_map_write ON cspp_kategori_mapping FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin')));

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'cspp_kategori_mapping' AS tabel, COUNT(*) AS jumlah FROM cspp_kategori_mapping;
