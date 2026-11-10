import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const PLAN_CATALOG: Record<string, { tier: string; period: "monthly" | "yearly"; amount: number; label: string }> = {
  // Keep legacy keys for the currently deployed frontend until the production release.
  nakama_monthly: { tier: "nakama", period: "monthly", amount: 9900, label: "Nakama Monthly (legacy)" },
  nakama_yearly: { tier: "nakama", period: "yearly", amount: 79900, label: "Nakama Yearly (legacy)" },
  supernova_monthly: { tier: "supernova", period: "monthly", amount: 19900, label: "Supernova Monthly (legacy)" },
  supernova_yearly: { tier: "supernova", period: "yearly", amount: 149900, label: "Supernova Yearly (legacy)" },
  yonko_monthly: { tier: "yonko", period: "monthly", amount: 39900, label: "Yonko Monthly (legacy)" },
  yonko_yearly: { tier: "yonko", period: "yearly", amount: 299900, label: "Yonko Yearly (legacy)" },
  nakama_monthly_v2: { tier: "nakama", period: "monthly", amount: 14900, label: "Nakama Monthly" },
  nakama_yearly_v2: { tier: "nakama", period: "yearly", amount: 149900, label: "Nakama Yearly" },
  supernova_monthly_v2: { tier: "supernova", period: "monthly", amount: 29900, label: "Supernova Monthly" },
  supernova_yearly_v2: { tier: "supernova", period: "yearly", amount: 299900, label: "Supernova Yearly" },
  yonko_monthly_v2: { tier: "yonko", period: "monthly", amount: 59900, label: "Yonko Monthly" },
  yonko_yearly_v2: { tier: "yonko", period: "yearly", amount: 599900, label: "Yonko Yearly" },
  pirate_king_monthly_v2: { tier: "pirate_king", period: "monthly", amount: 99900, label: "Pirate King Monthly" },
  pirate_king_yearly_v2: { tier: "pirate_king", period: "yearly", amount: 999900, label: "Pirate King Yearly" },
};
const ALLOWED_ORIGINS = new Set(["https://straw-hat-signal.vercel.app", "http://localhost:5173", "http://127.0.0.1:5173", "http://127.0.0.1:4173"]);
function headers(origin: string | null) {
  const allowed = origin && (ALLOWED_ORIGINS.has(origin) || /^https:\/\/straw-hat-studio-[a-z0-9-]+-pandaankit2007-8884\.vercel\.app$/.test(origin));
  return {
    "Access-Control-Allow-Origin": allowed ? origin! : "https://straw-hat-signal.vercel.app",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-razorpay-signature, x-razorpay-event-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  };
}
function json(status: number, body: Record<string, unknown>, h: Record<string,string>) {
  return new Response(JSON.stringify(body), { status, headers: h });
}
function hex(bytes: ArrayBuffer) {
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function hmac(secret: string, value: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)));
}
async function sha256(value: string) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}
function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
function razorpayAuth(keyId: string, keySecret: string) {
  return "Basic " + btoa(keyId + ":" + keySecret);
}
async function razorpayRequest(path: string, method: string, keyId: string, keySecret: string, body?: unknown, extraHeaders: Record<string,string> = {}) {
  const response = await fetch("https://api.razorpay.com/v1" + path, {
    method,
    headers: { Authorization: razorpayAuth(keyId, keySecret), "Content-Type": "application/json", ...extraHeaders },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("Razorpay API error", { path, status: response.status, code: data?.error?.code });
    throw new Error(data?.error?.description || "Razorpay could not complete the request.");
  }
  return data;
}
function getClients() {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!url || !anon || !serviceKey) throw new Error("Supabase server configuration is incomplete.");
  return {
    anon: createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } }),
    service: createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } }),
  };
}
async function requireUser(req: Request) {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) throw new Error("AUTH_REQUIRED");
  const { anon, service } = getClients();
  const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) throw new Error("AUTH_INVALID");
  return { user: data.user, service };
}
function getRazorpayConfig() {
  const mode = Deno.env.get("RAZORPAY_MODE") ?? "disabled";
  const enabled = mode === "live"
    ? Deno.env.get("RAZORPAY_LIVE_ENABLED") === "true"
    : mode === "test" && Deno.env.get("RAZORPAY_ENABLED") === "true";
  const keyId = mode === "live" ? Deno.env.get("RAZORPAY_LIVE_KEY_ID") : Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = mode === "live" ? Deno.env.get("RAZORPAY_LIVE_KEY_SECRET") : Deno.env.get("RAZORPAY_KEY_SECRET");
  const webhookSecret = mode === "live" ? Deno.env.get("RAZORPAY_LIVE_WEBHOOK_SECRET") : Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  const validPrefix = mode === "live" ? keyId?.startsWith("rzp_live_") : mode === "test" && keyId?.startsWith("rzp_test_");
  if (!enabled || !validPrefix || !keySecret || !webhookSecret) {
    throw new Error(mode === "live" ? "Razorpay live checkout is not configured." : "Razorpay test checkout is not configured.");
  }
  return { keyId: keyId!, keySecret: keySecret!, webhookSecret: webhookSecret!, mode };
}
async function activate(service: ReturnType<typeof createClient>, orderId: string, paymentId: string, amount: number, currency: string) {
  const { data, error } = await service.rpc("activate_membership_from_verified_payment", {
    p_razorpay_order_id: orderId,
    p_razorpay_payment_id: paymentId,
    p_amount_paise: amount,
    p_currency: currency,
  });
  if (error) throw new Error(error.message);
  return data;
}
async function confirmDonation(service: ReturnType<typeof createClient>, orderId: string, paymentId: string, amount: number, currency: string) {
  const { data: donation, error } = await service.from("donation_orders")
    .select("id,amount_paise,currency,status,razorpay_payment_id")
    .eq("razorpay_order_id", orderId).maybeSingle();
  if (error) throw new Error("Could not find the matching donation order: " + error.message);
  if (!donation) return false;
  if (Number(donation.amount_paise) !== amount || donation.currency !== currency) {
    throw new Error("Captured donation amount or currency does not match the recorded order.");
  }
  if (donation.razorpay_payment_id && donation.razorpay_payment_id !== paymentId) {
    throw new Error("This donation order is already linked to a different payment.");
  }
  if (["paid", "partially_refunded", "refunded"].includes(donation.status) && donation.razorpay_payment_id === paymentId) return true;
  const { data: updated, error: updateError } = await service.from("donation_orders")
    .update({ status: "paid", razorpay_payment_id: paymentId, paid_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", donation.id).in("status", ["created", "failed"]).select("id");
  if (updateError) throw new Error("Could not confirm the donation: " + updateError.message);
  if (updated?.length) return true;
  const { data: current, error: currentError } = await service.from("donation_orders")
    .select("status,razorpay_payment_id").eq("id", donation.id).maybeSingle();
  if (currentError) throw new Error("Could not verify donation confirmation: " + currentError.message);
  if (current?.razorpay_payment_id === paymentId && ["paid", "partially_refunded", "refunded"].includes(current.status)) return true;
  throw new Error("Donation confirmation was not applied. The order may have changed concurrently.");
}
async function recordRefundWebhook(service: ReturnType<typeof createClient>, refund: any, status: "failed" | "processed") {
  if (!refund?.id) return;
  const refundKey = String(refund?.notes?.shs_ref_key ?? "");
  const patch = { razorpay_refund_id: String(refund.id), status, updated_at: new Date().toISOString() };

  if (refundKey) {
    const { data, error } = await service.from("membership_refunds")
      .update(patch).eq("idempotency_key", refundKey).select("id");
    if (error) throw new Error("Could not update the matching refund attempt: " + error.message);
    if (data?.length) return;
  }

  const { data: matched, error: matchError } = await service.from("membership_refunds")
    .update(patch).eq("razorpay_refund_id", String(refund.id)).select("id");
  if (matchError) throw new Error("Could not match the Razorpay refund: " + matchError.message);
  if (matched?.length) return;

  // Compatibility fallback for older refund events that predate the correlation note.
  if (!refundKey && refund.payment_id && Number.isFinite(Number(refund.amount))) {
    const { data: pending, error: pendingError } = await service.from("membership_refunds")
      .select("id").eq("payment_id", String(refund.payment_id))
      .eq("amount_paise", Number(refund.amount)).eq("status", "requested")
      .is("razorpay_refund_id", null).order("created_at", { ascending: true }).limit(1);
    if (pendingError) throw new Error("Could not find the pending refund: " + pendingError.message);
    if (pending?.[0]) {
      const { error } = await service.from("membership_refunds").update(patch).eq("id", pending[0].id);
      if (error) throw new Error("Could not update the pending refund: " + error.message);
      return;
    }
  }

  if (refundKey) throw new Error("No refund attempt matches the Razorpay correlation key.");
}
async function handleWebhook(req: Request, h: Record<string,string>) {
  let config: ReturnType<typeof getRazorpayConfig>;
  try { config = getRazorpayConfig(); } catch { return json(503, { error: "Razorpay webhook/payment configuration is incomplete." }, h); }
  const webhookSecret = config.webhookSecret;
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  const eventId = req.headers.get("x-razorpay-event-id") ?? "";
  const raw = await req.text();
  if (!signature || !/^[0-9a-f]{64}$/i.test(signature) || !eventId || eventId.length > 128) {
    return json(400, { error: "Invalid webhook headers." }, h);
  }
  const expected = await hmac(webhookSecret, raw);
  if (!safeEqual(expected, signature.toLowerCase())) return json(401, { error: "Invalid webhook signature." }, h);
  let payload: any;
  try { payload = JSON.parse(raw); } catch { return json(400, { error: "Invalid webhook body." }, h); }
  const { service } = getClients();
  const eventType = String(payload?.event ?? "unknown").slice(0, 120);
  const payloadHash = await sha256(raw);
  const { data: claimed, error: claimError } = await service.rpc("claim_razorpay_webhook_event", {
    p_event_id: eventId,
    p_event_type: eventType,
    p_payload_hash: payloadHash,
  });
  if (claimError) return json(503, { error: "Could not claim webhook event for processing." }, h);
  if (claimed !== true) {
    const { data: prior } = await service.from("razorpay_webhook_events")
      .select("status").eq("event_id", eventId).maybeSingle();
    return json(200, { received: true, duplicate: true, status: prior?.status ?? "processing" }, h);
  }
  try {
    const { keyId, keySecret } = config;
    if (eventType === "payment.captured") {
      const paymentId = String(payload?.payload?.payment?.entity?.id ?? "");
      const payment = await razorpayRequest("/payments/" + encodeURIComponent(paymentId), "GET", keyId, keySecret);
      if (payment.status !== "captured" || !payment.order_id) throw new Error("Payment is not captured or has no order.");
      const donationHandled = await confirmDonation(service, payment.order_id, payment.id, Number(payment.amount), String(payment.currency));
      if (!donationHandled) await activate(service, payment.order_id, payment.id, Number(payment.amount), String(payment.currency));
    } else if (eventType === "payment.failed") {
      const payment = payload?.payload?.payment?.entity;
      if (payment?.order_id) {
        const { data: donation, error: donationLookupError } = await service.from("donation_orders")
          .select("id").eq("razorpay_order_id", payment.order_id).maybeSingle();
        if (donationLookupError) throw new Error("Could not look up failed donation: " + donationLookupError.message);
        if (donation) {
          const { error } = await service.from("donation_orders").update({ status: "failed", updated_at: new Date().toISOString() })
            .eq("id", donation.id).eq("status", "created");
          if (error) throw new Error("Could not record failed donation: " + error.message);
        } else {
          const { error } = await service.from("membership_orders").update({ status: "failed", updated_at: new Date().toISOString() })
            .eq("razorpay_order_id", payment.order_id).eq("status", "created");
          if (error) throw new Error("Could not record failed membership payment: " + error.message);
        }
      }
    } else if (eventType === "refund.failed") {
      await recordRefundWebhook(service, payload?.payload?.refund?.entity, "failed");
    } else if (eventType === "refund.processed" || eventType === "payment.refunded") {
      const refund = payload?.payload?.refund?.entity;
      const paymentEntity = payload?.payload?.payment?.entity;
      const paymentId = String(refund?.payment_id ?? paymentEntity?.id ?? "");
      if (refund?.id) await recordRefundWebhook(service, refund, "processed");
      if (paymentId) {
        const payment = await razorpayRequest("/payments/" + encodeURIComponent(paymentId), "GET", keyId, keySecret);
        const { data: donation, error: donationLookupError } = await service.from("donation_orders")
          .select("id,amount_paise").eq("razorpay_payment_id", paymentId).maybeSingle();
        if (donationLookupError) throw new Error("Could not look up refunded donation: " + donationLookupError.message);
        if (donation) {
          const refunded = Number(payment.amount_refunded ?? 0);
          if (!Number.isInteger(refunded) || refunded < 0 || refunded > Number(donation.amount_paise)) throw new Error("Razorpay returned an invalid donation refund amount.");
          const status = refunded >= Number(donation.amount_paise) ? "refunded" : refunded > 0 ? "partially_refunded" : "paid";
          const { error } = await service.from("donation_orders").update({
            refunded_amount_paise: refunded, status, updated_at: new Date().toISOString(),
          }).eq("id", donation.id);
          if (error) throw new Error("Could not reconcile donation refund: " + error.message);
        } else {
          const { error } = await service.rpc("apply_membership_refund", {
            p_razorpay_payment_id: paymentId,
            p_refunded_amount_paise: Number(payment.amount_refunded ?? 0),
            p_payment_amount_paise: Number(payment.amount),
          });
          if (error) throw new Error("Could not reconcile membership refund: " + error.message);
        }
      }
    }
    const { error: processedError } = await service.from("razorpay_webhook_events")
      .update({ status: "processed", processed_at: new Date().toISOString(), error_message: null })
      .eq("event_id", eventId);
    if (processedError) throw new Error("Could not mark webhook event processed: " + processedError.message);
    return json(200, { received: true }, h);
  } catch (error) {
    const message = error instanceof Error ? error.message.slice(0, 500) : "Webhook processing failed.";
    await service.from("razorpay_webhook_events").update({ status: "failed", error_message: message }).eq("event_id", eventId);
    return json(500, { error: "Webhook was authenticated but could not be processed. Razorpay may retry delivery." }, h);
  }
}
Deno.serve(async (req: Request) => {
  const h = headers(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return json(405, { error: "Method not allowed." }, h);
  if (req.headers.has("x-razorpay-signature")) return handleWebhook(req, h);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "Send a valid JSON request." }, h); }
  try {
    const { user, service } = await requireUser(req);
    const action = String(body.action ?? "");
    if (action === "get_config") {
      const mode = Deno.env.get("RAZORPAY_MODE") ?? "disabled";
      let available = false;
      try { getRazorpayConfig(); available = true; } catch { available = false; }
      return json(200, {
        checkout_available: available,
        mode,
        test_checkout_available: available && mode === "test",
      }, h);
    }
    if (action === "create_donation_order") {
      const { keyId, keySecret } = getRazorpayConfig();
      const amountInr = Number(body.amount_inr);
      if (!Number.isInteger(amountInr) || amountInr < 10 || amountInr > 100000) {
        return json(400, { error: "Choose a donation amount between ₹10 and ₹1,00,000." }, h);
      }
      const amountPaise = amountInr * 100;
      const displayName = String(body.donor_name ?? user.user_metadata?.full_name ?? user.user_metadata?.name ?? "Nakama")
        .replace(/[\u0000-\u001F\u007F]/g, "").trim().slice(0, 40) || "Nakama";
      const anonymous = body.is_anonymous === true;
      const message = String(body.donor_message ?? "").replace(/[\u0000-\u001F\u007F]/g, "").trim().slice(0, 250) || null;
      const donationId = crypto.randomUUID();
      const receiptNumber = "SHD-" + crypto.randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase();
      const order = await razorpayRequest("/orders", "POST", keyId, keySecret, {
        amount: amountPaise, currency: "INR", receipt: receiptNumber,
        notes: { user_id: user.id, donation_id: donationId, product: "Straw Hat Studio Donation" },
      });
      const { error } = await service.from("donation_orders").insert({
        id: donationId, user_id: user.id, amount_paise: amountPaise, currency: "INR",
        donor_display_name: displayName, is_anonymous: anonymous, donor_message: message,
        receipt_number: receiptNumber, razorpay_order_id: order.id, status: "created",
      });
      if (error) {
        console.error("Donation order persistence failed", { code: error.code, order_id: order.id });
        return json(503, { error: "The donation order could not be safely recorded. No checkout was opened." }, h);
      }
      return json(200, {
        key_id: keyId, order_id: order.id, amount: amountPaise, currency: "INR",
        name: "Straw Hat Studio", description: "Support the Straw Hat Studio community",
        receipt_number: receiptNumber, donation_id: donationId,
      }, h);
    }
    if (action === "verify_donation_payment") {
      const { keyId, keySecret } = getRazorpayConfig();
      const orderId = String(body.razorpay_order_id ?? "");
      const paymentId = String(body.razorpay_payment_id ?? "");
      const signature = String(body.razorpay_signature ?? "");
      if (!/^order_[A-Za-z0-9]+$/.test(orderId) || !/^pay_[A-Za-z0-9]+$/.test(paymentId) || !/^[0-9a-f]{64}$/i.test(signature)) {
        return json(400, { error: "Invalid donation verification details." }, h);
      }
      const { data: donation, error } = await service.from("donation_orders").select("id,user_id,receipt_number,amount_paise,currency,status")
        .eq("razorpay_order_id", orderId).eq("user_id", user.id).maybeSingle();
      if (error || !donation) return json(404, { error: "Donation order not found for this account." }, h);
      const expected = await hmac(keySecret, orderId + "|" + paymentId);
      if (!safeEqual(expected, signature.toLowerCase())) return json(400, { error: "Donation payment signature verification failed." }, h);
      const payment = await razorpayRequest("/payments/" + encodeURIComponent(paymentId), "GET", keyId, keySecret);
      if (payment.order_id !== orderId || Number(payment.amount) !== donation.amount_paise || payment.currency !== donation.currency) {
        return json(400, { error: "Payment details do not match this donation order." }, h);
      }
      if (payment.status !== "captured") {
        return json(202, { success: false, pending: true, message: "Payment is not captured yet. Your donation receipt will appear after Razorpay confirms capture." }, h);
      }
      await confirmDonation(service, orderId, paymentId, Number(payment.amount), String(payment.currency));
      return json(200, { success: true, donation: { id: donation.id, receipt_number: donation.receipt_number, status: "paid" } }, h);
    }
    if (action === "create_order") {
      const { keyId, keySecret } = getRazorpayConfig();
      const planKey = String(body.plan_key ?? "");
      const plan = PLAN_CATALOG[planKey];
      if (!plan) return json(400, { error: "Choose a valid membership plan." }, h);
      const { data: activeMemberships, error: activeError } = await service.from("membership_entitlements")
        .select("tier_key,ends_at").eq("user_id", user.id).eq("status", "active")
        .gt("ends_at", new Date().toISOString()).order("ends_at", { ascending: false }).limit(1);
      if (activeError) return json(503, { error: "Could not verify your current membership." }, h);
      if (activeMemberships?.[0] && activeMemberships[0].tier_key !== plan.tier) {
        return json(409, { error: "Your " + activeMemberships[0].tier_key + " membership is still active until " + activeMemberships[0].ends_at + ". Renew that tier or wait until it expires before changing tiers." }, h);
      }
      const receipt = "shs_" + crypto.randomUUID().replaceAll("-", "").slice(0, 24);
      const order = await razorpayRequest("/orders", "POST", keyId, keySecret, {
        amount: plan.amount, currency: "INR", receipt,
        notes: { user_id: user.id, plan_key: planKey, product: "Straw Hat Studio Membership" },
      });
      const { error } = await service.from("membership_orders").insert({
        user_id: user.id, tier_key: plan.tier, plan_key: planKey, billing_period: plan.period,
        amount_paise: plan.amount, currency: "INR", razorpay_order_id: order.id, status: "created",
      });
      if (error) {
        console.error("Membership order persistence failed", { code: error.code, order_id: order.id });
        return json(503, { error: "The payment order could not be safely recorded. No checkout was opened." }, h);
      }
      return json(200, {
        key_id: keyId, order_id: order.id, amount: plan.amount, currency: "INR",
        name: "Straw Hat Studio", description: plan.label,
      }, h);
    }
    if (action === "verify_payment") {
      const { keyId, keySecret } = getRazorpayConfig();
      const orderId = String(body.razorpay_order_id ?? "");
      const paymentId = String(body.razorpay_payment_id ?? "");
      const signature = String(body.razorpay_signature ?? "");
      if (!/^order_[A-Za-z0-9]+$/.test(orderId) || !/^pay_[A-Za-z0-9]+$/.test(paymentId) || !/^[0-9a-f]{64}$/i.test(signature)) {
        return json(400, { error: "Invalid payment verification details." }, h);
      }
      const { data: order, error } = await service.from("membership_orders").select("*")
        .eq("razorpay_order_id", orderId).eq("user_id", user.id).maybeSingle();
      if (error || !order) return json(404, { error: "Membership order not found for this account." }, h);
      const expected = await hmac(keySecret, orderId + "|" + paymentId);
      if (!safeEqual(expected, signature.toLowerCase())) return json(400, { error: "Payment signature verification failed." }, h);
      const payment = await razorpayRequest("/payments/" + encodeURIComponent(paymentId), "GET", keyId, keySecret);
      if (payment.order_id !== orderId || Number(payment.amount) !== order.amount_paise || payment.currency !== order.currency) {
        return json(400, { error: "Payment details do not match this membership order." }, h);
      }
      if (payment.status !== "captured") {
        return json(202, { success: false, pending: true, message: "Payment is not captured yet. Membership will activate after Razorpay confirms capture." }, h);
      }
      const activated = await activate(service, orderId, paymentId, Number(payment.amount), String(payment.currency));
      return json(200, { success: true, membership: activated }, h);
    }
    if (action === "refund_payment") {
      if (user.app_metadata?.role !== "admin") return json(403, { error: "Admin access required." }, h);
      const { keyId, keySecret } = getRazorpayConfig();
      const paymentId = String(body.payment_id ?? "");
      const amount = body.amount_paise == null ? null : Number(body.amount_paise);
      if (!/^pay_[A-Za-z0-9]+$/.test(paymentId)) {
        return json(400, { error: "Provide a valid Razorpay payment ID." }, h);
      }
      const { data: order, error } = await service.from("membership_orders").select("*").eq("razorpay_payment_id", paymentId).maybeSingle();
      if (error || !order) return json(404, { error: "Membership payment not found." }, h);
      const payment = await razorpayRequest("/payments/" + encodeURIComponent(paymentId), "GET", keyId, keySecret);
      const remainingBeforeRefund = Number(payment.amount) - Number(payment.amount_refunded ?? 0);
      const refundAmount = amount ?? remainingBeforeRefund;
      if (payment.status !== "captured" || !Number.isInteger(refundAmount) || refundAmount < 1 || refundAmount > remainingBeforeRefund) {
        return json(400, { error: "Payment is not refundable or the refund amount is invalid." }, h);
      }

      // Stable operation key for this exact order + remaining balance. A confirmed
      // failed attempt advances to a new suffix; transient retries reuse the same key.
      const baseRefundKey = "shs_" + (await sha256(String(order.id) + "|" + paymentId + "|" + String(refundAmount))).slice(0, 28);
      const { data: attempts, error: attemptsError } = await service.from("membership_refunds")
        .select("id,razorpay_refund_id,idempotency_key,amount_paise,payment_id,status")
        .eq("order_id", order.id).eq("payment_id", paymentId).eq("amount_paise", refundAmount)
        .gte("idempotency_key", baseRefundKey)
        .lt("idempotency_key", baseRefundKey + "\uffff")
        .order("created_at", { ascending: true });
      if (attemptsError) return json(503, { error: "Could not inspect prior refund attempts." }, h);
      const prior = attempts?.[attempts.length - 1] ?? null;

      if (prior?.status === "processed" || (prior?.status === "requested" && prior.razorpay_refund_id)) {
        return json(200, { success: true, refund: { id: prior.razorpay_refund_id, status: prior.status, amount: prior.amount_paise }, duplicate: true }, h);
      }

      const idempotencyKey = prior?.status === "failed"
        ? baseRefundKey + "_r" + String((attempts?.length ?? 1) + 1)
        : prior?.idempotency_key ?? baseRefundKey;

      if (!prior || prior.status === "failed") {
        const { error: insertError } = await service.from("membership_refunds").insert({
          user_id: order.user_id, order_id: order.id, payment_id: paymentId,
          idempotency_key: idempotencyKey, amount_paise: refundAmount, status: "requested",
        });
        if (insertError) {
          const { data: existing } = await service.from("membership_refunds").select("razorpay_refund_id,status,amount_paise").eq("idempotency_key", idempotencyKey).maybeSingle();
          if (existing?.razorpay_refund_id) return json(200, { success: true, refund: { id: existing.razorpay_refund_id, status: existing.status, amount: existing.amount_paise }, duplicate: true }, h);
          return json(409, { error: "A refund attempt with this operation key is already being created. Refresh the order before retrying." }, h);
        }
      }

      const refund = await razorpayRequest("/payments/" + encodeURIComponent(paymentId) + "/refund", "POST", keyId, keySecret,
        { amount: refundAmount, notes: { reason: String(body.reason ?? "Membership refund").slice(0, 200), shs_ref_key: idempotencyKey } },
        { "X-Refund-Idempotency": idempotencyKey });
      await service.from("membership_refunds").update({
        razorpay_refund_id: refund.id, status: refund.status === "processed" ? "processed" : "requested", updated_at: new Date().toISOString(),
      }).eq("idempotency_key", idempotencyKey);
      const { error: auditError } = await service.from("admin_audit_logs").insert({
        actor_id: user.id, actor_role: "admin", action: "issue_membership_refund",
        target_table: "membership_orders", target_id: String(order.id),
        after_data: { payment_id: paymentId, refund_id: refund.id, amount_paise: refundAmount, idempotency_key: idempotencyKey, status: refund.status },
      });
      if (auditError) console.error("Membership refund audit logging failed", { order_id: order.id, message: auditError.message });
      return json(200, { success: true, refund: { id: refund.id, status: refund.status, amount: refund.amount } }, h);
    }
    return json(400, { error: "Unknown membership payment action." }, h);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected payment error.";
    const status = message === "AUTH_REQUIRED" ? 401 : message === "AUTH_INVALID" ? 401 : /not configured/.test(message) ? 503 : 500;
    return json(status, { error: status === 500 ? "The payment service encountered an error. Please retry." : message }, h);
  }
});
