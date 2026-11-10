# Supabase migration history

The `live-versions.txt` file is a snapshot of the connected Straw Hat Studio Supabase project's migration history. The original `profiles` and `user_settings` tables predate the recorded migration history, so `supabase/bootstrap/legacy-profile-schema.sql` recreates only that legacy baseline for clean local replay; it is not deployed to production. CI checks that every listed migration has exactly one matching SQL file and that no extra migration file is present.

When applying a new migration:
1. Add the SQL file using the exact version returned by Supabase.
2. Add the matching `version_name` line to `live-versions.txt`.
3. Run `npm run check:migrations`.
4. For a fresh-project release, replay the complete migration chain on a separate empty Supabase project before using `supabase db push` against production.

Do not edit or renumber migrations already recorded in Supabase. CI now starts a local Supabase stack, applies the legacy baseline fixture, and successfully replays all 41 tracked migrations against a clean local database. The inventory check verifies version filenames against the live history; it does not prove that hosted Auth, Discord OAuth, Storage CDN behavior, or Razorpay secrets are configured correctly.
