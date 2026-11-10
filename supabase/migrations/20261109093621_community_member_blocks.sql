CREATE TABLE IF NOT EXISTS public.community_blocks (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT community_blocks_no_self_block CHECK (blocker_id <> blocked_id)
);

ALTER TABLE public.community_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read their own community blocks" ON public.community_blocks;
DROP POLICY IF EXISTS "Members create their own community blocks" ON public.community_blocks;
DROP POLICY IF EXISTS "Members remove their own community blocks" ON public.community_blocks;

CREATE POLICY "Members read their own community blocks"
ON public.community_blocks FOR SELECT
TO authenticated
USING (blocker_id = (SELECT auth.uid()));

CREATE POLICY "Members create their own community blocks"
ON public.community_blocks FOR INSERT
TO authenticated
WITH CHECK (blocker_id = (SELECT auth.uid()) AND blocked_id <> (SELECT auth.uid()));

CREATE POLICY "Members remove their own community blocks"
ON public.community_blocks FOR DELETE
TO authenticated
USING (blocker_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.community_blocks FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.community_blocks TO authenticated;
