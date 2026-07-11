# Header Mega Nav

A per-site, admin-managed primary navigation strip for Discourse.
One repo serves any number of sites: **the entire menu lives in theme
settings**, edited at
**Admin → Customize → Themes → Header Mega Nav → Settings** — no file
edits, no rebuild; changes apply on the next page refresh.

## The per-site model (read this once)

Discourse stores edited theme settings in **each site's database**. The
same component installed on two sites carries two fully independent
menus. Component updates ship new *defaults and schema* only — **a site
that has edited a setting keeps its value through every update.** The
defaults in `settings.yml` are examples; the first thing to do on a new
site is replace them in the admin panel.

> Maintainer rule: schema changes must be **additive**. Never rename a
> setting key or remove a schema property — per-site stored values are
> keyed to them.

## Managing the menu

Everything is the `je_nav_destinations` objects setting. Each row:

| Field | Meaning |
|---|---|
| `label`, `icon` | Text + FontAwesome icon (add custom icons to the `svg_icons` setting) |
| `type` | `link` (goes to `href`) or `dropdown` (opens a panel of `children`) |
| `href` | Destination. `/my/...` resolves to the current user |
| `color` | Icon tint when not active (any CSS color) |
| `badge` | Optional accent chip — `NEW`, `LIVE` |
| `show_when` | `all` · `members` (logged-in) · `staff` |
| `children` | Dropdown rows: `label`, `href`, `icon`, `subtext`, `badge`, `show_when`, `section` |

**Mega menu:** give children a `section` label and the dropdown renders
one titled column per section. No sections → classic single column.

**Anonymous visitors:** the strip is members-only by default; switch
`je_nav_show_anon` ON to show it to logged-out visitors (`members`/
`staff` items stay hidden for them).

Brand (label + icon), avatar link, and the Plaza sidebar-hiding behavior
are their own settings — see descriptions in the admin panel.

## Example: a Word-centered site menu

```json
[
  { "label": "Discussions", "icon": "comments", "type": "dropdown", "color": "#378add",
    "children": [
      { "label": "General", "icon": "book-open", "href": "/c/general/4", "section": "Forum" },
      { "label": "All categories", "icon": "table-cells-large", "href": "/categories", "section": "Forum" },
      { "label": "Scripture Campaign", "icon": "scroll", "href": "/scripture-campaign", "section": "The Word", "subtext": "Walk a season", "badge": "NEW" },
      { "label": "Bible Trivia", "icon": "trophy", "href": "/trivia", "section": "The Word", "subtext": "Contests & the bank" }
    ] },
  { "label": "Scripture Campaign", "icon": "scroll", "href": "/scripture-campaign", "type": "link", "color": "#d8a657", "badge": "NEW" },
  { "label": "Bible Trivia", "icon": "trophy", "href": "/trivia", "type": "link", "color": "#378add" },
  { "label": "Messages", "icon": "envelope", "href": "/my/messages", "type": "link", "color": "#1d9e75" },
  { "label": "Talk to Logos", "icon": "wand-magic-sparkles", "href": "/discourse-ai/ai-bot/conversations", "type": "link", "color": "#b07cdb" }
]
```

(Use either the flat links or the sectioned dropdown — the JSON above
shows both shapes.)

## Version notes

**2.0.0** — mega-menu sections, per-item/child `show_when` visibility,
badge chips, optional anonymous strip (`je_nav_show_anon`), neutral
shared-repo identity, this README. All schema changes additive; v1
per-site values render unchanged.
