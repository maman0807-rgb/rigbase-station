-- ============================================================
-- Hapus SKPI di Drawwork (keputusan Maman 2026-10-14)
-- SKPI milik unit Mobile Rig (MR-...), bukan per komponen:
--   DW-H35KD, DW-KB150A  -> nomor sama dengan SKPI MR-nya (duplikat)
--   DW-100A (2019), DW-KB150C (2018) -> SKPI lama, sudah diganti SKPI MR
-- Tidak disentuh: COI ACC-100A/ACC-H35KD, LAINNYA TRANS-STANDBY-02 (nomor SN).
--
-- Satu perintah. Dicocokkan by id + tag + nomor supaya tidak salah hapus.
-- Kolom ringkasan SKPI di equipment ikut dikosongkan otomatis oleh
-- trigger trg_air_after_izin. Hasil: daftar baris yang terhapus
-- (kosong kalau sudah pernah dijalankan).
-- ============================================================

DELETE FROM izin_operasi i
 USING equipment e
 WHERE e.id = i.equipment_id
   AND i.jenis = 'SKPI'
   AND (i.id, e.tag_number, i.nomor) IN (
     ('1aff11ed-2868-4efc-9ad8-53bb4c908224'::uuid, 'DW-100A',   '665/47/PLO/DMT/2019'),
     ('bbb3a388-e6e5-4990-a05e-eaa729660651'::uuid, 'DW-H35KD',  '1521.PLO/47-26/MG.06/DMT/2025'),
     ('09b6a0f1-e180-48cd-b6e6-8abab5170727'::uuid, 'DW-KB150A', '586/47-26/PLO/DMT/2023'),
     ('c1233f5f-0d62-4a68-8986-9b841d030f3f'::uuid, 'DW-KB150C', '538/47-2/PLO/DMT/2018')
   )
RETURNING e.tag_number, i.jenis, i.nomor;
