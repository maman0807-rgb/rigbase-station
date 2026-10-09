// Tes pembaca Laporan Harian v2 — jalankan: node tests/laporan_harian.test.js
// Fixture utama: laporan nyata 06/10/2026 (tests/fixtures/laporan_2026-10-06.txt).
const fs = require('fs');
const path = require('path');
const L = require('../js/laporan_harian_v2.js');

let lulus = 0, gagal = 0;
function cek(kondisi, pesan, detail) {
  if (kondisi) { lulus++; console.log('  ok   ' + pesan); }
  else { gagal++; console.log('  GAGAL ' + pesan + (detail !== undefined ? '  → ' + JSON.stringify(detail) : '')); }
}
const adaFlag = (p, kode, level) => p.flags.some(f => f.kode === kode && (!level || f.level === level));

const teks = fs.readFileSync(path.join(__dirname, 'fixtures/laporan_2026-10-06.txt'), 'utf8');
const r = L.parseLaporan(teks);
const P = no => r.pekerjaan.find(p => p.no === no);

console.log('Header & status rig');
cek(r.tanggal === '2026-10-06', 'tanggal laporan 06/10/2026', r.tanggal);
cek(r.status_rig.length === 5, '5 baris status rig', r.status_rig.length);
cek(r.status_rig.find(s => s.unit === 'BW KB150B')?.lokasi === 'GNK-39', 'BW KB150B lokasi GNK-39');
cek(r.status_rig.find(s => s.unit === 'BW-100A')?.lokasi === 'OGN-39', 'BW-100A lokasi OGN-39');
cek(r.status_rig.every(s => s.rh === null), 'RH kosong semua (tidak ada baris RH)');
cek(r.flags.length === 0, 'tidak ada flag tingkat laporan', r.flags);

console.log('Blok pekerjaan');
cek(r.pekerjaan.length === 8, '8 blok pekerjaan', r.pekerjaan.length);
cek(P(1).tipe === 'BARU' && [2, 3, 4, 5, 6, 7, 8].every(n => P(n).tipe === 'LANJUT'), '#1 BARU, #2–#8 LANJUT');

console.log('#1 BW KB150A – Rig carier');
const p1 = P(1);
cek(p1.unit === 'BW KB150A' && p1.unit_rig, 'unit BW KB150A (rig)', p1.unit);
cek(p1.equipment === 'Rig carier', 'equipment Rig carier', p1.equipment);
cek(p1.jenis === 'CM' && p1.is_ts && p1.status_kerja === 'TS', 'jenis CM (TS) → status kerja TS', [p1.jenis, p1.status_kerja]);
cek(p1.gejala === 'low pressure air system', 'gejala', p1.gejala);
cek(p1.mulai === '2026-10-06' && p1.jam_mulai === '10:00', 'mulai 06/10 10.00', [p1.mulai, p1.jam_mulai]);
cek(p1.selesai === '2026-10-06' && p1.jam_selesai === '17:00', 'selesai 06/10 17.00', [p1.selesai, p1.jam_selesai]);
cek(p1.status === 'Selesai' && p1.progress === 100, 'status Selesai 100%', [p1.status, p1.progress]);
cek(p1.part.length === 3, 'part 3 baris', p1.part);
cek(p1.part[0].nama === 'Valve R5' && p1.part[0].qty === 1 && p1.part[0].satuan === 'pcs', 'Valve R5 qty 1 pcs', p1.part[0]);
cek(p1.part[1].nama === 'Quick Valve' && p1.part[1].qty === 2, 'Quick Valve qty 2', p1.part[1]);
cek(/^Pelumas/.test(p1.part[2].nama) && p1.part[2].qty === null, 'Pelumas qty null', p1.part[2]);
cek(p1.deskripsi.length === 4, 'deskripsi 4 bullet', p1.deskripsi);
cek(p1.meter_nilai === 14200 && p1.meter_tipe === 'HM', 'meter HM 14200');
cek(adaFlag(p1, 'rig_stop', 'kurang'), 'flag kurang: rig stop');
cek(adaFlag(p1, 'meter_sama', 'cek'), 'flag cek: HM sama dengan #2');
cek(adaFlag(p1, 'banyak_equipment', 'cek'), 'flag cek: banyak equipment');
cek(adaFlag(p1, 'part_qty', 'cek'), 'flag cek: part tanpa qty');

console.log('#2 BW H35KD – Tower light JCB');
const p2 = P(2);
cek(p2.unit === 'BW H35KD' && p2.equipment === 'Tower light JCB', 'unit & equipment', [p2.unit, p2.equipment]);
cek(p2.sn === 'X2CH25843', 'SN X2CH25843', p2.sn);
cek(p2.mulai === '2026-09-30' && p2.selesai === null, 'mulai 30/09/2026, selesai kosong', [p2.mulai, p2.selesai]);
cek(p2.jam_mulai === '10:00' && p2.jam_selesai === '15:55', 'jam dari label deskripsi (10.00–15.55)', [p2.jam_mulai, p2.jam_selesai]);
cek(p2.status === 'Progress' && p2.progress === 70, 'Progress 70', [p2.status, p2.progress]);
cek(p2.deskripsi.length === 9, '9 bullet deskripsi', p2.deskripsi.length);
cek(adaFlag(p2, 'meter_sama'), 'flag HM sama dengan #1');
cek(adaFlag(p2, 'rig_stop', 'kurang'), 'flag kurang: rig stop (CM di unit rig)');

console.log('#3 Fire pump Ziegler');
const p3 = P(3);
cek(p3.unit === null && !p3.unit_rig, 'unit non-rig (null)', p3.unit);
cek(p3.equipment === 'Fire pump Ziegler', 'equipment Fire pump Ziegler', p3.equipment);
cek(p3.sn === 'LD425/2', 'SN LD425/2', p3.sn);
cek(p3.jenis === 'CM' && p3.gejala === 'unit tidak bisa running', 'CM, gejala dari kurung', [p3.jenis, p3.gejala]);
cek(p3.mulai === '2026-08-05', 'mulai 05/08/2026', p3.mulai);
cek(p3.status === 'Tunggu' && p3.status_ket === 'part' && p3.progress === 30, 'Tunggu part 30%', [p3.status, p3.status_ket, p3.progress]);
cek(p3.meter_nilai === null, 'meter "-" = null');
cek(!adaFlag(p3, 'rig_stop'), 'tidak wajib rig stop (bukan unit rig)');

console.log('#4 MAN FT-03');
const p4 = P(4);
cek(p4.equipment === 'MAN FT-03 BG 8015 CZ' && p4.sn === '20830005312999', 'equipment & SN', [p4.equipment, p4.sn]);
cek(p4.gejala === 'low power', 'gejala low power (dari "TS low power")', p4.gejala);
cek(p4.status === 'Tunggu' && /realise SPK/i.test(p4.status_ket) && p4.progress === 20, 'Tunggu realise SPK 20% (baris "*Status")', [p4.status, p4.status_ket, p4.progress]);

console.log('#5 Dozer D7G');
const p5 = P(5);
cek(p5.jenis === 'CM' && p5.gejala === 'radiator leak & track kendor', 'gejala dari kurung', p5.gejala);
cek(p5.status === 'Tunggu' && /Tim Trakindo/.test(p5.status_ket) && p5.progress === 78, 'Tunggu Tim Trakindo 78%', [p5.status, p5.status_ket, p5.progress]);

console.log('#6 Genset Perkins MTU');
const p6 = P(6);
cek(p6.jenis === 'OH' && p6.mulai === '2026-06-26', 'OH, mulai 26/06/2026', [p6.jenis, p6.mulai]);
cek(p6.status === 'Tunggu' && p6.progress === 45, 'Tunggu part 45%', [p6.status, p6.progress]);

console.log('#7 Hino TS-03');
const p7 = P(7);
cek(p7.jenis === 'Lainnya' && adaFlag(p7, 'jenis', 'cek'), 'jenis Lainnya + flag tidak dikenali', p7.jenis);
cek(p7.meter_tipe === 'KM' && p7.meter_nilai === 16911.6, 'meter KM 16911.6', [p7.meter_tipe, p7.meter_nilai]);
cek(p7.status === 'Selesai' && p7.selesai === '2026-10-06', 'Selesai 06/10/2026', [p7.status, p7.selesai]);
cek(p7.part.length === 2 && p7.part[0].nama === 'Cross Joint' && p7.part[0].qty === 2 && p7.part[1].nama === 'Sling Coupling' && p7.part[1].qty === 2, 'part Cross Joint 2, Sling Coupling 2', p7.part);
cek(p7.jam_mulai === '09:00' && p7.jam_selesai === '15:30', 'jam 09.00–15.30 WIB');

console.log('#8 Genset Krisbow Dongfeng MTU');
const p8 = P(8);
cek(p8.unit === 'Genset Krisbow Dongfeng MTU', 'unit Genset Krisbow Dongfeng MTU', p8.unit);
cek(p8.equipment === 'Genset Krisbow Dongfeng MTU' && p8.judul_ket === 'Engine not crank', 'equipment = genset, "Engine not crank" sebagai keterangan judul', [p8.equipment, p8.judul_ket]);
cek(p8.gejala === 'Engine Cant running', 'gejala dari field Gejala', p8.gejala);
cek(p8.mulai === '2026-10-05', 'mulai 05/10/2026 ("..": diabaikan)', p8.mulai);
cek(p8.meter_nilai === 14219.7, 'meter 14219.7', p8.meter_nilai);
cek(p8.status === 'Progress' && p8.progress === 30, 'Progress 30', [p8.status, p8.progress]);
cek(p8.jam_mulai === '14:00' && p8.jam_selesai === '15:00', 'jam "Time 14.00 S/d 15.00" tanpa titik dua');

console.log('Tidak mengarang');
cek(P(3).pic === null && P(5).pic === null && P(6).no_wo === null, 'field yang tidak ada = null');
cek(r.pekerjaan.every(p => p.rig_stop === null), 'rig stop tidak ditebak (tidak ada di teks)');

console.log('Fungsi kecil');
cek(['BW 100A', 'BW-100 A', 'BW100', 'BW 100 A'].every(x => L.normalisasiUnit(x) === 'BW-100A'), 'alias BW-100A');
cek(['BW-H35KD', 'BWH35KD', 'BW H 35KD', 'H35KD'].every(x => L.normalisasiUnit(x) === 'BW H35KD'), 'alias BW H35KD');
cek(['BW-KB150A', 'BW KB 150A', 'BW KB.150A', 'BW KB 150 A', 'KB150A'].every(x => L.normalisasiUnit(x) === 'BW KB150A'), 'alias BW KB150A');
cek(L.normalisasiUnit('Fire pump Ziegler') === null, 'unit non-rig tidak dipaksa ke rig');
cek(L.namaParentUnit('BW KB150B') === 'BW KB150.B', 'nama parent unit eRAMHoist');
cek(L.normalisasiJenis('TOH').jenis === 'OH' && L.normalisasiJenis('PM 3').jenis === 'PM' && L.normalisasiJenis('Cek rutin').jenis === 'Inspeksi', 'jenis OH/PM/Inspeksi');
cek(JSON.stringify(L.parseRigStop('Ya – 7 jam')) === JSON.stringify({ rig_stop: true, rig_stop_ket: '7 jam' }), 'rig stop "Ya – 7 jam"');
cek(L.parseRigStop('Tidak').rig_stop === false, 'rig stop "Tidak"');
cek(L.parseTanggal('5/08', 2026) === '2026-08-05', 'tanggal tanpa tahun → tahun laporan');
const st = L.normalisasiStatus('Progress 100%', null);
cek(st.status === 'Selesai' && st.flags.some(f => f.kode === 'selesai_tanpa_tgl'), '"Progress 100%" tanpa tgl selesai → Selesai + flag');
const rh = L.parseLaporan('*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*\n*Rabu, 07/10/2026*\n*A. STATUS RIG*\n*BW KB150C*| TTB-17 | operasi\nRH: Eng rig 3 | MP GD 0 | Gen Deutz 4 | Gen CAT 3\n*B. PEKERJAAN*\n');
cek(JSON.stringify(rh.status_rig[0].rh) === JSON.stringify({ 'Eng rig': 3, 'MP GD': 0, 'Gen Deutz': 4, 'Gen CAT': 3 }), 'baris RH opsional', rh.status_rig[0].rh);
const ps = L.parsePart('Filter oli | 1R-0750 | 2 pcs | gudang');
cek(ps.pn === '1R-0750' && ps.qty === 2 && ps.sumber === 'gudang', 'part dengan PN & sumber', ps);

console.log('Pencocokan equipment');
const eqList = [
  { id: 'e1', tag_number: 'CARRIER-KB150A', nama_equipment: 'Rig Carrier BW KB150A', serial_number: 'ABC111', assigned_unit_id: 3 },
  { id: 'e2', tag_number: 'TL-H35KD', nama_equipment: 'Tower Light JCB', serial_number: 'X2CH25843', assigned_unit_id: 2 },
  { id: 'e3', tag_number: 'TS-03', nama_equipment: 'Hino Truck Service', serial_number: null, assigned_unit_id: null },
  { id: 'e4', tag_number: 'FP-01', nama_equipment: 'Fire Pump Ziegler', serial_number: null, assigned_unit_id: null },
  { id: 'e5', tag_number: 'FP-02', nama_equipment: 'Fire Pump Ziegler', serial_number: null, assigned_unit_id: null },
];
const units = [{ id: 1, name: 'BW-100A' }, { id: 2, name: 'BW H35KD' }, { id: 3, name: 'BW KB150.A' }];
cek(L.cocokkanEquipment(p2, eqList, units)?.id === 'e2', '#2 cocok lewat SN');
cek(L.cocokkanEquipment(p7, eqList, units)?.id === 'e3', '#7 cocok lewat kode TS-03 di tag');
cek(L.cocokkanEquipment(p3, eqList, units) === null, '#3 dua Fire Pump Ziegler → tidak ditebak');

console.log('Fixture 08/10/2026 (variasi: ON GOING / NEW JOB, rig di tengah judul, Note)');
const r8 = L.parseLaporan(fs.readFileSync(path.join(__dirname, 'fixtures/laporan_2026-10-08.txt'), 'utf8'));
const Q = no => r8.pekerjaan.find(p => p.no === no);
cek(r8.tanggal === '2026-10-08' && r8.status_rig.length === 5 && r8.flags.length === 0, '08/10: tanggal & 5 status rig');
cek(r8.status_rig.find(x => x.unit === 'BW KB150C')?.keterangan === 'all unit Standby, program test produksi.', '08/10: keterangan KB150C');
cek(r8.pekerjaan.length === 7, '08/10: 7 pekerjaan', r8.pekerjaan.length);
cek([1, 2, 3, 4, 5, 6].every(n => Q(n).tipe === 'LANJUT' && Q(n).tipe_asli === 'ON GOING') && Q(7).tipe === 'BARU' && Q(7).tipe_asli === 'NEW JOB', '08/10: ON GOING → LANJUT, NEW JOB → BARU');
cek(Q(1).unit === 'BW H35KD' && Q(1).equipment === 'Tower light JCB' && Q(1).progress === 78 && Q(1).deskripsi.length === 4 && Q(1).pic === 'David, ilham', '08/10 #1 Tower light: 78%, 4 deskripsi, PIC');
cek(Q(5).jenis === 'OH' && Q(5).status === 'Tunggu' && Q(5).progress === 45, '08/10 #5 Genset Perkins: OH, Tunggu 45%');
cek(Q(6).jam_mulai === '09:00' && Q(6).jam_selesai === '11:00' && Q(6).progress === 40 && Q(6).status === 'Progress', '08/10 #6: "Time 09.00 S/d 11.00", lanjut 40%');
const q7 = Q(7);
cek(q7.unit === 'BW KB150C' && q7.unit_rig && q7.equipment === 'Rig carier', '08/10 #7: unit rig dari tengah judul "Rig carier BW KB 150 C"', [q7.unit, q7.equipment]);
cek(q7.gejala === 'Brake stuck' && q7.jenis === 'CM', '08/10 #7: CM, gejala Brake stuck');
cek(q7.status === 'Selesai' && q7.progress === 100 && q7.selesai === '2026-10-08' && q7.jam_selesai === '15:00', '08/10 #7: "*status : pekerjaan 100% selesai*" → Selesai');
cek(/^terdapat temuan pada box driling konsul/.test(q7.catatan || ''), '08/10 #7: Note tersimpan sebagai catatan');
cek(q7.deskripsi.length === 4 && q7.meter_nilai === null, '08/10 #7: 4 deskripsi, HM "-" kosong');
cek(adaFlag(Q(1), 'rig_stop', 'kurang') && adaFlag(q7, 'rig_stop', 'kurang') && !adaFlag(Q(2), 'rig_stop'), '08/10: rig stop diminta hanya untuk CM di unit rig');
cek(L.parseLaporan('*B. PEKERJAAN*\n*1. ONGOING – Genset X*\n*2. New Job – BW KB150A – Mud pump*\n*3. Lanjutan – Hino TS-03*').pekerjaan.map(p => p.tipe).join() === 'LANJUT,BARU,LANJUT', 'variasi ejaan: ONGOING / New Job / Lanjutan');

console.log('Laporan terpotong 2 pesan Telegram (bagian ke-2 mengulang judul)');
{
  const t8 = fs.readFileSync(path.join(__dirname, 'fixtures/laporan_2026-10-08.txt'), 'utf8');
  const i5 = t8.indexOf('*5. ON GOING');
  const judul = '*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*\n*Kamis, 08/10/2026*\n\n';
  const b1 = L.parseLaporan(t8.slice(0, i5));
  const b2 = L.parseLaporan(judul + t8.slice(i5));
  const b2b = L.parseLaporan(judul + '*B. PEKERJAAN*\n' + t8.slice(i5));
  cek(b1.tanggal === '2026-10-08' && b1.status_rig.length === 5 && b1.pekerjaan.map(p => p.no).join() === '1,2,3,4', 'bagian 1: status rig + #1–#4');
  cek(b2.tanggal === '2026-10-08' && b2.status_rig.length === 0 && b2.pekerjaan.map(p => p.no).join() === '5,6,7' && b2.flags.length === 0, 'bagian 2 tanpa "B. PEKERJAAN": #5–#7 tetap terbaca');
  cek(b2b.pekerjaan.map(p => p.no).join() === '5,6,7', 'bagian 2 dengan "B. PEKERJAAN"');
  cek(b2.pekerjaan.find(p => p.no === 7).unit === 'BW KB150C', 'bagian 2: #7 tetap utuh');
}

console.log('Template di Panduan');
const tc = L.parseLaporan(L.TEMPLATE_CONTOH);
cek(tc.tanggal === '2026-10-08' && tc.status_rig.length === 5 && tc.flags.length === 0, 'contoh template: tanggal & 5 status rig');
cek(JSON.stringify(tc.status_rig[1].rh) === JSON.stringify({ 'Eng rig': 6, 'MP GD': 2, 'Gen Deutz': 10, 'Gen CAT': 0 }), 'contoh template: baris RH');
cek(tc.pekerjaan.length === 2 && tc.pekerjaan.every(p => p.flags.length === 0), 'contoh template: 2 pekerjaan tanpa peringatan', tc.pekerjaan.map(p => p.flags));
const c1 = tc.pekerjaan[0];
cek(c1.rig_stop === true && c1.rig_stop_ket === '3 jam' && c1.no_wo === '4500123456' && c1.pic === 'Ilham, Rizki' && c1.status === 'Selesai', 'contoh #1: rig stop, WO, PIC, selesai');
cek(tc.pekerjaan[1].unit === null && tc.pekerjaan[1].status === 'Tunggu' && tc.pekerjaan[1].status_ket === 'part', 'contoh #2: unit "-" kosong, Tunggu part');
const tk = L.parseLaporan(L.TEMPLATE_KOSONG);
cek(tk.pekerjaan.length === 1 && tk.status_rig.length === 5, 'template kosong tetap bisa dibaca (tidak error)');

console.log('Salinan parser');
const salinan = fs.readFileSync(path.join(__dirname, '../supabase/functions/_shared/laporan_harian_v2.js'), 'utf8');
cek(salinan.endsWith(fs.readFileSync(path.join(__dirname, '../js/laporan_harian_v2.js'), 'utf8')), 'salinan Edge Function identik dengan js/laporan_harian_v2.js');

console.log(`\n${gagal ? 'ADA YANG GAGAL' : 'SEMUA LULUS'}: ${lulus} lulus, ${gagal} gagal`);
process.exit(gagal ? 1 : 0);
