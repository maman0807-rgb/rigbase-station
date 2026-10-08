/* ============================================================
 * ⚠️ ADA SALINAN file ini di supabase/functions/_shared/laporan_harian_v2.js
 * (dipakai Edge Function telegram-laporan-webhook, bot Telegram → draft
 * otomatis). KALAU UBAH ATURAN PARSER DI SINI, COPY ULANG KE FILE ITU JUGA —
 * biar hasil parse bot & "Tempel Laporan" di app selalu sama persis.
 * ============================================================ */
/* ============================================================
 * Laporan Harian v2 — pembaca rangkuman format baru (disepakati tim HHE, 06/10/2026)
 *
 * Fungsi murni tanpa AI / tanpa akses database: teks rangkuman → struktur data.
 * Dipakai di app (tombol "📋 Tempel Laporan") dan di tes:
 *   node tests/laporan_harian.test.js
 *
 * Prinsip: JANGAN MENGARANG. Isian yang tidak ada di teks = null. Yang aneh /
 * kurang → masuk daftar flag (level 'kurang' = wajib dicek sebelum final,
 * 'cek' = peringatan) untuk dibetulkan admin, bukan ditebak.
 * ============================================================ */
(function (root) {
  'use strict';

  // ---------- Kamus unit rig (alias → nama baku) ----------
  // Nama baku mengikuti format laporan; parent_units di eRAMHoist memakai titik (BW KB150.A),
  // dicocokkan lewat namaParentUnit().
  const RIG_BAKU = ['BW-100A', 'BW H35KD', 'BW KB150A', 'BW KB150B', 'BW KB150C'];
  const kunciUnit = s => String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  const RIG_ALIAS = {
    BW100A: 'BW-100A', BW100: 'BW-100A',
    BWH35KD: 'BW H35KD', H35KD: 'BW H35KD',
    BWKB150A: 'BW KB150A', KB150A: 'BW KB150A',
    BWKB150B: 'BW KB150B', KB150B: 'BW KB150B',
    BWKB150C: 'BW KB150C', KB150C: 'BW KB150C',
  };
  function normalisasiUnit(teks) {
    if (!teks) return null;
    return RIG_ALIAS[kunciUnit(teks)] || null;
  }
  // Cari unit rig DI DALAM teks bebas, mis. "Rig carier BW KB 150 C" → {rig:'BW KB150C', sisa:'Rig carier'}
  const RIG_DALAM_RE = /\b(BW[\s.-]*KB[\s.-]*150[\s.-]*[ABC]|KB[\s.-]*150[\s.-]*[ABC]|BW[\s.-]*H[\s.-]*35[\s.-]*KD|H35KD|BW[\s.-]*100[\s.-]*A?)\b/i;
  function cariRigDalam(teks) {
    const m = RIG_DALAM_RE.exec(String(teks || ''));
    if (!m) return null;
    const rig = normalisasiUnit(m[1]);
    if (!rig) return null;
    const sisa = (teks.slice(0, m.index) + ' ' + teks.slice(m.index + m[0].length)).replace(/\s+/g, ' ').replace(/^[\s–—-]+|[\s–—-]+$/g, '').trim();
    return { rig, sisa: sisa || null };
  }
  // Tipe judul: BARU/NEW JOB → BARU ; LANJUT/ON GOING → LANJUT
  function normalisasiTipe(t) {
    return /^(BARU|NEW)/i.test(String(t).trim()) ? 'BARU' : 'LANJUT';
  }

  // 'BW KB150A' → 'BW KB150.A' (nama parent_units di eRAMHoist)
  function namaParentUnit(rig) {
    const m = /^BW KB150([ABC])$/.exec(rig || '');
    return m ? `BW KB150.${m[1]}` : rig;
  }

  // ---------- Pembersih teks WA/Telegram ----------
  // Buang *tebal* / _miring_ tapi pertahankan bullet di awal baris.
  function bersihkanBaris(line) {
    let s = String(line || '').replace(/ /g, ' ').replace(/\r/g, '').trim();
    let bullet = false;
    const mb = /^([*\-•·])\s+(.*)$/.exec(s);
    if (mb) { bullet = true; s = mb[2]; }
    s = s.replace(/[*_]/g, '').replace(/\s+/g, ' ').trim();
    return { teks: s, bullet };
  }
  const kosong = v => v == null || /^[\s\-–—.]*$/.test(String(v));

  // ---------- Tanggal & jam ----------
  function parseTanggal(teks, tahunDefault) {
    if (kosong(teks)) return null;
    const m = /(\d{1,2})\s*\/\s*(\d{1,2})(?:\s*\/\s*(\d{2,4}))?/.exec(teks);
    if (!m) return null;
    const d = Number(m[1]), mo = Number(m[2]);
    let y = m[3] ? Number(m[3]) : tahunDefault;
    if (!y) return null;
    if (y < 100) y += 2000;
    if (d < 1 || d > 31 || mo < 1 || mo > 12) return null;
    return `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }
  const jam2 = (h, m) => `${String(Number(h)).padStart(2, '0')}:${m}`;
  // Jam setelah tanggal: "06/10/2026 10.00" → "10:00"
  function parseJamSetelahTanggal(teks) {
    const m = /\d{1,2}\/\d{1,2}(?:\/\d{2,4})?\s+(\d{1,2})[.:](\d{2})/.exec(teks || '');
    return m ? jam2(m[1], m[2]) : null;
  }
  // Rentang "10.00 S/d 17.00", "09.00 s/d 15.30 WIB", "(10.00–15.55)", "14.00-15.00"
  function parseRentangJam(teks) {
    const m = /(\d{1,2})[.:](\d{2})\s*(?:s\s*\/\s*d|sd|sampai|[-–—~])\s*(\d{1,2})[.:](\d{2})/i.exec(teks || '');
    return m ? { mulai: jam2(m[1], m[2]), selesai: jam2(m[3], m[4]) } : null;
  }

  // ---------- Angka meter ----------
  function parseMeter(teks) {
    if (kosong(teks)) return { tipe: null, nilai: null };
    const tipe = /\bKM\b/i.test(teks) ? 'KM' : 'HM';
    const m = /(\d[\d.]*(?:,\d+)?)/.exec(String(teks).replace(/\bKM\b/i, ''));
    if (!m) return { tipe: null, nilai: null };
    let n = m[1];
    // 16.911,6 → 16911.6 ; 14219,7 → 14219.7 ; 14200 → 14200
    if (n.includes(',')) n = n.replace(/\./g, '').replace(',', '.');
    const nilai = Number(n);
    return Number.isFinite(nilai) ? { tipe, nilai } : { tipe: null, nilai: null };
  }

  // ---------- Jenis ----------
  const JENIS_LIST = ['CM', 'PM', 'OH', 'Cat 3', 'Cat 4', 'Inspeksi', 'Lainnya'];
  function normalisasiJenis(teks) {
    const asli = kosong(teks) ? null : String(teks).trim();
    const hasil = { jenis: null, isTS: false, gejalaDariJenis: null, dikenali: true, asli };
    if (!asli) return hasil;
    const mk = /^(.*?)\(\s*(.*?)\s*\)\s*$/.exec(asli);
    const pokok = (mk ? mk[1] : asli).trim();
    const dalam = mk ? mk[2].trim() : '';
    const P = pokok.toUpperCase();
    if (/^(CM|TS)\b/.test(P) || /\bCORRECTIVE\b/.test(P)) {
      hasil.jenis = 'CM';
      if (/^TS\b/.test(P)) hasil.isTS = true;
      if (dalam) {
        const t = /^TS\b\s*(.*)$/i.exec(dalam);
        if (t) { hasil.isTS = true; if (t[1].trim()) hasil.gejalaDariJenis = t[1].trim(); }
        else hasil.gejalaDariJenis = dalam;
      }
    } else if (/^(OH|TOH|GOH|OVERHAUL)\b/.test(P)) hasil.jenis = 'OH';
    else if (/^(PM\s*\d*|SERVICE)\b/.test(P)) hasil.jenis = 'PM';
    else if (/^CAT\s*3\b/.test(P)) hasil.jenis = 'Cat 3';
    else if (/^CAT\s*4\b/.test(P)) hasil.jenis = 'Cat 4';
    else if (/^(INSPEKSI|CEK RUTIN|CHECK ?LIST|CHECKLIST)\b/.test(P)) hasil.jenis = 'Inspeksi';
    else { hasil.jenis = 'Lainnya'; hasil.dikenali = false; }
    return hasil;
  }
  // Status kerja di tabel lama (Standby/Operasi/CM/PM/TS/Lainnya) supaya Analisa/PLO/peringatan
  // "CM/TS tanpa Downtime" tetap bekerja.
  function statusKerjaLama(j) {
    if (j.jenis === 'CM') return j.isTS ? 'TS' : 'CM';
    if (j.jenis === 'PM') return 'PM';
    return 'Lainnya';
  }

  // ---------- Status ----------
  function normalisasiStatus(teks, selesaiTgl) {
    const asli = kosong(teks) ? null : String(teks).trim();
    const t = (asli || '').toLowerCase();
    const angka = [...t.matchAll(/(\d{1,3})\s*%/g)].map(m => Number(m[1])).filter(n => n <= 100);
    let progress = angka.length ? angka[angka.length - 1] : null;
    let status, ket = null;
    const flags = [];
    if (/\bselesai\b/.test(t) || progress === 100 || selesaiTgl) {
      status = 'Selesai';
      progress = 100;
      if (!selesaiTgl) flags.push({ level: 'kurang', kode: 'selesai_tanpa_tgl', pesan: 'Status selesai tapi tanggal Selesai kosong' });
    } else if (/\b(tunggu|menunggu|waiting)\b/.test(t)) {
      status = 'Tunggu';
      const m = /\b(?:tunggu|menunggu|waiting)\b\s*(.*)$/i.exec(asli);
      ket = (m ? m[1] : '')
        .replace(/,?\s*progress\s*\d{1,3}\s*%/ig, '').replace(/\s*\d{1,3}\s*%\s*$/, '')
        .replace(/[,.\s]+$/, '').trim() || null;
    } else {
      status = 'Progress';
    }
    return { status, progress, ket, asli, flags };
  }

  // ---------- Rig stop ----------
  function parseRigStop(teks) {
    if (kosong(teks)) return { rig_stop: null, rig_stop_ket: null };
    const t = String(teks).trim();
    if (/^(ya|yes|y)\b/i.test(t)) {
      const ket = t.replace(/^(ya|yes|y)\b\s*[-–—:,]?\s*/i, '').trim();
      return { rig_stop: true, rig_stop_ket: ket || null };
    }
    if (/^(tidak|no|n|tdk)\b/i.test(t)) return { rig_stop: false, rig_stop_ket: null };
    return { rig_stop: null, rig_stop_ket: t };
  }

  // ---------- Part ----------
  // "* Valve R5 |1 pcs|", "* Nama | PN | qty | sumber", "* Pelumas (atf, ...)"
  function parsePart(teks) {
    const bagian = String(teks).split('|').map(s => s.trim()).filter(s => s !== '');
    const nama = bagian.shift() || '';
    let pn = null, qty = null, satuan = null, sumber = null;
    const qtyRe = /^(\d+(?:[.,]\d+)?)\s*([A-Za-z]*)$/;
    for (const b of bagian) {
      const q = qtyRe.exec(b);
      if (q && qty == null) { qty = Number(q[1].replace(',', '.')); satuan = q[2] ? q[2].toLowerCase() : null; }
      else if (qty == null && pn == null) pn = b;
      else if (sumber == null) sumber = b;
    }
    return { nama, pn, qty, satuan, sumber };
  }

  // ---------- Label field ----------
  function kunciLabel(label) {
    const k = String(label || '').toLowerCase().replace(/\(.*?\)/g, '').replace(/[^a-z/ ]/g, '').replace(/\s+/g, ' ').trim();
    if (/^unit$/.test(k)) return 'unit';
    if (/^equipment|^eq$|^alat$/.test(k)) return 'equipment';
    if (/^sn|serial|model/.test(k)) return 'sn';
    if (/^jenis/.test(k)) return 'jenis';
    if (/^gejala|^keluhan/.test(k)) return 'gejala';
    if (/^mulai/.test(k)) return 'mulai';
    if (/^selesai/.test(k)) return 'selesai';
    if (/^time$|^waktu|^jam kerja|^jam$/.test(k)) return 'time';
    if (/^hm|^rh|^km|^meter/.test(k)) return 'meter';
    if (/^lokasi|^site/.test(k)) return 'lokasi';
    if (/^pic|^teknisi|^mekanik/.test(k)) return 'pic';
    if (/^status/.test(k)) return 'status';
    if (/^rig ?stop/.test(k)) return 'rigstop';
    if (/^no ?wo$|^wo$|^nomor wo/.test(k)) return 'nowo';
    if (/^deskripsi/.test(k)) return 'deskripsi';
    if (/^note|^catatan|^temuan|^keterangan|^ket$/.test(k)) return 'catatan';
    if (/^part|^sparepart|^spare part/.test(k)) return 'part';
    return null;
  }

  // Kata kunci komponen untuk cek "satu blok berisi banyak equipment"
  const KOMPONEN = [
    ['crownomatic', /crown\s*o?\s*matic/], ['compressor', /compres+or|kompres+or/], ['engine', /\bengine\b|\bmesin\b/],
    ['spark arrestor', /spark\s*ar+estor/], ['genset', /\bgenset\b/], ['pompa', /\bpump\b|\bpompa\b/],
    ['transmisi', /transmis/], ['radiator', /radiator/], ['track', /\btrack\b/], ['winch', /\bwinch\b/],
    ['drawwork', /drawwork/], ['mast', /\bmast\b/], ['accumulator', /accumulator/], ['bop', /\bbop\b/],
  ];

  // ============================================================
  // PARSER UTAMA
  // ============================================================
  function parseLaporan(teksAsli) {
    const hasil = { tanggal: null, status_rig: [], pekerjaan: [], flags: [] };
    const baris = String(teksAsli || '').split('\n').map(bersihkanBaris);

    // Header & tanggal
    const iHeader = baris.findIndex(b => /laporan harian/i.test(b.teks));
    for (let i = Math.max(0, iHeader); i < Math.min(baris.length, Math.max(0, iHeader) + 4); i++) {
      const t = parseTanggal(baris[i].teks, null);
      if (t) { hasil.tanggal = t; break; }
    }
    if (iHeader < 0) hasil.flags.push({ level: 'cek', pesan: 'Judul "LAPORAN HARIAN HOIST & HEAVY EQUIPMENT" tidak ditemukan' });
    if (!hasil.tanggal) hasil.flags.push({ level: 'kurang', pesan: 'Tanggal laporan tidak ditemukan di judul' });
    const tahun = hasil.tanggal ? Number(hasil.tanggal.slice(0, 4)) : new Date().getFullYear();

    // Bagian A & B. Baris "B. PEKERJAAN" boleh tidak ada (mis. bagian ke-2 dari laporan yang
    // terpotong jadi 2 pesan Telegram) — blok pekerjaan dikenali dari judul bernomornya.
    const judulRe = /^(\d+)\s*[.)]\s*(BARU|LANJUTAN|LANJUT|ON\s*-?\s*GOING|NEW\s*JOB|NEW)\s*[-–—:]\s*(.+)$/i;
    const iA = baris.findIndex(b => /^A\.?\s*STATUS RIG/i.test(b.teks));
    let iB = baris.findIndex(b => /^B\.?\s*PEKERJAAN/i.test(b.teks));
    if (iB < 0) {
      const iJudul = baris.findIndex((b, i) => i > iA && !b.bullet && judulRe.test(b.teks));
      if (iJudul >= 0) iB = iJudul - 1;
    }

    if (iA >= 0) {
      const akhirA = iB > iA ? iB : baris.length;
      for (let i = iA + 1; i < akhirA; i++) {
        const t = baris[i].teks;
        if (!t) continue;
        if (/^RH\s*:/i.test(t) && hasil.status_rig.length) {
          const rh = {};
          t.replace(/^RH\s*:/i, '').split('|').forEach(seg => {
            const m = /^(.*?)\s*(\d+(?:[.,]\d+)?)\s*$/.exec(seg.trim());
            if (m && m[1]) rh[m[1].trim()] = Number(m[2].replace(',', '.'));
          });
          hasil.status_rig[hasil.status_rig.length - 1].rh = Object.keys(rh).length ? rh : null;
          continue;
        }
        if (!t.includes('|')) continue;
        const [u, lok, ...ket] = t.split('|').map(s => s.trim());
        const unit = normalisasiUnit(u);
        hasil.status_rig.push({ unit: unit || u, unit_dikenali: !!unit, lokasi: lok || null, keterangan: ket.join(' | ').trim() || null, rh: null });
        if (!unit) hasil.flags.push({ level: 'cek', pesan: `Status rig: unit "${u}" tidak dikenali` });
      }
    }

    // Pecah blok pekerjaan
    if (iB >= 0) {
      let blok = null;
      const blokList = [];
      for (let i = iB + 1; i < baris.length; i++) {
        const b = baris[i];
        const mj = !b.bullet && judulRe.exec(b.teks);
        if (mj) { blok = { no: Number(mj[1]), tipe: normalisasiTipe(mj[2]), tipe_asli: mj[2].trim(), judul: mj[3].trim(), baris: [] }; blokList.push(blok); continue; }
        if (blok && b.teks) blok.baris.push(b);
      }
      blokList.forEach(bl => hasil.pekerjaan.push(parseBlok(bl, tahun)));
    } else if (iA < 0) {
      hasil.flags.push({ level: 'cek', pesan: 'Tidak ada status rig maupun blok pekerjaan bernomor yang terbaca' });
    }

    // Cek lintas blok: HM/KM sama persis di unit berbeda (indikasi salah salin)
    const perNilai = {};
    hasil.pekerjaan.forEach(p => { if (p.meter_nilai != null) (perNilai[p.meter_nilai] = perNilai[p.meter_nilai] || []).push(p); });
    Object.values(perNilai).forEach(list => {
      const unitBeda = new Set(list.map(p => (p.unit || '') + '|' + (p.equipment || '')));
      if (list.length > 1 && unitBeda.size > 1) {
        list.forEach(p => {
          const lain = list.filter(x => x !== p).map(x => `#${x.no}`).join(', ');
          p.flags.push({ level: 'cek', kode: 'meter_sama', pesan: `HM/KM ${p.meter_nilai} sama persis dengan ${lain} (unit lain) — kemungkinan salah salin` });
        });
      }
    });
    return hasil;
  }

  function parseBlok(bl, tahun) {
    const p = {
      no: bl.no, tipe: bl.tipe, tipe_asli: bl.tipe_asli || bl.tipe, judul: bl.judul, catatan: null,
      unit: null, unit_rig: false, equipment: null, judul_ket: null, sn: null,
      jenis: null, jenis_asli: null, is_ts: false, status_kerja: null, gejala: null,
      mulai: null, selesai: null, jam_mulai: null, jam_selesai: null,
      meter_tipe: null, meter_nilai: null, lokasi: null, pic: null, no_wo: null,
      rig_stop: null, rig_stop_ket: null,
      deskripsi: [], part: [],
      status: null, progress: null, status_ket: null, status_asli: null,
      flags: [],
    };
    // Judul: "BW-KB150A – Rig carier" / "Fire pump Ziegler" / "Genset … MTU – Engine not crank"
    const bagJudul = bl.judul.split(/\s+[-–—]\s+/).map(s => s.trim()).filter(Boolean);
    const rigJudul = normalisasiUnit(bagJudul[0]);
    if (rigJudul) { p.unit = rigJudul; p.unit_rig = true; p.equipment = bagJudul.slice(1, 2).join('') || null; p.judul_ket = bagJudul.slice(2).join(' – ') || null; }
    else {
      // Unit rig bisa terselip di tengah judul: "Rig carier BW KB 150 C – Brake stuck"
      const dalam = cariRigDalam(bagJudul[0] || '');
      if (dalam) { p.unit = dalam.rig; p.unit_rig = true; p.equipment = dalam.sisa; }
      else p.equipment = bagJudul[0] || null;
      p.judul_ket = bagJudul.slice(1).join(' – ') || null;
    }

    const f = {};
    let mode = null;  // 'deskripsi' | 'part'
    for (const b of bl.baris) {
      if (b.bullet) {
        if (mode === 'part') p.part.push(parsePart(b.teks));
        else p.deskripsi.push(b.teks.replace(/\s*\(ok\)\s*$/i, ' (ok)').trim());
        continue;
      }
      // "Label : nilai" ; juga "Time 14.00 S/d 15.00 WIB" (tanpa titik dua)
      let label, nilai;
      const mc = /^([^:]{1,40}?)\s*:\s*(.*)$/.exec(b.teks);
      if (mc && kunciLabel(mc[1])) { label = kunciLabel(mc[1]); nilai = mc[2].trim(); }
      else {
        const mt = /^(time|waktu)\b\s*(.*)$/i.exec(b.teks);
        if (mt) { label = 'time'; nilai = mt[2].trim(); }
      }
      if (!label) { if (mode === 'deskripsi') p.deskripsi.push(b.teks); continue; }
      if (label === 'deskripsi') {
        mode = 'deskripsi';
        const rj = parseRentangJam(mc ? mc[1] : '');
        if (rj && !f.time) f.timeDariDeskripsi = rj;
        if (!kosong(nilai)) p.deskripsi.push(nilai);
        continue;
      }
      if (label === 'part') { mode = 'part'; if (!kosong(nilai)) p.part.push(parsePart(nilai)); continue; }
      mode = null;
      f[label] = nilai;
    }

    // Unit & equipment dari field (field menang atas judul)
    if (!kosong(f.unit)) {
      const r = normalisasiUnit(f.unit);
      if (r) { p.unit = r; p.unit_rig = true; }
      else if (!p.unit) p.unit = f.unit;
      else if (p.unit_rig && !p.equipment) p.equipment = f.unit;   // "Unit : Rig carier" padahal unit rig sudah dari judul
    }
    if (!kosong(f.equipment)) p.equipment = f.equipment;
    if (!p.equipment && p.unit && !p.unit_rig) p.equipment = p.unit;
    if (!kosong(f.sn)) {
      // "Portable pump Ziegler LD425/2" → "LD425/2" ; "MAN – 20830005312999" → "20830005312999"
      const tok = String(f.sn).split(/\s+[-–—]\s+|\s+/).filter(Boolean);
      const kode = tok.filter(t => /\d/.test(t));
      p.sn = kode.length ? kode[kode.length - 1] : f.sn;
    }
    // Jenis & gejala
    const j = normalisasiJenis(f.jenis);
    p.jenis = j.jenis; p.jenis_asli = j.asli; p.is_ts = j.isTS;
    p.status_kerja = j.jenis ? statusKerjaLama(j) : null;
    p.gejala = !kosong(f.gejala) ? f.gejala : (j.gejalaDariJenis || null);
    if (!j.dikenali) p.flags.push({ level: 'cek', kode: 'jenis', pesan: `Jenis tidak dikenali: "${j.asli}"` });
    // Tanggal & jam
    p.mulai = parseTanggal(f.mulai, tahun);
    p.selesai = parseTanggal(f.selesai, tahun);
    const rj = parseRentangJam(f.time) || f.timeDariDeskripsi || null;
    p.jam_mulai = rj ? rj.mulai : parseJamSetelahTanggal(f.mulai);
    p.jam_selesai = rj ? rj.selesai : parseJamSetelahTanggal(f.selesai);
    // Lain-lain
    const mtr = parseMeter(f.meter);
    p.meter_tipe = mtr.tipe; p.meter_nilai = mtr.nilai;
    p.lokasi = kosong(f.lokasi) ? null : f.lokasi;
    p.pic = kosong(f.pic) ? null : f.pic;
    p.no_wo = kosong(f.nowo) ? null : f.nowo;
    p.catatan = kosong(f.catatan) ? null : f.catatan;
    Object.assign(p, parseRigStop(f.rigstop));
    // Status
    const st = normalisasiStatus(f.status, p.selesai);
    p.status = st.status; p.progress = st.progress; p.status_ket = st.ket; p.status_asli = st.asli;
    p.flags.push(...st.flags);
    if (p.deskripsi.length === 1 && kosong(p.deskripsi[0])) p.deskripsi = [];

    // Validasi — level 'kurang'
    if (!p.equipment) p.flags.push({ level: 'kurang', kode: 'equipment', pesan: 'Equipment tidak ada' });
    if (p.jenis === 'CM' && !p.gejala) p.flags.push({ level: 'kurang', kode: 'gejala', pesan: 'CM tanpa Gejala' });
    if (p.jenis === 'CM' && p.unit_rig && p.rig_stop == null) p.flags.push({ level: 'kurang', kode: 'rig_stop', pesan: 'CM di unit rig: Rig stop belum diisi' });
    if (p.tipe === 'LANJUT' && !p.mulai) p.flags.push({ level: 'kurang', kode: 'mulai', pesan: 'LANJUT tanpa tanggal Mulai' });
    // Validasi — level 'cek'
    if (p.part.some(x => x.qty == null)) p.flags.push({ level: 'cek', kode: 'part_qty', pesan: 'Ada part tanpa qty' });
    const teksDesk = p.deskripsi.join(' ').toLowerCase();
    const komp = KOMPONEN.filter(([, re]) => re.test(teksDesk)).map(([n]) => n);
    if (komp.length >= 2) p.flags.push({ level: 'cek', kode: 'banyak_equipment', pesan: `Deskripsi menyebut beberapa equipment (${komp.join(', ')}) — pertimbangkan pecah jadi beberapa pekerjaan` });
    return p;
  }

  // ============================================================
  // Pencocokan ke master equipment eRAMHoist (opsional, tanpa menebak)
  // eqList: [{id, tag_number, nama_equipment, serial_number, assigned_unit_id}]
  // units:  [{id, name}] (parent_units)
  // Hasil: {id, alasan} kalau satu kandidat jelas; null kalau tidak yakin.
  // ============================================================
  const kata = s => String(s || '').toLowerCase().replace(/[^a-z0-9/ -]/g, ' ').split(/[\s/-]+/).filter(w => w.length >= 2);
  function cocokkanEquipment(p, eqList, units) {
    if (!eqList || !eqList.length) return null;
    const snK = kunciUnit(p.sn);
    if (snK.length >= 5) {
      const bySn = eqList.filter(e => e.serial_number && kunciUnit(e.serial_number) === snK);
      if (bySn.length === 1) return { id: bySn[0].id, alasan: 'SN sama' };
    }
    const unitRow = p.unit_rig && units ? units.find(u => kunciUnit(u.name) === kunciUnit(namaParentUnit(p.unit))) : null;
    // Token unik di judul yang mirip kode (TS-03, FT-03, D7G, BDEH-433) → cocokkan ke tag_number
    const kodeJudul = String([p.equipment, p.unit && !p.unit_rig ? p.unit : '', p.judul].join(' ')).toUpperCase().match(/\b[A-Z]{1,5}-?\d{1,4}[A-Z]?\b/g) || [];
    for (const k of kodeJudul) {
      const kk = kunciUnit(k);
      if (kk.length < 3) continue;
      const byTag = eqList.filter(e => kunciUnit(e.tag_number).includes(kk) && (!unitRow || e.assigned_unit_id === unitRow.id));
      if (byTag.length === 1) return { id: byTag[0].id, alasan: `kode ${k} di tag` };
    }
    // Kemiripan nama (dalam unit rig yang sama kalau ada)
    const target = kata(p.equipment);
    if (!target.length) return null;
    const kand = eqList
      .filter(e => !unitRow || e.assigned_unit_id === unitRow.id)
      .map(e => {
        const w = new Set(kata(e.nama_equipment + ' ' + e.tag_number));
        const cocok = target.filter(t => w.has(t) || [...w].some(x => x.startsWith(t) || t.startsWith(x))).length;
        return { e, skor: cocok / target.length };
      })
      .filter(x => x.skor >= 0.6)
      .sort((a, b) => b.skor - a.skor);
    if (kand.length && (kand.length === 1 || kand[0].skor > kand[1].skor)) return { id: kand[0].e.id, alasan: 'nama mirip' };
    return null;
  }

  // ---------- Template untuk perangkum (ditampilkan di Panduan, ada tombol Salin) ----------
  const TEMPLATE_KOSONG = [
    '*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*',
    '*Hari, dd/mm/yyyy*',
    '',
    '*A. STATUS RIG*',
    '*BW-100A* | Lokasi | keterangan',
    '*BW H35KD* | Lokasi | keterangan',
    '*BW KB150A* | Lokasi | keterangan',
    '*BW KB150B* | Lokasi | keterangan',
    '*BW KB150C* | Lokasi | keterangan',
    '',
    '*B. PEKERJAAN*',
    '*1. BARU – Unit – Equipment*',
    'Unit      :',
    'Equipment :',
    'SN/Model  :',
    'Jenis     : CM / CM (TS) / PM / OH / Cat 3 / Cat 4 / Inspeksi',
    'Gejala    :',
    'Rig stop  : Ya – … jam / Tidak',
    'Mulai     : dd/mm/yyyy jj.mm',
    'Selesai   : dd/mm/yyyy jj.mm',
    'HM/RH/KM  :',
    'Lokasi    :',
    'PIC       :',
    'No WO     :',
    'Deskripsi pekerjaan :',
    '* …',
    'Part:',
    '* Nama part | qty satuan',
    'Status    : Progress …%',
  ].join('\n');
  const TEMPLATE_CONTOH = [
    '*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*',
    '*Kamis, 08/10/2026*',
    '',
    '*A. STATUS RIG*',
    '*BW-100A* | OGN-39 | all unit operasi',
    '*BW H35KD* | TLJ-104 | moving dari GNK-89',
    'RH: Eng rig 6 | MP GD 2 | Gen Deutz 10 | Gen CAT 0',
    '*BW KB150A* | TLJ-255 | rig up upper mast',
    '*BW KB150B* | GNK-39 | operasi',
    '*BW KB150C* | TTB-17 | operasi',
    '',
    '*B. PEKERJAAN*',
    '*1. BARU – BW KB150C – Mud pump*',
    'Unit      : BW KB150C',
    'Equipment : Mud pump',
    'SN/Model  : NOV 7P50',
    'Jenis     : CM (TS)',
    'Gejala    : tekanan discharge drop',
    'Rig stop  : Ya – 3 jam',
    'Mulai     : 08/10/2026 08.00',
    'Selesai   : 08/10/2026 11.00',
    'HM/RH/KM  : 5230',
    'Lokasi    : TTB-17',
    'PIC       : Ilham, Rizki',
    'No WO     : 4500123456',
    'Deskripsi pekerjaan :',
    '* Cek valve & seat, ganti valve rubber',
    '* Test running ok',
    'Part:',
    '* Valve rubber | 2 pcs',
    '* Seal kit | 1 set',
    'Status    : Selesai, Progress 100%',
    '',
    '*2. LANJUT – Fire pump Ziegler*',
    'Unit      : -',
    'Equipment : Fire pump Ziegler',
    'Jenis     : CM',
    'Gejala    : unit tidak bisa running',
    'Mulai     : 05/08/2026',
    'Selesai   : -',
    'Lokasi    : SP 6 TLJ',
    'Status    : Tunggu part, Progress 30%',
  ].join('\n');

  const api = { parseLaporan, normalisasiUnit, namaParentUnit, normalisasiJenis, normalisasiStatus, parseTanggal, parseRentangJam, parseMeter, parsePart, parseRigStop, cocokkanEquipment, RIG_BAKU, JENIS_LIST, TEMPLATE_KOSONG, TEMPLATE_CONTOH };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.LaporanHarianV2 = api;
})(typeof window !== 'undefined' ? window : globalThis);
