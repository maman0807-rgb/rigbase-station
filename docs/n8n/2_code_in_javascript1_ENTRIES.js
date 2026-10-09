// Ubah hasil baca → baris laporan_harian_entries (kolom lama + kolom format baru),
// sama persis dengan yang dibuat app eRAMHoist. Juga menyusun ringkasan balasan bot.
const { rawText, chatId, hasil } = $input.first().json;
const eqList = $('Aggregate').first().json.data || [];

const entries = hasil.pekerjaan.map(p => {
  const eq = p._match ? eqList.find(e => e.id === p._match.id) : null;
  const label = [p.unit_rig ? p.unit : (p.unit && p.unit !== p.equipment ? p.unit : null), p.equipment || p.judul].filter(Boolean).join(' – ');
  return {
    equipment_id: eq ? eq.id : null,
    equipment_manual_nama: eq ? null : label,
    site: p.lokasi || null,
    status_kerja: p.status_kerja || 'Lainnya',
    job_desc: [p.jenis ? p.jenis + (p.jenis === 'CM' && p.is_ts ? ' (TS)' : '') : p.jenis_asli, p.gejala].filter(Boolean).join(' – ') || null,
    sn: p.sn || null,
    rh: p.meter_nilai,
    progress_pct: p.progress,
    checklist: p.deskripsi.map(item => ({ item, checked: true })),
    notes: [p.catatan ? `Note: ${p.catatan}` : null, p.judul_ket ? `Ket. judul: ${p.judul_ket}` : null].filter(Boolean).join('\n') || null,
    follow_up_items: p.status === 'Tunggu' ? [`Tunggu ${p.status_ket || ''}`.trim()] : [],
    tipe_v2: p.tipe, no_urut: p.no, unit_lapor: p.unit, judul_lapor: p.equipment || p.judul,
    jenis: p.jenis, jenis_asli: p.jenis_asli, gejala: p.gejala,
    mulai_pekerjaan: p.mulai, selesai_pekerjaan: p.selesai, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai,
    meter_tipe: p.meter_tipe, rig_stop: p.rig_stop, rig_stop_ket: p.rig_stop_ket, pic: p.pic, no_wo: p.no_wo,
    status_v2: p.status, status_ket: p.status_ket, status_asli: p.status_asli,
    part: p.part, flags: p.flags,
  };
});

// Ringkasan untuk balasan bot
const pk = hasil.pekerjaan;
const kurang = [];
hasil.flags.filter(f => f.level === 'kurang').forEach(f => kurang.push(f.pesan));
pk.forEach(p => p.flags.filter(f => f.level === 'kurang').forEach(f => kurang.push(`#${p.no} ${p.equipment || p.judul}: ${f.pesan}`)));
const tgl = hasil.tanggal ? hasil.tanggal.split('-').reverse().join('/') : '-';
let ringkasan = `✅ Laporan ${tgl} diterima — draft tersimpan\n`
  + `Status rig: ${hasil.status_rig.length} · Pekerjaan: ${pk.length} (${pk.filter(p => p.tipe === 'BARU').length} baru, ${pk.filter(p => p.tipe === 'LANJUT').length} lanjut, ${pk.filter(p => p.status === 'Selesai').length} selesai)\n`;
if (!pk.length) ringkasan += '⚠ Tidak ada pekerjaan yang terbaca — cek format "B. PEKERJAAN" & judul bernomor.\n';
ringkasan += kurang.length
  ? `⚠ Isian kurang (${kurang.length}):\n` + kurang.slice(0, 12).map(k => '• ' + k).join('\n') + (kurang.length > 12 ? '\n• …' : '') + '\n'
  : '👍 Tidak ada isian kurang.\n';
ringkasan += 'Silakan cek & konfirmasi di app eRAMHoist.';

return [{ json: {
  tanggal: hasil.tanggal,
  tim: 'Ram Hoist & Heavy Equipment',
  entries,
  chat_id: chatId,
  status_rig: hasil.status_rig,
  raw_text: rawText,
  ringkasan,
} }];
