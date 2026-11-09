import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function newCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  const raw = Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
  return "SHS-" + raw.match(/.{1,4}/g)!.join("-");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: "Server configuration is incomplete. Configure Supabase function secrets." });
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Sign in first." });

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: userResult, error: authError } = await userClient.auth.getUser();
  if (authError || !userResult.user) return json(401, { error: "Your session is invalid or expired. Sign in again." });

  const user = userResult.user;
  const isAdmin = user.app_metadata?.role === "admin";
  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Send a valid JSON request." });
  }

  try {
    switch (body.action) {
      case "redeem_code": {
        const rawCode = String(body.code ?? "").trim().toUpperCase();
        if (!/^SHS(?:-[A-Z0-9]{4}){4}$/.test(rawCode)) return json(400, { error: "Enter a valid Straw Hat Studio code." });
        const codeHash = await sha256(rawCode);
        const { data, error } = await service.rpc("redeem_code_atomic", {
          p_code_hash: codeHash,
          p_user_id: user.id,
        });
        if (error) return json(400, { error: error.message.replace(/^.*ERROR:\s*/, "") });
        return json(200, data as Record<string, unknown>);
      }
      case "purchase_item": {
        const itemId = String(body.item_id ?? "");
        if (!/^[0-9a-f-]{36}$/i.test(itemId)) return json(400, { error: "Choose a valid shop item." });
        const { data, error } = await service.rpc("purchase_shop_item_atomic", {
          p_user_id: user.id,
          p_item_id: itemId,
        });
        if (error) return json(400, { error: error.message.replace(/^.*ERROR:\s*/, "") });
        return json(200, data as Record<string, unknown>);
      }
      case "generate_code": {
        if (!isAdmin) return json(403, { error: "Admin access required." });
        const rewardCoins = Number(body.reward_coins);
        const maxRedemptions = Number(body.max_redemptions ?? 1);
        if (!Number.isInteger(rewardCoins) || rewardCoins < 1 || rewardCoins > 100000) return json(400, { error: "Reward must be between 1 and 100,000 coins." });
        if (!Number.isInteger(maxRedemptions) || maxRedemptions < 1 || maxRedemptions > 10000) return json(400, { error: "Maximum redemptions must be between 1 and 10,000." });
        let expiresAt: string | null = null;
        if (body.expires_at) {
          const d = new Date(String(body.expires_at));
          if (Number.isNaN(d.getTime()) || d.getTime() <= Date.now()) return json(400, { error: "Expiry must be a future date." });
          expiresAt = d.toISOString();
        }
        const code = newCode();
        const { error } = await service.from("redeem_codes").insert({
          code_hash: await sha256(code),
          reward_coins: rewardCoins,
          max_redemptions: maxRedemptions,
          expires_at: expiresAt,
          created_by: user.id,
        });
        if (error) return json(500, { error: "Could not create the code. Try again." });
        return json(200, { success: true, code, reward_coins: rewardCoins, max_redemptions: maxRedemptions, expires_at: expiresAt, note: "Copy this code now; the raw code is not stored and cannot be shown again." });
      }
      case "grant_coins": {
        if (!isAdmin) return json(403, { error: "Admin access required." });
        const targetUserId = String(body.user_id ?? "");
        const amount = Number(body.amount);
        const reason = String(body.reason ?? "admin_grant").slice(0, 100);
        if (!/^[0-9a-f-]{36}$/i.test(targetUserId) || !Number.isInteger(amount) || amount < 1 || amount > 100000) {
          return json(400, { error: "Provide a valid user ID and a coin amount between 1 and 100,000." });
        }
        const { error } = await service.from("coin_ledger").insert({
          user_id: targetUserId, amount, reason, reference_type: "admin_grant", created_by: user.id,
        });
        if (error) return json(400, { error: "Could not grant coins. Check the user ID and try again." });
        return json(200, { success: true, amount, user_id: targetUserId });
      }
      case "create_ad_slot": {
        if (!isAdmin) return json(403, { error: "Admin access required." });
        const slotKey = String(body.slot_key ?? "").trim().toLowerCase().replace(/[^a-z0-9_-]/g, "-").slice(0, 60);
        const label = String(body.label ?? "").trim().slice(0, 100);
        const creativeUrl = String(body.creative_url ?? "").trim();
        const destinationUrl = String(body.destination_url ?? "").trim();
        const placement = body.placement && typeof body.placement === "object" ? body.placement : {};
        if (!slotKey || !label) return json(400, { error: "Slot name and label are required." });
        for (const value of [creativeUrl, destinationUrl]) {
          if (value && !/^https:\/\//i.test(value)) return json(400, { error: "Ad URLs must use HTTPS." });
        }
        const { data, error } = await service.from("ad_slots").upsert({
          slot_key: slotKey, label, creative_url: creativeUrl || null, destination_url: destinationUrl || null,
          placement, is_enabled: false, updated_at: new Date().toISOString(),
        }, { onConflict: "slot_key" }).select().single();
        if (error) return json(400, { error: "Could not save the ad slot." });
        return json(200, { success: true, ad_slot: data });
      }
      case "init_storage": {
        if (!isAdmin) return json(403, { error: "Admin access required." });
        // Idempotent setup for the two fixed buckets. Actual write access remains enforced by Storage RLS.
        const { data: bucket } = await service.storage.getBucket("studio-media");
        if (!bucket) {
          const { error } = await service.storage.createBucket("studio-media", {
            public: true,
            fileSizeLimit: 104857600,
            allowedMimeTypes: ["image/gif", "image/png", "image/jpeg", "image/webp", "video/mp4", "audio/mpeg", "audio/mp4"],
          });
          if (error && !/already exists/i.test(error.message)) return json(500, { error: "Could not initialize media storage." });
        }
        const { data: gifBucket } = await service.storage.getBucket("user-gifs");
        if (!gifBucket) {
          const { error } = await service.storage.createBucket("user-gifs", {
            public: false,
            fileSizeLimit: 20971520,
            allowedMimeTypes: ["image/gif"],
          });
          if (error && !/already exists/i.test(error.message)) return json(500, { error: "Could not initialize custom GIF storage." });
        }
        return json(200, { success: true, buckets: ["studio-media", "user-gifs"], video_max_file_size_mb: 100, gif_max_file_size_mb: 20 });
      }
      default:
        return json(400, { error: "Unknown action." });
    }
  } catch (_error) {
    return json(500, { error: "Unexpected server error. Please retry." });
  }
});