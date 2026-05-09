-- Violin Hero user accounts table
create table if not exists public.violin_users (
  username text primary key,
  password_hash text not null,
  avatar_id text not null default 'avatar_frog',
  created_at timestamptz not null default now()
);

create index if not exists idx_violin_users_created
  on public.violin_users (created_at desc);
