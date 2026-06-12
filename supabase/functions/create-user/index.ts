// Supabase Edge Function: create-user
// Buat user baru (auth + profile). HANYA admin yang boleh memanggil.
// User langsung aktif (email auto-confirmed).
//
// Deploy lewat Dashboard: Edge Functions → create-user → paste seluruh isi file ini
// → Deploy (timpa yang lama). SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY otomatis tersedia.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ROLES = ["operator", "mekanik", "sr_mekanik", "gudang", "spv", "sr_spv", "astmen", "admin", "user", "tamu"];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ ok: false, error: "Tidak ada token autentikasi." }, 401);
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1) Verifikasi pemanggil = admin
    const { data: { user }, error: uErr } = await admin.auth.getUser(token);
    if (uErr || !user) return json({ ok: false, error: "Sesi tidak valid." }, 401);
    const { data: prof, error: pErr } = await admin.from("profiles").select("role").eq("id", user.id).single();
    if (pErr || !prof || prof.role !== "admin") {
      return json({ ok: false, error: "Hanya admin yang boleh membuat user." }, 403);
    }

    // 2) Validasi input
    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const full_name = body.full_name ? String(body.full_name).trim() : null;
    const role = String(body.role ?? "user");
    const telegram_user_id = body.telegram_user_id ? String(body.telegram_user_id).trim() : null;

    if (!email || !email.includes("@")) return json({ ok: false, error: "Email tidak valid." }, 400);
    if (password.length < 6) return json({ ok: false, error: "Password minimal 6 karakter." }, 400);
    if (!ALLOWED_ROLES.includes(role)) return json({ ok: false, error: "Role tidak valid." }, 400);

    // 3) Buat auth user (auto-confirm)
    const { data: created, error: cErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { full_name },
    });
    if (cErr || !created?.user) return json({ ok: false, error: cErr?.message || "Gagal membuat auth user." }, 400);
    const newId = created.user.id;

    // 4) Set profile (trigger handle_new_user mungkin sudah bikin baris → upsert)
    const { error: upErr } = await admin.from("profiles").upsert({
      id: newId, email, full_name, role, telegram_user_id,
    }, { onConflict: "id" });
    if (upErr) {
      // rollback auth user kalau profile gagal, biar tidak ada user yatim
      await admin.auth.admin.deleteUser(newId).catch(() => {});
      return json({ ok: false, error: "Profil gagal disimpan: " + upErr.message }, 400);
    }

    return json({ ok: true, user_id: newId });
  } catch (e) {
    return json({ ok: false, error: (e as Error)?.message || "Terjadi kesalahan server." }, 500);
  }
});
