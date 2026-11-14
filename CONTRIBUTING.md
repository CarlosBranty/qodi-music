# Contributing

Thanks for your interest in Qodi Music. Bug reports, fixes and focused features are welcome.

## Before you start

- For anything larger than a small fix, open an issue first so we can agree on the approach.
- Changes to the HTTP API must update [`docs/api.md`](docs/api.md), which is the contract the
  server and the client share.

## Development setup

| Part | Requirements | Commands |
|---|---|---|
| Server (`server/`) | Rust stable, `ffmpeg` (optional, used by transcoding tests) | `cargo test` · `cargo clippy --all-targets -- -D warnings` |
| Client (`app/`) | Flutter 3.50, `libmpv` on Linux | `flutter pub get` · `flutter analyze` · `flutter test` |

See [`server/README.md`](server/README.md) and [`app/README.md`](app/README.md) for details.

## Pull requests

1. Branch from `main`.
2. Add tests for behavior changes. Pull requests run the same checks as CI (server and app jobs).
3. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, …).
4. Keep pull requests small and focused; describe what changed and how you verified it.
5. Add new UI strings to both `app/lib/l10n/app_en.arb` and `app/lib/l10n/app_es.arb`.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
