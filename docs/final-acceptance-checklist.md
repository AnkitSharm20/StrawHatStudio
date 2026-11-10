# Straw Hat Studio — final acceptance checklist

Use the latest Vercel Preview deployment from the security-hardening PR. Do not use the production site for destructive tests.

## Automated checks already in CI

- Production Vite build
- npm audit at moderate severity or above
- Desktop Chromium public-route smoke tests
- Pixel 7-sized Chromium viewport checks
- iPhone 13 WebKit viewport checks
- Horizontal overflow checks on Home, Explore, Community and Membership
- Membership page test verifies that the UI never claims payment success before server verification

These are browser emulations, not physical-device certification. Authenticated staging tests are skipped until their dedicated staging secrets are configured.

## Authenticated browser acceptance

The Playwright authenticated suite uses pre-created Supabase session JSON for two dedicated non-production accounts and an optional admin account. It verifies app behavior and RLS, but session injection does not exercise the Discord OAuth redirect/callback. Verify the actual Discord OAuth flow manually in the staging preview.

1. Add the current Vercel branch alias `https://straw-hat-studio-git-fix-production-d75d29-pandaankit2007-8884.vercel.app` to Supabase Auth's allowed redirect URLs. Keep the Discord OAuth callback URI set to `https://xlwtpysdknjzgjiecbhm.supabase.co/auth/v1/callback`.
2. Sign in through Discord OAuth and confirm the callback returns to the same preview origin.
3. Confirm first-login profile creation, username save and session persistence after refresh.
4. Upload a profile banner and avatar. Confirm the banner bucket remains private and signed URLs resolve only for allowed viewers.
5. As member A, publish a Community post. As member B, follow the author, submit a report, reply, and block the author. Verify posts/replies/follows/reactions are hidden in both directions, blocked replies/follows are rejected, and no new reply/follow/reaction notifications cross the block. Unblock and verify visibility returns.
6. Keep member A's Notifications page open while member B replies. Confirm the notification arrives over Realtime, mark it read, and delete it. Confirm notification deletion is limited to the owner.
7. As a normal member, open /admin and confirm access is denied.
8. As the verified admin test account, open the moderation queue, hide the reported test post, and inspect the audit log. Confirm the moderation action is recorded.
9. Confirm no test account has been granted admin access on the production project.

## Razorpay Test Mode acceptance

After adding the test secrets and webhook in docs/razorpay-test-setup.md:

1. Test all three membership tiers and both periods.
2. Test a successful captured payment and confirm only the matching account receives the correct entitlement.
3. Test an abandoned checkout and a failed payment; neither may grant an entitlement.
4. Test invalid HMAC, incorrect amount/currency/order ID, duplicate webhook delivery and webhook retry.
5. Test full refund, partial refund, refund failure and duplicate refund request. A full refund must revoke the linked entitlement; a partial refund must not.
6. Confirm the admin refund action is rejected for non-admin sessions and logged for authorized admin sessions.
7. Verify that no live-mode key or automatic recurring mandate is used.

## Physical-device acceptance

On a real Android phone and a real iPhone, check:

- No horizontal page scrolling on Home, Explore, Community, Membership, Profile and Admin.
- Mobile drawer opens/closes, focus and back navigation work, and touch targets are usable.
- Images, private banner signed URLs, upload controls, dialogs and notifications render correctly.
- Community composer, reply input, moderation/report dialog and membership controls remain usable with the on-screen keyboard.
- No clipped dialogs, overlapping sticky headers, broken safe-area spacing or unexpected zoom.

Record device model, OS/browser version, route, pass/fail and screenshot for each issue. Do not mark physical acceptance complete from emulator results alone.
