-- ============================================================
-- FASE 13 — SOS Lab Module (Scheduled Oil Sampling Trakindo)
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Hierarki:
--   Equipment → equipment_components → sos_samples
--                                      + sos_thresholds (per component_type+param)
--                                      + sos_signatures (mapping pola wear)
-- ============================================================

-- 1. EQUIPMENT_COMPONENTS — komponen fluida yg di-monitor
CREATE TABLE IF NOT EXISTS equipment_components (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  component_type TEXT NOT NULL CHECK (component_type IN ('ENGINE','GEARBOX','TRANSMISSION','FUEL')),
  engine_subtype TEXT,                                -- 'diesel'/'gas'/'dual_fuel'/NULL
  name TEXT NOT NULL,                                 -- "Engine oil - CAT C7.1"
  serial_number TEXT,
  sampling_interval_hours INT DEFAULT 250,
  spec_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_eqcomp_equipment ON equipment_components(equipment_id);
CREATE INDEX IF NOT EXISTS idx_eqcomp_type ON equipment_components(component_type);

-- 2. SOS_SAMPLES — satu record per tgl sampling
CREATE TABLE IF NOT EXISTS sos_samples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_id UUID NOT NULL REFERENCES equipment_components(id) ON DELETE CASCADE,
  -- Sample metadata
  sampled_date DATE NOT NULL,
  sample_id TEXT,                                     -- "J21A-56141-0215"
  lab_date DATE,
  label_code TEXT,                                    -- "0F39"
  interp_by TEXT,                                     -- nama analyst Trakindo
  interpreted_on DATE,
  received_date DATE,                                 -- received di branch
  branch_rec_dt DATE,                                 -- received di lab
  sample_ship_time_days INT,
  -- Meter info
  meter_hr NUMERIC,                                   -- jam unit saat sampling
  comp_meter_hr NUMERIC,                              -- jam component (beda dgn unit)
  meter_on_fluid NUMERIC,                             -- jam oli saat sampling
  -- Fluid info
  fluid_change_yn BOOLEAN DEFAULT FALSE,
  filter_change_yn BOOLEAN DEFAULT FALSE,
  kidney_loop TEXT,                                   -- 'Y'/'N'/'U'(Unknown)
  fluid_type TEXT,                                    -- "NG LUBE", "SAE 15W-40"
  fluid_brand TEXT,                                   -- "PERTAMINA", "Shell Rimula"
  fluid_weight TEXT,                                  -- "40" (SAE grade)
  make_up_fluid_l NUMERIC,                            -- top-up liter
  total_fluid_added NUMERIC,
  -- Trakindo location info
  trakindo_region TEXT,                               -- "Southern Sumatera"
  trakindo_location TEXT,                             -- "PRABUMULIH-SP3 6"
  -- Lab verdict & rekomendasi (apa adanya dari Trakindo)
  lab_status TEXT,                                    -- "No Action Required"/"Action Required"/etc
  lab_recommendation TEXT,                            -- text rekomendasi
  -- File
  pdf_attachment_path TEXT,                           -- storage path
  -- Lab data — JSONB (fleksibel per component_type)
  -- ENGINE: { wear_metals:{cr,pb,fe,cu,al,sn,ni}, contaminants:{b,k,na,si},
  --          additives:{ca,p,zn,mg,mo}, oil_condition:{soot,oxidation,nitration,sulfate_by_product,sulfur_products},
  --          fuel:'N', viscosity_100c, tbn, tan, water:'N', pqi,
  --          particle_count:{pc_4um,pc_6um,pc_14um,iso_code}, visual }
  data JSONB DEFAULT '{}'::jsonb,
  notes TEXT,                                         -- catatan internal
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sos_component ON sos_samples(component_id);
CREATE INDEX IF NOT EXISTS idx_sos_date ON sos_samples(sampled_date DESC);
CREATE INDEX IF NOT EXISTS idx_sos_status ON sos_samples(lab_status);

-- 3. SOS_THRESHOLDS — batas per parameter (Sub-fase 1B, boleh kosong dulu)
CREATE TABLE IF NOT EXISTS sos_thresholds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_type TEXT NOT NULL CHECK (component_type IN ('ENGINE','GEARBOX','TRANSMISSION','FUEL')),
  parameter TEXT NOT NULL,                            -- 'fe','cu','water','viscosity_100c'
  normal_max NUMERIC,
  warning_max NUMERIC,
  critical_max NUMERIC,
  unit TEXT,                                          -- 'ppm','cSt','%'
  description TEXT,
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(component_type, parameter)
);

-- 4. SOS_SIGNATURES — mapping pola wear → arah action (Modul 2)
CREATE TABLE IF NOT EXISTS sos_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_type TEXT NOT NULL,
  signature_name TEXT NOT NULL,                       -- "Top-end wear (TOH)"
  required_params TEXT[] NOT NULL,                    -- ['fe','cr']
  optional_params TEXT[],                             -- ['al','si']
  direction TEXT,                                     -- 'TOH'/'GOH'/'INVESTIGATE'/etc
  recommendation TEXT,
  severity TEXT,                                      -- 'WATCH'/'PLAN_ACTION'/'ACT_NOW'
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. RLS — semua Sr Mekanik+
ALTER TABLE equipment_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_thresholds ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_signatures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sos_components_all ON equipment_components;
CREATE POLICY sos_components_all ON equipment_components FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above()) WITH CHECK (is_sr_mekanik_or_above());

DROP POLICY IF EXISTS sos_samples_all ON sos_samples;
CREATE POLICY sos_samples_all ON sos_samples FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above()) WITH CHECK (is_sr_mekanik_or_above());

DROP POLICY IF EXISTS sos_thresholds_all ON sos_thresholds;
CREATE POLICY sos_thresholds_all ON sos_thresholds FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above()) WITH CHECK (is_sr_mekanik_or_above());

DROP POLICY IF EXISTS sos_signatures_all ON sos_signatures;
CREATE POLICY sos_signatures_all ON sos_signatures FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above()) WITH CHECK (is_sr_mekanik_or_above());

-- 6. Storage bucket sos-reports (PRIVATE)
INSERT INTO storage.buckets (id, name, public)
VALUES ('sos-reports', 'sos-reports', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS sos_reports_read ON storage.objects;
CREATE POLICY sos_reports_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'sos-reports' AND is_sr_mekanik_or_above());

DROP POLICY IF EXISTS sos_reports_insert ON storage.objects;
CREATE POLICY sos_reports_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'sos-reports' AND is_sr_mekanik_or_above());

DROP POLICY IF EXISTS sos_reports_delete ON storage.objects;
CREATE POLICY sos_reports_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'sos-reports' AND is_sr_mekanik_or_above());

-- 7. Trigger updated_at
DROP TRIGGER IF EXISTS trg_eqcomp_updated_at ON equipment_components;
CREATE TRIGGER trg_eqcomp_updated_at BEFORE UPDATE ON equipment_components
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sos_samples_updated_at ON sos_samples;
CREATE TRIGGER trg_sos_samples_updated_at BEFORE UPDATE ON sos_samples
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 8. Seed default signatures (Modul 2, editable nanti via admin UI)
INSERT INTO sos_signatures (component_type, signature_name, required_params, optional_params, direction, recommendation, severity) VALUES
('ENGINE',       'Top-end wear (kandidat TOH)',    ARRAY['fe','cr'],            ARRAY['al','si'], 'TOH',                       'Tren naik Fe+Cr mengindikasikan keausan ring/liner/valve. Disarankan mulai rencanakan TOH dan siapkan parts.', 'PLAN_ACTION'),
('ENGINE',       'Lower-end wear (kandidat GOH)',  ARRAY['pb','sn','cu'],       NULL,             'GOH',                       'Tren naik Pb+Sn+Cu mengindikasikan keausan bearing. Disarankan rencanakan GOH (full engine rebuild).',         'PLAN_ACTION'),
('ENGINE',       'Kontaminasi debu/intake',        ARRAY['si','fe'],            NULL,             'INVESTIGATE_AIR_FILTER',    'Si naik dgn Fe → kontaminasi debu/abrasif dari intake. Cek air filter, intake hose, breather.',                  'TIGHTEN_SAMPLING'),
('ENGINE',       'Coolant masuk oli (URGENT)',     ARRAY['na','water'],         ARRAY['k'],       'INVESTIGATE_HEAD_GASKET',   'Na/K + water naik → coolant masuk oli. Investigasi head gasket / liner / oil cooler. PRIORITAS TINGGI.',           'ACT_NOW'),
('GEARBOX',      'Keausan gear/bearing',           ARRAY['fe','pq_index'],      NULL,             'OVERHAUL',                  'Tren naik Fe+PQ Index mengindikasikan keausan gear/bearing internal. Disarankan inspeksi.',                       'PLAN_ACTION'),
('GEARBOX',      'Kontaminasi seal/breather',      ARRAY['si'],                 NULL,             'INVESTIGATE_SEAL',          'Si naik → kontaminasi dari luar. Cek seal & breather.',                                                           'TIGHTEN_SAMPLING'),
('GEARBOX',      'Water ingress',                  ARRAY['water'],              NULL,             'INVESTIGATE_SEAL_BREATHER', 'Water naik → seal/breather bermasalah. Cek & drain.',                                                             'TIGHTEN_SAMPLING'),
('TRANSMISSION', 'Keausan pump/motor',             ARRAY['cu','al'],            NULL,             'OVERHAUL',                  'Tren naik Cu+Al mengindikasikan keausan pump/motor hidrostatik.',                                                 'PLAN_ACTION'),
('TRANSMISSION', 'Kontaminasi hidrolik (URGENT)',  ARRAY['water','particle_count'], NULL,         'FILTER_AND_FLUSH',          'Water/particle naik di hidrostatik = PRIORITAS TINGGI. Hidrostatik sangat sensitif kontaminasi.',                  'ACT_NOW'),
('TRANSMISSION', 'Viscosity drift',                ARRAY['viscosity_100c'],     NULL,             'CHECK_FLUID',               'Viscosity drift → degradasi atau pakai oli salah. Cek spec & ganti.',                                             'TIGHTEN_SAMPLING'),
('FUEL',         'Kontaminasi microbial',          ARRAY['microbial'],          ARRAY['water','particle_count'], 'FUEL_POLISHING', 'Microbial naik → fuel polishing atau drain & treat tangki.',                                                   'PLAN_ACTION')
ON CONFLICT DO NOTHING;

-- Verifikasi:
-- SELECT COUNT(*) AS components FROM equipment_components;
-- SELECT COUNT(*) AS samples FROM sos_samples;
-- SELECT COUNT(*) AS signatures FROM sos_signatures;
-- SELECT * FROM storage.buckets WHERE id = 'sos-reports';
