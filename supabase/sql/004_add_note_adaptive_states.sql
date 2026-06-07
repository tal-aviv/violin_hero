-- Per-note adaptive learning state (Level 1/2/3 mastery flags).
-- Additive migration — safe to run on a populated table:
--   • IF NOT EXISTS guards against re-runs.
--   • Existing rows pick up the default '{}' JSON object.
--   • No existing column or row data is touched.
--
-- The column is keyed by GameNote.id (e.g. 'D5_A', 'F#4_D'), and each
-- value carries a compact set of boolean flags:
--   {
--     "m":  true,   -- mastered (sticky)
--     "hh": true,   -- hideHint  (currently at Level 2+)
--     "nm": true,   -- nameMastered (sticky)
--     "hn": true    -- hideName  (currently at Level 3)
--   }
-- Notes with all flags false are omitted from the JSON to keep the
-- column lean — the client treats missing entries as fresh.
alter table public.violin_user_progress
  add column if not exists note_adaptive_states jsonb not null default '{}'::jsonb;
