-- GRAPHYSICS VISUAL SITE EDITOR (run after supabase-schema.sql)
-- Replace the email below with the email you use to LOG IN to the Graphysics site.
-- This grants only that signed-in account permission to publish homepage appearance/content settings.
create table if not exists public.site_settings (
  id text primary key,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.site_settings enable row level security;
drop policy if exists "Public can read Graphysics site settings" on public.site_settings;
create policy "Public can read Graphysics site settings" on public.site_settings
  for select to anon, authenticated using (true);
drop policy if exists "Owner can publish Graphysics site settings" on public.site_settings;
create policy "Owner can publish Graphysics site settings" on public.site_settings
  for update to authenticated
  using ((auth.jwt() ->> 'email') = 'REPLACE_WITH_YOUR_LOGIN_EMAIL')
  with check ((auth.jwt() ->> 'email') = 'REPLACE_WITH_YOUR_LOGIN_EMAIL');
insert into public.site_settings (id, settings)
values ('homepage', '{"heroTitle":"Ideas deserve\\nto be seen.","heroSubtitle":"Discover standout design, meet independent creators and turn your next big idea into something real.","eyebrow":"THE CREATIVE COMMUNITY","buttonText":"Explore creative work","primary":"#9b7cff","accent":"#f4a6ff","background":"#171329","heroImage":"","hiddenSections":[],"sectionOrder":["home","stats","discover","creators","directory","services","cta"]}'::jsonb)
on conflict (id) do nothing;
grant select on public.site_settings to anon, authenticated;
grant update on public.site_settings to authenticated;
