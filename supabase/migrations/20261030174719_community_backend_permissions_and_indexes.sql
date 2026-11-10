-- Community backend indexes and least-privilege Data API grants.
create index if not exists community_posts_author_idx on public.community_posts(author_id,created_at desc);
create index if not exists idx_community_posts_author_created on public.community_posts(author_id,created_at desc) where status='published';
create index if not exists community_replies_author_idx on public.community_replies(author_id);
create index if not exists idx_community_replies_author_created on public.community_replies(author_id,created_at desc) where status='published';
create index if not exists community_reactions_user_idx on public.community_post_reactions(user_id);
create index if not exists community_follows_followed_idx on public.community_follows(followed_id);
create index if not exists community_reports_post_idx on public.community_reports(post_id);
create index if not exists community_reports_reply_idx on public.community_reports(reply_id);
create index if not exists community_reports_reporter_idx on public.community_reports(reporter_id);
create index if not exists studio_notifications_actor_idx on public.studio_notifications(actor_id);

revoke all on table
  public.community_posts,public.community_replies,public.community_post_reactions,
  public.community_follows,public.community_reports,public.studio_notifications
from anon,authenticated;
grant select on table
  public.community_posts,public.community_replies,public.community_post_reactions,public.community_follows
to anon;
grant select,insert,update,delete on table
  public.community_posts,public.community_replies,public.community_post_reactions
to authenticated;
grant select,insert,delete on table public.community_follows to authenticated;
grant select,insert,update on table public.community_reports to authenticated;
grant select,update,delete on table public.studio_notifications to authenticated;
grant all on table
  public.community_posts,public.community_replies,public.community_post_reactions,
  public.community_follows,public.community_reports,public.studio_notifications
to service_role;
