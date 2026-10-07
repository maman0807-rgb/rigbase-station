-- ============================================================
-- FASE 37: Pedoman AIR Tahap 3 — Spare Part VIS
-- Pedoman AIR No. A4-009/PHE23000/2026-S9 Rev.0 (Tabel 1)
--
-- Jalankan di Supabase SQL Editor SETELAH fase35 & fase36. Aman re-run.
-- Uji: fase37_air_tahap3_test.sql (otomatis rollback).
--
-- Keputusan Maman (2026-10-07):
--  * materials.kimap = No. material SAP (dipakai, tidak dibuat kolom baru)
--  * materials.safety_stock = stok minimum (dipakai)
--  * SEMUA part keluar dihitung pemakaian di proyeksi 2 tahun (termasuk
--    Peminjaman & Permintaan). Penyesuaian Audit Gudang bukan pemakaian.
--  * Batas usia simpan: Lubricant 24, Consumable 36, lainnya 60 bulan (usulan)
--
-- Tidak mengubah kode/alur Logbook: hanya kolom baru (Logbook tidak
-- membaca/menulis kolom yang tidak dikenalnya) + view + tabel baru.
-- ROLLBACK di bagian bawah.
-- ============================================================


-- ============================================================
-- 1. KOLOM BARU DI materials
-- ============================================================
ALTER TABLE materials
  ADD COLUMN IF NOT EXISTS kelas_vis_override TEXT CHECK (kelas_vis_override IN ('V','I','S')),
  ADD COLUMN IF NOT EXISTS stok_maksimum      NUMERIC;

COMMENT ON COLUMN materials.kimap              IS 'No. material SAP (KIMAP)';
COMMENT ON COLUMN materials.safety_stock       IS 'Stok minimum (AIR: spare part Vital wajib tersedia)';
COMMENT ON COLUMN materials.kelas_vis_override IS 'AIR: koreksi manual kelas V/I/S. NULL = otomatis dari criticality equipment terkait';


-- ============================================================
-- 2. KONFIGURASI
-- ============================================================
INSERT INTO air_config (kunci, nilai, dari_pedoman, keterangan) VALUES
  ('proyeksi_sparepart_bulan', '24', true,
   'Kebutuhan spare part dianalisis untuk 2 tahun (two years spare part)'),
  ('usia_simpan_maks_bulan', '{"Lubricant":24,"Consumable":36,"_default":60}', false,
   'Batas usia penyimpanan per kategori material (bulan). _default untuk kategori lain.')
ON CONFLICT (kunci) DO NOTHING;


-- ============================================================
-- 3. RELASI PART ↔ EQUIPMENT (gabungan 2 sumber yang sudah ada)
--    materials.related_equipments (Gudang Logbook) + cspp_equipment_mapping (CSPP)
-- ============================================================
CREATE OR REPLACE VIEW v_material_equipment
WITH (security_invoker = true) AS
SELECT DISTINCT x.material_id, x.equipment_id
FROM (
  SELECT m.id AS material_id, (j.val)::uuid AS equipment_id
    FROM materials m
    CROSS JOIN LATERAL jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(m.related_equipments) = 'array' THEN m.related_equipments ELSE '[]'::jsonb END
    ) AS j(val)
   WHERE j.val ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  UNION ALL
  SELECT c.material_id, c.equipment_id FROM cspp_equipment_mapping c
) x
JOIN equipment e ON e.id = x.equipment_id;


-- ============================================================
-- 4. VIEW UTAMA: v_sparepart_vis
--    kelas VIS, status stok (habis vs dipinjam), usia simpan FIFO,
--    proyeksi kebutuhan 2 tahun, flag alert.
-- ============================================================
CREATE OR REPLACE VIEW v_sparepart_vis
WITH (security_invoker = true) AS
WITH cfg AS (
  SELECT
    COALESCE((SELECT (nilai #>> '{}')::int FROM air_config WHERE kunci = 'proyeksi_sparepart_bulan'), 24) AS proyeksi_bulan,
    COALESCE((SELECT nilai FROM air_config WHERE kunci = 'usia_simpan_maks_bulan'), '{"_default":60}'::jsonb) AS usia_cfg,
    -- Data transaksi baru ada sejak transaksi pertama tercatat; rata-rata bulanan dibagi
    -- jumlah bulan data yang benar-benar ada (maks = periode proyeksi)
    (SELECT min(created_at) FROM stock_transactions) AS data_sejak
),
crit AS (
  SELECT me.material_id,
         count(*)::int AS jumlah_equipment,
         bool_or(e.is_vital) AS ada_vital,
         bool_or(e.criticality = 'IMPORTANT') AS ada_important
    FROM v_material_equipment me JOIN equipment e ON e.id = me.equipment_id
   GROUP BY me.material_id
),
pakai AS (
  -- Pemakaian bersih: keluar (Input Harian, WO, Gudang manual) dikurangi koreksi
  -- masuk dari edit/hapus Input Harian & WO. Audit Gudang = penyesuaian, bukan pemakaian.
  SELECT t.material_id,
         sum(CASE WHEN t.tipe = 'keluar' AND t.sumber IN ('dailyLog','workOrder','manual','manual_app') THEN t.jumlah
                  WHEN t.tipe = 'masuk'  AND t.sumber IN ('dailyLog','workOrder')                      THEN -t.jumlah
                  ELSE 0 END) AS qty
    FROM stock_transactions t, cfg
   WHERE t.created_at >= NOW() - make_interval(months => cfg.proyeksi_bulan)
   GROUP BY t.material_id
),
terakhir AS (
  -- Transaksi masuk terakhir & peminjaman sesudahnya (untuk status "Dipinjam")
  SELECT t.material_id, max(t.created_at) FILTER (WHERE t.tipe = 'masuk') AS masuk_terakhir
    FROM stock_transactions t GROUP BY t.material_id
),
pinjam AS (
  SELECT t.material_id, sum(t.jumlah) AS qty, max(t.created_at) AS sejak
    FROM stock_transactions t
    JOIN daily_logs d ON d.id = t.daily_log_id AND d.maintenance_type = 'Peminjaman'
    LEFT JOIN terakhir tr ON tr.material_id = t.material_id
   WHERE t.tipe = 'keluar' AND (tr.masuk_terakhir IS NULL OR t.created_at > tr.masuk_terakhir)
   GROUP BY t.material_id
),
terima AS (
  -- Penerimaan barang (masuk manual Gudang), terbaru dulu, kumulatif → FIFO:
  -- sisa stok dianggap berasal dari penerimaan terbaru.
  SELECT t.material_id, t.created_at, t.jumlah,
         sum(t.jumlah) OVER (PARTITION BY t.material_id ORDER BY t.created_at DESC, t.id) AS kum
    FROM stock_transactions t
   WHERE t.tipe = 'masuk' AND t.sumber IN ('manual','manual_app')
),
fifo AS (
  SELECT m.id AS material_id,
         min(r.created_at) FILTER (WHERE r.kum - r.jumlah < m.stok) AS tgl_tertua,
         COALESCE(max(r.kum), 0) >= COALESCE(m.stok, 0) AS tercakup
    FROM materials m LEFT JOIN terima r ON r.material_id = m.id
   GROUP BY m.id, m.stok
),
base AS (
  SELECT m.*,
         COALESCE(c.jumlah_equipment, 0) AS jumlah_equipment,
         CASE WHEN c.ada_vital THEN 'V' WHEN c.ada_important THEN 'I' ELSE 'S' END AS kelas_vis_otomatis,
         GREATEST(0, COALESCE(p.qty, 0)) AS pakai_periode,
         GREATEST(1, LEAST(cfg.proyeksi_bulan,
           CEIL(EXTRACT(EPOCH FROM (NOW() - COALESCE(cfg.data_sejak, NOW()))) / 2629800.0)))::int AS bulan_data,
         cfg.proyeksi_bulan,
         COALESCE(pj.qty, 0) AS qty_dipinjam, pj.sejak AS dipinjam_sejak,
         -- Usia simpan: dari penerimaan FIFO; kalau riwayat masuk tidak menutup stok
         -- (stok awal hasil import), pakai tgl_masuk (format YYYY-MM-DD) / created_at.
         CASE WHEN COALESCE(m.stok, 0) <= 0 THEN NULL
              WHEN f.tercakup AND f.tgl_tertua IS NOT NULL THEN f.tgl_tertua::date
              WHEN m.tgl_masuk ~ '^\d{4}-\d{2}-\d{2}' THEN substr(m.tgl_masuk, 1, 10)::date
              ELSE m.created_at::date END AS tgl_stok_tertua,
         (COALESCE(m.stok, 0) > 0 AND NOT f.tercakup) AS usia_perkiraan,
         COALESCE((cfg.usia_cfg ->> m.category)::int, (cfg.usia_cfg ->> '_default')::int, 60) AS usia_maks_bulan
    FROM materials m
    CROSS JOIN cfg
    LEFT JOIN crit   c  ON c.material_id  = m.id
    LEFT JOIN pakai  p  ON p.material_id  = m.id
    LEFT JOIN pinjam pj ON pj.material_id = m.id
    LEFT JOIN fifo   f  ON f.material_id  = m.id
)
SELECT
  b.id, b.part_number, b.description, b.category, b.satuan, b.kimap AS sap_material_no, b.penyimpanan,
  COALESCE(b.stok, 0) AS stok, COALESCE(b.safety_stock, 0) AS stok_minimum, b.stok_maksimum, b.lead_time_days,
  b.unit_price,
  b.jumlah_equipment, (b.jumlah_equipment > 0) AS dipetakan,
  b.kelas_vis_otomatis, b.kelas_vis_override,
  COALESCE(b.kelas_vis_override, b.kelas_vis_otomatis) AS kelas_vis,
  -- Status stok: habis karena dipinjam ≠ habis permanen
  CASE WHEN COALESCE(b.stok, 0) <= 0 AND b.qty_dipinjam > 0 THEN 'DIPINJAM'
       WHEN COALESCE(b.stok, 0) <= 0 THEN 'HABIS'
       WHEN COALESCE(b.safety_stock, 0) > 0 AND b.stok <= b.safety_stock THEN 'RENDAH'
       WHEN b.stok_maksimum IS NOT NULL AND b.stok > b.stok_maksimum THEN 'BERLEBIH'
       ELSE 'AMAN' END AS status_stok,
  b.qty_dipinjam, b.dipinjam_sejak,
  b.tgl_stok_tertua, b.usia_perkiraan,
  CASE WHEN b.tgl_stok_tertua IS NULL THEN NULL
       ELSE (EXTRACT(YEAR FROM age(CURRENT_DATE, b.tgl_stok_tertua)) * 12
           + EXTRACT(MONTH FROM age(CURRENT_DATE, b.tgl_stok_tertua)))::int END AS usia_bulan,
  b.usia_maks_bulan,
  -- Proyeksi 2 tahun
  b.pakai_periode, b.bulan_data,
  ROUND(b.pakai_periode / b.bulan_data, 2) AS pakai_per_bulan,
  CEIL(b.pakai_periode / b.bulan_data * b.proyeksi_bulan)::numeric AS kebutuhan_2th,
  GREATEST(0, CEIL(b.pakai_periode / b.bulan_data * b.proyeksi_bulan)
              + COALESCE(b.safety_stock, 0) - COALESCE(b.stok, 0))::numeric AS rekomendasi_pengadaan,
  -- Flag alert
  (COALESCE(b.kelas_vis_override, b.kelas_vis_otomatis) = 'V' AND COALESCE(b.stok, 0) <= 0 AND b.qty_dipinjam = 0) AS alert_vital_habis,
  (COALESCE(b.kelas_vis_override, b.kelas_vis_otomatis) = 'V' AND COALESCE(b.stok, 0) > 0
     AND COALESCE(b.safety_stock, 0) > 0 AND b.stok <= b.safety_stock) AS alert_vital_rendah,
  (COALESCE(b.kelas_vis_override, b.kelas_vis_otomatis) = 'V' AND COALESCE(b.safety_stock, 0) = 0) AS alert_vital_tanpa_minimum,
  (b.tgl_stok_tertua IS NOT NULL AND
   (EXTRACT(YEAR FROM age(CURRENT_DATE, b.tgl_stok_tertua)) * 12
    + EXTRACT(MONTH FROM age(CURRENT_DATE, b.tgl_stok_tertua))) > b.usia_maks_bulan) AS alert_usia_simpan
FROM base b;


-- ============================================================
-- 5. RESERVASI SPARE PART (nomor reservasi resmi dari SAP)
-- ============================================================
CREATE TABLE IF NOT EXISTS reservasi_sparepart (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id         UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  equipment_id        UUID REFERENCES equipment(id) ON DELETE SET NULL,
  qty                 NUMERIC NOT NULL CHECK (qty > 0),
  sap_reservation_no  TEXT,
  tanggal             DATE NOT NULL DEFAULT CURRENT_DATE,
  status              TEXT NOT NULL DEFAULT 'DIAJUKAN'
    CHECK (status IN ('DIAJUKAN','DISETUJUI','DIAMBIL','BATAL')),
  catatan             TEXT,
  created_by          UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reservasi_material ON reservasi_sparepart(material_id);

ALTER TABLE reservasi_sparepart ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reservasi_read"  ON reservasi_sparepart;
CREATE POLICY "reservasi_read"  ON reservasi_sparepart FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "reservasi_write" ON reservasi_sparepart;
CREATE POLICY "reservasi_write" ON reservasi_sparepart FOR ALL TO authenticated
  USING (is_gudang() OR is_sr_mekanik_or_above()) WITH CHECK (is_gudang() OR is_sr_mekanik_or_above());


-- ============================================================
-- 6. VERIFIKASI
-- ============================================================
-- Ringkasan kelas & status:
-- SELECT kelas_vis, status_stok, count(*) FROM v_sparepart_vis GROUP BY 1,2 ORDER BY 1,2;
-- Part Vital yang perlu tindakan:
-- SELECT part_number, description, stok, stok_minimum, status_stok FROM v_sparepart_vis
--  WHERE alert_vital_habis OR alert_vital_rendah ORDER BY part_number;


-- ============================================================
-- ROLLBACK
-- ============================================================
-- DROP VIEW IF EXISTS v_sparepart_vis, v_material_equipment;
-- DROP TABLE IF EXISTS reservasi_sparepart;
-- ALTER TABLE materials DROP COLUMN IF EXISTS kelas_vis_override, DROP COLUMN IF EXISTS stok_maksimum;
-- DELETE FROM air_config WHERE kunci IN ('proyeksi_sparepart_bulan','usia_simpan_maks_bulan');
