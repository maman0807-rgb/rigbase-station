-- Index buat query "Cari Equipment" di Laporan Harian (filter equipment_id) —
-- kemungkinan penyebab respon terasa lambat kalau belum ada index di kolom ini.
create index if not exists idx_lh_entries_equipment_id on public.laporan_harian_entries (equipment_id);
