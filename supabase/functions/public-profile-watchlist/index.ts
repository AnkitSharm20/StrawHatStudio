import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const allowedOrigins = new Set([
  "https://straw-hat-signal.vercel.app",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "http://127.0.0.1:4173",
]);
function cors(origin: string | null) {
  const allowed = origin && (allowedOrigins.has(origin) || /^https:\/\/straw-hat-studio-[a-z0-9-]+-pandaankit2007-8884\.vercel\.app$/.test(origin));
  return {
    "Access-Control-Allow-Origin": allowed ? origin! : "https://straw-hat-signal.vercel.app",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  };
}
function respond(status: number, body: Record<string, unknown>, headers: Record<string,string>) {
  return new Response(JSON.stringify(body), { status, headers });
}
Deno.serve(async (req: Request) => {
  const headers = cors(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return respond(405, { error: "Method not allowed" }, headers);
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!url || !key) return respond(503, { error: "Profile service is temporarily unavailable." }, headers);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return respond(400, { error: "Invalid request." }, headers); }
  const username = String(body.username ?? "").trim().toLowerCase();
  if (!/^[a-z0-9_]{3,24}$/.test(username)) return respond(400, { error: "Invalid username." }, headers);
  const service = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await service
    .from("profiles").select("id,is_public,show_watchlist").eq("username", username).maybeSingle();
  if (profileError) return respond(503, { error: "Could not load this public profile." }, headers);
  if (!profile || profile.is_public !== true || profile.show_watchlist !== true) return respond(200, { watchlist: [] }, headers);
  const { data: settings, error: settingsError } = await service
    .from("user_settings").select("preferences").eq("user_id", profile.id).maybeSingle();
  if (settingsError) return respond(503, { error: "Could not load this public watchlist." }, headers);
  const raw = settings?.preferences?.watchlist;
  const watchlist = Array.isArray(raw)
    ? raw.filter((item: unknown): item is string => typeof item === "string").map((item: string) => item.trim()).filter((item: string) => item.length > 0 && item.length <= 120).slice(0, 100)
    : [];
  return respond(200, { watchlist }, headers);
});
