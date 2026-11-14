# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's
[private vulnerability reporting](https://github.com/cbranty/qodi-music/security/advisories/new)
instead. Include the affected version or commit, the steps to reproduce, and the
impact you expect. You should get a first answer within a week.

## Supported versions

Only the latest `main` (and the `latest` container image) receives fixes.

## Hardening checklist for operators

- Put the server behind HTTPS (reverse proxy or Cloudflare Tunnel). Tokens travel
  in the `Authorization` header and, for media URLs, in the `?token=` query string.
- Use a strong `QODI_ADMIN_PASSWORD`, and leave `QODI_JWT_SECRET` empty so the
  server generates a random one, or set one with at least 32 random bytes.
- Rate-limit `POST /api/v1/auth/login` at your proxy or CDN. The server itself does
  not throttle login attempts.
- Mount the music folder read-only (the default Compose file already does).
- Back up the `qodi-data` volume. It holds the database and the signing secret.

## Known limitations

- Changing a password does not revoke tokens that were already issued. They expire
  after `QODI_TOKEN_TTL_DAYS` (default 30). Rotating `QODI_JWT_SECRET` signs
  everyone out.
- Proxies may log full URLs, including `?token=` on stream and cover requests.
