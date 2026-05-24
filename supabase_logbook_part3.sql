-- ============================================================
-- LOGBOOK PART 3: siapkan equipment untuk migrasi 33 unit operasional
-- Jalankan di Supabase SQL Editor. Idempoten.
-- ============================================================

-- firestore_id: untuk mapping migrasi + resolve QR lama (QR berisi ID Firebase)
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS firestore_id TEXT;
CREATE INDEX IF NOT EXISTS idx_equipment_firestore ON equipment(firestore_id);

-- ============================================================
-- SELESAI part 3. Lanjut: jalankan migrate_equipment.cjs (Claude).
-- ============================================================
