-- ============================================================
-- WAHA WhatsApp Integration — Tahap 0
-- Tabel wa_whitelist & wa_form_session
-- Jalankan di Supabase SQL Editor, project olmowzrlokajhniqijfq
-- (project yang sama dengan eRAMHoist & Logbook)
-- ============================================================

-- 1. Whitelist nomor WA yang boleh entry jam jalan
CREATE TABLE wa_whitelist (
  id         uuid primary key default gen_random_uuid(),
  nomor_wa   text unique not null,   -- format 62817xxxxxxx, tanpa + / spasi
  nama       text not null,
  rig        text,                   -- NULL = admin (akses SEMUA rig, pengganti operator sakit); diisi = operator dibatasi rig itu saja
  aktif      boolean default true,
  created_at timestamptz default now()
);

-- 2. Sesi aktif /form per nomor WA — supaya balasan angka ("2 6 baik")
--    bisa di-resolve ke equipment yang benar
CREATE TABLE wa_form_session (
  nomor_wa     text primary key,
  rig          text not null,
  mapping      jsonb not null,       -- { "1": "TT-100A", "2": "DC-100A", ... }
  generated_at timestamptz default now()
);

-- 3. RLS
-- Kedua tabel ini CUMA diakses n8n lewat service_role key (otomatis bypass RLS),
-- BUKAN dari app eRAMHoist/Logbook atau user login manapun. Jadi RLS diaktifkan
-- TANPA policy sama sekali → default deny-all untuk role anon/authenticated,
-- cuma service_role yang bisa baca/tulis. Ini beda dari pola tabel app-facing
-- (mis. `pemasangan`) yang memang butuh policy terbuka untuk user login.
ALTER TABLE wa_whitelist ENABLE ROW LEVEL SECURITY;
ALTER TABLE wa_form_session ENABLE ROW LEVEL SECURITY;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- Contoh isi whitelist (SESUAIKAN nomor & nama asli, lalu jalankan manual)
-- Ingat: minimal 2 nomor admin (rig=NULL) untuk backup silang operator sakit
-- ============================================================
-- INSERT INTO wa_whitelist (nomor_wa, nama, rig) VALUES
--   ('62811111111', 'Rudi',            'BW-100A'),
--   ('62822222222', 'Operator B',      'BW-100B'),
--   ('62833333333', 'Operator C',      'H35KD'),
--   ('62844444444', 'Operator D',      'KB150A'),
--   ('62855555555', 'Operator E',      'KB150B'),
--   ('62866666666', 'Budi (Admin)',    NULL),
--   ('62877777777', 'Admin Kedua',     NULL);
