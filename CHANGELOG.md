# Changelog — discourse-vc-feed

## v0.8.0 — 2026-07-10
Visual pass: card-on-canvas contrast + gradient compose CTA.

- Compose trigger rebuilt: the fake-input pill is now a full-width gradient
  button (pencil icon, "Share what the Lord is teaching you", "+ New Post"
  chip). Markup change in `components/vc-feed/composer.gjs`; new locale keys
  `composer_cta` / `composer_cta_chip`. FAB and `composer_placeholder`
  (used as the FAB title) unchanged.
- Feed contrast: stream returns to white cards (14px radius, soft
  elevation, 0.75em gaps) floating on a faint `--primary-very-low` canvas.
  Rail modules join the same card system. Hover shows a 3px tertiary
  left-edge accent instead of a gray row wash.
- Avatars reduced to 36px in feed rows.
- Action row up-sized: counts at `--font-0` semibold, icons at
  `--font-up-1`, larger hit targets, row max-width 380px.
- All colors remain core scheme variables; gradients/overlays derived via
  `color-mix` from `--tertiary` / `--secondary`. No hex values introduced.
- Scope: `vc-feed.scss`, `composer.gjs`, `client.en.yml`, version bump only.

## v0.7.1 and earlier
Pre-changelog. See git log.
