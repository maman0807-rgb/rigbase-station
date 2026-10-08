// ============================================================
// Laporan Harian v2 — pembaca rangkuman TANPA Claude (gratis, hasil selalu sama).
// Parser identik dengan app eRAMHoist (rigbase-station/js/laporan_harian_v2.js, 98 tes).
// Kalau aturan parser di repo berubah, salin ulang bagian PARSER di bawah ini.
// ============================================================
const LaporanHarianV2 = (() => { const module = { exports: {} };
/*PARSER*/
return module.exports; })();

const msg = $('Telegram Trigger').first().json.message;
const chatId = msg.chat.id;
// Buang perintah /laporan di awal pesan
const rawText = String(msg.text || '').replace(/^\s*\/laporan(@\w+)?\s*/i, '');
const equipmentList = $('Aggregate').first().json.data || [];

const hasil = LaporanHarianV2.parseLaporan(rawText);
hasil.pekerjaan.forEach(p => {
  p._match = LaporanHarianV2.cocokkanEquipment(p, equipmentList, []);
  if (!p._match) p.flags.push({ level: 'cek', kode: 'equipment_belum_cocok', pesan: 'Belum dicocokkan ke master equipment — pilih di kartu' });
});
// Tanggal tidak terbaca di judul → pakai tanggal kirim pesan (WIB) + tandai
if (!hasil.tanggal && msg.date) {
  hasil.tanggal = new Date((msg.date + 7 * 3600) * 1000).toISOString().slice(0, 10);
  hasil.flags.push({ level: 'kurang', pesan: 'Tanggal tidak terbaca di judul — dipakai tanggal kirim pesan' });
}
return [{ json: { rawText, chatId, hasil } }];
