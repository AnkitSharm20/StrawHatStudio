revoke all on public.anime_moment_reports from authenticated;
grant select, insert on public.anime_moment_reports to authenticated;
grant update (status, reviewed_at) on public.anime_moment_reports to authenticated;
