# Authentication and password protection — Free plan

## Current verified state

- The Supabase organization is on the Free plan. Supabase documents native Have I Been Pwned leaked-password rejection as Pro and above.
- The live Auth database currently has one user and zero password credentials; the only recorded identity provider is Discord.
- Straw Hat Studio's app sign-in flow uses Discord OAuth PKCE. It does not expose email/password sign-up or password sign-in controls.

## Safe operating posture on Free

1. Keep Discord OAuth as the only sign-in method exposed by this application.
2. A server-side Before User Created hook is available on Free/Pro. I added and tested `private.block_non_discord_signups(event jsonb)`: it allows Discord signups and rejects other new identity providers with HTTP 403. It does not inspect a password or check HIBP.
3. **One dashboard step remains:** open Supabase Dashboard → Authentication → Hooks → Before User Created, choose the Postgres function `private.block_non_discord_signups`, and enable it. The function is deployed as `SECURITY INVOKER` (it does not need elevated database access), and only `supabase_auth_admin` can execute it. The hook is not active until you enable it in that dashboard screen. The hosted Before User Created hook is configured in the Supabase Dashboard; it is intentionally not placed in `config.toml` because the current local CLI config schema does not list this hook type.
4. Because this app does not use email/password or magic-link authentication, you can also disable the Email provider under Authentication → Sign In / Providers after confirming no other workflow relies on it. The hook blocks new email signups; disabling the provider closes the direct Auth API password route as well.
5. Do not add password sign-up, password login, or password reset UI while native leaked-password protection is unavailable. Do not rely on a browser-only HIBP check: users could bypass it by calling Supabase Auth directly.
6. The Free/Pro Before User Created hook receives request metadata and the prospective user record, not the submitted password. The Password Verification Attempt hook is Teams/Enterprise-only and receives only the user ID plus a valid/invalid result; it also cannot inspect a candidate password for HIBP.
7. When the project is upgraded to Pro, enable Supabase Auth's native leaked-password protection and rerun the Security Advisor.

The Security Advisor warning remains a plan-level warning, not evidence that an existing Straw Hat Studio user password has leaked. The current database has no password credentials. The new hook reduces the risk of future non-Discord signups once enabled, but it is not equivalent to native leaked-password screening. Supabase documents Before User Created as available on Free and Pro, while native leaked-password protection is Pro+.

## Authenticated test safety

Mutating Playwright acceptance tests are opt-in and require a separate non-production Supabase project, two staging test-user sessions, and an explicit E2E_ALLOW_MUTATING_TESTS=true flag. The test harness refuses to run those tests against the production project reference. Never put a production user's session token in CI secrets.
