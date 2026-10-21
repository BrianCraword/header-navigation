# Header Navigation 5.5.0 candidate

Enable je_nav_unified_navigation_enabled on a test site to use the configured global menu on Feed and ordinary pages. It takes precedence over je_nav_focus_companion_enabled without rewriting either destinations or the old setting. The desktop Home brand link is suppressed; the site logo continues to own Home. The mobile list retains its configured pin order, More/You, and access gates. AI composer suppression remains unchanged; pair with AI Conversations Next 1.1.0 for its top toolbar.

Default off. Rollback: turn this switch off to restore the previous projection and brand behavior. No home redirect, logo destination, Feed content, Canvas styling, member groups or database migration changes. This stage does not yet change mobile pins to the proposed Feed/AI/Matchmaking arrangement; that needs a reviewed configuration migration. Community Plaza retirement and shared homepage policy remain separate.

Validate Feed and standard routes as member/guest/staff, mobile and desktop, including transitions with menus open, composer open/close, interview suppression and all parent/child group gates. Validate with Canvas 2.9 and the AI toolbar before production enablement. Brian owns deployment.

## Validation (2026-10-19)
42 Node tests pass across this component and AI Conversations Next, including the new Feed/standard source and rollback checks. Existing nested group, surface, i18n and projection regressions pass. git diff --check passes.

In the isolated local Discourse 2026.9.0-latest test database, Canvas 2.9.0 + Navigation 5.5.0 + AI Next 1.1.0 imported and compiled JavaScript successfully; combined common/desktop/mobile stylesheet requests completed with no theme field errors. Both opt-in switches were enabled for that check; imported database records were rolled back. This is actual Discourse compilation, not browser rendering. Live core is newer (2026.10), and phone/draft/lifecycle acceptance remains pending.

Independent verifier found no concrete blocker for the disabled candidate. Desktop still closes its dropdown on Feed-class changes, which is intentional harmless route-close behavior; only mobile's projection-specific close/reset is bypassed. Source review is not production enablement approval.
