# Straw Hat Studio

Responsive anime-community web app built with React, Vite, Supabase and Vercel.

## Current implemented features
- Responsive premium desktop, tablet and mobile UI with dark/light themes.
- Landing page, anime discovery and locally cached guest watchlist.
- Discord OAuth sign-in through Supabase Auth.
- Signed-in user preference sync for theme and watchlist through the existing `user_settings` table.
- Marketplace reads active inventory from Supabase `shop_items`.
- Purchases call the JWT-protected `rewards` Edge Function; the browser never writes coin balances or entitlements directly.
- Community, profile, settings, membership and Streaming Luffy experience previews.
- Vercel SPA routing and Supabase client configured with a publishable key.

## Local development
```bash
npm install
npm run dev
```

Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in `.env.local`. Never expose a Supabase service-role/secret key in a browser bundle.

## Supabase setup
Project: `xlwtpysdknjzgjiecbhm` (Mumbai region).
The frontend uses existing RLS-protected `profiles`, `user_settings`, `shop_items`, and `user_entitlements` tables. Purchases go through the existing `rewards` Edge Function. Configure Discord as an enabled Supabase Auth provider and add the exact site/preview redirect URLs in Supabase Auth URL Configuration before testing OAuth.

## Deployment
The `studio-development` branch is for preview work. Do not push development commits to `main` until the production project is separated and the new release is explicitly approved. Vercel previews may be protected by team SSO.

## Still in development
- Persistent posts, replies, reactions, reports and notifications (the current community feed is sample content).
- Editable profile fields, privacy controls and avatar/banner upload.
- Full admin console and audited moderation tools.
- Discord Rich Presence companion app. The browser cannot keep desktop Discord activity alive after the tab closes.
- Licensed anime playback, watch parties, paid memberships and ad-provider integrations. No unauthorized streaming sources or payment flows are included.

## Safety and integrity
All wallet, rewards and purchase mutations must be server-side and authenticated. Admin authorization must use trusted server-side app metadata, never user-editable profile fields. Anime distribution requires appropriate rights.
