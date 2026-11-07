# Header Navigation 5.8.1 — native private-message unread badge

The configured messages_unread badge now matches Discourse's native Messages tab: unread private-message notifications, not total inbox items, unseen/new messages, Chat messages, or all notifications. The previous new_personal_messages_notifications_count can be zero after notifications are seen while unread private-message notifications remain.

Uses site.notification_types.private_message and reactive currentUser.get reads of grouped_unread_notifications, including the same legacy grouped fallback as native core821e9e2. Desktop and mobile pass the site service. Static labels,99+ cap, zero behavior, visibility gates, custom configuration, Chat, other counters and native controls are preserved. No settings migration, background polling or notification writes are introduced.

Verified 2026-11-07:68 tests pass, independently rerun by verifier; source review accepted with runtime gates now passed. Isolated exact-core compilation preserves34 saved settings. Ordinary member fixture with unread2/new0 renders Messages2; reload retains2; opening/closing You retains2; native notification broadcasts clear and restore the badge without reload. Synthetic local notification records only: no message/email sent, records removed and original seen position restored. Preview closed and viewport reset.

The saved isolated configuration already uses messages_unread. Current production settings were not freshly inspected; the October observation is consistent with this counter mismatch but is not a fresh live diagnosis. Sites with static/unconfigured badges retain those choices. Physical-device, group inbox and full production-stack acceptance remain outside this bounded fix. No notification bell or native-control retirement.

Independent reviewed product SHA256: core3fa3133d900237b368127912d836e1df59ee196df12723599d2e7a28dee191e6; desktop71b5918d80a282b7341ff193eee8c93f69b97b97f5b822dad107c15383256830; mobile4cd850c43bcad402f7a64712a5501a0bb5a757f0a208dc18f9ff83ca791e2001.

Brian owns updating existing Header Mega Nav component250 from main; astra owns follow-up. No production deployment. Roll back the component to5.8.0 if necessary; no data/configuration migration to undo.
