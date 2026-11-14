-- Initial schema for qodi-server. Timestamps are stored as Unix epoch milliseconds (UTC).

CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at    INTEGER NOT NULL
);

CREATE TABLE tracks (
    id                  TEXT PRIMARY KEY,
    path                TEXT NOT NULL UNIQUE,
    title               TEXT NOT NULL,
    artist              TEXT NOT NULL,
    artist_id           TEXT NOT NULL,
    album               TEXT NOT NULL,
    album_id            TEXT NOT NULL,
    album_artist        TEXT NOT NULL,
    album_artist_id     TEXT NOT NULL,
    track_number        INTEGER,
    disc_number         INTEGER,
    year                INTEGER,
    genre               TEXT,
    duration_ms         INTEGER NOT NULL,
    format              TEXT NOT NULL,
    bitrate_kbps        INTEGER,
    size_bytes          INTEGER NOT NULL,
    mtime_ms            INTEGER NOT NULL,
    has_embedded_cover  INTEGER NOT NULL,
    has_embedded_lyrics INTEGER NOT NULL,
    has_cover           INTEGER NOT NULL,
    has_lyrics          INTEGER NOT NULL,
    search_text         TEXT NOT NULL,
    updated_at          INTEGER NOT NULL
);
CREATE INDEX tracks_artist_id ON tracks (artist_id);
CREATE INDEX tracks_album_id ON tracks (album_id);
CREATE INDEX tracks_album_artist_id ON tracks (album_artist_id);
CREATE INDEX tracks_updated_at ON tracks (updated_at);

CREATE TABLE tombstones (
    track_id   TEXT PRIMARY KEY,
    removed_at INTEGER NOT NULL
);
CREATE INDEX tombstones_removed_at ON tombstones (removed_at);

CREATE TABLE waveforms (
    track_id TEXT PRIMARY KEY,
    peaks    TEXT NOT NULL
);

CREATE TABLE favorites (
    user_id    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    track_id   TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, track_id)
);

CREATE TABLE playlists (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX playlists_user ON playlists (user_id, updated_at);

CREATE TABLE playlist_tracks (
    playlist_id TEXT NOT NULL REFERENCES playlists (id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    track_id    TEXT NOT NULL,
    PRIMARY KEY (playlist_id, position)
);

CREATE TABLE plays (
    client_id   TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    track_id    TEXT NOT NULL,
    played_at   INTEGER NOT NULL,
    listened_ms INTEGER NOT NULL
);
CREATE INDEX plays_user_time ON plays (user_id, played_at);
