-- FamilyGuard Postgres schema — migration 002 (Phase 2).
-- Run with:  npm run db:migrate
-- Safe to re-run: all statements are IF NOT EXISTS.
--
-- Tables mirror the five new in-memory collections in
-- backend/src/config/store.js (installedApps, browsingSessions,
-- agreements, rewardEvents, keywordLists). The modules still read the
-- in-memory store; these tables are the persistence target when the
-- repository is wired up, following migration 001's pattern.
--
-- Browsing sessions deliberately have NO url column: full URL history is
-- not accessible on Android without a VPN/proxy, so the schema records
-- browser-app sessions only (which browser, when, how long).
-- Keyword alerts are SIMPLE substring lists — no ML model, no extra table:
-- a match writes a row to the existing sos_alerts table (see 001).

CREATE TABLE IF NOT EXISTS installed_apps (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  label TEXT,
  version_name TEXT,
  installed_at TIMESTAMPTZ,
  system_app BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (device_id, package_name)
);
CREATE INDEX IF NOT EXISTS idx_installed_apps_device
  ON installed_apps(device_id, last_seen_at DESC);

CREATE TABLE IF NOT EXISTS browsing_sessions (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  browser_label TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  duration_seconds INT,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_browsing_device
  ON browsing_sessions(device_id, started_at DESC);

CREATE TABLE IF NOT EXISTS agreements (
  id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rules JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN (
    'proposed', 'accepted', 'declined'
  )),
  effective_from DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  signed_at TIMESTAMPTZ,
  signed_note TEXT
);
CREATE INDEX IF NOT EXISTS idx_agreements_child
  ON agreements(child_id, created_at DESC);

CREATE TABLE IF NOT EXISTS reward_events (
  id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  points INT NOT NULL CHECK (points > 0),
  reason TEXT NOT NULL,
  badge TEXT,
  date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reward_events_child
  ON reward_events(child_id, created_at DESC);
-- The daily screen-time bonus is idempotent per child+date: one bonus
-- event per child per day, enforced here as well as in the controller.
CREATE UNIQUE INDEX IF NOT EXISTS idx_reward_events_bonus_unique
  ON reward_events(child_id, date)
  WHERE date IS NOT NULL;

CREATE TABLE IF NOT EXISTS keyword_lists (
  child_id TEXT PRIMARY KEY,
  keywords JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by TEXT REFERENCES users(id) ON DELETE SET NULL
);
