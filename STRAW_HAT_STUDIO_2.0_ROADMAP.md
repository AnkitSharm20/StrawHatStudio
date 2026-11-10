# Straw Hat Studio 2.0 — Delivery Roadmap

## Product direction

- Visual identity: deep ocean, pirate orange, treasure gold, pearl white, and restrained wanted-red accents.
- Experience: premium anime community, pirate-adventure atmosphere, balanced motion, mobile-first layouts.
- Typography: Cinzel for editorial headings, Bebas Neue for display moments, Inter for interface text, and Lora for selected emphasis.
- Preserve the existing React + Vite + Supabase + Discord OAuth architecture unless a measured technical reason requires a change.
- Keep the production domain unchanged until the redesign passes preview QA and the owner approves promotion.

## Non-negotiable guardrails

1. Do not remove existing routes or silently change established product behavior.
2. Do not expose service-role keys, payment secrets, or privileged operations in browser code.
3. Membership checkout remains disabled until Razorpay order creation, signature verification, webhook processing, entitlement grants, refunds, and idempotency pass test-mode verification.
4. No production deployment or database migration without a clear need and a verified rollback path.
5. Avoid fake progress, dead buttons, placeholder links, and success messages before the server confirms success.
6. Respect reduced-motion preferences, keyboard access, responsive layouts, and image loading performance.
7. Use original pirate-inspired design assets; do not reproduce copyrighted anime scenes or logos as site branding.

## Phase tracking

### Phase 1 — Foundation and audit
- [x] Create isolated branch: `redesign/straw-hat-studio-2.0`.
- [x] Establish design tokens and a final-loaded design layer.
- [x] Apply consistent colours, typography, surfaces, controls, focus states, and reduced-motion support.
- [ ] Finish route-by-route functional inventory and record existing behavior.
- [ ] Review Supabase policies, storage permissions, Edge Functions, and auth redirects before touching backend behavior.
- [ ] Record baseline accessibility, performance, and browser-console results.

### Phase 2 — Homepage transformation
- [x] Keep the video hero free of text overlays.
- [x] Keep hero media admin-managed through the existing media-assets workflow.
- [x] Replace the public-facing empty upload message with a cinematic artwork fallback.
- [x] Add “THE SEA IS CALLING” campaign copy below the video hero.
- [x] Add direct Explore and Community actions.
- [x] Add loading skeletons for live anime artwork.
- [ ] Complete desktop, tablet, and mobile visual QA with an authenticated preview session.
- [ ] Verify admin hero upload, publish/unpublish, and fallback behavior end-to-end.

### Phase 3 — Global pages and navigation
- [x] Prioritise Home, Explore, Community, and Membership in the desktop top navigation.
- [x] Add shared visual refinements to page headings, anime cards, community surfaces, and mobile layouts.
- [x] Add a retry state when the AniList catalogue is unavailable.
- [x] Add a short in-memory cache for recent Explore catalogue pages.
- [ ] Finish Explore search, genre, sorting, pagination, and empty/error-state QA.
- [ ] Redesign Community feed, composer, replies, reporting, moderation, and empty states.
- [ ] Refine profile, public profile, settings, notifications, and account menus.
- [ ] Verify Discord OAuth and every redirect/callback route.

### Phase 4 — Membership and marketplace
- [ ] Audit pricing copy, billing terms, membership state, and entitlements.
- [ ] Keep checkout disabled until all payment checks pass.
- [ ] Test Razorpay in test mode: order creation, amount/currency checks, signature verification, webhook signatures, duplicate events, failures, refunds, and entitlement rollback.
- [ ] Verify marketplace purchases, inventory, coin balances, and transaction history server-side.

### Phase 5 — New community features
- [ ] Plan achievements, XP, crew groups, events, challenges, rewards, and profile customisation.
- [ ] Design schema and RLS before implementation.
- [ ] Add server-side validation, abuse limits, and audit trails.

### Phase 6 — Admin and CMS
- [ ] Improve hero-video and image-slot management.
- [ ] Add safe media validation, preview, publish state, and clear upload errors.
- [ ] Review moderation queue, role checks, and admin audit logs.

### Phase 7 — Visual polish and performance
- [ ] Refine transitions, hover states, skeletons, loading screens, and motion.
- [ ] Optimise responsive imagery, fonts, video delivery, and route loading.
- [ ] Test reduced motion, keyboard navigation, contrast, and touch targets.

### Phase 8 — Security, QA, and launch
- [ ] Run dependency and secret scans; resolve confirmed vulnerabilities without blind major upgrades.
- [ ] Test critical user journeys in preview: guest, Discord sign-in, profile, watchlist, community, notifications, marketplace, admin, and payment test mode.
- [ ] Confirm no console errors, broken routes, duplicate writes, or unintended data changes.
- [ ] Obtain owner approval before merging or promoting to production.

## Current implementation notes

- Latest implementation branch: `redesign/straw-hat-studio-2.0`.
- The 2.0 CSS is isolated in `src/studio-2.0.css` and imported after the existing stylesheet layers.
- Homepage, Explore error handling/cache, shared page styling, and document metadata have received first-pass changes.
- Vercel preview builds have completed successfully. Preview access is protected by Vercel Authentication, so visual QA is not considered complete until the owner or an authorised browser session can inspect the preview.
- Build output reports two moderate npm audit findings. Identify their exact dependency paths before choosing remediation; do not run `npm audit fix --force` blindly.
- Production remains unchanged.
