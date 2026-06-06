// ============================================================
// Supabase Edge Function: send-telegram-alert
// ============================================================
// CARA DEPLOY (sekali saja):
//
// 1. Buka Supabase Dashboard → Edge Functions → "New Function"
// 2. Nama function: send-telegram-alert
// 3. Paste seluruh kode file ini
// 4. Klik Deploy
//
// 5. Masuk ke Edge Functions → Secrets → Add new secret:
//    TELEGRAM_BOT_TOKEN  = token dari @BotFather
//    TELEGRAM_CHAT_ID    = Chat ID group (contoh: -1001234567890)
//
// Cara dapat Chat ID group:
//    - Tambahkan bot ke group
//    - Kirim pesan apa saja di group
//    - Buka: https://api.telegram.org/bot<TOKEN>/getUpdates
//    - Cari "chat": { "id": -100xxxxxxx }  ← itu Chat ID-nya
// ============================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  // Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN');
    const CHAT_ID   = Deno.env.get('TELEGRAM_CHAT_ID');

    if (!BOT_TOKEN || !CHAT_ID) {
      return new Response(
        JSON.stringify({ error: 'TELEGRAM_BOT_TOKEN atau TELEGRAM_CHAT_ID belum diset di Secrets.' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const message: string = body?.message;

    if (!message || !message.trim()) {
      return new Response(
        JSON.stringify({ error: 'Field "message" kosong atau tidak ada.' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const tgRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: CHAT_ID,
        text: message,
        parse_mode: 'HTML',
        disable_web_page_preview: true,
      }),
    });

    const tgJson = await tgRes.json();

    if (!tgJson.ok) {
      throw new Error(`Telegram API error: ${tgJson.description}`);
    }

    return new Response(
      JSON.stringify({ success: true, message_id: tgJson.result?.message_id }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
