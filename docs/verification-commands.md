# Gate V1 verification — run after ./launcher rebuild app

## 0. Plugin is alive
Admin → Plugins → discourse-vc-feed listed, enabled after switching
`vc_feed_enabled` on. Set `vc_feed_categories` to the Community Feed category.

## 1. Read verb (anon terminal check)
    curl -s https://community.victoriouschristians.com/vc-feed/stream.json | head -c 400
Expect `{"items":[...],"has_more":false}` — topics already in Community Feed
appear newest-first with `cooked` bodies. Empty category → `{"items":[]}`, NOT an error.

## 2. Write verb (browser console as a TL1+ member)
    await fetch("/vc-feed/posts.json", {
      method: "POST",
      headers: { "Content-Type": "application/json",
                 "X-CSRF-Token": document.querySelector('meta[name=csrf-token]').content },
      body: JSON.stringify({ raw: "Testing the wall — the steadfast love of the LORD never ceases." })
    }).then(r => r.json())
Expect a JSON item with `is_micropost: true`, a generated `title`, correct `topic_id`.

## 3. Round trip
Reload `/vc-feed/stream.json` — the new post is item 0. Open its `url` — a
normal Discourse topic with the generated title. Like it there, refetch the
stream — `liked: true`, `like_count: 1`.

## 4. Short-body title rescue
Post `raw: "Amen!"` (pad to min post length if needed: "Amen! Praise God.").
Title must be `Post by <username> · <stamp>` or body + stamp — never a validation error.

## 5. Gating
Repeat step 2 as a TL0 account → 403. Anonymous POST → 403.

## 6. ADR-F1 proof (the one that matters)
Disable `vc_feed_enabled`, or remove the plugin and rebuild:
site functions stock — no residue beyond inert custom fields and settings.

## 7. The surface (v0.2.0) — Gate V1 proper, in the browser
Visit `/feed` as a TL1+ member:
- Composer shows "What is the Lord teaching you today?" — type, Post →
  the card appears INSTANTLY at the top (optimistic), survives reload.
- Heart a card → fills with the love color; open the topic → the like is
  there (one engagement system, two skins). Unheart → both agree again.
- Second browser/account posts → first browser shows the "new post" pill
  WITHOUT moving your scroll; click → new card merges above.
- Scroll to the bottom → older posts load automatically (if >20 exist).
- TL0 account: `/feed` shows the stream, NO composer. Logged out: same.
- `vc_feed_enabled` off → `/feed` bounces to /latest.

## 8. Full-page load (v0.2.1)
Type https://community.victoriouschristians.com/feed directly in the URL
bar (or open in a fresh tab): the wall must render — no 404. This is the
shared-link path; it matters more than in-app navigation for a feed.
Console probe should now show modules:
    Object.keys(requirejs.entries).filter(k => k.includes("vc-feed"))

## 9. Program cards (v0.3.0 + plugin patches) — Gate V2
Prereq: feed-cards patches applied to scripture-campaign and trivia, rebuilt.
    curl -s -b <session> https://community.victoriouschristians.com/scripture-campaign/feed-cards.json
    curl -s -b <session> https://community.victoriouschristians.com/trivia/feed-cards.json
Anon curl returns { "protocol": 1, "cards": [] } — never an error.
On /feed as a member, with an active campaign run (open scene) or live
trivia contest: the card appears interleaved with >= feed_card_spacing
member posts between program cards. Dismiss (x) removes it and it stays
gone on reload (per_event: returns when the NEXT scene/contest arrives).
Walk the scene / enter the contest, reload: card state flips to progress
wording. Disable either program plugin: its card vanishes, wall unharmed
(ADR-F3 proof). Long posts now clamp at ~420px with Show more.

## 10. Thread panel + rail (v0.4.0) — Gate V4 preview
- Heart a card on the wall: the like registers and the page DOES NOT
  navigate (the composedPath fix). Reply icon still navigates.
- Click a card body: slide-over thread panel opens at /feed/t/<id> —
  OP on top, reply box DIRECTLY under it, replies below. Browser back
  closes the panel. Direct URL entry of /feed/t/<id> works (server route).
- Reply from the panel: appears immediately; open the classic topic via
  "Open full discussion" — the reply is there (one thread, two skins).
- Right rail (>=1100px viewport): campaign module (when a run is active),
  trivia module, Online now avatars (whos-online plugin), Latest
  discussions linking into the panel. Disable any source: its module
  vanishes, rail unharmed. Rail hides on narrow viewports.

## 11. Canvas claim + X chrome (v0.4.1)
- Console module count: Object.keys(requirejs.entries)
    .filter(k => k.includes("vc-feed")).length  -> 14 on v0.4.1.
- On /feed: <body> carries class vc-feed-active; navigate to /latest —
  class gone, site width back to stock (route-scoped claim proof).
- Rail visible beside the stream on wide screens even WITH the core left
  sidebar open; on narrow screens the rail stacks BELOW the stream
  (never silently absent).
- Thread panel header reads "<- Post" (X pattern).
- Open a feed topic's classic page: "<- Feed" link above the post stream;
  non-feed-category topics show nothing.

## 12. Center-column thread view + threading (v0.5.0)
- Click a card: the thread REPLACES the stream (rail persists, no panel,
  no backdrop). <- Post returns to the feed with scroll position sane.
- Reply to the OP from the box; then press Reply on someone's reply:
  a "Replying to @user x" chip appears; post it. The reply lands
  INDENTED under that person (two-level threading). Open the classic
  view: the same post appears at the chronological end with the
  "in reply to" indicator — one linear topic, two geometries.
- Deep chains: reply to a sub-reply — it flattens up under the same
  top-level ancestor (X behavior).
- Rail now shows Top this week (likes) and Trending tags alongside
  Latest; each vanishes gracefully when empty.

## 13. The editor + the sacred timeline (v0.6.0)
EDITOR (composer and thread reply box are the same engine now):
- Toolbar renders: bold/italic/link/quote/lists etc. Type @br... — user
  autocomplete appears; type :pra... — emoji autocomplete; # — hashtags.
- If Discourse AI helper is enabled for your group: the AI button
  appears IN the toolbar (registered via api.onToolbarCreate — same
  path as the main composer). Select text -> AI helper options.
- Image button uploads via /uploads.json and inserts image markdown;
  post it; the image renders on the wall card.
- Ctrl+Enter posts. Short content shows "N more characters" hint and a
  disabled Post button — no error popups.
TIMELINE:
- Scroll deep, open a thread, press <- Post: return is INSTANT, scroll
  held, no refetch flash. Like an OP inside the thread, go back: the
  card's heart/count already agree. Reply in thread, go back: card's
  reply count bumped.

## 14. Editor frame corrections (v0.6.1)
- Composer placeholder reads "What is the Lord teaching you today?";
  thread box reads "Post your reply" — no raw vc_feed.* keys anywhere.
- The typing area spans the FULL width of the card: no side-by-side
  preview pane in the feed composer or the thread reply box.
- Toolbar, mentions/emoji/hashtag autocomplete, AI helper button (when
  enabled), image upload, Ctrl+Enter — all unchanged from v0.6.0.

## 15. Editor mechanics (v0.6.2)
- Type in the composer: the Post button ENABLES once past min length;
  click elsewhere — the text STAYS. No "[object Event]" ever.
- The MD/A mode toggle is GONE from the wall's toolbar (markdown engine
  pinned); the docked/classic composer keeps the member's own preference.
- Image button -> pick a file -> spinner -> image markdown appears in
  the box at the end of your text -> Post -> image renders on the card.
- Ctrl+Enter posts. Same checks in the thread reply box.

## 16. Live button, mobile containment, rail growth (v0.6.3)
- Type in the composer: Post enables the MOMENT min length is reached —
  no blur needed. Delete below min: it disables again live.
- Mobile (or narrow window): toolbar wraps to a second row inside the
  card; Post button fully visible; nothing scrolls horizontally.
- Rail: Hot this week (top weekly topics -> thread view) and Our
  community (members / posts / active 7d) join the existing modules.
- Polish: cards lift subtly on hover; composer border glows on focus;
  action icons gain round hover targets; oversized images cap at 480px.

## 17. Core composer + X geometry (v0.7.0)
COMPOSER:
- Desktop: click the "What is the Lord teaching you today?" trigger —
  Discourse's REAL docked composer opens, category locked to Community
  Feed, title/category/tags row HIDDEN. Toolbar shows Upload, GIF,
  Ask AI, fullscreen — every inherent feature.
- Write a body (no title anywhere) -> Create Topic enables -> submit.
  Open the created topic: it has a machine title from your first line.
- Drafts: type, close with Save-and-close, reopen the trigger — the
  draft returns (core behavior, free).
- Mobile: the trigger row is gone; a round compose FAB floats bottom-
  right; tapping it opens the same composer.
- Compose from /latest into a NON-wall category: title field present
  as stock — the wall manners apply ONLY to wall categories.
GEOMETRY:
- Feed posts are full-width rows with hairline dividers — no borders,
  no cages; hover tints the row. Avatars 40px. Detail row shows
  reply / like / views (views from real topic data).
- Rail modules are filled rounded blocks, no outlines.
NOTE: after Create Topic, core navigates to the new topic page; the
"<- Feed" link returns, and the wall shows the new-post pill. If we
want post-in-place instead, that is the next refinement — say so.

## 18. Feed -> topic direct (v0.7.1)
- Click a feed row (or Show more): you land on the CLASSIC topic page —
  full Discourse toolkit, docked composer for replies.
- "<- Feed" link at the top of wall-category topics returns to the feed:
  instant restore, scroll held (sacred timeline across classic pages).
- Rail Latest/Hot links go to topic pages directly.
- /feed/t/... no longer exists (route retired); old links 404 — none
  were ever surfaced to members.
