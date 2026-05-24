-- =====================================================================
-- Kolom Overhaul & Kelayakan (berbasis jam) untuk tabel equipment
-- Fase 1: lifecycle TOH/GOH/umur ekonomis dari running_hours (HM).
-- Jalankan SEKALI di Supabase SQL Editor (project olmowzrlokajhniqijfq).
-- =====================================================================
alter table public.equipment
  add column if not exists toh_interval_hours  numeric,  -- interval Top Overhaul (jam), dari OEM
  add column if not exists goh_interval_hours  numeric,  -- interval General Overhaul (jam), dari OEM
  add column if not exists economic_life_hours numeric,  -- batas umur ekonomis (jam) → kandidat ganti
  add column if not exists last_toh_hours      numeric,  -- HM saat TOH terakhir (baseline; null=0)
  add column if not exists last_goh_hours      numeric;  -- HM saat GOH terakhir (baseline; null=0)
