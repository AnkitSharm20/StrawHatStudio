# Razorpay test-mode setup

The membership payment implementation is deployed to Supabase, but checkout is deliberately disabled until test credentials are added. Live payments are not supported by this release.

## Supabase Edge Function secrets

In Supabase Dashboard → Project Settings → Edge Functions → Secrets, add:

- `RAZORPAY_MODE=test`
- `RAZORPAY_ENABLED=true`
- `RAZORPAY_KEY_ID=rzp_test_...`
- `RAZORPAY_KEY_SECRET=...`
- `RAZORPAY_WEBHOOK_SECRET=...`

Use only Razorpay **Test Mode** credentials. Do not put secrets in Vite variables, GitHub source, browser storage, or chat. The function already uses the Supabase project URL and server-side service key supplied by the Edge Functions runtime.

## Razorpay webhook

Register this URL in the Razorpay Test Mode dashboard:

`https://xlwtpysdknjzgjiecbhm.supabase.co/functions/v1/membership-payments`

Use the same webhook secret configured above. Subscribe to:

- `payment.captured`
- `payment.failed`
- `refund.processed`
- `refund.failed`
- `payment.refunded`

The function validates the HMAC against the raw request body, atomically claims each Razorpay event ID, fetches the payment from Razorpay and checks order, amount and currency before activating a membership. Refund requests carry a compact `shs_ref_key` in Razorpay refund notes so `refund.processed` and `refund.failed` events update the exact idempotent attempt, even if the webhook arrives before the API response is saved. Refund totals are reconciled from Razorpay's payment API; full refunds revoke the linked entitlement, while partial refunds keep it active. Admin-initiated refunds are restricted to a trusted `app_metadata.role=admin` session and are written to the admin audit log.

## Current product rules

- Nakama: ₹99 monthly pass / ₹799 yearly pass
- Supernova: ₹199 monthly pass / ₹1,499 yearly pass
- Yonko: ₹399 monthly pass / ₹2,999 yearly pass
- Monthly and yearly are one-time purchases with manual renewal. No recurring mandate or automatic renewal is created.
- The amount is fixed on the server. The browser cannot choose the amount.
- A pass starts only after captured-payment verification. A client callback alone never grants an entitlement.
- The refund control submits the remaining refundable amount. A full refund marks the associated entitlement refunded.

## Test checklist before considering live mode

1. Test each tier and billing period with Razorpay test cards/UPI.
2. Confirm failed and abandoned checkouts never create entitlements.
3. Send an invalid webhook signature and confirm HTTP 401.
4. Replay the same webhook event ID, including two concurrent deliveries, and confirm atomic idempotent handling and stale-processing recovery.
5. Test amount, currency and order-ID mismatch rejection.
6. Test full, partial, failed and duplicate refunds. Confirm the webhook updates the exact refund attempt and a full refund revokes the entitlement only after Razorpay confirms the cumulative refund amount.
7. Confirm the admin audit entry exists for every admin-initiated refund.
8. Publish final prices, benefits, support contact, refund/cancellation terms and applicable tax disclosures.
9. Keep live credentials and `RAZORPAY_MODE=live` disabled until a separate explicit launch approval and a successful end-to-end test review.

Rollback-only database logic tests have passed for duplicate webhook claims, stale-lease recovery, cross-tier membership rejection, same-tier renewal, and partial/full refund entitlement transitions. These tests do not replace a real Razorpay Test Mode transaction and webhook delivery.

The current Edge Function intentionally refuses checkout unless `RAZORPAY_MODE=test`, the key ID starts with `rzp_test_`, and `RAZORPAY_ENABLED=true`. It does not accept live credentials.
