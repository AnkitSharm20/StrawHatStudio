-- The public watchlist read path now uses the public-profile-watchlist Edge Function.
-- The function checks profile visibility server-side and returns only the watchlist field.
-- Drop the exposed SECURITY DEFINER RPC to remove its anon/authenticated execution surface.
drop function if exists public.get_public_profile_watchlist(text);
