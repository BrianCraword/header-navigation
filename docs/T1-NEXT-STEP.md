# T1 next-step delivery

Status: final candidate tested locally; independent review recorded in the project delivery evidence. Not deployed. Brian controls deployment.

## Data and ownership

The Matchmaking GET projection reads only the current session user, consent, own profile, identity flags, interview metadata, topic visibility and configured AI agent/group availability. It emits only schema version, stage, translated label, local action URL, blocked reason, session state and optional-identity flag. Responses are private/no-store. Selector parameters are rejected. No provider call, profile/session/group write, topic creation, identity grant or AI prompt mutation occurs in this endpoint.

Existing grant-consent, profile editors, identity workflows, interview POST and verification jobs remain the writers. The endpoint is presentation guidance, never an authorization token: all existing protected actions retain their own enforcement. Earlier privacy protections and hidden-group rules are preserved.

## Client invariants

Journey, Feed and You use the same current-account projection. Concurrent consumers share a read. Explicit refresh starts a new request generation; old responses cannot restore old actions. A missing or failed response never becomes an inferred interview invitation. Refresh clears actionable stale state. No projection is stored persistently. Separate profile/identity hydration has its own generation and cannot override a newer projection. Polling does not overlap requests and stops at its limit or component teardown.

## Rollout and rollback

Install Matchmaking 0.21.0 before Feed 0.40.0 and Header Navigation 5.3.0. Enable vc_next_step_contract_enabled only after integrated member checks. Switch-off gives neutral companion links; it does not roll back Journey. For full rollback restore Matchmaking 0.20.2, Feed 0.39.1 and navigation 5.2.0. No new persisted state needs conversion. Preserve site settings and prior artifacts before Brian updates the site.

## Acceptance record

Final candidate checks (2026-10-16):

- Matchmaking next-step request suite: 23 examples, 0 failures (seed 3461).
- Client lifecycle and navigation checks: 35 passed (15 Matchmaking, 20 navigation).
- Chromium Journey QUnit: 5 passed (seed xMiPorIX), including consent refresh, supporting-model retry, pending lifecycle and resume without creation.
- Chromium Feed QUnit: 2 passed (seed AKbF0UOM), using the actual shared service, private-card revalidation and hold removal.
- Full server comparison: candidate 367 examples / 78 failures; unchanged baseline 344 / 78. The same 78 descriptions fail in both, with zero added failures. This is not a green inherited suite. Missing Follow integration and older lifecycle/eligibility expectations remain baseline limitations.
- Existing Feed upload suite also fails all seven cases on unchanged baseline. Exploratory test edits were discarded; no upload product changes are included.
- Installed local VC-Canvas and candidate navigation: ordinary synthetic member consent advances to Profile, reload preserves that stage, mobile Feed → You shows “Complete your dating profile” and opens the same Journey. Screenshots captured with real styles. No production data or external identity/AI calls were used.

Runtime: isolated WSL/Podman Discourse snapshot, Ruby 3.4.10, Node 22.23.2, Chromium 152. The core Git revision is a synthetic import, not upstream provenance. Preview uses isolated `vc_t1_preview`, disabled outgoing email, and explicitly enabled mobile navigation. Production configuration, physical devices and actual identity-provider/interview execution are not certified by these local checks.

Rollback baselines: Matchmaking `6db41fb0287514dbee477088c9e89382eec75b29` (0.20.2), Feed `4492e46056f03eb46015752f8be7d8d75cce48f8` (0.39.1), navigation `e1a0607ebcb5da5ba97ab90da36a2d0bdd3d81c7` (5.2.0). Git delivery does not deploy the site; Brian owns installation and live smoke checks.


Final installed-theme regression: desktop Feed Explore → Dating → browser Back passed; injected HTTP 503 produces the intended neutral “Open dating” link, then reload restores the profile action. Phone-width reload and You refresh with an injected review response render the hold without a link. No browser errors on the final run. Hold injection proves UI response handling, not a real stored verification transition.

That same full-page regression first reproduced an existing Feed cached-return assertion (`refreshing` read and written during construction). Feed 0.40.0 now defers that refresh until rendering completes, with teardown/selection guards. The exact previously failing scenario passed after rebuilding, and focused Feed QUnit again passed 2/2 (seed zUEsmZWD). No Matchmaking server code changed after its final tests.

Delivery parts: Matchmaking server projection, client service/Journey, settings/locales, specs and docs changed; Feed consumers, cached-return lifecycle, tests/dependency metadata and docs changed; navigation You action, version and docs changed. Database schema, identity provider, AI prompts, site theme source and production settings were not changed. Existing writes and endpoint authorization remain in their prior owners.
