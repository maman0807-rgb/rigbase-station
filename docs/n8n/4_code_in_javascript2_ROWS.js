const laporanId = $input.first().json.id;
const entries = $('Code in JavaScript1').first().json.entries;
return entries.map(e => ({ json: { laporan_id: laporanId, ...e } }));
