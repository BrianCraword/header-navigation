# Notification bell — Header Navigation 5.9.0

## Outcome and rollback

The native notifications/account button displays a bell when both `je_nav_notification_bell_enabled` (default true) and `je_nav_you_enabled` are enabled. The native accessible name remains "Notifications and account". The native button, handlers, menu tabs, account fallback, unread badges, status and pause controls remain in place. Chat and private Messages remain distinct; desktop navigation and permissions are unchanged. There are no new polling loops or notification mutations.

Disable `je_nav_notification_bell_enabled` and refresh to restore the avatar. Disabling You also restores it. Missing connector/glyph or unsupported CSS `:has` keeps the avatar. No data migration is required.

## Acceptance — 2026-11-12

- Builder and independent bell_release_review: existing regression suite 68 passed, zero failed. Independent reviewer accepted the exact five product files without blockers; runtime evidence below is builder-owned.
- Exact production core observed read-only as ordinary member: `821e9e2f9f94483a3be8d1e077cde0fd94970479`. Isolated preview used that core. Combined theme compilation passed and preserved 34 existing navigation settings. New connector ESLint and Prettier passed.
- Desktop 1440 and mobile 320/390 previews; light and dark palette checks passed. Native account controls, tabs, view-all links, status overlay and pause/resume remained available. Enter and Space opened the native menu. Native badge activation worked with both bell and avatar fallback.
- Disposable mention/reply/private-message/bookmark fixtures: opening You left seen/unread state unchanged. Opening the native menu changed seen state without clearing unread items. Native private-message dismissal cleared only its unread count and corresponding Messages badge.
- Bell-off and You-off rollback passed. Unsupported-selector/missing-connector fallback was source-reviewed, not emulated in another browser engine.
- Escape did not close the mobile menu in either native avatar baseline or bell preview. This existing native behavior is unchanged, not an acceptance claim that Escape closes it.

Physical phones, Safari, 200% zoom, exhaustive role/plugin and cross-tab parity were not tested. No native account controls were retired. No production settings or notification state were changed. Temporary fixture notifications/topic/status, palette and user preferences were restored; cleanup returned `BELL_FIXTURE_CLEANUP_OK`.

Independent accepted connector SHA256: `159237AE99E40FFE3051CE42BEFE353B3580167EB0BD931F07FDA86190BFBC0E`; stylesheet: `5ACE2AD926C03AA30F753407E708041A6201BB64CB2A98303979ED4ADB74CBBE`.

## Installation handoff

Brian updates existing Header Mega Nav component **250** from main, then checks the installed bell, unread badges, account fallback and phone layout. AI Conversations remains 1.6.5. Source publication is not production deployment. Native-control retirement requires a separate capability review and accessible replacements.