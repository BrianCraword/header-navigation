# header-navigation

Theme component "Header Mega Nav 4.1" (site id 250, under VC-Canvas). Desktop strip
(`je-nav`) and mobile bottom bar (`je-mnav`), both built from the
`je_nav_destinations` setting. README.md explains the code; this file is how to test it.

## Testing live
- Site: https://community.victoriouschristians.com (Chrome is signed in as admin).
- Live settings in the page console:
  `moduleBroker.lookup("discourse/lib/theme-settings-store").getObjectForTheme(250)`
- Translations resolve only through `themePrefix`; check one live with
  `require("discourse-i18n").default.t("theme_translations.250.je_nav.focus.home")`.
- Tests: `node --test test/*.cjs`. The focused-menu tests copy the live destinations
  shape; re-check it against the live setting when the menu config changes.
- Screenshots and window resizing do not work in the browser tool; ask Brian to check
  the phone bar on his phone.

## Hard-won facts
- The focused Feed companion (`je_nav_focus_companion_enabled`) is ON live since
  2026-10-11: /feed shows Home · Explore · Messages · AI Conversations on both surfaces.
- Rows copied from the configured menu bring their own `order` and `mobile_pinned`;
  anything unpinned goes under More on the phone bar.
- Rules scoped to `.je-nav--focus` apply only while the companion is mounted. Changes to
  the general strip CSS change every page for every member; measure before and after.
- The live strip's `.je-nav__inner` overhangs `.je-nav` by 12px (content-box). Known,
  left as is in 5.1.x.
