# Header Mega Nav — Changelog

---
[4.1.0] - 2026-07-25

One menu, two surfaces, and a menu that can finally read the room. The
4.0 system could describe WHERE things are; it could not say WHO should
see them, WHICH surface they belong to, or WHAT is happening behind
them. Everything here is additive — every stored 4.0 destination renders
unchanged until an admin fills in a new field.

  * SURFACE — `surface` on destinations and children: both (default),
    desktop, or mobile. The single answer to "how do I configure the two
    surfaces differently" without keeping two lists in sync. Resolved in
    je-nav-core so the strip and the bar can never drift.
  * GROUP VISIBILITY — `visible_groups`, a pipe-separated list of group
    NAMES, composing with show_when (both gates must pass). Names rather
    than ids because ids are invisible in the admin panel and differ per
    site. Staff deliberately do NOT bypass it: a group gate is usually a
    funnel stage, and staff seeing every stage at once makes the funnel
    impossible to inspect.
  * LIVE STATE — `href_source` and `badge_source` let a row read state a
    plugin publishes on current_user instead of hardcoding a URL or a
    number. `matchmaking_journey` exists because matchmaking's own law is
    that GATED DESTINATIONS ARE NEVER LINKED DIRECTLY — an unconfirmed
    member doors to the Journey, a confirmed member to the hub — and
    every menu that hardcoded /matchmaking/profile was breaking it for
    every unconfirmed member. Badges hide themselves at zero; an empty
    badge is worse than no badge. See stateBag() for the contract and
    WHY it rides on current_user rather than a fetch.
  * PANEL HEADERS — `panel_title` / `panel_subtext` render at the top of
    the desktop panel AND the mobile sheet. A dropdown with a heading is
    a mega menu with something to say; without one it renders exactly as
    it always has.
  * SHEET LAYOUTS — `sheet_layout`: list (default), grid (thumb-sized
    tiles), cards (roomy rows that give subtext a real second line). The
    mobile sheet is full height and has been spending it on two rows.
  * CENTERED RAISED TAB — `emphasis` is finally DECLARED in the schema
    (4.0.0 shipped the behavior and the CSS but never the property, so it
    worked only where the value was already in the database and would
    have been lost on a full re-save). New je_nav_mobile_center_emphasis
    moves the raised tab to the true middle index, so pinning or
    unpinning something no longer drifts the pillar off-center.
  * CORE-CHROME SUPPRESSION — je_nav_suppress_core_desktop / _mobile
    retire duplicated core controls per surface:
    hamburger|search|chat|ai-bot|avatar. Selectors were verified against
    the live header, not assumed. CSS-only via body classes the
    initializer adds: nothing core is patched, and disabling the
    component restores every control on the next paint (ADR-F1). The
    icon cluster's empty <li> is removed with :has() so no gap is left
    behind.
  * LOCALES — je_nav_mobile_avatar_tab, je_nav_identity_links (including
    its schema property labels), je_nav_identity_primary_label and
    je_nav_identity_primary_href shipped in 4.0.0 with NO locale
    entries, so the admin panel showed raw keys. Every setting and every
    schema property is now labeled; the file is checked against
    settings.yml so this can't silently regress.

DEFERRED, deliberately: second-level sheet push (a child that is itself a
dropdown). It needs three levels of object-schema nesting and that depth
is not verified on this Discourse version. Shipping it unverified would
trade a working menu for an admin panel that can't edit it.

---

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
