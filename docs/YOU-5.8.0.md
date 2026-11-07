# You consolidation — Header Navigation 5.8.0 candidate

Status: accepted for source publication on 2026-11-06. Product candidate af7e5419818bda7911bcd7f9a07710475c78655b; no production deployment. Parent: main d5309b4c5b7159d6c60b84f7a2e5de3319a67dc9 (5.7.2). AI 1.6.5 is unchanged.

## Behavior

You is one shared desktop/mobile dialog, grouped into Your activity, Your profiles, Account, and Your links. Standard Messages becomes Private messages; custom labels remain. Drafts shows the native positive draft count. Invitations is added only when the native current-user permission permits it; a configured invitation row, including a hidden alias, suppresses the automatic row.

Account controls embeds Discourse's native profile-menu content, preserving its permission checks and registered contributions. Native links and logout/anonymous departures pass through the existing AI draft guard. Session-ending actions are blocked while a native composer is open; finish or close it first. Presence/status/pause actions keep native behavior. Native dialogs open after You closes.

The native avatar/notifications menu, Chat, hamburger/sidebar and desktop destination menus remain. Existing destination settings and visibility rules are used, not rewritten. Dating keeps the existing next-step contract. Community profile and native Summary provide access to profile statistics instead of an inline statistics strip.

`je_nav_you_enabled` defaults on. Disable it to restore the previous mobile identity panel and desktop avatar behavior. Browser rollback verified as an ordinary member: disabled restores the previous identity panel and desktop behavior; re-enabled restores grouped You.

## Evidence

- 64 navigation tests pass, including eight new grouping/permission/draft/action cases. No AI changes.
- New panel/model ESLint clean; new panel/model/styles pass the exact-core Prettier configuration.
- Isolated Discourse core 821e9e2f9f94483a3be8d1e077cde0fd94970479 (2026.10.0-latest), optimized frontend, compiles candidate with Canvas and AI; all 33 existing theme settings retained.
- Ordinary member browser: desktop 1440x900, phone 390x844 and 320x568. Grouped You renders, content scrolls, account subview accessible, native Activity navigation works. Escape restores You focus. Native pause-notifications dialog opens with You closed.
- AI draft departure through native Account Activity: Keep editing retains the exact draft and editor focus; Discard and leave navigates. No AI request or message submitted. Disposable draft discarded; preview tab closed and viewport reset.
- Independent verifier found pending-request fallback and template-variable-shadowing issues during development; both fixed. After limits reset, verifier independently reran all64 tests and accepted exact product commit af7e5419818bda7911bcd7f9a07710475c78655b for source publication. No remaining source blockers.

## Acceptance limits

Independent source acceptance and browser rollback are complete. Conditional status, anonymous, invited/staff/plugin contribution combinations, logout, physical phones/Safari, dark appearance, and the complete installed production stack have not been runtime-tested. Native permission rendering is reused and permission/model cases are tested, but this is not full live parity evidence. No native controls may be retired on this evidence.

Brian owns updating the existing Header Mega Nav component250 from main and installed-device acceptance. Astra owns follow-up. Disable je_nav_you_enabled if a rollback is needed; retain native controls.

## Resume

Source: C:/claude-workspace/components/header-navigation. Run `node --test test/*.cjs test/*.mjs`. Isolated rootful Podman container: vc-discourse-test-20260909; core /tmp/vc-production-core, database vc_core_20261028, nav theme37, Canvas36, AI38. Candidate staging /tmp/vc-you-nav includes a temporary node_modules link and lint config; never copy these back into source. Compilation script /tmp/compile-you.rb. Local preview port4300. Do not touch production settings.
