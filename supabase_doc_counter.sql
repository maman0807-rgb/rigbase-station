-- ============================================================
-- NO. DOKUMEN OTOMATIS — counter berurutan per tipe & tahun
-- Jalankan di Supabase SQL Editor. Idempoten. Akses: authenticated (via fungsi).
-- ============================================================

CREATE TABLE IF NOT EXISTS doc_counters (
  key TEXT PRIMARY KEY,
  seq INT NOT NULL DEFAULT 0
);
ALTER TABLE doc_counters ENABLE ROW LEVEL SECURITY;
-- Tidak ada policy langsung; akses hanya lewat fungsi SECURITY DEFINER.

-- Ambil nomor urut berikutnya (atomik) untuk sebuah key (mis. 'FMEA-2026').
CREATE OR REPLACE FUNCTION next_doc_seq(p_key TEXT)
RETURNS INT
LANGUAGE SQL SECURITY DEFINER AS $$
  INSERT INTO doc_counters (key, seq) VALUES (p_key, 1)
  ON CONFLICT (key) DO UPDATE SET seq = doc_counters.seq + 1
  RETURNING seq;
$$;
GRANT EXECUTE ON FUNCTION next_doc_seq(TEXT) TO authenticated;

-- ============================================================
-- SELESAI. Tanpa SQL ini, report tetap bisa dicetak (No. dokumen
-- dikosongkan untuk diisi manual).
-- ============================================================
