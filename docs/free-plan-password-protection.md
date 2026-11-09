# Authentication and password protection — Free plan

## Current verified state

- The Supabase organization is on the Free plan. Supabase documents native Have I Been Pwned leaked-password rejection as Pro and above.
- The live Auth database currently has one user and zero password credentials; the only recorded identity provider is Discord.
- Straw Hat Studio's app sign-in flow uses Discord OAuth PKCE. It does not expose email/password sign-up or password sign-in controls.

## Safe operating posture on Free

1. Keep Discord OAuth as the only sign-in method exposed by this application.
2. Because this app does not use email/password or magic-link authentication, consider disabling the Email provider in Supabase Dashboard → Authentication → Sign In / Providers. Do this only after confirming no other app or workflow relies on email sign-in. It closes the direct Auth API password-signup route; hiding password forms in the React app alone does not.
3. Do not add password sign-up, password login, or password reset UI while native leaked-password protection is unavailable.
4. Do not rely on a browser-only HIBP check as a substitute: users could bypass it by calling Supabase Auth directly.
5. The Free/Pro Before User Created hook receives request metadata and the prospective user record, not the submitted password. The Password Verification Attempt hook is Teams/Enterprise-only and receives only the user ID plus a valid/invalid result; it also cannot inspect a candidate password for HIBP.
6. When the project is upgraded to Pro, enable Supabase Auth's native leaked-password protection and rerun the Security Advisor.

The Security Advisor warning is therefore a known plan limitation, not evidence that an existing Straw Hat Studio user password has leaked. The current database has no password credentials.

## Authenticated test safety

Mutating Playwright acceptance tests are opt-in and require a separate non-production Supabase project, two staging test-user sessions, and an explicit E2E_ALLOW_MUTATING_TESTS=true flag. The test harness refuses to run those tests against the production project reference. Never put a production user's session token in CI secrets.
