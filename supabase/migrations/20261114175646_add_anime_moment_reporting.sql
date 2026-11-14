create table public.anime_moment_reports (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.anime_moments(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('spam','harassment','copyright','inappropriate','misinformation','other')),
  details text check (details is null or char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open','reviewed','resolved','dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (moment_id, reporter_id)
);

create index anime_moment_reports_status_created_idx
on public.anime_moment_reports (status, created_at desc);

alter table public.anime_moment_reports enable row level security;
revoke all on public.anime_moment_reports from anon, public;
grant select, insert on public.anime_moment_reports to authenticated;
grant update (status, reviewed_at) on public.anime_moment_reports to authenticated;

create policy "Reporters and admins read Anime Moment reports"
on public.anime_moment_reports for select to authenticated
using (
  reporter_id = (select auth.uid())
  or (select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin'
);

create policy "Members report other creators published Anime Moments"
on public.anime_moment_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and exists (
    select 1 from public.anime_moments m
    where m.id = moment_id
      and m.status = 'published'
      and m.creator_id <> (select auth.uid())
  )
);

create policy "Admins resolve Anime Moment reports"
on public.anime_moment_reports for update to authenticated
using ((select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin')
with check ((select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin');
