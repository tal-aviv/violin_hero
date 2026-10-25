-- Skill level chosen at signup ('beginner' | 'intermediate' | 'advanced').
-- Additive migration — safe to run on a populated table:
--   • IF NOT EXISTS guards against re-runs.
--   • Existing rows get NULL, which the client treats as beginner.
-- The client's kUserLevels map still overrides this value.
-- Run this BEFORE deploying the violin-auth function that writes it.
alter table public.violin_users
  add column if not exists level text
  check (level in ('beginner', 'intermediate', 'advanced'));
