-- FamilyGuard Postgres schema — migration 001 (initial).
-- Run with:  npm run db:migrate
-- Requires DATABASE_URL. Safe to re-run: all statements are IF NOT EXISTS,
-- and applied migrations are tracked in schema_migrations.
--
-- Design: one table per in-memory collection in backend/src/config/store.js,
-- plus the Phase 1 tables (remote_commands, media_captures, audit_log,
-- push_tokens). Existing modules still read the in-memory store; new
-- modules (remotecommands, media) use the repository in
-- backend/src/db/repository.js, which writes here when DATABASE_URL is set
-- and falls back to the in-memory store otherwise. Migrating the older
-- modules one at a time is documented in docs/ROADMAP.md (Phase 1).

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  role TEXT NOT NULL CHECK (role IN ('parent', 'child')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS children (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'windows')),
  device_name TEXT NOT NULL,
  push_token TEXT,
  push_platform TEXT CHECK (push_platform IN ('fcm', 'apns')),
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS consents (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  accepted_text TEXT NOT NULL,
  consent_version TEXT NOT NULL DEFAULT '1',
  accepted_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_consents_device ON consents(device_id);

CREATE TABLE IF NOT EXISTS usage_events (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  app_name TEXT NOT NULL,
  duration_seconds INT NOT NULL DEFAULT 0,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS screen_time_limits (
  device_id TEXT PRIMARY KEY,
  daily_minutes INT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS blocked_apps (
  device_id TEXT PRIMARY KEY,
  apps JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS locations (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_locations_device ON locations(device_id, at DESC);

CREATE TABLE IF NOT EXISTS geofences (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  radius_m INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS geofence_events (
  id TEXT PRIMARY KEY,
  geofence_id TEXT NOT NULL REFERENCES geofences(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('enter', 'exit')),
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sos_alerts (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT 'SOS triggered',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS web_filters (
  device_id TEXT PRIMARY KEY,
  blocked_domains JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bedtime_schedules (
  device_id TEXT PRIMARY KEY,
  start_hour INT NOT NULL CHECK (start_hour BETWEEN 0 AND 23),
  end_hour INT NOT NULL CHECK (end_hour BETWEEN 0 AND 23),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS contacts (
  device_id TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms_messages (
  device_id TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS call_logs (
  device_id TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS files (
  device_id TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Phase 1: remote commands (parent -> child). The child polls for pending
-- commands; push (FCM) is a best-effort notification only, never the
-- delivery mechanism itself.
CREATE TABLE IF NOT EXISTS remote_commands (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'lock_now', 'unlock', 'send_message',
    'request_screenshot', 'request_audio'
  )),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'delivered', 'acknowledged', 'completed',
    'expired', 'rejected', 'cancelled'
  )),
  result JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  acknowledged_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_remote_commands_device
  ON remote_commands(device_id, status, created_at DESC);

-- Phase 1: media captures (on-request screenshots + SOS-only short audio).
-- Only metadata lives here. The file itself is referenced by storage_ref
-- (Phase 2 fills this in with the real upload target). Nothing here is
-- ever captured secretly: every row has a source (sos | parent_request)
-- and an expires_at; retention is 7 days by default (MEDIA_RETENTION_DAYS).
CREATE TABLE IF NOT EXISTS media_captures (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('screenshot', 'sos_audio')),
  source TEXT NOT NULL CHECK (source IN ('sos', 'parent_request')),
  command_id TEXT REFERENCES remote_commands(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN (
    'requested', 'captured', 'delivered', 'deleted', 'expired'
  )),
  storage_ref TEXT,
  size_bytes BIGINT,
  duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds <= 30),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_media_device ON media_captures(device_id, created_at DESC);

-- Audit log: everything sensitive is visible to the child in
-- "What My Parent Sees" (GET /api/transparency/:deviceId). No silent
-- collection — if it is not in this log, it did not happen.
CREATE TABLE IF NOT EXISTS audit_log (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  detail JSONB NOT NULL DEFAULT '{}'::jsonb,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_device ON audit_log(device_id, at DESC);
