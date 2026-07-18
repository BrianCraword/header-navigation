# Header Mega Nav — Changelog

---
[4.0.0] - 2026-07-17

The Mobile House. The bottom-bar system grows the FB grammar in VC's
voice: identity compressed into an avatar and summoned as a sheet, the
Word raised to the center of the bar.

  * IDENTITY SHEET — the mobile hero, one tap away instead of 1,400px
    tall. Big avatar with an always-visible camera badge (Change photo
    is a SNAP: both the photo and the pill deep-link to account
    preferences where the selector lives), name/@handle, lazy-loaded
    stat chips (hearts given/received, topics, posts, days walked, from
    /u/:username/summary.json), a settings-driven primary button
    (default: Update your profile -> /steering/profile), and a
    settings-driven quick-links GRID (je_nav_identity_links; defaults:
    My Profile, My Walk, Bookmarks, Messages, Badges, Preferences).
    Opens three ways: the new trailing AVATAR TAB on the bottom bar
    (je_nav_mobile_avatar_tab, default on), the new profile row at the
    top of the More sheet, and the document event
    "je-nav:identity:open" (claimed via preventDefault) — which the
    vc-feed porch avatar dispatches, so plugin and theme meet without
    coupling.
  * EMPHASIS TAB — additive `emphasis` boolean on the destination
    schema. An emphasized pinned destination renders as a raised accent
    circle in the bar — the "Word at the center" treatment. Pinned
    DROPDOWNS already open a contextual sheet of their children, so a
    Word tab with Campaign/Trivia/Verse children needs zero new code
    beyond the flag.
  * Scrim, Escape, hide-on-scroll, and route changes all treat the
    identity sheet as a first-class overlay.
  * Schema discipline held: every change is additive; stored per-site
    destination values survive the update untouched.

---
[3.0.1] - (prior) Bottom tab bar + overflow sheet; shared je-nav-core.js
drives desktop + mobile from one schema.
