// Kolom header laporan_harian (dikirim auto-map ke Supabase)
const b = $('Code in JavaScript1').first().json;
return [{ json: {
  tanggal: b.tanggal,
  tim: b.tim,
  status: 'draft',
  sumber: 'bot_telegram',
  raw_text: b.raw_text,
  format_versi: 'v2',
  status_rig: b.status_rig,
} }];
