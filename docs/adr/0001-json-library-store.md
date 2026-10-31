# ADR 0001 — JSON file for the Phase 1 library (instead of drift/SQLite)

**Status:** accepted for Phase 1. **Revisit:** before playlists with large libraries, or Phase 2 download jobs.

**Context.** Phase 1 needs persistent imported media, resume positions, history and favorites on Android and Windows.
The spec suggests `drift` + sqlite3, which needs `build_runner` code generation and per-platform sqlite binaries.
That adds build surface I cannot verify without running Flutter.

**Decision.** `LibraryController` stores a small versioned JSON file in the app support directory
(atomic write via temp file + rename, corrupt files are quarantined as `.corrupt`).
UI only talks to `LibraryController`, so the store can be swapped.

**Alternatives.** drift/SQLite (better for thousands of rows, queries, migrations); shared_preferences (poor fit for lists).

**Impact.** Android and Windows behave the same. Fine for hundreds of items; migrate to drift when playlists or
download jobs make queries/relations necessary. The JSON has a `version` field to ease migration.
