# Straw Hat Studio — Nakama Pass payment design (review draft)

**Status: DESIGN ONLY — live payments disabled**

## Prices

| Plan | Customer price | Billing |
|---|---:|---|
| Monthly Nakama | INR 99 | Every month |
| Yearly Nakama | INR 799 | Every year |

Razorpay API amounts are represented in paise: monthly `9900`, yearly `79900`.

## Proposed benefits (not yet active)

1. Nakama supporter badge on the member profile.
2. Exclusive profile cosmetics: frames, themes and banner treatments.
3. Additional Streaming Luffy profile display presets and member styling.
4. Planned private supporter community area / Discord role.
5. Selected member-only cosmetic drops or marketplace offers.
6. Supporter recognition and early access to selected community features.
7. Support the operating costs, moderation and continued development of Straw Hat Studio.

Do not advertise any item as available until the corresponding feature and entitlement enforcement are shipped. The Windows Rich Presence companion is a separate optional local app; membership must not imply it is hosted or runs automatically.

## Intended payment lifecycle

1. User signs in through Discord OAuth and opens Membership.
2. Browser requests a checkout session from an authenticated server endpoint. The browser sends only a plan key (`nakama_monthly` or `nakama_yearly`), never an amount or user ID to trust.
3. Server loads the immutable plan price from server-side configuration and creates a Razorpay order/subscription using secret credentials stored only in Vercel environment variables or a trusted server secret store.
4. Server creates a pending local payment record with the authenticated Supabase user ID, Razorpay order/subscription ID, expected amount/currency, plan key and an idempotency key.
5. Browser opens Razorpay Checkout using the returned public key ID and order/subscription ID.
6. Browser success callback is informational only. It must not grant membership.
7. Server verifies the checkout signature using Razorpay's documented HMAC procedure and the server secret. It also validates the fetched payment/order/subscription state, amount, currency, plan mapping and user association.
8. Razorpay webhook endpoint verifies the HMAC against the exact raw request body with the webhook secret, checks event ID for idempotency, and handles captured/paid, failed, cancelled, paused, charged/renewed, refunded and disputed events as applicable.
9. Only a verified server-side event can update the subscription record and grant/revoke entitlements. Store webhook event IDs and processing outcomes to prevent duplicate grants.
10. Membership UI reads the server-maintained entitlement/subscription state. Users can view billing state and follow a secure cancellation flow.

## Proposed server-side data model

- `membership_plans`: stable plan key, label, amount in paise, currency, interval, active flag, benefits version. Public reads only for active display plans; writes restricted to server/admin.
- `membership_subscriptions`: user ID, plan key, Razorpay customer/subscription IDs, status, period start/end, cancel-at-period-end, timestamps. Users may read only their own rows; no browser writes.
- `membership_payments`: user ID, plan key, Razorpay order/payment IDs, amount, currency, state, verified timestamp, metadata. Users may read only their own rows; writes server-only.
- `razorpay_webhook_events`: unique Razorpay event ID, event type, payload hash, processed timestamp, outcome. No client access.

All tables in exposed schemas must have RLS. Client roles receive no INSERT/UPDATE/DELETE on payment/subscription state. Use server-only service credentials in Edge Functions or server functions, never in the browser.

## Environment secrets required before implementation/testing

- `RAZORPAY_KEY_ID` — public checkout key ID, can be returned to authenticated browser only after server creates a pending order.
- `RAZORPAY_KEY_SECRET` — server-only, never exposed to client bundles or logs.
- `RAZORPAY_WEBHOOK_SECRET` — server-only, distinct webhook signing secret.
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` / publishable key for client.
- `SUPABASE_SERVICE_ROLE_KEY` — server-only only if the chosen backend needs it; never in Vite `VITE_*` variables.

## Review and activation gates

- Confirm whether yearly membership is a one-time 12-month purchase or an automatically renewing annual subscription. Current UI copy proposes one annual payment for 12 months, not auto-renewal.
- Confirm exact benefit list and which perks are implemented on launch.
- Confirm refund/cancellation policy, renewal reminders, taxes/invoice details and customer support contact.
- Configure Razorpay plans/product records and webhook endpoint in the Razorpay Dashboard.
- Add production secrets to Vercel/Supabase server-side secret storage.
- Implement server endpoints and database tables with RLS.
- Test in Razorpay Test Mode: success, failure, duplicate webhook, invalid signature, amount mismatch, delayed webhook, refund, cancellation and renewal.
- Run Supabase security advisors and end-to-end tests.
- Only after owner approval and all checks, enable the live checkout feature flag.

## Current connector limitation

The connected Razorpay toolset available in this workspace exposes read-only fetch operations for orders, payments, refunds, settlements, QR codes and payment links. It does not expose create-plan, create-subscription, create-order, webhook configuration or payment capture operations. Therefore this draft does not create Razorpay objects or activate any payment capability. Implement the write path through secured server-side Razorpay API calls after credentials and test-mode setup are available.
