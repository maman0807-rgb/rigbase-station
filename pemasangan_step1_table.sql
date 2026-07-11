-- ============================================================
-- STEP 1 — Tabel pemasangan
-- eRAMHoist HM Tracking Induk-Anak
-- Rollback: DROP TABLE IF EXISTS pemasangan CASCADE;
-- ============================================================
-- Catatan konteks Step 0:
--   Tabel induk/anak = equipment (self-referencing via parent_equipment_id)
--   PK induk            = equipment.id  (uuid)
--   HM induk            = equipment.running_hours  (numeric)
--   Identitas anak      = equipment.tag_number  (UNIQUE, tidak NULL)
--                         ← pakai tag_number, bukan serial_number, karena
--                           80%+ serial_number NULL di data live.
--   Mode numpang induk  = follow_parent_hm = TRUE   → punya_meter_sendiri = FALSE
--   Mode meter sendiri  = follow_parent_hm = FALSE  → punya_meter_sendiri = TRUE

CREATE TABLE IF NOT EXISTS pemasangan (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relasi ke equipment yang jadi induk
  induk_id            uuid NOT NULL
                        REFERENCES equipment(id) ON DELETE RESTRICT,

  -- Identitas unit fisik anak — pakai tag_number (UNIQUE, tidak NULL)
  anak_tag            text NOT NULL,

  -- Slot/posisi anak di induk (mis. 'engine_deck', 'transmisi')
  posisi              text,

  -- Periode pemasangan
  tanggal_pasang      date NOT NULL DEFAULT CURRENT_DATE,
  tanggal_lepas       date,          -- NULL = masih terpasang

  -- FALSE = numpang HM induk (transmisi, swivel, dll)
  -- TRUE  = punya meter sendiri (engine ECU)
  punya_meter_sendiri boolean NOT NULL DEFAULT false,

  -- Snapshot mode NUMPANG INDUK (dibekukan saat event pasang/lepas)
  hm_induk_pasang     numeric,       -- HM induk saat anak dipasang
  hm_induk_lepas      numeric,       -- HM induk saat anak dilepas

  -- Snapshot mode METER SENDIRI (dibekukan saat event pasang/lepas)
  hm_meter_pasang     numeric,       -- meter anak saat dipasang
  hm_meter_lepas      numeric,       -- meter anak saat dilepas

  catatan             text,
  created_at          timestamptz NOT NULL DEFAULT now(),

  -- Guard: mode numpang wajib ada hm_induk_pasang; mode sendiri wajib hm_meter_pasang
  CONSTRAINT chk_mode_pasang CHECK (
    (punya_meter_sendiri = false AND hm_induk_pasang IS NOT NULL)
    OR
    (punya_meter_sendiri = true  AND hm_meter_pasang IS NOT NULL)
  ),

  -- Guard: hm_lepas >= hm_pasang bila terisi
  CONSTRAINT chk_induk_urut CHECK (
    hm_induk_lepas IS NULL OR hm_induk_lepas >= hm_induk_pasang
  ),
  CONSTRAINT chk_meter_urut CHECK (
    hm_meter_lepas IS NULL OR hm_meter_lepas >= hm_meter_pasang
  )
);

-- Index untuk query yang sering
CREATE INDEX IF NOT EXISTS idx_pemasangan_anak_tag ON pemasangan(anak_tag);
CREATE INDEX IF NOT EXISTS idx_pemasangan_induk    ON pemasangan(induk_id);
CREATE INDEX IF NOT EXISTS idx_pemasangan_aktif    ON pemasangan(anak_tag) WHERE tanggal_lepas IS NULL;

-- Cegah satu anak terpasang ganda di waktu bersamaan
CREATE UNIQUE INDEX IF NOT EXISTS uq_anak_aktif
  ON pemasangan(anak_tag)
  WHERE tanggal_lepas IS NULL;

-- Verifikasi Step 1:
-- SELECT COUNT(*) FROM pemasangan;       -- harus 0 sebelum backfill
-- \d pemasangan                          -- lihat struktur
