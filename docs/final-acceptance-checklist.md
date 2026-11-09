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

Use two dedicated non-production Discord test accounts and one separate admin test account.

1. Sign in through Discord OAuth and confirm the callback returns to the same preview origin.
2. Confirm first-login profile creation, username save and session persistence after refresh.
3. Upload a profile banner and avatar. Confirm the banner bucket remains private and signed URLs resolve only for allowed viewers.
4. As member A, publish a Community post. As member B, reply, follow, report and block. Confirm each action is reflected correctly.
5. As member A, confirm the reply notification appears and unread state updates. Confirm notification deletion is limited to the owner.
6. As a normal member, open /admin and confirm access is denied.
7. As the verified admin test account, open the moderation queue and audit log. Perform one harmless moderation action and confirm an audit entry is recorded.
8. Confirm no test account has been granted admin access on the production project.

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
