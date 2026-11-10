-- Browser clients only need to read their own wallet and purchase records.
-- All writes must pass through trusted server-side functions.
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
