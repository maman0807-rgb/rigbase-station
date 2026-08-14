-- ============================================================
-- FASE 25 — Perbaikan 2 celah keamanan kritis dari audit 2026-08-14
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
-- ============================================================

-- ------------------------------------------------------------
-- 1) profiles_update_own cuma ngunci kolom `role`, bukan `can_payroll`.
--    Akibatnya user mana pun (login apa saja) bisa PATCH profilnya
--    sendiri jadi can_payroll=true lewat REST API langsung, buka akses
--    penuh ke 7 tabel payroll (gaji, kasbon, BPJS, NPWP dll).
--    Fix: WITH CHECK juga wajib can_payroll tetap sama kayak nilai lama.
--    (Admin tetap bisa ubah can_payroll siapa pun lewat policy
--    profiles_admin_all yang terpisah, tidak kena batasan ini.)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM profiles WHERE id = auth.uid())
    AND can_payroll = (SELECT can_payroll FROM profiles WHERE id = auth.uid())
  );
-- Catatan: user biasa boleh update profil sendiri (nama, telegram_user_id,
-- dll) TAPI tidak boleh ubah role ATAU can_payroll sendiri.

-- ------------------------------------------------------------
-- 2) rca_records pakai USING(true) — pembatasan "Sr Mekanik ke atas"
--    cuma ada di UI (index.html), bukan di database. Siapa pun yang
--    login bisa insert/edit/hapus record RCA langsung lewat API.
--    Fix: samakan pola dengan fmea_entries (fungsi serupa, sudah benar
--    role-gated sejak awal) — is_sr_mekanik_or_above() di DB juga.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "rca_auth" ON rca_records;
CREATE POLICY "rca_all" ON rca_records
  FOR ALL TO authenticated
  USING (is_sr_mekanik_or_above())
  WITH CHECK (is_sr_mekanik_or_above());

-- ------------------------------------------------------------
-- Verifikasi kedua policy sudah terpasang benar:
-- ------------------------------------------------------------
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE (tablename = 'profiles' AND policyname = 'profiles_update_own')
   OR (tablename = 'rca_records' AND policyname = 'rca_all');
