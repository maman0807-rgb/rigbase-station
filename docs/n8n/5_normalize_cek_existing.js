const rows = $input.all().map(i => i.json);
const found = rows.length > 0 && !!rows[0].id;
const base = $('Code in JavaScript1').first().json;
return [{ json: {
  found,
  id: found ? rows[0].id : null,
  status: found ? rows[0].status : null,
  tanggal: base.tanggal,
  chat_id: base.chat_id,
} }];
