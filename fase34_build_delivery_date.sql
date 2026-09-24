-- ============================================================
-- Fase 34: tambah kolom Build Date & Delivery Date di equipment
-- Buat nyimpen data pabrikan (mis. dari lookup CAT SIS seperti
-- contoh 6TB06109 / Arrangement 7C-6843) — Build Date = tanggal
-- keluar pabrik, Delivery Date = tanggal diterima dari dealer/vendor.
-- Data diisi manual per-equipment lewat form Edit (tab Info → Spesifikasi).
-- ============================================================

ALTER TABLE equipment ADD COLUMN IF NOT EXISTS build_date DATE;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS delivery_date DATE;
