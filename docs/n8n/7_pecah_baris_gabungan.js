// Satu item per baris pekerjaan → Create a row1 (auto-map)
return $input.first().json.rows.map(r => ({ json: r }));
