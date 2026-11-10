# Straw Hat Studio

A responsive anime community experience built with React, Vite and an optional Supabase backend.

## Run locally
```bash
npm install
npm run dev
```

Copy `.env.example` to `.env.local` and configure a Supabase project to enable backend connectivity. The public anon key is intended for browser use only; secure all tables with Row Level Security.

## Deploy on Vercel
Import this GitHub repository into Vercel. Framework: Vite. Build: `npm run build`. Output: `dist`. Add the two Supabase public environment variables only after configuring Supabase policies.

## Current implementation
- Responsive landing page, explore, community, streaming activity guide, marketplace, membership, profile, settings and admin preview.
- Local demo preferences and watchlist; these are not a secure account or wallet.
- Discord Rich Presence companion starter is documented under `companion/`.

## Important boundaries
A website cannot keep a desktop Discord Rich Presence alive after the browser closes on its own. The companion desktop app must remain running and Discord must be open. The companion is a starter and needs a registered Discord application ID before it can publish activity. It does not modify Discord custom status.
Streaming copyrighted anime requires appropriate distribution rights. No unlicensed video sources are included. Payments, rewarded ads, coin balances and admin actions must be verified server-side before production.

## Browser and responsive tests

Run the production build and Playwright smoke tests:

```bash
npm install
npx playwright install chromium webkit
npm run build
npm run test:e2e
```

CI checks desktop Chromium, Pixel 7-sized Chromium and iPhone 13-sized WebKit viewports. These are browser/device emulations, not physical-device certification. Authenticated Discord, upload, two-account moderation and payment tests require dedicated staging accounts and Razorpay test credentials; production user sessions must never be placed in CI secrets.

For authenticated staging acceptance, configure GitHub Actions secrets `E2E_SUPABASE_URL`, `E2E_SUPABASE_ANON_KEY`, `E2E_USER_A_SESSION_JSON`, `E2E_USER_B_SESSION_JSON`, and optionally `E2E_ADMIN_SESSION_JSON`. Set the repository variable `E2E_ALLOW_MUTATING_TESTS=true` only after the test project and accounts are isolated from production. Each session secret must contain the Supabase Auth session JSON for a dedicated staging account. The test harness skips these write tests unless the project reference is non-production and the opt-in variable is enabled.
