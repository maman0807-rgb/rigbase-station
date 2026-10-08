# eRAMHoist — Laporan Harian v2 (Format Rangkuman Baru)

## 0. Konteks

eRAMHoist adalah PWA (Vanilla JS + Supabase + Vercel, tanpa build tool) untuk manajemen equipment & spare part Hoist & Heavy Equipment (HHE) PHR Field Prabumulih.

Modul **Laporan Harian** sudah ada dengan alur:
Telegram bot → n8n (webhook) → Claude API (parsing) → Supabase (draft) → admin konfirmasi di app.

Tim HHE sudah **menyepakati format rangkuman laporan harian baru** (dipakai sejak 06/10/2026). Teknisi lapangan tetap lapor bebas di grup WA; satu orang perangkum menyusun rangkuman dengan format di bawah, lalu mengirimnya ke bot Telegram.

Tujuan perubahan: setiap rangkuman yang masuk menjadi **data terstruktur per pekerjaan** (bukan per kalimat), supaya ke depan bisa dihitung: history per unit/equipment, MTTR, downtime rig (rig stop), pemakaian part, running hours.

**Bahasa UI & komentar: Indonesia.** Jangan ubah modul lain.

---

## 1. LANGKAH PERTAMA — Audit dulu, jangan langsung ubah

Sebelum menulis kode apa pun:

1. Baca seluruh kode modul Laporan Harian yang ada (halaman app, fungsi JS, SQL/migration, prompt parsing Claude yang sekarang, workflow n8n kalau ada file export-nya di repo).
2. Tampilkan ringkasan ke saya:
   - tabel Supabase yang dipakai sekarang + kolomnya,
   - bentuk JSON hasil parsing sekarang,
   - alur draft → konfirmasi sekarang,
   - di mana prompt parsing Claude disimpan (di n8n atau di kode).
3. Usulkan **pemetaan** dari struktur lama ke struktur baru (Bagian 4). Kalau tabel lama bisa dipakai/diperluas, perluas — **jangan drop tabel atau data lama**. Migration harus additive.
4. Tunggu persetujuan saya sebelum eksekusi.

---

## 2. Format rangkuman yang disepakati

Contoh nyata (fixture utama untuk testing, simpan sebagai `tests/fixtures/laporan_2026-10-06.txt`):

```
*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*
*Selasa, 06/10/2026*

*A. STATUS RIG*
*BW-100A*| OGN-39  |  Engine rig carrier, engine mud pump & all genset operasi

*BW H35KD*| GNK-89  |  Persiapan program moving ke TLJ-104

*BW KB150A*| TLJ-255 |  Unit engine operasi lanjut Rig up Upper mast.

*BW KB150B*| GNK-39 | Unit operasi moving dari GNK-72 ke GNK-39, install matting & landaskan unit rig, rig up lower & upper mast 

*BW KB150C*| TTB-17  | all unit operasi, cleaning fuel filter engine genset CAT, test function (ok)

*B. PEKERJAAN*
*1. BARU – BW-KB150A – Rig carier*
Unit      : BW KB150A
Equipment : Rig carier
SN/Model  :
Jenis     : CM (TS)
Gejala    : low pressure air system
Mulai     : 06/10/2026 10.00
Selesai   : 06/10/2026 17.00
Time : 10.00 S/d 17.00
HM/RH/KM  : 14200
Lokasi    : TLJ-255
PIC       : Ilham, dipta, rizki
Deskripsi pekerjaan :
* Install R5 Valve crownomatic, F/T setting crownomatic ok
* Compressor bocor pada connector oli, ganti connector aman, tidak ada kebocoran
* Fill up oli engine rig carier dan oli stock (ATF, RORED, MEDITRAN S40)
* Isi air water spark arrestor sampai penuh
Part:
* Valve R5 |1 pcs|
* Quick Valve |2 Pcs|
* Pelumas (atf, meditran, rored s140) 
Status    : Progress 100%

*2. LANJUT – BW H35KD – Tower light JCB*
Unit      : BW H35KD
Equipment : Tower light JCB
SN/Model  : X2CH25843
Jenis     : CM (TS)
Gejala    : Short Line electrical
Mulai Pekerjaan    : 30/09/2026
Selesai Pekerjaan : - 
Time :
HM/RH/KM  : 14200
Lokasi    : GNK-89
PIC       : David
Deskripsi pekerjaan (10.00–15.55):
* Check all around
* Dismantle body cover 
* Dismantle Dinamo stater di Test Ok
* Install Dinamo stater 
* Replace sekring dan rumah sekring
* Isolasi kabel yg terindikasi short
* Test Running (keluar asap dari rumah sekring)
* check visual kabel (tidak ada yg terkelupas)
* housekeeping area
Status    : Progress 70%

*3. LANJUT – Fire pump Ziegler*
SN/Model  : Portable pump Ziegler LD425/2
Jenis     : CM (TS unit tidak bisa running)
HM/RH/KM  : -
Mulai Pekerjaan : 5/08/2026
Selesai Pekerjaan : -
Time :
Deskripsi pekerjaan: -
Status    : Tunggu part, Progress 30%

*4. LANJUT – MAN FT-03 BG 8015 CZ*
SN/Model  : MAN – 20830005312999
Jenis     : CM (TS low power)
Mulai Pekerjaan : 02/09/2026
Selesai Pekerjaan : -
Time :
Lokasi : BPK
PIC  : RAM Hoist
Deskripsi pekerjaan: - 
*Status    : tunggu realise SPK, Progress 20%

*5. LANJUT – Dozer D7G BDEH-433*
SN/Model  : 7MB02721
Jenis     : CM (radiator leak & track kendor)
Mulai Pekerjaan : 02/09/2026
Selesai Pekerjaan : -
Time :
Lokasi    : SP 6 TLJ
Deskripsi pekerjaan: - 
Status    : Tunggu Tim Trakindo untuk perbaikan 78%

*6. LANJUT – Genset Perkins MTU*
SN/Model  : Perkins – DK32000U468058B
Jenis  : OH (TOH)
Mulai Pekerjaan : 26/06/2026
Selesai Pekerjaan : -
Time :
Lokasi : BPM
Deskripsi pekerjaan: - 
Status : Tunggu part 45%

*7. LANJUT – Hino TS-03 BG 8013 CZ*
Jenis     : install part recomendation
HM/RH/KM  : KM 16911,6
Lokasi   : BPK
Mulai Pekerjaan : 31/07/2026
Selesai Pekerjaan : 06/10/2026
Time : 09.00 S/d 15.30 WIB
Deskripsi pekerjaan :
* check all around
* Persiapan tools 
* Install crossjoint 2ea *(ok)*
* Install Sling coupling *(ok)*
* install kembali ban depan kiri dan kanan *(ok)*
* Housekeeping
Part:
* Cross Joint |2 pcs|
* Sling Coupling |2 Pcs|
Status    : Pekerjaan selesai, Progress 100%

*8. Lanjut – Genset Krisbow Dongfeng MTU – Engine not crank*
Unit      : Genset Krisbow Dongfeng MTU
Jenis     : CM
Gejala    : Engine Cant running
Mulai Pekerjaan : 05/10/2026 ..
Selesai Pekerjaan : -
Time 14.00 S/d 15.00 WIB
HM/RH/KM  : 14219,7
Lokasi    : BPM
Deskripsi pekerjaan :
* Check Unit Engine genset yang baru dikirim dari MTU
* Reposisi Unit Genset
* TTD serah terima Genset *(ok)*
Status    : Pekerjaan Lanjut, progress 30%
```

### Aturan format yang disepakati tim

| Bagian | Aturan |
|---|---|
| Header | `*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*` + hari, tanggal `dd/mm/yyyy`. Tanggal laporan diambil dari sini. |
| A. Status Rig | 1 baris per rig: `*Unit* \| Lokasi \| keterangan bebas`. **Kondisi rig TIDAK ditulis** (sudah disepakati) — jangan wajibkan, jangan tebak. |
| Baris RH (opsional) | Muncul di bawah baris rig **hanya kalau RH dilaporkan**, mis. `RH: Eng rig 3 \| MP GD 0 \| Gen Deutz 4 \| Gen CAT 3 \| Comp 0 \| Acc 0 \| FP 0`. Pisah per `\|`, nama equipment + angka jam. Kalau tidak ada, abaikan (bukan isian kurang). |
| B. Pekerjaan | Blok bernomor. Judul: `N. BARU – Unit – Equipment` atau `N. LANJUT – Unit – Equipment`. Unit bisa tidak ada (unit non-rig: judul langsung nama equipment). Huruf besar/kecil BARU/LANJUT/Lanjut bebas. |
| Field | `Label : nilai`. Label bisa bervariasi (lihat Bagian 3). Field kosong/`-` = kosong. |
| **Rig stop** (field baru) | `Rig stop : Ya / Tidak`, boleh + jam, mis. `Ya – 7 jam` atau `Ya – sejak 06/10 10.00`. Wajib untuk CM di unit rig. |
| Deskripsi | Bullet `*` atau `-`, bisa ada jam di label `(10.00–15.55)`. `*(ok)*` boleh. |
| Part | Bullet: `* Nama \|qty satuan\|` , PN opsional: `* Nama \| PN \| qty \| sumber`. Qty bisa kosong. |
| Status | Teks bebas → dinormalisasi (Bagian 3). |
| Markdown WA | `*tebal*`, `_miring_`, bullet — semua harus di-strip saat parsing. |

---

## 3. Normalisasi (wajib, deterministik di JS — jangan hanya andalkan Claude)

Buat file `js/laporan/normalisasi.js` (atau sesuai struktur repo) berisi fungsi murni + unit test sederhana.

**Unit rig (kamus + alias):**
- `BW-100A` ← BW 100A, BW-100 A, BW100, BW 100 A
- `BW H35KD` ← BW-H35KD, BWH35KD, BW H 35KD, H35KD
- `BW KB150A` ← BW-KB150A, BW KB 150A, BW KB.150A, BW KB 150 A, KB150A
- `BW KB150B`, `BW KB150C` ← pola sama
- Unit non-rig (Fire pump Ziegler, MAN FT-03, Dozer D7G, Genset …, Hino TS-03): simpan nama apa adanya di `unit` + cocokkan ke master equipment eRAMHoist kalau ada (by nama/SN/no polisi). Jangan paksa ke 5 rig.
- Kamus alias disimpan di tabel (bisa ditambah admin), bukan hardcode saja.

**Jenis** (kamus tetap: `CM, PM, OH, Cat 3, Cat 4, Inspeksi, Lainnya`):
- `CM`, `CM (TS)`, `TS`, `CM (… keterangan …)` → `CM`; teks dalam kurung yang bukan "TS" dipindah ke `gejala` kalau gejala kosong (contoh no. 5: "radiator leak & track kendor" → gejala).
- `OH`, `TOH`, `GOH`, `Overhaul` → `OH`
- `PM`, `PM 1..5`, `Service` → `PM`
- `Inspeksi`, `Cek rutin`, `Check list` → `Inspeksi`
- selain itu → `Lainnya` + **flag** "jenis tidak dikenali: <teks asli>" (contoh no. 7 "install part recomendation").

**Status** → `status` (enum) + `progress` (0–100) + `status_ket`:
- mengandung "selesai" / "progress 100%" / `Selesai Pekerjaan` terisi tanggal → `Selesai`, progress 100
- mengandung "tunggu" / "menunggu" / "waiting" → `Tunggu` + `status_ket` = sisa teks ("part", "realise SPK", "Tim Trakindo …")
- lainnya → `Progress` + angka % kalau ada
- Konflik (mis. "Progress 100%" tapi Selesai kosong) → `Selesai` + flag "tanggal selesai kosong".

**Tanggal & jam:** `d/m/yyyy`, `dd/mm/yyyy`, `dd/mm`, jam `10.00`/`10:00`, rentang `10.00 S/d 17.00`, `(10.00–15.55)`. Sisa karakter seperti `..` diabaikan. Tahun kosong → tahun laporan.

**Angka:** `14219,7` → 14219.7. `KM 16911,6` → `meter_tipe='KM'`, nilai 16911.6. `HM/RH` → `meter_tipe='HM'`.

---

## 4. Struktur data (usulan — sesuaikan dengan hasil audit Langkah 1)

```
laporan_harian            -- satu per tanggal
  id, tanggal (unique), teks_asli, sumber ('telegram'), pengirim_tg,
  status ('draft'|'dikonfirmasi'), dikonfirmasi_oleh, dikonfirmasi_at, created_at

laporan_status_rig        -- 5 baris per laporan
  id, laporan_id, unit, lokasi, keterangan, rh jsonb null   -- {"Eng rig":3,"MP GD":0,...}

pekerjaan                 -- SATU baris per pekerjaan, hidup lintas hari
  id, kode (auto, mis. HHE-2026-0001 — tidak ditulis user),
  unit, equipment, sn_model, jenis, gejala,
  mulai_tgl, mulai_jam, selesai_tgl, selesai_jam,
  rig_stop bool null, rig_stop_jam numeric null, rig_stop_ket,
  meter_tipe, meter_nilai, lokasi, pic, no_wo,
  status, progress, status_ket,
  equipment_id (FK master equipment, null boleh),
  dibuat_dari_laporan_id, created_at, updated_at

pekerjaan_log             -- jejak harian: satu baris per pekerjaan per laporan
  id, pekerjaan_id, laporan_id, tanggal, tipe ('BARU'|'LANJUT'),
  jam_mulai, jam_selesai, deskripsi (text, bullet digabung \n),
  status, progress, status_ket, meter_nilai

pekerjaan_part
  id, pekerjaan_id, log_id, nama_part, pn, qty numeric null, satuan, sumber

laporan_flag              -- isian kurang / peringatan untuk admin
  id, laporan_id, pekerjaan_log_id null, level ('kurang'|'cek'), pesan, selesai bool

kamus_unit_alias          -- alias → unit baku
```

RLS: ikuti pola RLS yang sudah dipakai di modul lain eRAMHoist.

---

## 5. Pencocokan BARU / LANJUT

- **BARU** → buat `pekerjaan` baru + `pekerjaan_log`.
- **LANJUT** → cari `pekerjaan` yang statusnya belum Selesai dengan:
  1. unit sama (setelah normalisasi), dan
  2. equipment mirip (case-insensitive, abaikan tanda baca; boleh similarity sederhana), dan
  3. `mulai_tgl` sama dengan "Mulai" di blok (kalau ada).
  - Ketemu 1 → tambah `pekerjaan_log`, update status/progress/selesai.
  - Ketemu >1 atau 0 → **jangan menebak**: buat pekerjaan baru dengan flag `cek` "LANJUT tanpa pekerjaan induk — pilih induk atau jadikan baru", tampilkan pilihan kandidat di layar konfirmasi.
- Masa transisi: pekerjaan yang dimulai sebelum sistem ini jalan (mis. Mulai 26/06/2026) wajar tidak punya induk → admin pilih "jadikan pekerjaan baru (data lama)".

---

## 6. Validasi → `laporan_flag`

Level `kurang` (wajib dilengkapi sebelum konfirmasi, tapi admin boleh override dengan alasan):
- CM tanpa Gejala
- CM di unit rig (5 BW) tanpa **Rig stop**
- LANJUT tanpa tanggal Mulai
- Status Selesai tanpa tanggal Selesai
- Blok tanpa Equipment

Level `cek` (peringatan saja):
- Jenis tidak dikenali
- HM/RH/KM sama persis dengan pekerjaan **unit lain** di laporan yang sama (indikasi salah copy — contoh: no. 1 KB150A HM 14200 = no. 2 tower light H35KD)
- Deskripsi menyebut ≥2 equipment berbeda dalam satu blok (contoh no. 1: crownomatic, compressor, oli engine, spark arrestor) → saran "pecah jadi beberapa pekerjaan"
- Part tanpa qty
- Pekerjaan open kemarin yang tidak muncul hari ini (bandingkan dengan Daftar Open)

---

## 7. Parsing dengan Claude API

- Parser **dua lapis**: (a) JS/regex memecah teks menjadi header, baris status rig, baris RH, dan blok pekerjaan per nomor; (b) Claude API dipanggil **per blok** (atau satu panggilan dengan array blok) untuk mengisi field yang labelnya tidak baku. Hasil Claude lalu dilewatkan ke normalisasi Bagian 3.
- Claude harus mengembalikan **JSON saja**, skema:

```json
{
  "tipe": "BARU|LANJUT",
  "unit": "string|null",
  "equipment": "string",
  "sn_model": "string|null",
  "jenis_asli": "string|null",
  "gejala": "string|null",
  "mulai": "dd/mm/yyyy HH.MM|null",
  "selesai": "dd/mm/yyyy HH.MM|null",
  "jam_kerja": "HH.MM-HH.MM|null",
  "rig_stop": "Ya|Tidak|null",
  "rig_stop_ket": "string|null",
  "meter": "string|null",
  "lokasi": "string|null",
  "pic": "string|null",
  "no_wo": "string|null",
  "deskripsi": ["string"],
  "part": [{"nama":"string","pn":"string|null","qty":"string|null","sumber":"string|null"}],
  "status_asli": "string"
}
```

- Instruksi di prompt Claude: **jangan mengarang** nilai yang tidak ada di teks — kosong = null. Jangan memecah blok sendiri (pemecahan dilakukan admin).
- Simpan prompt parsing di satu tempat yang jelas (file di repo, mis. `prompts/parse_laporan_harian.md`) dan referensikan dari n8n/kode.
- Model & API key: pakai konfigurasi yang sudah ada.

---

## 8. Alur Telegram

1. **Buffer pesan**: Telegram memotong pesan >4096 karakter jadi beberapa pesan. Bot menampung semua pesan dari chat yang sama sampai perangkum menekan tombol inline **"Proses laporan"** (atau kirim `/proses`). Setelah setiap pesan masuk, bot balas singkat: "Diterima (bagian 2). Tekan Proses laporan kalau sudah lengkap." dengan tombol tersebut.
2. Saat diproses: gabungkan pesan sesuai urutan → parsing → simpan draft.
3. Bot membalas ringkasan:
   ```
   Laporan 06/10/2026 – draft tersimpan
   Status rig: 5 · Pekerjaan: 8 (1 baru, 7 lanjut, 2 selesai)
   ⚠ Isian kurang (2):
   • #1 BW KB150A – Rig carier: Rig stop belum diisi
   • #4 MAN FT-03: Gejala kosong
   ⚑ Perlu dicek (2): ...
   Buka: <link halaman konfirmasi>
   ```
4. Kalau laporan untuk tanggal yang sama dikirim ulang → tanyakan "Ganti draft yang ada?" (jangan duplikasi).

**Daftar Open setiap pagi (06.00 WIB)** — dikirim bot ke chat perangkum:
```
PEKERJAAN OPEN per 07/10/2026
1. LANJUT – BW H35KD – Tower light JCB (mulai 30/09, 70%)
2. LANJUT – Fire pump Ziegler (mulai 05/08, tunggu part 30%)
...
```
Format judul sama persis dengan format laporan supaya bisa langsung disalin.

---

## 9. Halaman konfirmasi (app)

- Daftar laporan draft per tanggal.
- Di dalam laporan: tab **Status Rig** (5 baris + RH kalau ada) dan **Pekerjaan** (kartu per blok).
- Kartu pekerjaan: semua field bisa diedit; Jenis/Unit/Status pakai dropdown kamus; Rig stop toggle Ya/Tidak + jam; flag ditampilkan merah (kurang) / kuning (cek) di field terkait.
- Tombol **"Pecah pekerjaan"**: memecah satu blok jadi 2+ pekerjaan (pilih bullet deskripsi & part mana ikut ke mana).
- Untuk LANJUT tanpa induk: dropdown kandidat pekerjaan open + opsi "jadikan baru".
- Tombol **Konfirmasi** aktif kalau tidak ada flag `kurang` yang belum ditangani (atau di-override dengan alasan).
- Teks asli laporan selalu bisa dilihat (panel samping/accordion).
- Mobile-first.

---

## 10. Kriteria selesai (uji dengan fixture 06/10/2026)

Hasil parsing fixture harus:
- tanggal laporan 06/10/2026; 5 baris status rig dengan lokasi benar (BW KB150B = GNK-39); RH kosong semua (tidak ada baris RH) tanpa flag
- 8 blok pekerjaan: #1 BARU, #2–#8 LANJUT
- #1: unit `BW KB150A`, jenis `CM`, gejala "low pressure air system", mulai 06/10 10.00, selesai 06/10 17.00, status `Selesai`, part 3 baris (Valve R5 qty 1, Quick Valve qty 2, Pelumas qty null); flag `kurang` rig stop; flag `cek` HM sama dengan #2; flag `cek` banyak equipment
- #3: unit null/non-rig, equipment "Fire pump Ziegler", SN "LD425/2", jenis `CM`, gejala "unit tidak bisa running", mulai 05/08/2026, status `Tunggu` (ket "part"), progress 30
- #5: jenis `CM`, gejala "radiator leak & track kendor", status `Tunggu` (ket mengandung "Tim Trakindo"), progress 78
- #6: jenis `OH`, mulai 26/06/2026
- #7: jenis `Lainnya` + flag jenis tidak dikenali; meter KM 16911.6; status `Selesai` selesai 06/10/2026; part Cross Joint 2, Sling Coupling 2
- #8: unit "Genset Krisbow Dongfeng MTU", mulai 05/10/2026, meter 14219.7, status `Progress` 30
- tidak ada nilai yang dikarang (field yang tidak ada di teks = null)

Tulis tes ini sebagai skrip yang bisa dijalankan (`node tests/laporan_harian.test.js`) memakai fungsi parsing + normalisasi (Claude bisa di-mock dengan JSON yang diharapkan untuk tes deterministik).

---

## 11. Di luar cakupan tahap ini (jangan dikerjakan dulu)

- Dashboard rekap (MTTR, availability rig dari rig stop, pemakaian part per PN, tren RH) — tahap berikutnya setelah data 2 minggu terkumpul.
- Draft rangkuman otomatis dari chat mentah operator di grup WA.
- Import history 2016–2025 dari Excel rekap.

---

## Urutan kerja

1. Audit & laporan ke saya (Langkah 1) → tunggu persetujuan.
2. Migration SQL (additive) + kamus alias.
3. `normalisasi.js` + tes.
4. Parser (pemecah blok + prompt Claude) + tes fixture.
5. Alur Telegram (buffer, Proses laporan, ringkasan balasan, Daftar Open pagi).
6. Halaman konfirmasi.
7. Uji end-to-end dengan fixture 06/10/2026, lalu laporkan hasil + daftar file yang berubah.
