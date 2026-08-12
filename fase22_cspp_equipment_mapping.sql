-- ============================================================
-- eRAMHoist Fase 22 — CSPP Enrichment: ganti granularitas ke per-EQUIPMENT
-- (bukan per-kategori lagi). Alasan: genset satu kategori (Generator Set)
-- bisa beda merk/model (Perkins/Deutz/CAT/FGW) -> kebutuhan part kritis
-- beda-beda per unit spesifik, bukan seragam per kategori besar.
--
-- Tabel fase21 (cspp_kategori_mapping) masih kosong (0 baris, baru dibuat,
-- belum dipakai) -- aman di-drop, ganti pendekatan ke cspp_equipment_mapping.
-- Jalankan SEKALI di Supabase SQL Editor.
-- ============================================================

DROP TABLE IF EXISTS cspp_kategori_mapping;

CREATE TABLE IF NOT EXISTS cspp_equipment_mapping (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id     UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  material_id      UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  qty_recommended  NUMERIC DEFAULT 1,
  notes            TEXT,
  created_by       UUID REFERENCES profiles(id),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (equipment_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_cspp_eqmap_equipment ON cspp_equipment_mapping(equipment_id);

ALTER TABLE cspp_equipment_mapping ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cspp_eqmap_read ON cspp_equipment_mapping;
CREATE POLICY cspp_eqmap_read ON cspp_equipment_mapping FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS cspp_eqmap_write ON cspp_equipment_mapping;
CREATE POLICY cspp_eqmap_write ON cspp_equipment_mapping FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin')));

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'cspp_equipment_mapping' AS tabel, COUNT(*) AS jumlah FROM cspp_equipment_mapping;
