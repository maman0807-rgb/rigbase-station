-- Tracking "diverifikasi oleh siapa" untuk Laporan Harian RAM.
-- Konteks: laporan yang masuk via bot (Telegram/WhatsApp) mendarat sebagai status='draft'
-- dan direview manusia (SPV/admin, per pembagian peran yang sudah disepakati Maman) sebelum
-- disimpan final via lhSaveFinal(). Sebelumnya tidak ada jejak siapa yang melakukan verifikasi
-- itu -- cuma created_by (NULL untuk laporan bot) dan status. Kolom ini mengisi kekosongan itu,
-- diisi tiap kali lhSaveFinal() dijalankan (baik draft->final pertama kali, maupun edit ulang
-- laporan yang sudah final), bukan cuma sekali di awal.
ALTER TABLE laporan_harian
  ADD COLUMN IF NOT EXISTS verified_by      uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS verified_by_name text,
  ADD COLUMN IF NOT EXISTS verified_at      timestamptz;

NOTIFY pgrst, 'reload schema';
