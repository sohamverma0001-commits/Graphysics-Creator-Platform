-- GRAPHYSICS database setup (run once in Supabase > SQL Editor)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'New creator',
  role text not null default 'creator' check (role in ('creator','client')),
  specialty text default '', bio text default '', location text default '',
  portfolio_url text default '', avatar_url text default '',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  title text not null, category text not null, description text not null,
  image_url text not null, published boolean not null default true,
  likes integer not null default 0 check (likes >= 0),
  created_at timestamptz not null default now()
);
create table if not exists public.inquiries (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid references auth.users(id) on delete set null,
  client_name text not null, client_email text not null,
  message text not null, status text not null default 'new' check (status in ('new','read','closed')),
  created_at timestamptz not null default now()
);
create index if not exists projects_creator_id_idx on public.projects(creator_id);
create index if not exists projects_created_at_idx on public.projects(created_at desc);
create index if not exists inquiries_creator_id_idx on public.inquiries(creator_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.inquiries enable row level security;

-- Public can see creator/client public profile fields. Users can only edit their own row.
drop policy if exists "Public profiles readable" on public.profiles;
create policy "Public profiles readable" on public.profiles for select to anon, authenticated using (true);
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Public feed only shows published projects. Creators manage only their own projects.
drop policy if exists "Published projects readable" on public.projects;
create policy "Published projects readable" on public.projects for select to anon, authenticated using (published = true or (select auth.uid()) = creator_id);
drop policy if exists "Creators add own projects" on public.projects;
create policy "Creators add own projects" on public.projects for insert to authenticated with check ((select auth.uid()) = creator_id);
drop policy if exists "Creators update own projects" on public.projects;
create policy "Creators update own projects" on public.projects for update to authenticated using ((select auth.uid()) = creator_id) with check ((select auth.uid()) = creator_id);
drop policy if exists "Creators delete own projects" on public.projects;
create policy "Creators delete own projects" on public.projects for delete to authenticated using ((select auth.uid()) = creator_id);

-- A signed-in client can send an enquiry; only its recipient creator can read/update it.
drop policy if exists "Clients send enquiries" on public.inquiries;
create policy "Clients send enquiries" on public.inquiries for insert to authenticated with check (client_id = (select auth.uid()));
drop policy if exists "Creators read received enquiries" on public.inquiries;
create policy "Creators read received enquiries" on public.inquiries for select to authenticated using (creator_id = (select auth.uid()));
drop policy if exists "Creators update received enquiries" on public.inquiries;
create policy "Creators update received enquiries" on public.inquiries for update to authenticated using (creator_id = (select auth.uid())) with check (creator_id = (select auth.uid()));

-- Create a PUBLIC storage bucket for portfolio artwork (5 MB per file).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio-images', 'portfolio-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Uploads are stored under <user-uuid>/<filename>; users can upload/delete only in their own folder.
drop policy if exists "Creators upload own portfolio images" on storage.objects;
create policy "Creators upload own portfolio images" on storage.objects for insert to authenticated with check (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Creators update own portfolio images" on storage.objects;
create policy "Creators update own portfolio images" on storage.objects for update to authenticated using (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = (select auth.uid())::text) with check (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Creators delete own portfolio images" on storage.objects;
create policy "Creators delete own portfolio images" on storage.objects for delete to authenticated using (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Automatically create the public profile at sign-up (also works with email confirmation).
create or replace function public.handle_new_graphysics_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    case when new.raw_user_meta_data ->> 'role' = 'client' then 'client' else 'creator' end
  ) on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_graphysics_auth_user_created on auth.users;
create trigger on_graphysics_auth_user_created
after insert on auth.users for each row execute procedure public.handle_new_graphysics_user();
