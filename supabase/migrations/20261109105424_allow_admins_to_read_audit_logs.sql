-- Keep the audit RPC SECURITY INVOKER and let RLS enforce admin-only reads.
GRANT SELECT ON TABLE public.admin_audit_logs TO authenticated;
DROP POLICY IF EXISTS "Admins read admin audit logs" ON public.admin_audit_logs;
CREATE POLICY "Admins read admin audit logs"
ON public.admin_audit_logs FOR SELECT TO authenticated
USING ((SELECT auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
