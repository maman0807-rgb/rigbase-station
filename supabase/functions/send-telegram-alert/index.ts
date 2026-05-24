// Edge Function: send-telegram-alert
// Kirim pesan ke Telegram chat (default: group Rigbase Alert)
// POST body: { message: string, chat_id?: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const DEFAULT_CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { message, chat_id } = await req.json();
    if (!message) throw new Error("Missing 'message' field");

    const targetChatId = chat_id || DEFAULT_CHAT_ID;
    const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: targetChatId,
        text: message,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
    const data = await resp.json();
    if (!data.ok) throw new Error(`Telegram API: ${data.description || "unknown error"}`);

    return new Response(JSON.stringify({ ok: true, message_id: data.result.message_id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err.message || err) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});