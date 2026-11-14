-- Admin flag, invites and per-track audio quality. Only adds columns and tables:
-- every existing row is kept.

-- Nobody is admin after the upgrade; startup promotes QODI_ADMIN_USER.
ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;

ALTER TABLE tracks ADD COLUMN sample_rate_hz INTEGER;
ALTER TABLE tracks ADD COLUMN bit_depth INTEGER;
ALTER TABLE tracks ADD COLUMN channels INTEGER;
ALTER TABLE tracks ADD COLUMN lossless INTEGER NOT NULL DEFAULT 0;
-- 0 for tracks indexed before quality fields existed: the next scan re-reads
-- them even when size and mtime are unchanged.
ALTER TABLE tracks ADD COLUMN quality_scanned INTEGER NOT NULL DEFAULT 0;

CREATE TABLE invites (
    code       TEXT PRIMARY KEY,
    created_by TEXT REFERENCES users (id) ON DELETE SET NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    max_uses   INTEGER NOT NULL,
    uses       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX invites_created_at ON invites (created_at);
