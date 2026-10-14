-- ============================================================
-- FASE 43: Samakan Kategori Aset AIR untuk equipment yang pindah
-- kategori di fase41 (keputusan Maman 2026-10-14)
--
--   Diubah (ikut rekan sekategorinya):
--     Power Tong Wellkin-01/04/05, MuBo KB150C   -> LFT (Handling Tools)
--     Raising RAM, Working Floor KB150C          -> WIN (Mast)
--     Transmisi Allison CLT backup               -> TRK (Prime Mover)
--   Sengaja TIDAK diubah:
--     Air Receiver Tank KB150A/B/C  tetap STA (bejana tekan, pendekatan integrity)
--     Engine Power Swivel           tetap ROT
--     Truck/Head Truck/Crane Truck MTU tetap WIN (ikut keputusan fase35: MTU = WIN)
--
-- Satu perintah saja (SQL Editor menjalankan tiap perintah terpisah).
-- Hanya mengubah kalau nilainya masih sama dengan nilai lama, jadi
-- isian manual yang sudah diganti tidak tertimpa. Aman di-run ulang.
-- Hasil: daftar equipment yang diubah (kosong kalau sudah pernah jalan).
-- ============================================================

WITH v(tag, lama, baru) AS (VALUES
  ('HYDTONG-Wellkin-01',  'AUX', 'LFT'),
  ('HYDTONG-Wellkin-04',  'ROT', 'LFT'),
  ('HYDTONG-Wellkin-05',  'AUX', 'LFT'),
  ('MUBO-BW-KB150C',      'WIN', 'LFT'),
  ('Rai-BW-KB150.C',      'SNE', 'WIN'),
  ('WPF-BW-KB150.C',      'AUX', 'WIN'),
  ('TRANS-BACKUP-CLT750', 'WIN', 'TRK')
), upd AS (
  UPDATE equipment e
     SET kategori_aset = v.baru
    FROM v
   WHERE btrim(e.tag_number) = v.tag
     AND e.kategori_aset = v.lama
  RETURNING e.tag_number, e.nama_equipment, v.lama, e.kategori_aset AS baru
)
SELECT * FROM upd ORDER BY tag_number;
