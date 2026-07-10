# discourse-vc-feed

The wall at the heart of Victorious Christians — title-less microposting into a
stream that unifies member posts and (Phase 2) program cards from
discourse-scripture-campaign and discourse-bible-trivia.

Architecture: `PROJECT-INSTRUCTIONS-VC-FEED.md` (the convergence blueprint).
Governing rule — **ADR-F1**: new surfaces over core data, never modification of
core surfaces. Disable this plugin and a stock, upgradeable Discourse remains.

## Phase 1 surface (this version, v0.2.0)

| Verb | Route | Notes |
|---|---|---|
| Write | `POST /vc-feed/posts` | body `raw` only; title machine-generated (ADR-F4); wraps `PostCreator` so ALL core defenses apply |
| Read | `GET /vc-feed/stream.json?before=<topic_id>` | union of `vc_feed_categories`, creation-ordered, keyset-paginated, first-post bodies + like state inline |
| Live | MessageBus `/vc-feed/stream` | tiny payload on topic create; the pill refetches the head |
| Walk | `/feed` | the wall itself: composer, stream, inline like, live pill, infinite scroll |

## Install

Standard plugin install — add to `app.yml` hooks and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/BrianCraword/discourse-vc-feed.git
```

`./launcher rebuild app` (then the habitual `docker system prune -f`).

## Settings

- `vc_feed_enabled` — master switch (default off).
- `vc_feed_categories` — the wall is the UNION of these; FIRST entry is the
  compose target. Default `1` (Community Feed).
- `vc_feed_post_allowed_groups` — default TL1 auto group. TL0 reads, TL1 writes.
- `vc_feed_title_length` — display budget for generated titles (default 50).
- `feed_card_spacing` — reserved for Phase 2 interleaving.

## Verification

See `docs/verification-commands.md` — Gate V1 checks runnable the moment the
rebuild finishes. Specs: `bundle exec rspec plugins/discourse-vc-feed/spec`
inside a dev environment.

## Roadmap (per blueprint)

- Phase 2: `feed-cards.json` protocol consumers; deterministic book-tagging
  post-processor (bible-tagger, server-side).
- Phase 3: repost verb (`vc_feed_reposts`), quote-repost via
  `referenced_topic_id`, notifications.
- Phase 4/5: theme rails + homepage flip; slide-over thread panel; JE deploy.
