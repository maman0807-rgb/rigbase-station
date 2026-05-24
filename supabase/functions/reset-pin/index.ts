// Supabase Edge Function: reset-pin
// Reset PIN (password) user lain. HANYA admin yang boleh memanggil.
// Password = `${pin}@HHE` (skema login app).
//
// Deploy lewat Dashboard: Edge Functions → Deploy a new function → nama "reset-pin"
// → paste seluruh isi file ini → Deploy. (Tidak perlu set secret tambahan:
//  SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY sudah otomatis tersedia.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PIN_SUFFIX = "@HHE";

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
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Tidak ada token autentikasi." }, 401);

    // 1) Verifikasi pemanggil: ambil user dari JWT, lalu cek role-nya di profiles.
    const caller = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error: uErr } = await caller.auth.getUser();
    if (uErr || !user) return json({ error: "Sesi tidak valid." }, 401);

    const { data: profile, error: pErr } = await caller
      .from("profiles").select("role").eq("id", user.id).single();
    if (pErr || !profile || profile.role !== "admin") {
      return json({ error: "Hanya admin yang boleh reset PIN." }, 403);
    }

    // 2) Validasi input.
    const { userId, pin } = await req.json().catch(() => ({}));
    if (!userId || !/^\d{4}$/.test(String(pin ?? ""))) {
      return json({ error: "userId / PIN tidak valid (PIN harus 4 digit angka)." }, 400);
    }
    if (userId === user.id) {
      return json({ error: "Untuk PIN sendiri gunakan menu Ganti PIN." }, 400);
    }

    // 3) Reset password target via service_role.
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error: upErr } = await admin.auth.admin.updateUserById(userId, {
      password: `${pin}${PIN_SUFFIX}`,
    });
    if (upErr) return json({ error: upErr.message }, 400);

    return json({ ok: true });
  } catch (e) {
    return json({ error: (e as Error)?.message || "Terjadi kesalahan server." }, 500);
  }
});
