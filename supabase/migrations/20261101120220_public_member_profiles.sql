alter table public.profiles add column if not exists bio text;
update public.profiles p
set bio = nullif(left(coalesce(s.preferences->>'profileBio',''),240),'')
from public.user_settings s
where s.user_id = p.id and p.bio is null and coalesce(s.preferences->>'profileBio','') <> '';
create unique index if not exists profiles_username_lower_unique
on public.profiles (lower(username))
where username is not null and btrim(username) <> '';
create index if not exists idx_community_follows_followed_id on public.community_follows(followed_id);
create index if not exists idx_community_posts_author_created on public.community_posts(author_id, created_at desc) where status='published';
create index if not exists idx_community_replies_author_created on public.community_replies(author_id, created_at desc) where status='published';