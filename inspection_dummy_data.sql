-- ============================================================
-- RIGBASE INSPECTION — DUMMY DATA SAMPLE
-- ============================================================
-- 2 siklus + 6 findings buat testing UI Fase 2-7.
-- Aman dijalankan ulang (ON CONFLICT inspection_code DO NOTHING).
-- ============================================================

BEGIN;

-- ============================================================
-- SIKLUS 1: SIKLUS-2026-001
-- Rig: BW-100A | Cat 3 | PT PJ-Tek Mandiri | Completed
-- ============================================================
INSERT INTO inspections (
  inspection_code, parent_unit_id, kategori_inspeksi,
  client, service, rig_type, manufacturer, year_manufactured, model_serial,
  height_of_mast, hook_load, power_hp, place_of_inspection,
  start_date, end_date, pi_company, rig_inspector,
  status, progress_akumulatif, catatan
) VALUES (
  'SIKLUS-2026-001',
  (SELECT id FROM parent_units WHERE name='BW-100A'),
  'Cat 3',
  'PT Pertamina EP', 'Workover Service', 'Mobile Rig 350 HP',
  'Cooper', 1980, 'LTO-350 SN 1407',
  29.6, 63.45, 350, 'Wellpad WP-X1, Field Cepu',
  '2026-04-05', '2026-04-15',
  'PT PJ-Tek Mandiri', 'Ir. Budi Santoso',
  'Completed', 100,
  'Inspeksi rutin 6 bulanan. Semua temuan sudah diclose sebelum siklus berakhir.'
) ON CONFLICT (inspection_code) DO NOTHING;

-- Findings untuk SIKLUS-2026-001
INSERT INTO inspection_findings (
  inspection_id, no_urut, equipment_id, equipment_name_snapshot, qty,
  bagian, category, finding, mpi_result, acceptance_criteria, recommendation,
  tgl_ditemukan, status, tgl_closed, pic_perbaikan, catatan
) VALUES
  -- Finding #1: Drawwork Brake Major - sudah Closed
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-001'),
    1,
    (SELECT id FROM equipment WHERE tag_number='DW-100A'),
    'Drawwork BW-100A (Cooper LTO-350)', '1ea',
    NULL,
    'Major',
    'Kampas brake aus tidak merata, ketebalan tersisa 3mm (minimum 5mm per spec).',
    'N/A',
    'API Spec 7K',
    'Ganti kampas brake set lengkap. Stel ulang brake balance.',
    '2026-04-07', 'Closed', '2026-04-10', 'Tim Mekanik BW-100A',
    'Kampas baru sudah dipasang dan tested 5 cycle. OK.'
  ),
  -- Finding #2: Mast Crown Block Critical - sudah Closed
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-001'),
    2,
    (SELECT id FROM equipment WHERE tag_number='MAST-100A'),
    'Mast BW-100A (Tubing Truss 29.6m)', '1ea',
    'Crown Block',
    'Critical',
    'Indikasi crack pada wirerope socket Crown Block sebelah kanan, panjang ±15mm.',
    'Discontinuity',
    'API RP 8B Section 5.3.2.4',
    'Replace socket dengan unit baru. NDT verifikasi area sekitar setelah replacement.',
    '2026-04-08', 'Closed', '2026-04-13', 'PT Welltech Indonesia',
    'Socket replacement selesai. MPI follow-up: No Discontinuity. Re-inspected by PI: OK.'
  ),
  -- Finding #3: BOP Annular - N/A (kondisi baik)
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-001'),
    3,
    (SELECT id FROM equipment WHERE tag_number='BOPA-100A'),
    'BOP Annular BW-100A (Hydrill GK)', '1ea',
    NULL,
    'N/A',
    'Equipment dalam kondisi baik. Pressure test 3000 psi hold selama 10 menit, no leak.',
    'No Discontinuity',
    'API Spec 16A',
    'Continue normal operation. Next inspection per schedule.',
    '2026-04-12', 'Closed', '2026-04-12', '-',
    NULL
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- SIKLUS 2: SIKLUS-2026-002
-- Rig: BW H35KD | Cat 4 | PT BKI | On Progress
-- ============================================================
INSERT INTO inspections (
  inspection_code, parent_unit_id, kategori_inspeksi,
  client, service, rig_type, manufacturer, year_manufactured, model_serial,
  height_of_mast, hook_load, power_hp, place_of_inspection,
  start_date, end_date, pi_company, rig_inspector,
  status, progress_akumulatif, catatan
) VALUES (
  'SIKLUS-2026-002',
  (SELECT id FROM parent_units WHERE name='BW H35KD'),
  'Cat 4',
  'PT Pertamina EP', 'Workover Service', 'Mobile Rig H35KD',
  'Cooper', 1985, 'H35KD SN 6TB10789',
  30.0, 70.0, 350, 'Wellpad WP-Y3, Field Sangasanga',
  '2026-05-01', NULL,
  'PT BKI', 'Capt. Bambang Wijaya',
  'On Progress', 65,
  'Inspeksi 4 tahunan untuk perpanjangan PLO. Estimasi selesai akhir Mei 2026.'
) ON CONFLICT (inspection_code) DO NOTHING;

-- Findings untuk SIKLUS-2026-002
INSERT INTO inspection_findings (
  inspection_id, no_urut, equipment_id, equipment_name_snapshot, qty,
  bagian, category, finding, mpi_result, acceptance_criteria, recommendation,
  tgl_ditemukan, status, tgl_closed, pic_perbaikan, catatan
) VALUES
  -- Finding #1: BOP Double Ram Critical - masih Open
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-002'),
    1,
    (SELECT id FROM equipment WHERE tag_number='BOPDR-H35KD'),
    'BOP Double Ram BW H35KD', '1ea',
    NULL,
    'Critical',
    'Leakage pada upper ram seal saat pressure test 5000 psi (max allowable rated). Pressure drop 100 psi dalam 5 menit.',
    'N/A',
    'API Spec 16A — Pressure test acceptance',
    'Replace upper ram seal kit lengkap. Re-test setelah replacement. Bring spare seals dari workshop pusat.',
    '2026-05-08', 'Open', NULL, 'Tim Workshop Cepu',
    'PT BKI sudah issue Non-Conformity Report (NCR). Menunggu spare part dari workshop.'
  ),
  -- Finding #2: Mast Upper Major - masih Open
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-002'),
    2,
    (SELECT id FROM equipment WHERE tag_number='MAST-H35KD'),
    'Mast BW H35KD', '1ea',
    'Upper',
    'Major',
    'Surface crack pada lateral brace Upper section, panjang ±25mm. Indikasi fatigue.',
    'Discontinuity',
    'API RP 8B Section 5.3.2.4 — Crack acceptance criteria',
    'Welding repair dengan procedure qualification. NDT verifikasi setelah repair. Monitor next inspection.',
    '2026-05-10', 'Open', NULL, 'Tim Welding PT Steeltech',
    'Welding procedure (WPS) sedang disiapkan. Estimasi repair 3 hari setelah WPS approved.'
  ),
  -- Finding #3: Genset N/A (kondisi baik)
  (
    (SELECT id FROM inspections WHERE inspection_code='SIKLUS-2026-002'),
    3,
    (SELECT id FROM equipment WHERE tag_number='GS-H35KD'),
    'Genset BW H35KD', '1ea',
    NULL,
    'N/A',
    'Genset dalam kondisi baik. Load test 80% rated capacity selama 4 jam, voltage stable 380V ±2%.',
    'No Discontinuity',
    'IEC 60034 — Rotating electrical machines',
    'Continue normal operation. Recommended oil change at next 500h running.',
    '2026-05-12', 'Closed', '2026-05-12', '-',
    NULL
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'SIKLUS' AS info, inspection_code AS code,
       (SELECT name FROM parent_units WHERE id=i.parent_unit_id) AS rig,
       kategori_inspeksi, status, progress_akumulatif
FROM inspections i
ORDER BY inspection_code;

SELECT 'FINDINGS' AS info,
       (SELECT inspection_code FROM inspections WHERE id=f.inspection_id) AS siklus,
       f.no_urut, f.equipment_name_snapshot, f.bagian, f.category, f.status
FROM inspection_findings f
ORDER BY siklus, no_urut;

-- Ekspektasi:
--   2 siklus: SIKLUS-2026-001 (Completed 100%), SIKLUS-2026-002 (On Progress 65%)
--   6 findings: 3 di siklus 1 (all Closed), 3 di siklus 2 (1 Closed N/A, 2 Open)

COMMIT;
