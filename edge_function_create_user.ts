// Edge Function: create-user
// Bikin user baru via Auth Admin API (cuma admin yg boleh panggil).
// Pakai service role key — di-secure di Edge Function environment.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEYS")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // 1. Verify caller adalah admin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing Authorization header");

    const sb = createClient(SB_URL, SB_SERVICE_KEY);
    const token = authHeader.replace("Bearer ", "");

    const { data: { user: caller }, error: authErr } = await sb.auth.getUser(token);
    if (authErr || !caller) throw new Error("Invalid auth token");

    const { data: callerProfile, error: profErr } = await sb.from("profiles").select("role").eq("id", caller.id).single();
    if (profErr) throw new Error("Gagal cek role caller: " + profErr.message);
    if (!callerProfile || callerProfile.role !== "admin") throw new Error("Hanya admin yang boleh tambah user");

    // 2. Parse body
    const { email, password, full_name, role, telegram_user_id } = await req.json();
    if (!email || !password) throw new Error("Email & password wajib diisi");
    if (password.length < 6) throw new Error("Password minimal 6 karakter");
    if (role && !["user", "admin"].includes(role)) throw new Error("Role harus 'user' atau 'admin'");

    // 3. Create user via Auth Admin API
    // email_confirm: true → user langsung aktif, gak perlu verifikasi email
    const { data: created, error: createErr } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: full_name || email },
    });
    if (createErr) {
      // Translate Supabase error ke pesan friendly
      if (createErr.message?.includes("already")) throw new Error(`Email "${email}" sudah terdaftar`);
      throw createErr;
    }

    // 4. Profile auto-created by trigger handle_new_user.
    // Tapi trigger default role = 'user'. Kalau admin pilih role beda atau ada full_name/telegram → update.
    if ((role && role !== "user") || telegram_user_id || full_name) {
      const updates: Record<string, unknown> = {};
      if (full_name) updates.full_name = full_name;
      if (role) updates.role = role;
      if (telegram_user_id) updates.telegram_user_id = telegram_user_id;

      const { error: updErr } = await sb.from("profiles").update(updates).eq("id", created.user.id);
      if (updErr) console.warn("Profile update warning:", updErr.message);
    }

    return new Response(JSON.stringify({
      ok: true,
      user_id: created.user.id,
      email: created.user.email,
      role: role || "user",
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({
      ok: false,
      error: String((err as Error).message || err),
    }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
