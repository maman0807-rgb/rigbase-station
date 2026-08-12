-- ============================================================
-- eRAMHoist Fase 20 — Edit foto downtime (RLS UPDATE policy)
-- Sebelumnya downtime_photos cuma punya policy SELECT/INSERT/DELETE
-- -- kalau mekanik salah isi fase/tanggal/caption, satu-satunya cara
-- benerin adalah hapus + upload ulang gambarnya.
-- Fitur "✎ Edit" baru (tab History & modal Catat Downtime) butuh
-- policy UPDATE ini supaya nggak silently gagal karena RLS.
--
-- Rule: ADMIN ONLY (beda dari delete yang boleh sr_mekanik ke atas)
-- -- sesuai keputusan user 12 Agustus 2026.
-- Jalankan SEKALI di Supabase SQL Editor.
-- ============================================================

DROP POLICY IF EXISTS dp_update ON downtime_photos;
CREATE POLICY dp_update ON downtime_photos FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename = 'downtime_photos' ORDER BY policyname;
-- harusnya ada 4 baris: dp_delete, dp_insert, dp_read, dp_update

NOTIFY pgrst, 'reload schema';
