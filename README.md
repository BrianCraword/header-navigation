# Header Mega Nav

## 5.3.0 — Shared You dating action

When the configured You primary destination is `/matchmaking`, its label and destination use the optional Matchmaking 0.21.0 next-step service. Opening You refreshes that state. Holds have no navigation target; absent service uses a neutral Open dating entry. Other configured destinations, visibility rules and 5.2.0 hidden_groups behavior are unchanged.

Validation and rollout: see `docs/T1-NEXT-STEP.md`.

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
| `visible_groups` | Pipe-separated group names; the row shows only to members of one of them |
| `hidden_groups` | Pipe-separated group names; the row is hidden from members of any of them (5.2.0) |
| `children` | Dropdown rows: `label`, `href`, `icon`, `subtext`, `badge`, `show_when`, `visible_groups`, `hidden_groups`, `section` |

**Mega menu:** give children a `section` label and the dropdown renders
one titled column per section. No sections → classic single column.

**Anonymous visitors:** the strip is members-only by default; switch
`je_nav_show_anon` ON to show it to logged-out visitors (`members`/
`staff` items stay hidden for them).

Brand (label + icon), avatar link, and the Plaza sidebar-hiding behavior
are their own settings — see descriptions in the admin panel.

## Focused Feed companion (5.1.0+)

Off by default. With `je_nav_focus_companion_enabled` on, and only while a
member is on the Feed's focused route (the Feed plugin's
`vc_feed_focus_enabled` must be on), the strip and the mobile bar show four
controls instead of the configured menu: Home · Explore · Messages · AI
Conversations. They are computed from `je_nav_destinations`, which is never
rewritten; every `show_when` gate still applies, and `surface` too, except
that the Messages row (configured for mobile) is deliberately shown on desktop.

| Setting | Default | Purpose |
|---|---|---|
| `je_nav_focus_companion_enabled` | `false` | The switch. Off: 5.1.2 renders exactly as 5.0.0. |
| `je_nav_focus_ai_href` | `/discourse-ai/ai-bot/conversations` | Where AI Conversations opens (any query is dropped). |
| `je_nav_focus_home_href` | `/feed` | Where Home opens. |
| `je_nav_focus_keep_explore_on_scroll` | `true` | Keep the mobile bar visible while scrolling the focused Feed. |

Tests: `node --test test/*.cjs` (surface gates and translation keys).

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

**5.2.0** — `hidden_groups` on rows and children: hide a row from members of the listed groups. Built for funnel entry rows ("Start your Journey" steps aside once a member is in `mm_*`). Staff do not bypass it. Additive; existing rows render unchanged. Test: `test/hidden-groups.test.cjs`.

**2.0.0** — mega-menu sections, per-item/child `show_when` visibility,
badge chips, optional anonymous strip (`je_nav_show_anon`), neutral
shared-repo identity, this README. All schema changes additive; v1
per-site values render unchanged.
