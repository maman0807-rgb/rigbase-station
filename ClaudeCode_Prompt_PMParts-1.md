# Claude Code Prompt — PM Parts Checklist Feature
## eRAMHoist → eRAMCore | RAM Field Prabumulih

---

## KONTEKS SISTEM

Kamu sedang mengembangkan **eRAMHoist** — PWA berbasis Vanilla JS + HTML, backend Supabase/PostgreSQL, deploy di Vercel.

**Stack:**
- Frontend: Vanilla JS, HTML, CSS (no build tools, CDN only)
- Backend: Supabase (PostgreSQL)
- Deployment: Vercel
- Project URL: https://eramhoist.vercel.app

**Database:** Satu Supabase project yang sama dipakai oleh eRAMHoist dan Logbook PHR.

---

## TABEL SUPABASE YANG SUDAH ADA

```
equipment          → data equipment (id, name, tag_number, dll)
pm_schedules       → jadwal PM per equipment
daily_logs         → log harian termasuk running hours (HM)
materials          → stok spare parts gudang
stock_transactions → transaksi keluar masuk stok
work_orders        → work order management
```

**PENTING:** Sebelum mulai coding, jalankan query ini di Supabase SQL Editor untuk cek struktur tabel yang relevan:

```sql
-- Cek struktur tabel materials
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'materials' 
ORDER BY ordinal_position;

-- Cek struktur tabel equipment
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'equipment' 
ORDER BY ordinal_position;

-- Cek struktur tabel pm_schedules
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'pm_schedules' 
ORDER BY ordinal_position;

-- Lihat sample data materials
SELECT * FROM materials LIMIT 5;

-- Lihat sample data equipment
SELECT * FROM equipment LIMIT 5;
```

Sesuaikan nama kolom di kode dengan hasil query di atas.

---

## FITUR YANG AKAN DIBANGUN

### PM Parts Checklist — "Siapkan Part PM"

**Alur kerja:**
```
Dashboard eRAMHoist
→ Muncul alert equipment mendekati PM
  (contoh: MOBENG-KB150C sisa 29 HM)
→ Ada tombol "Siapkan Part PM"
→ Klik → Modal muncul berisi:
   - Daftar part wajib untuk interval PM ini
   - Qty yang dibutuhkan
   - Stok tersedia di gudang (real-time dari tabel materials)
   - Status: Cukup ✅ atau Kurang ⚠️
→ Summary: berapa item kurang stok
→ Tombol Export PDF & Kirim ke Gudang
```

---

## STEP 1 — BUAT TABEL BARU DI SUPABASE

Jalankan SQL ini di Supabase SQL Editor:

```sql
-- Tabel template parts per equipment per interval PM
CREATE TABLE IF NOT EXISTS pm_parts_template (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  interval_hm INTEGER NOT NULL,        -- 250, 500, 1000, dst
  part_name TEXT NOT NULL,
  part_number TEXT,
  material_id UUID REFERENCES materials(id), -- link ke stok gudang
  qty_required FLOAT NOT NULL DEFAULT 1,
  unit TEXT NOT NULL DEFAULT 'pcs',    -- pcs, liter, set, meter
  notes TEXT,
  is_mandatory BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index untuk performa query
CREATE INDEX IF NOT EXISTS idx_pm_parts_equipment 
  ON pm_parts_template(equipment_id);
CREATE INDEX IF NOT EXISTS idx_pm_parts_interval 
  ON pm_parts_template(equipment_id, interval_hm);

-- Enable RLS
ALTER TABLE pm_parts_template ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON pm_parts_template FOR ALL USING (true);

-- Contoh data awal (sesuaikan equipment_id dengan data aktual)
-- Jalankan dulu: SELECT id, name FROM equipment LIMIT 20;
-- Lalu insert dengan id yang sesuai
```

---

## STEP 2 — BUAT FORM INPUT PM PARTS TEMPLATE

Buat file baru: `pm-parts-admin.html`

Form untuk input/edit daftar parts per equipment per interval.

**Fitur form:**
```
- Dropdown pilih equipment (dari tabel equipment)
- Input interval HM (250 / 500 / 1000 / 2000)
- Tabel input parts:
  - Nama part
  - Part number (opsional)
  - Link ke materials (dropdown search dari tabel materials)
  - Qty required
  - Unit (pcs/liter/set/meter)
  - Mandatory toggle
  - Tombol hapus baris
- Tombol tambah baris baru
- Tombol Save All
- Tampilkan parts yang sudah ada per equipment per interval
```

**Kode struktur (Vanilla JS):**

```html
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PM Parts Template — eRAMHoist</title>
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gray-50 p-4">

  <!-- Header -->
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-gray-800 mb-2">PM Parts Template</h1>
    <p class="text-gray-500 text-sm mb-6">
      Kelola daftar spare parts per equipment per interval PM
    </p>

    <!-- Filter -->
    <div class="bg-white rounded-xl shadow p-4 mb-6 flex gap-4 flex-wrap">
      <div class="flex-1 min-w-48">
        <label class="text-sm font-medium text-gray-600">Equipment</label>
        <select id="sel-equipment" class="w-full mt-1 border rounded-lg px-3 py-2 text-sm">
          <option value="">-- Pilih Equipment --</option>
        </select>
      </div>
      <div>
        <label class="text-sm font-medium text-gray-600">Interval PM</label>
        <select id="sel-interval" class="mt-1 border rounded-lg px-3 py-2 text-sm">
          <option value="250">250 HM</option>
          <option value="500">500 HM</option>
          <option value="1000">1000 HM</option>
          <option value="2000">2000 HM</option>
        </select>
      </div>
      <div class="flex items-end">
        <button onclick="loadParts()" 
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700">
          Load Parts
        </button>
      </div>
    </div>

    <!-- Parts Table -->
    <div class="bg-white rounded-xl shadow p-4">
      <div class="flex justify-between items-center mb-4">
        <h2 class="font-semibold text-gray-700" id="table-title">Daftar Parts</h2>
        <button onclick="addRow()" 
          class="bg-green-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-green-700">
          + Tambah Part
        </button>
      </div>
      
      <table class="w-full text-sm" id="parts-table">
        <thead class="bg-gray-50">
          <tr>
            <th class="text-left p-2 font-medium text-gray-600">Nama Part</th>
            <th class="text-left p-2 font-medium text-gray-600">Part Number</th>
            <th class="text-left p-2 font-medium text-gray-600">Link ke Gudang</th>
            <th class="text-center p-2 font-medium text-gray-600">Qty</th>
            <th class="text-center p-2 font-medium text-gray-600">Unit</th>
            <th class="text-center p-2 font-medium text-gray-600">Wajib</th>
            <th class="text-center p-2 font-medium text-gray-600">Hapus</th>
          </tr>
        </thead>
        <tbody id="parts-tbody">
          <tr><td colspan="7" class="text-center p-8 text-gray-400">
            Pilih equipment dan interval untuk memuat parts
          </td></tr>
        </tbody>
      </table>

      <div class="mt-4 flex gap-3">
        <button onclick="saveParts()" 
          class="bg-blue-600 text-white px-6 py-2 rounded-lg text-sm hover:bg-blue-700 font-medium">
          💾 Simpan Semua
        </button>
        <span id="save-status" class="text-sm text-gray-500 self-center"></span>
      </div>
    </div>
  </div>

  <script>
    const SUPABASE_URL = 'YOUR_SUPABASE_URL';
    const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY';
    const supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    let allMaterials = [];
    let currentParts = [];

    // Load equipment dropdown
    async function loadEquipment() {
      const { data } = await supabase
        .from('equipment')
        .select('id, name, tag_number')
        .order('name');
      
      const sel = document.getElementById('sel-equipment');
      data.forEach(eq => {
        sel.innerHTML += `<option value="${eq.id}">${eq.tag_number} — ${eq.name}</option>`;
      });
    }

    // Load materials untuk dropdown link gudang
    async function loadMaterials() {
      const { data } = await supabase
        .from('materials')
        .select('id, description, satuan, stok, part_number') // sesuaikan kolom
        .order('name');
      allMaterials = data || [];
    }

    // Load existing parts
    async function loadParts() {
      const eqId = document.getElementById('sel-equipment').value;
      const interval = document.getElementById('sel-interval').value;
      if (!eqId) { alert('Pilih equipment dulu'); return; }

      const { data } = await supabase
        .from('pm_parts_template')
        .select('*')
        .eq('equipment_id', eqId)
        .eq('interval_hm', interval)
        .order('part_name');

      currentParts = data || [];
      renderTable(currentParts);

      const eqName = document.getElementById('sel-equipment').selectedOptions[0].text;
      document.getElementById('table-title').textContent = 
        `Parts PM ${interval} HM — ${eqName}`;
    }

    function renderTable(parts) {
      const tbody = document.getElementById('parts-tbody');
      if (parts.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center p-6 text-gray-400">
          Belum ada parts. Klik "+ Tambah Part" untuk mulai.
        </td></tr>`;
        return;
      }
      tbody.innerHTML = parts.map((p, i) => rowHtml(p, i)).join('');
    }

    function addRow() {
      const tbody = document.getElementById('parts-tbody');
      if (tbody.querySelector('.empty-row')) tbody.innerHTML = '';
      const i = tbody.children.length;
      const row = document.createElement('tr');
      row.innerHTML = rowHtml({}, i);
      tbody.appendChild(row);
    }

    function rowHtml(p, i) {
      const matOptions = allMaterials.map(m => 
        `<option value="${m.id}" ${p.material_id === m.id ? 'selected' : ''}>
          ${m.description}
        </option>`
      ).join('');

      return `<tr class="border-t" id="row-${i}">
        <td class="p-2">
          <input type="hidden" value="${p.id || ''}" class="part-id">
          <input type="text" value="${p.part_name || ''}" 
            placeholder="Nama part..." 
            class="part-name w-full border rounded px-2 py-1 text-sm">
        </td>
        <td class="p-2">
          <input type="text" value="${p.part_number || ''}" 
            placeholder="Part No."
            class="part-number w-full border rounded px-2 py-1 text-sm">
        </td>
        <td class="p-2">
          <select class="material-id w-full border rounded px-2 py-1 text-sm">
            <option value="">-- Tidak ada --</option>
            ${matOptions}
          </select>
        </td>
        <td class="p-2 text-center">
          <input type="number" value="${p.qty_required || 1}" min="0.1" step="0.1"
            class="qty-required w-16 border rounded px-2 py-1 text-sm text-center">
        </td>
        <td class="p-2 text-center">
          <select class="unit border rounded px-2 py-1 text-sm">
            ${['pcs','liter','set','meter','kg','roll'].map(u => 
              `<option ${(p.unit||'pcs')===u?'selected':''}>${u}</option>`
            ).join('')}
          </select>
        </td>
        <td class="p-2 text-center">
          <input type="checkbox" class="is-mandatory w-4 h-4" 
            ${p.is_mandatory !== false ? 'checked' : ''}>
        </td>
        <td class="p-2 text-center">
          <button onclick="deleteRow('${p.id || ''}', ${i})" 
            class="text-red-500 hover:text-red-700 text-lg">×</button>
        </td>
      </tr>`;
    }

    async function saveParts() {
      const eqId = document.getElementById('sel-equipment').value;
      const interval = parseInt(document.getElementById('sel-interval').value);
      if (!eqId) return;

      const rows = document.querySelectorAll('#parts-tbody tr');
      const upserts = [];

      rows.forEach(row => {
        const name = row.querySelector('.part-name')?.value?.trim();
        if (!name) return;

        upserts.push({
          id: row.querySelector('.part-id')?.value || undefined,
          equipment_id: eqId,
          interval_hm: interval,
          part_name: name,
          part_number: row.querySelector('.part-number')?.value || null,
          material_id: row.querySelector('.material-id')?.value || null,
          qty_required: parseFloat(row.querySelector('.qty-required')?.value) || 1,
          unit: row.querySelector('.unit')?.value || 'pcs',
          is_mandatory: row.querySelector('.is-mandatory')?.checked ?? true,
        });
      });

      const { error } = await supabase
        .from('pm_parts_template')
        .upsert(upserts, { onConflict: 'id' });

      const status = document.getElementById('save-status');
      if (error) {
        status.textContent = '❌ Gagal simpan: ' + error.message;
        status.className = 'text-sm text-red-500 self-center';
      } else {
        status.textContent = '✅ Tersimpan!';
        status.className = 'text-sm text-green-600 self-center';
        setTimeout(() => status.textContent = '', 3000);
        loadParts();
      }
    }

    async function deleteRow(id, i) {
      if (id) {
        await supabase.from('pm_parts_template').delete().eq('id', id);
      }
      document.getElementById(`row-${i}`)?.remove();
    }

    // Init
    loadEquipment();
    loadMaterials();
  </script>
</body>
</html>
```

---

## STEP 3 — BUAT MODAL PM PARTS di DASHBOARD

Di file dashboard eRAMHoist yang sudah ada, tambahkan:

### 3A. Tombol di card PM Alert

Cari bagian yang render card "Mendekati Maintenance PM" dan tambahkan tombol:

```javascript
// Di fungsi render PM alert card, tambahkan tombol ini:
function renderPMAlertCard(equipment) {
  return `
    <div class="pm-alert-card">
      <!-- existing content -->
      <button 
        onclick="showPMPartsModal('${equipment.id}', '${equipment.nama}', ${equipment.interval_hm}, ${equipment.sisa_hm})"
        class="btn-siapkan-parts">
        📦 SIAPKAN PART PM
      </button>
    </div>
  `;
}
```

### 3B. Fungsi Modal PM Parts

Tambahkan di file JS dashboard:

```javascript
async function showPMPartsModal(equipmentId, equipmentName, intervalHm, sisaHm) {
  // Show loading modal dulu
  showModal(`
    <div class="modal-pm-parts">
      <div class="modal-header">
        <h3>🔧 Part List PM — ${equipmentName}</h3>
        <p>Interval ${intervalHm} HM &nbsp;|&nbsp; Sisa: <strong>${sisaHm} HM</strong></p>
        <button onclick="closeModal()" class="btn-close">×</button>
      </div>
      <div id="pm-parts-content">
        <p class="loading">Memuat daftar parts...</p>
      </div>
    </div>
  `);

  try {
    // 1. Ambil template parts untuk equipment ini + interval
    const { data: parts, error: e1 } = await supabase
      .from('pm_parts_template')
      .select(`
        *,
        materials (
          id,
          name,
          stok,
          unit
        )
      `)
      .eq('equipment_id', equipmentId)
      .eq('interval_hm', intervalHm)
      .order('is_mandatory', { ascending: false })
      .order('part_name');

    if (e1) throw e1;

    if (!parts || parts.length === 0) {
      document.getElementById('pm-parts-content').innerHTML = `
        <div class="empty-parts">
          <p>⚠️ Belum ada template parts untuk PM ${intervalHm} HM equipment ini.</p>
          <a href="/pm-parts-admin.html" target="_blank" class="btn-setup">
            Setup Parts Template →
          </a>
        </div>
      `;
      return;
    }

    // 2. Analisa stok vs kebutuhan
    let kurangCount = 0;
    const partsHtml = parts.map(part => {
      const stokAda = part.materials?.stok ?? 0;
      const qtyButuh = part.qty_required;
      const unit = part.unit;
      const cukup = stokAda >= qtyButuh;
      if (!cukup && part.is_mandatory) kurangCount++;

      const statusIcon = cukup ? '✅' : '⚠️';
      const statusClass = cukup ? 'stok-cukup' : 'stok-kurang';
      const stokText = part.materials 
        ? `${stokAda} ${part.materials.satuan || unit}`
        : 'Tidak terhubung ke gudang';

      return `
        <tr class="${statusClass}">
          <td class="part-name">
            ${part.is_mandatory ? '' : '<span class="optional">Opsional</span>'}
            ${part.part_name}
            ${part.part_number ? `<span class="part-no">(${part.part_number})</span>` : ''}
          </td>
          <td class="qty-need">${qtyButuh} ${unit}</td>
          <td class="stok-status">
            ${statusIcon} ${stokText}
          </td>
        </tr>
      `;
    }).join('');

    // 3. Render tabel lengkap
    document.getElementById('pm-parts-content').innerHTML = `
      <table class="parts-table">
        <thead>
          <tr>
            <th>Nama Part</th>
            <th>Qty Butuh</th>
            <th>Stok Gudang</th>
          </tr>
        </thead>
        <tbody>${partsHtml}</tbody>
      </table>

      ${kurangCount > 0 ? `
        <div class="alert-kurang">
          ⚠️ <strong>${kurangCount} item stok kurang</strong> — segera proses PO sebelum PM!
        </div>
      ` : `
        <div class="alert-cukup">
          ✅ Semua stok wajib tersedia — siap untuk PM!
        </div>
      `}

      <div class="modal-actions">
        <button onclick="exportPMPartsPDF('${equipmentName}', ${intervalHm})" 
          class="btn-export">📤 Export PDF</button>
        <button onclick="kirimKeGudang('${equipmentId}', ${intervalHm})" 
          class="btn-kirim">📨 Kirim ke Gudang</button>
        <button onclick="closeModal()" class="btn-tutup">Tutup</button>
      </div>
    `;

  } catch(err) {
    document.getElementById('pm-parts-content').innerHTML = `
      <p class="error">❌ Error: ${err.message}</p>
    `;
  }
}
```

### 3C. Export PDF Parts List

```javascript
async function exportPMPartsPDF(equipmentName, intervalHm) {
  // Ambil data dari modal yang sudah tampil
  const rows = document.querySelectorAll('.parts-table tbody tr');
  
  let tableContent = '';
  rows.forEach(row => {
    const cells = row.querySelectorAll('td');
    tableContent += `
      <tr>
        <td>${cells[0]?.textContent?.trim()}</td>
        <td>${cells[1]?.textContent?.trim()}</td>
        <td>${cells[2]?.textContent?.trim()}</td>
      </tr>
    `;
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>PM Parts List</title>
      <style>
        body { font-family: Arial; font-size: 12px; padding: 20px; }
        h2 { color: #1B3A5C; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th { background: #1B3A5C; color: white; padding: 8px; text-align: left; }
        td { padding: 6px 8px; border-bottom: 1px solid #ddd; }
        .header-info { color: #666; margin-bottom: 8px; }
        .footer { margin-top: 24px; font-size: 10px; color: #999; }
      </style>
    </head>
    <body>
      <h2>📋 PM Parts List — ${equipmentName}</h2>
      <p class="header-info">
        Interval: <strong>${intervalHm} HM</strong> &nbsp;|&nbsp;
        Tanggal: <strong>${new Date().toLocaleDateString('id-ID')}</strong> &nbsp;|&nbsp;
        eRAMHoist — RAM Field Prabumulih
      </p>
      <table>
        <thead>
          <tr>
            <th>Nama Part</th>
            <th>Qty Dibutuhkan</th>
            <th>Status Stok</th>
          </tr>
        </thead>
        <tbody>${tableContent}</tbody>
      </table>
      <p class="footer">
        Ref: Pedoman Pemeliharaan PT Pertamina EP No. A04-005/PEP23000/2023-S9<br>
        Dicetak dari eRAMHoist — ${new Date().toLocaleString('id-ID')}
      </p>
    </body>
    </html>
  `;

  const win = window.open('', '_blank');
  win.document.write(html);
  win.document.close();
  win.print();
}
```

---

## STEP 4 — CSS STYLING MODAL

Tambahkan CSS untuk modal PM Parts:

```css
/* Modal PM Parts */
.modal-pm-parts {
  background: white;
  border-radius: 16px;
  padding: 24px;
  max-width: 600px;
  width: 90%;
  max-height: 80vh;
  overflow-y: auto;
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 700;
  color: #1B3A5C;
  margin-bottom: 4px;
}

.modal-header p {
  font-size: 13px;
  color: #666;
  margin-bottom: 16px;
}

.parts-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.parts-table th {
  background: #1B3A5C;
  color: white;
  padding: 10px 12px;
  text-align: left;
  font-weight: 600;
}

.parts-table td {
  padding: 8px 12px;
  border-bottom: 1px solid #eee;
}

.stok-kurang td {
  background: #FFF5F5;
}

.stok-cukup td {
  background: white;
}

.part-no {
  font-size: 11px;
  color: #888;
  margin-left: 4px;
}

.optional {
  font-size: 10px;
  background: #E2E8F0;
  color: #666;
  padding: 1px 6px;
  border-radius: 4px;
  margin-right: 4px;
}

.alert-kurang {
  background: #FFF3CD;
  border: 1px solid #F59E0B;
  border-radius: 8px;
  padding: 12px 16px;
  margin-top: 16px;
  font-size: 13px;
  color: #92400E;
}

.alert-cukup {
  background: #F0FDF4;
  border: 1px solid #10B981;
  border-radius: 8px;
  padding: 12px 16px;
  margin-top: 16px;
  font-size: 13px;
  color: #065F46;
}

.modal-actions {
  display: flex;
  gap: 12px;
  margin-top: 20px;
  flex-wrap: wrap;
}

.btn-export {
  background: #2E6DA4;
  color: white;
  border: none;
  padding: 10px 16px;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}

.btn-kirim {
  background: #028090;
  color: white;
  border: none;
  padding: 10px 16px;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}

.btn-tutup {
  background: #E2E8F0;
  color: #333;
  border: none;
  padding: 10px 16px;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}
```

---

## STEP 5 — TESTING CHECKLIST

Setelah semua kode selesai, test urutan ini:

```
□ 1. Buka Supabase — pastikan tabel pm_parts_template berhasil dibuat
□ 2. Buka pm-parts-admin.html — pilih equipment MOBENG-KB150C
□ 3. Pilih interval 250 HM — input minimal 3 parts
□ 4. Save — cek di Supabase tabelnya terisi
□ 5. Buka dashboard eRAMHoist
□ 6. Klik "Siapkan Part PM" di card MOBENG-KB150C
□ 7. Pastikan modal muncul dengan daftar parts
□ 8. Cek status stok muncul dari tabel materials
□ 9. Test Export PDF — pastikan bisa print
□ 10. Test kalau parts template kosong — muncul pesan yang jelas
```

---

## CATATAN PENTING

1. **Supabase credentials** — ganti `YOUR_SUPABASE_URL` dan `YOUR_SUPABASE_ANON_KEY` dengan nilai aktual dari project settings Supabase

2. **Nama kolom materials** — sebelum coding, cek dulu nama kolom aktual tabel `materials`:
   - Nama item → kemungkinan `name` atau `item_name` atau `description`
   - Stok qty → kemungkinan `stok` atau `quantity` atau `qty`
   - Sesuaikan query di kode

3. **equipment_id format** — pastikan UUID format konsisten antara tabel equipment dan pm_parts_template

4. **Modal system** — gunakan modal system yang sudah ada di eRAMHoist kalau sudah ada, tidak perlu buat baru

5. **RLS Supabase** — kalau ada Row Level Security yang ketat, mungkin perlu adjust policy untuk tabel pm_parts_template

---

## REFERENSI

- **Standar:** Pedoman Pemeliharaan PT Pertamina EP No. A04-005/PEP23000/2023-S9 — Bab VI Suku Cadang
- **Project:** eRAMHoist → eRAMCore | RAM Field Prabumulih
- **User:** Abdul Rachman (Maman) — Senior Teknisi RAM PHR
