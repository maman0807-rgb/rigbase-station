-- ============================================================
-- STRESS SCORE — Storage bucket untuk PDF JMP
-- Jalankan di Supabase SQL Editor. Idempoten.
-- Akses upload/baca: Sr Mekanik ke atas.
-- ============================================================

-- Bucket privat untuk dokumen JMP
INSERT INTO storage.buckets (id, name, public)
VALUES ('jmp-docs', 'jmp-docs', false)
ON CONFLICT (id) DO NOTHING;

-- Baca file: Sr Mekanik ke atas
DROP POLICY IF EXISTS "jmp_read" ON storage.objects;
CREATE POLICY "jmp_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'jmp-docs' AND is_sr_mekanik_or_above());

-- Upload file: Sr Mekanik ke atas
DROP POLICY IF EXISTS "jmp_insert" ON storage.objects;
CREATE POLICY "jmp_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'jmp-docs' AND is_sr_mekanik_or_above());

-- (opsional) hapus file: Sr Mekanik ke atas
DROP POLICY IF EXISTS "jmp_delete" ON storage.objects;
CREATE POLICY "jmp_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'jmp-docs' AND is_sr_mekanik_or_above());

-- ============================================================
-- SELESAI. Tanpa SQL ini, ekstraksi & auto-isi tetap jalan;
-- hanya penyimpanan file PDF-nya yang tidak aktif.
-- ============================================================
