-- ============================================================
-- FASE 40: Laporan Harian v2 — "📋 Tempel Laporan" (format rangkuman baru 06/10/2026)
--
-- Pilihan A (disetujui Maman 2026-10-08): rangkuman dari Telegram ditempel di app →
-- dibaca otomatis (js/laporan_harian_v2.js, tanpa AI) → jadi draft Laporan Harian
-- biasa → admin cek → Simpan Final seperti sekarang.
--
-- HANYA MENAMBAH KOLOM (additive). Tabel & data lama tidak diubah, jadi Analisa
-- Laporan, Laporan PLO, riwayat equipment, peringatan "CM/TS tanpa Downtime" tetap jalan.
-- Jalankan di Supabase SQL Editor. Aman re-run.
-- ============================================================

-- Header: penanda format + status rig (bagian A rangkuman)
ALTER TABLE laporan_harian
  ADD COLUMN IF NOT EXISTS format_versi TEXT,          -- 'v2' = dari Tempel Laporan format baru
  ADD COLUMN IF NOT EXISTS status_rig   JSONB;         -- [{unit, lokasi, keterangan, rh:{"Eng rig":3,...}|null}]

-- Entry: field pekerjaan yang belum punya tempat di kartu lama
ALTER TABLE laporan_harian_entries
  ADD COLUMN IF NOT EXISTS tipe_v2           TEXT,     -- 'BARU' | 'LANJUT' (NULL = entry format lama)
  ADD COLUMN IF NOT EXISTS no_urut           INT,      -- nomor blok di rangkuman
  ADD COLUMN IF NOT EXISTS unit_lapor        TEXT,     -- unit seperti di rangkuman (BW KB150A / nama unit non-rig)
  ADD COLUMN IF NOT EXISTS judul_lapor       TEXT,     -- equipment seperti ditulis di rangkuman
  ADD COLUMN IF NOT EXISTS jenis             TEXT,     -- CM | PM | OH | Cat 3 | Cat 4 | Inspeksi | Lainnya
  ADD COLUMN IF NOT EXISTS jenis_asli        TEXT,
  ADD COLUMN IF NOT EXISTS gejala            TEXT,
  ADD COLUMN IF NOT EXISTS mulai_pekerjaan   DATE,     -- tanggal mulai pekerjaan (bisa jauh sebelum tanggal laporan)
  ADD COLUMN IF NOT EXISTS selesai_pekerjaan DATE,
  ADD COLUMN IF NOT EXISTS jam_mulai         TEXT,     -- "10:00" (jam kerja hari itu)
  ADD COLUMN IF NOT EXISTS jam_selesai       TEXT,
  ADD COLUMN IF NOT EXISTS meter_tipe        TEXT,     -- 'HM' | 'KM' (nilainya di kolom rh yang sudah ada)
  ADD COLUMN IF NOT EXISTS rig_stop          BOOLEAN,  -- NULL = belum diisi
  ADD COLUMN IF NOT EXISTS rig_stop_ket      TEXT,     -- mis. "7 jam" / "sejak 06/10 10.00"
  ADD COLUMN IF NOT EXISTS pic               TEXT,
  ADD COLUMN IF NOT EXISTS no_wo             TEXT,
  ADD COLUMN IF NOT EXISTS status_v2         TEXT,     -- Selesai | Tunggu | Progress
  ADD COLUMN IF NOT EXISTS status_ket        TEXT,     -- mis. "part", "realise SPK"
  ADD COLUMN IF NOT EXISTS status_asli       TEXT,
  ADD COLUMN IF NOT EXISTS part              JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [{nama, pn, qty, satuan, sumber}] — dicatat saja, TIDAK memotong stok
  ADD COLUMN IF NOT EXISTS flags             JSONB NOT NULL DEFAULT '[]'::jsonb;  -- [{level:'kurang'|'cek', kode, pesan}] hasil pembacaan

COMMENT ON COLUMN laporan_harian_entries.part IS 'Laporan Harian v2: part yang disebut di rangkuman. Hanya catatan — stok Gudang tetap dipotong lewat Input Harian Logbook.';

NOTIFY pgrst, 'reload schema';

-- Verifikasi:
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'laporan_harian_entries' AND column_name IN ('tipe_v2','gejala','rig_stop','part','flags');  -- 5 baris

-- ROLLBACK (kolom baru saja; data format lama tidak terpengaruh):
-- ALTER TABLE laporan_harian DROP COLUMN IF EXISTS format_versi, DROP COLUMN IF EXISTS status_rig;
-- ALTER TABLE laporan_harian_entries DROP COLUMN IF EXISTS tipe_v2, DROP COLUMN IF EXISTS no_urut,
--   DROP COLUMN IF EXISTS unit_lapor, DROP COLUMN IF EXISTS judul_lapor, DROP COLUMN IF EXISTS jenis,
--   DROP COLUMN IF EXISTS jenis_asli, DROP COLUMN IF EXISTS gejala, DROP COLUMN IF EXISTS mulai_pekerjaan,
--   DROP COLUMN IF EXISTS selesai_pekerjaan, DROP COLUMN IF EXISTS jam_mulai, DROP COLUMN IF EXISTS jam_selesai,
--   DROP COLUMN IF EXISTS meter_tipe, DROP COLUMN IF EXISTS rig_stop, DROP COLUMN IF EXISTS rig_stop_ket,
--   DROP COLUMN IF EXISTS pic, DROP COLUMN IF EXISTS no_wo, DROP COLUMN IF EXISTS status_v2,
--   DROP COLUMN IF EXISTS status_ket, DROP COLUMN IF EXISTS status_asli, DROP COLUMN IF EXISTS part, DROP COLUMN IF EXISTS flags;
