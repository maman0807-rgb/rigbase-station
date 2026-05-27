-- ============================================================
-- eRAMHoist Fase 6 — Downtime Photo Storage
-- Tambah dukungan upload foto per kejadian downtime/perbaikan
-- Jalankan SEKALI di Supabase SQL Editor.
-- ============================================================

-- 6.1 Tabel downtime_photos
CREATE TABLE IF NOT EXISTS downtime_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  downtime_event_id UUID NOT NULL REFERENCES downtime_events(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,           -- path di Supabase Storage bucket
  phase TEXT CHECK (phase IN ('before','after','part','other')) DEFAULT 'before',
  caption TEXT,                          -- max 200 char
  uploaded_by UUID REFERENCES profiles(id),
  uploaded_by_name TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_downtime_photos_event ON downtime_photos(downtime_event_id);

-- 6.2 Storage bucket — public read, authenticated write
INSERT INTO storage.buckets (id, name, public)
VALUES ('downtime-photos','downtime-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 6.3 RLS policies untuk tabel
ALTER TABLE downtime_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dp_read ON downtime_photos;
CREATE POLICY dp_read ON downtime_photos FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS dp_insert ON downtime_photos;
CREATE POLICY dp_insert ON downtime_photos FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS dp_delete ON downtime_photos;
CREATE POLICY dp_delete ON downtime_photos FOR DELETE TO authenticated USING (
  uploaded_by = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sr_mekanik','spv','sr_spv','astmen','admin'))
);

-- 6.4 Storage RLS — bucket downtime-photos
DROP POLICY IF EXISTS "downtime-photos read" ON storage.objects;
CREATE POLICY "downtime-photos read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'downtime-photos');

DROP POLICY IF EXISTS "downtime-photos write" ON storage.objects;
CREATE POLICY "downtime-photos write" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'downtime-photos');

DROP POLICY IF EXISTS "downtime-photos delete" ON storage.objects;
CREATE POLICY "downtime-photos delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'downtime-photos');

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'downtime_photos' AS tabel, COUNT(*) FROM downtime_photos
UNION ALL
SELECT 'storage.buckets (downtime-photos)', COUNT(*) FROM storage.buckets WHERE id='downtime-photos';
