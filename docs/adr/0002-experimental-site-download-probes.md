# ADR 0002 — Experimental site downloads and direct distribution

Status: scope accepted by the user on 22 October 2026; production engine choice
remains provisional pending samples and dependency-license review.

## Decision

Target public authorized YouTube, Facebook, TikTok and X videos experimentally,
with direct APK/Windows distribution. Do not claim universal or official site
support. Use independent, reproducible downloads on both platforms before
building the full download UI.

Use yt-dlp in an isolated Windows venv and evaluate the youtubedl-android wrapper
in a separate Android package. No hosted extractor or user login/cookies for
the first proof. Keep successful download, decodable output, engine version,
bytes, duration and failure evidence separate from mere metadata extraction.

## Outcome so far

One user-supplied YouTube Shorts sample downloaded on both Windows and the
physical Android phone. Files are byte-identical and validated. Facebook,
TikTok and X are awaiting user sample URLs. See `../DOWNLOAD_PROBE_RESULTS.md`.

## Follow-up

- Collect samples for the other three sites and report outcomes independently.
- Confirm the final Android engine/license and source-distribution plan.
- Then implement provider boundaries, extraction errors, permanent download
  jobs, expiry-aware URL refresh, supported pause/resume and Android lifecycle.
- Keep protected/private/DRM content, playlists and live streams outside the
  initial scope. Direct distribution does not override platform terms or rights.
