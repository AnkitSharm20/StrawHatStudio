-- Reduce Community table privileges to the operations actually used by the app.
revoke all on table
  public.community_posts,
  public.community_replies,
  public.community_post_reactions,
  public.community_follows,
  public.community_reports,
  public.studio_notifications
from anon, authenticated;

grant select on table
  public.community_posts,
  public.community_replies,
  public.community_post_reactions,
  public.community_follows
to anon;

grant select, insert, update, delete on table
  public.community_posts,
  public.community_replies,
  public.community_post_reactions
to authenticated;

grant select, insert, delete on table public.community_follows to authenticated;
grant select, insert, update on table public.community_reports to authenticated;
grant select, update, delete on table public.studio_notifications to authenticated;

grant all on table
  public.community_posts,
  public.community_replies,
  public.community_post_reactions,
  public.community_follows,
  public.community_reports,
  public.studio_notifications
to service_role;
