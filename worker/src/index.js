const MODEL = "gemini-2.5-flash";
const MAX_PROMPT_LENGTH = 8000;
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 20;
const buckets = new Map();

function allowed(request) {
  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  const now = Date.now();
  const previous = buckets.get(ip);
  if (!previous || now - previous.startedAt >= RATE_WINDOW_MS) {
    if (buckets.size > 10_000) buckets.clear();
    buckets.set(ip, { startedAt: now, count: 1 });
    return true;
  }
  if (previous.count >= RATE_LIMIT) return false;
  previous.count += 1;
  return true;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "content-type",
      "access-control-allow-methods": "POST, OPTIONS",
      "cache-control": "no-store",
    },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return json({ ok: true });
    if (request.method !== "POST") return json({ error: "Metodo non consentito" }, 405);
    if (!allowed(request)) return json({ error: "Troppe richieste, riprova tra un minuto" }, 429);

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: "JSON non valido" }, 400);
    }

    const prompt = typeof body?.prompt === "string" ? body.prompt.trim() : "";
    if (!prompt) return json({ error: "Il campo prompt è obbligatorio" }, 400);
    if (prompt.length > MAX_PROMPT_LENGTH) {
      return json({ error: `Prompt troppo lungo (massimo ${MAX_PROMPT_LENGTH} caratteri)` }, 413);
    }
    if (!env.GEMINI_API_KEY) return json({ error: "Il Worker non è configurato" }, 500);

    const upstream = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${encodeURIComponent(env.GEMINI_API_KEY)}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: "Sei un assistente per il gioco di ruolo Cyberpunk RED. Conosci il manuale base. Rispondi in modo conciso, accurato e con atmosfera cyberpunk.\n\n" + prompt,
            }],
          }],
        }),
      },
    );

    const responseBody = await upstream.json().catch(() => ({}));
    if (!upstream.ok) {
      return json({ error: "Gemini ha rifiutato la richiesta", details: responseBody?.error?.message ?? "errore upstream" }, upstream.status >= 400 && upstream.status < 500 ? upstream.status : 502);
    }

    const text = responseBody?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string" || !text.trim()) return json({ error: "Risposta Gemini vuota" }, 502);
    return json({ text: text.trim() });
  },
};
