# ── Header Mega Nav — per-site settings ─────────────────────────────────
#
# ONE REPO, MANY SITES. Everything an admin edits here is stored in THIS
# site's database (theme_settings), so the same component installed on two
# sites carries two fully independent menus. Component updates ship new
# DEFAULTS and SCHEMA only — a site that has edited a setting keeps its
# value through every update. The defaults below are EXAMPLES (revision-1
# links) to make the schema visible; replace them per site in
# Admin → Customize → Themes → this component → Settings. No rebuild, no
# file edits — changes apply on the next page refresh.
#
# SCHEMA DISCIPLINE (for future maintainers): evolve this schema
# ADDITIVELY only. Never rename a setting key or remove a property —
# stored per-site values are keyed to them.

je_nav_destinations:
  description: >-
    The primary navigation. Each row is one destination: type 'link' goes
    straight to href; type 'dropdown' opens a panel of children. MEGA MENU:
    give children a 'section' label and the panel renders one titled column
    per section (children without a section render first, untitled).
    Visibility: show_when = all / members (logged-in) / staff, per
    destination AND per child. 'badge' renders a small accent chip (NEW,
    LIVE). The /my/ href alias resolves to the current user. 'color' tints
    the icon when not active (any CSS color). Icons must be in the
    svg_icons setting below (or already in core's subset).
  type: objects
  default:
    [
      {
        "label": "Discussions",
        "icon": "comments",
        "type": "dropdown",
        "color": "#378add",
        "children":
          [
            { "label": "General", "icon": "book-open", "href": "/c/general/4", "subtext": "Most active" },
            { "label": "Site Feedback", "icon": "message", "href": "/c/site-feedback/2", "subtext": "Suggestions & bugs" },
            { "label": "All categories", "icon": "table-cells-large", "href": "/categories", "subtext": "Enter the full forum" },
          ],
      },
      { "label": "Matches", "icon": "heart", "href": "/matchmaking/matches", "type": "link", "color": "#e24b4a" },
      { "label": "Messages", "icon": "envelope", "href": "/my/messages", "type": "link", "color": "#1d9e75" },
      { "label": "Talk to Logos", "icon": "wand-magic-sparkles", "href": "/discourse-ai/ai-bot/conversations", "type": "link", "color": "#b07cdb" },
    ]
  schema:
    name: "destination"
    identifier: label
    properties:
      label:
        type: string
        required: true
      icon:
        type: string
        required: true
      type:
        type: enum
        default: link
        choices:
          - link
          - dropdown
      href:
        type: string
        validations:
          url: true
      color:
        type: string
      badge:
        type: string
      order:
        type: integer
      show_when:
        type: enum
        default: all
        choices:
          - all
          - members
          - staff
      children:
        type: objects
        schema:
          name: "child"
          identifier: label
          properties:
            label:
              type: string
              required: true
            icon:
              type: string
            href:
              type: string
              required: true
              validations:
                url: true
            subtext:
              type: string
            section:
              type: string
            badge:
              type: string
            order:
              type: integer
            show_when:
              type: enum
              default: all
              choices:
                - all
                - members
                - staff

je_nav_show_anon:
  description: "Show the navigation strip to anonymous (logged-out) visitors. Items marked show_when 'members' or 'staff' stay hidden for them. OFF preserves the original members-only behavior."
  type: bool
  default: false

je_nav_show_mobile:
  description: "Render the strip on mobile too (compact, horizontally scrollable; dropdowns open full-width). OFF preserves the desktop-only behavior for sites where another component owns mobile navigation."
  type: bool
  default: false

je_nav_show_brand:
  description: "Show the brand lockup (icon + name) at the left of the strip. Disable if your theme already renders a logo above the strip."
  type: bool
  default: true

je_nav_brand_label:
  description: "Text shown in the brand lockup. Set per site (e.g. 'Jesus Enough', 'Victorious Christians')."
  type: string
  default: "Jesus Enough"

je_nav_brand_icon:
  description: "FontAwesome icon name for the brand lockup."
  type: string
  default: "cross"

je_nav_show_avatar:
  description: "Show a link to the user's account at the right of the strip. Leave OFF if you rely on Discourse's native header avatar menu (recommended, to avoid duplicating the account menu)."
  type: bool
  default: false

je_nav_hide_sidebar_in_plaza:
  description: "Master switch. When ON, the Discourse sidebar is hidden on Plaza routes (everywhere except forum routes) and a per-user pin toggle appears on the strip. When OFF, the sidebar always shows and no toggle is offered."
  type: bool
  default: true

je_nav_sidebar_default_hidden:
  description: "When the master switch is ON, this is the default state for users who haven't set their own preference: hidden (clean app feel) or shown. Each user can override and their choice is remembered in their browser."
  type: bool
  default: true

je_nav_forum_route_classes:
  description: "Body classes that mark a 'forum mode' route, where the sidebar should remain visible. Add more (e.g. tag-show pages) as your forum grows."
  type: list
  list_type: compact
  default: "navigation-categories|navigation-topics|navigation-category|categories-list"

svg_icons:
  default: "cross|scroll|trophy"
  type: list
  list_type: "compact"
  description: "Extra FontAwesome icons referenced by settings (brand icon, custom destinations). Add any icon you reference in je_nav_destinations here — per site, no rebuild."
