-- ============================================================
-- Migration: PM Parts Template
-- Jalankan di Supabase SQL Editor (project eRAMHoist)
-- ============================================================

CREATE TABLE IF NOT EXISTS pm_parts_template (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  interval_hm  INTEGER NOT NULL,
  part_name    TEXT NOT NULL,
  part_number  TEXT,
  material_id  UUID REFERENCES materials(id),
  qty_required FLOAT NOT NULL DEFAULT 1,
  unit         TEXT NOT NULL DEFAULT 'pcs',
  notes        TEXT,
  is_mandatory BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pm_parts_equipment ON pm_parts_template(equipment_id);
CREATE INDEX IF NOT EXISTS idx_pm_parts_interval  ON pm_parts_template(equipment_id, interval_hm);

ALTER TABLE pm_parts_template ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pm_parts_auth" ON pm_parts_template
  FOR ALL USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
