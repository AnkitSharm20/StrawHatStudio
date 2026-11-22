-- Explicitly deny browser roles access to the private rate-limit state.
CREATE POLICY deny_client_access_to_community_rate_limits
ON private.community_write_rate_limits
FOR ALL
TO anon, authenticated
USING (false)
WITH CHECK (false);
