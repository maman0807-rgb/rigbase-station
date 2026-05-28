-- ============================================================
-- FASE 8 — Spesifikasi Teknis Terstruktur (JSONB)
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Tujuan:
--   Field nameplate equipment (kVA, voltage, RPM, IP class, dll)
--   yg dulunya disumpel di spek_khusus (free text) sekarang punya
--   struktur per kategori. Mulai dari Genset; nanti extend ke
--   Engine, Mudpump, BOP, Fire Pump, dll.
--
-- Field: spec_data jsonb — fleksibel per kategori.
--   Genset: { rated_kva, rated_kw, power_factor, rated_voltage,
--             phase, frequency_hz, rated_current_a, rpm,
--             performance_class, enclosure_ip, insulation_class,
--             connection, excitation_v, excitation_a, mass_kg,
--             iso_8528, generator_sn, engine_sn, sales_order,
--             max_altitude_m, max_ambient_c }
-- ============================================================

ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS spec_data JSONB DEFAULT '{}'::jsonb;

-- Index untuk query JSONB (opsional, kalau nanti perlu filter mis. "kVA >= 100")
CREATE INDEX IF NOT EXISTS idx_equipment_spec_data ON equipment USING GIN (spec_data);

-- Verifikasi:
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name='equipment' AND column_name='spec_data';
