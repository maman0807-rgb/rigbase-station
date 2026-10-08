// Laporan terpotong jadi 2 pesan (atau terkirim ulang): gabungkan ke draft tanggal yang sama.
// Pekerjaan yang sudah ada (nomor + nama sama) dilewati supaya tidak dobel.
const lap = $('Normalize Cek Existing').first().json;
const baru = $('Code in JavaScript1').first().json;
const ada = $('Ambil Entry Existing').all().map(i => i.json).filter(r => r && r.id);
const k = s => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
const sudah = new Set(ada.map(r => `${r.no_urut ?? ''}|${k(r.judul_lapor || r.equipment_manual_nama)}`));
const rows = baru.entries
  .filter(e => !sudah.has(`${e.no_urut ?? ''}|${k(e.judul_lapor)}`))
  .map(e => ({ laporan_id: lap.id, ...e }));
const tgl = String(baru.tanggal || '').split('-').reverse().join('/');
const kurang = rows.filter(r => (r.flags || []).some(f => f.level === 'kurang')).length;
const ringkasan = rows.length
  ? `➕ Digabung ke draft ${tgl}: +${rows.length} pekerjaan (${rows.map(r => '#' + r.no_urut).join(', ')}) — total ${ada.length + rows.length} pekerjaan.\n`
    + (kurang ? `⚠ ${kurang} pekerjaan yang baru masuk masih ada isian kurang.\n` : '')
    + 'Silakan cek & konfirmasi di app eRAMHoist.'
  : `ℹ️ Laporan ${tgl}: semua pekerjaan di pesan ini sudah ada di draft — tidak ada yang ditambahkan.`;
return [{ json: { jumlah: rows.length, rows, ringkasan } }];
