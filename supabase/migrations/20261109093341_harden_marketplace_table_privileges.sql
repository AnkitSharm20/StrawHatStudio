-- Defense in depth: browser clients may read their own marketplace records under RLS,
-- but all balance, purchase, redemption, and entitlement writes must go through
-- trusted server-side functions using the service role.
REVOKE ALL PRIVILEGES ON TABLE
  public.coin_ledger,
  public.purchases,
  public.redeem_codes,
  public.redeem_redemptions,
  public.user_entitlements
FROM anon, authenticated;

GRANT SELECT ON TABLE
  public.coin_ledger,
  public.purchases,
  public.redeem_codes,
  public.redeem_redemptions,
  public.user_entitlements
TO authenticated;
